/// Retained for old callers, without scheduling any write-capable timer.
/// An arbitrary callback or interval cannot authorize automatic publication.
class PeriodicSyncRunner {
  PeriodicSyncRunner({
    required Future<void> Function() onTick,
    this.interval = const Duration(minutes: 5),
  });

  final Duration interval;
  bool get isRunning => false;
  void start() {}
  void dispose() {}
}
