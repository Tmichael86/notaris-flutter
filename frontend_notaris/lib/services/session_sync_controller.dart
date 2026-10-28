import 'dart:async';

import 'periodic_sync_runner.dart';

/// Coordinates sync triggers for an authenticated app session.
class SessionSyncController {
  SessionSyncController({
    required Future<void> Function() synchronize,
    this.onInitialSyncResult,
    Duration interval = const Duration(minutes: 5),
    this.resumeCooldown = const Duration(seconds: 60),
    DateTime Function()? clock,
  }) : _synchronize = synchronize,
       _clock = clock ?? DateTime.now {
    _periodicRunner = PeriodicSyncRunner(
      onTick: _runPeriodicSafely,
      interval: interval,
    );
  }

  final Future<void> Function() _synchronize;
  final void Function(Object? error)? onInitialSyncResult;
  final Duration resumeCooldown;
  final DateTime Function() _clock;
  late final PeriodicSyncRunner _periodicRunner;

  bool _started = false;
  bool _disposed = false;
  DateTime? _lastSyncAttemptAt;

  void start() {
    if (_started || _disposed) return;
    _started = true;

    // Do not make users wait for the first periodic interval after login.
    unawaited(_runInitialSafely());
    _periodicRunner.start();
  }

  void onAppResumed() {
    if (!_started || _disposed) return;

    final lastAttempt = _lastSyncAttemptAt;
    if (lastAttempt != null &&
        _clock().difference(lastAttempt) < resumeCooldown) {
      return;
    }

    unawaited(_runSafely());
  }

  Future<void> _runInitialSafely() async {
    _lastSyncAttemptAt = _clock();
    try {
      await _synchronize();
      if (!_disposed) onInitialSyncResult?.call(null);
    } catch (error) {
      if (!_disposed) onInitialSyncResult?.call(error);
    }
  }

  Future<void> _runPeriodicSafely() async {
    if (_disposed) return;
    _lastSyncAttemptAt = _clock();
    await _runSafely();
  }

  Future<void> _runSafely() async {
    if (_disposed) return;
    _lastSyncAttemptAt = _clock();
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
