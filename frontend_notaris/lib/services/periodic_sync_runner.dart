import 'dart:async';

/// Runs a lightweight callback on a fixed interval while the app is active.
///
/// The default interval is intentionally hardcoded for the first iteration.
/// User-configurable settings can be introduced during hardening.
class PeriodicSyncRunner {
  PeriodicSyncRunner({
    required Future<void> Function() onTick,
    this.interval = const Duration(minutes: 5),
  }) : _onTick = onTick;

  final Future<void> Function() _onTick;
  final Duration interval;
  Timer? _timer;

  bool get isRunning => _timer?.isActive ?? false;

  void start() {
    if (isRunning) return;
    _timer = Timer.periodic(interval, (_) {
      unawaited(_runTick());
    });
  }

  Future<void> _runTick() async {
    try {
      await _onTick();
    } catch (_) {
      // SyncCoordinator reports the failure through its status provider.
      // A failed tick must not terminate future scheduled attempts.
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
