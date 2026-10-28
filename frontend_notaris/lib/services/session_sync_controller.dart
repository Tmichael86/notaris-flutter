import 'dart:async';

import 'periodic_sync_runner.dart';

/// Coordinates sync triggers for an authenticated app session.
class SessionSyncController {
  SessionSyncController({
    required Future<void> Function() synchronize,
    this.onInitialSyncResult,
    Duration interval = const Duration(minutes: 5),
  }) : _synchronize = synchronize,
       _periodicRunner = PeriodicSyncRunner(
         onTick: synchronize,
         interval: interval,
       );

  final Future<void> Function() _synchronize;
  final void Function(Object? error)? onInitialSyncResult;
  final PeriodicSyncRunner _periodicRunner;

  bool _started = false;
  bool _disposed = false;

  void start() {
    if (_started || _disposed) return;
    _started = true;

    // Do not make users wait for the first periodic interval after login.
    unawaited(_runInitialSafely());
    _periodicRunner.start();
  }

  void onAppResumed() {
    if (!_started || _disposed) return;
    unawaited(_runSafely());
  }

  Future<void> _runInitialSafely() async {
    try {
      await _synchronize();
      onInitialSyncResult?.call(null);
    } catch (error) {
      onInitialSyncResult?.call(error);
    }
  }

  Future<void> _runSafely() async {
    try {
      await _synchronize();
    } catch (_) {
      // SyncCoordinator records status; future triggers should still run.
    }
  }

  void dispose() {
    _disposed = true;
    _periodicRunner.dispose();
  }
}
