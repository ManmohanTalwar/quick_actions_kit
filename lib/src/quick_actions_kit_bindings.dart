import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'lifecycle_stub.dart'
    if (dart.library.ui) 'lifecycle_native.dart'
    as lifecycle;

import 'platform.dart';

typedef _Dispatch = Void Function(Int64, Int32, Pointer<Utf8>);
typedef _Init = Int32 Function(Int64, Int32);
typedef _Request = Int32 Function(Int64, Pointer<Utf8>);

// One dispatcher per main isolate. Native registers its slot before retaining it.
final _dispatcher = Pointer.fromFunction<_Dispatch>(_dispatch);
void _dispatch(int token, int kind, Pointer<Utf8> payload) {
  // Never let an exception escape an FFI callback. Native retains the bytes only
  // for this synchronous invocation, so decode/copy before returning.
  QuickActionsKitBindings.instance.deliver(token, kind, payload.toDartString());
}

final class QuickActionsKitBindings implements QuickActionsPlatform {
  QuickActionsKitBindings._();
  static final instance = QuickActionsKitBindings._();
  static void loadSymbols() => instance._load();
  bool _loaded = false;
  late final int Function(int, Pointer<Utf8>) _request;
  late final int Function(int, int) _initialize;
  int _nextToken = DateTime.now().microsecondsSinceEpoch;
  final _pending = <int, Completer<void>>{};
  final _actions = StreamController<String>.broadcast();
  @override
  Stream<String> get actions => _actions.stream;

  void _load() {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    if (_loaded) {
      _checkStatus(_initialize(_dispatcher.address, 0));
      return;
    }
    final library = Platform.isIOS
        ? DynamicLibrary.process()
        : DynamicLibrary.open('libquick_actions_kit.so');
    final initialize = library.lookupFunction<_Init, int Function(int, int)>(
      'DNQuickActionsKitInitialize',
    );
    final request = library
        .lookupFunction<_Request, int Function(int, Pointer<Utf8>)>(
          'DNQuickActionsKitRequest',
        );
    _checkStatus(initialize(_dispatcher.address, 1));
    _initialize = initialize;
    _request = request; // Commit only after success, so failed loads can retry.
    _loaded = true;
    lifecycle.registerResumeListener(_load);
  }

  void _checkStatus(int status) {
    if (status != 0) {
      throw QuickActionsException(
        'unsupported_runtime',
        'Native initialization failed (status $status); required lifecycle or callback-safety APIs are unavailable.',
      );
    }
  }

  @override
  Future<void> invoke(String operation, [Object? payload]) async {
    _load();
    if (!_loaded) {
      throw UnsupportedError(
        'quick_actions_kit supports iOS and Android only.',
      );
    }
    final token = ++_nextToken;
    final completion = Completer<void>();
    _pending[token] = completion;
    final pointer = jsonEncode({
      'operation': operation,
      'payload': payload,
    }).toNativeUtf8();
    try {
      if (_request(token, pointer) != 0) {
        throw const QuickActionsException(
          'native_unavailable',
          'The native request could not be queued.',
        );
      }
      await completion.future.timeout(const Duration(seconds: 15));
    } finally {
      calloc.free(pointer);
      _pending.remove(token);
    }
  }

  void deliver(int token, int kind, String payload) {
    try {
      if (kind == 1) {
        final type = jsonDecode(payload);
        if (type is String && type.isNotEmpty) _actions.add(type);
        return;
      }
      final completion = _pending[token];
      if (completion == null) return; // timed out or belongs to an old isolate
      final result = jsonDecode(payload) as Map<String, dynamic>;
      if (result['error'] case final Map<String, dynamic> error) {
        completion.completeError(
          QuickActionsException(
            error['code'] as String,
            error['message'] as String,
          ),
        );
      } else {
        completion.complete();
      }
      _pending.remove(token);
    } catch (error, stack) {
      final completion = _pending.remove(token);
      if (completion != null && !completion.isCompleted) {
        completion.completeError(error, stack);
      }
      // A malformed event is discarded; callbacks must never throw into native.
    }
  }
}
