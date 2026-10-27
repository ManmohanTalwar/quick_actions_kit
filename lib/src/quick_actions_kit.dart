import 'dart:async';

import 'platform.dart';
import 'quick_actions_kit_bindings.dart';

/// One dynamic shortcut. [icon] is an iOS template asset / Android resource name.
final class ShortcutItem {
  const ShortcutItem({
    required this.type,
    required this.localizedTitle,
    this.localizedSubtitle,
    this.icon,
  });
  final String type;
  final String localizedTitle;

  /// iOS only; Android uses the title for both labels.
  final String? localizedSubtitle;
  final String? icon;

  Map<String, Object?> toJson() {
    if (type.trim().isEmpty ||
        localizedTitle.trim().isEmpty ||
        type.contains('\u0000') ||
        localizedTitle.contains('\u0000')) {
      throw ArgumentError(
        'Shortcut type and title must be nonempty and contain no NUL.',
      );
    }
    if (icon != null && !RegExp(r'^[A-Za-z0-9_]+$').hasMatch(icon!)) {
      throw ArgumentError.value(
        icon,
        'icon',
        'Use a native asset/resource name.',
      );
    }
    return {
      'type': type,
      'title': localizedTitle,
      'subtitle': localizedSubtitle,
      'icon': icon,
    };
  }
}

/// One app-wide owner of dynamic shortcuts and shortcut activation callbacks.
///
/// Call [initialize] early; replace the handler by calling it again. Delivery
/// is notification of navigation intent, never authorization for an action.
final class QuickActions {
  factory QuickActions() => _shared;
  QuickActions.withPlatform(this._platform);
  static final _shared = QuickActions.withPlatform(
    QuickActionsKitBindings.instance,
  );
  final QuickActionsPlatform _platform;
  StreamSubscription<String>? _subscription;
  void Function(String)? _handler;
  Future<void> _tail = Future<void>.value();

  Future<void> _serial(Future<void> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> initialize(
    void Function(String type) handler,
  ) => _serial(() async {
    _handler = handler;
    // Reassert delivery when the host remounts while retaining this isolate.
    _subscription ??= _platform.actions.listen((type) => _handler?.call(type));
    try {
      await _platform.invoke('listen');
    } catch (_) {
      await _subscription?.cancel();
      _subscription = null;
      _handler = null;
      rethrow;
    }
  });

  /// Atomically replaces dynamic shortcuts. Static/pinned shortcuts are separate.
  Future<void> setShortcutItems(List<ShortcutItem> items) {
    // Snapshot and validate before asynchronous work; caller mutation cannot race.
    final payload = items.map((item) => item.toJson()).toList(growable: false);
    final ids = payload.map((item) => item['type']).toSet();
    if (ids.length != payload.length) {
      throw ArgumentError('Shortcut types must be unique.');
    }
    return _serial(() => _platform.invoke('set', payload));
  }

  Future<void> clearShortcutItems() => _serial(() => _platform.invoke('clear'));

  /// Stops activation delivery; installed shortcuts remain until explicitly cleared.
  Future<void> dispose() => _serial(() async {
    _handler = null;
    await _subscription?.cancel();
    _subscription = null;
    await _platform.invoke('stop');
  });
}
