import 'dart:async';

import 'package:quick_actions_kit/quick_actions_kit.dart';
import 'package:quick_actions_kit/src/platform.dart';
import 'package:test/test.dart';

final class FakePlatform implements QuickActionsPlatform {
  final controller = StreamController<String>.broadcast();
  final calls = <(String, Object?)>[];
  String? coldAction;
  Object? failure;
  Completer<void>? gate;
  @override
  Stream<String> get actions => controller.stream;
  @override
  Future<void> invoke(String operation, [Object? payload]) async {
    calls.add((operation, payload));
    if (gate != null) await gate!.future;
    if (failure != null) throw failure!;
    if (operation == 'listen' && coldAction != null) {
      controller.add(coldAction!);
      coldAction = null;
    }
  }
}

void main() {
  late FakePlatform platform;
  late QuickActions actions;
  setUp(() {
    platform = FakePlatform();
    actions = QuickActions.withPlatform(platform);
  });
  tearDown(() async {
    await platform.controller.close();
  });

  test(
    'cold event is received even when native delivers during initialize',
    () async {
      platform.coldAction = 'compose';
      final received = <String>[];
      await actions.initialize(received.add);
      await Future<void>.delayed(Duration.zero);
      expect(received, ['compose']);
    },
  );
  test(
    'host remount refreshes native delivery without duplicate subscriptions',
    () async {
      final old = <String>[], current = <String>[];
      await actions.initialize(old.add);
      platform.coldAction = 'queued during host remount';
      await actions.initialize(current.add);
      platform.controller.add('search');
      await Future<void>.delayed(Duration.zero);
      expect(old, isEmpty);
      expect(current, ['queued during host remount', 'search']);
      expect(platform.calls.where((c) => c.$1 == 'listen'), hasLength(2));
    },
  );
  test('repeated user taps are not incorrectly deduplicated', () async {
    final received = <String>[];
    await actions.initialize(received.add);
    platform.controller
      ..add('compose')
      ..add('compose');
    await Future<void>.delayed(Duration.zero);
    expect(received, ['compose', 'compose']);
  });
  test('dispose stops delivery without clearing installed shortcuts', () async {
    final received = <String>[];
    await actions.initialize(received.add);
    await actions.dispose();
    platform.controller.add('late');
    await Future<void>.delayed(Duration.zero);
    expect(received, isEmpty);
    expect(platform.calls.map((c) => c.$1), ['listen', 'stop']);
    await actions.initialize(received.add);
    platform.controller.add('again');
    await Future<void>.delayed(Duration.zero);
    expect(received, ['again']);
  });
  test('failed registration cleans up and can be retried', () async {
    platform.failure = const QuickActionsException(
      'unsupported_runtime',
      'missing hook',
    );
    final received = <String>[];
    await expectLater(
      actions.initialize(received.add),
      throwsA(isA<QuickActionsException>()),
    );
    platform.controller.add('not registered');
    await Future<void>.delayed(Duration.zero);
    expect(received, isEmpty);
    platform.failure = null;
    await actions.initialize(received.add);
    platform.controller.add('working');
    await Future<void>.delayed(Duration.zero);
    expect(received, ['working']);
  });
  test('malformed item or duplicate id does not reach native', () {
    for (final item in [
      const ShortcutItem(type: '', localizedTitle: 'A'),
      const ShortcutItem(type: 'a', localizedTitle: '  '),
      const ShortcutItem(type: 'a', localizedTitle: 'A', icon: '../private'),
    ]) {
      expect(() => actions.setShortcutItems([item]), throwsArgumentError);
    }
    const item = ShortcutItem(type: 'a', localizedTitle: 'A');
    expect(() => actions.setShortcutItems([item, item]), throwsArgumentError);
    expect(platform.calls, isEmpty);
  });
  test('payload preserves Unicode, subtitle and resource names', () async {
    await actions.setShortcutItems([
      const ShortcutItem(
        type: 'compose_📝',
        localizedTitle: 'नया पोस्ट 📝',
        localizedSubtitle: 'Créer',
        icon: 'ic_compose',
      ),
    ]);
    expect(platform.calls.single.$2, [
      {
        'type': 'compose_📝',
        'title': 'नया पोस्ट 📝',
        'subtitle': 'Créer',
        'icon': 'ic_compose',
      },
    ]);
  });
  test('caller list mutation cannot change an enqueued update', () async {
    final items = [const ShortcutItem(type: 'a', localizedTitle: 'A')];
    final update = actions.setShortcutItems(items);
    items.clear();
    await update;
    expect(platform.calls.single.$2, hasLength(1));
  });
  test('replace then clear are serialized at the platform boundary', () async {
    platform.gate = Completer<void>();
    final first = actions.setShortcutItems([
      const ShortcutItem(type: 'a', localizedTitle: 'A'),
    ]);
    final second = actions.clearShortcutItems();
    await Future<void>.delayed(Duration.zero);
    expect(platform.calls.map((c) => c.$1), ['set']);
    platform.gate!.complete();
    await Future.wait([first, second]);
    expect(platform.calls.map((c) => c.$1), ['set', 'clear']);
  });
  test(
    'native failure propagates and does not poison subsequent commands',
    () async {
      platform.failure = const QuickActionsException(
        'rate_limited',
        'try later',
      );
      await expectLater(
        actions.clearShortcutItems(),
        throwsA(
          isA<QuickActionsException>().having(
            (e) => e.code,
            'code',
            'rate_limited',
          ),
        ),
      );
      platform.failure = null;
      await actions.clearShortcutItems();
      expect(platform.calls, hasLength(2));
    },
  );
  test('registrant is harmless on unsupported desktop test host', () {
    expect(QuickActionsKitBindings.loadSymbols, returnsNormally);
  });
}
