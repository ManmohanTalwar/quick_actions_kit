/// A native failure. An unsuccessful mutation never reports success.
final class QuickActionsException implements Exception {
  const QuickActionsException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'QuickActionsException($code): $message';
}

/// Internal boundary used by the native adapter and behavioural tests.
abstract interface class QuickActionsPlatform {
  Stream<String> get actions;
  Future<void> invoke(String operation, [Object? payload]);
}
