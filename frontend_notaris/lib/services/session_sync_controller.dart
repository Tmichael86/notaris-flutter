/// Compatibility boundary for old lifecycle callers. Global automatic sync
/// has no approved activation contract. The supplied callback is NEVER retained
/// or invoked, and no timer/microtask is registered, even after reconnection.
class SessionSyncController {
  SessionSyncController({
    required Future<void> Function() synchronize,
    this.onInitialSyncResult,
    Duration interval = const Duration(minutes: 5),
    Duration resumeCooldown = const Duration(seconds: 60),
    DateTime Function()? clock,
  });

  final void Function(Object? error)? onInitialSyncResult;
  bool _disposed = false;
  bool _started = false;

  void start() {
    if (_disposed || _started) return;
    _started = true;
    onInitialSyncResult?.call(const AutomaticSyncDisabled());
  }

  void onAppResumed() {}

  void dispose() => _disposed = true;
}

class AutomaticSyncDisabled implements Exception {
  const AutomaticSyncDisabled();
  @override
  String toString() =>
      'DISABLED_BY_POLICY: Sinkronisasi otomatis/global dinonaktifkan.';
}
