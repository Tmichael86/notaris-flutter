import '../database/app_database.dart';

/// Calendar-year activity from the business date of each local transaction.
class DashboardTransactions {
  DashboardTransactions(
    Iterable<Transaksi> transactions,
    int year,
    DateTime now,
  ) {
    final dated = transactions
        .where(
          (t) =>
              t.deletedAt == null &&
              _status(t) != 'dihapus' &&
              t.tanggalTransaksi?.toLocal().year == year,
        )
        .toList();
    final today = now.toLocal();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final monthly = List.filled(12, 0);
    final deadlines = <Transaksi>[];
    var completed = 0, inProgress = 0, newCount = 0, dueCount = 0;
    for (final t in dated) {
      monthly[t.tanggalTransaksi!.toLocal().month - 1]++;
      final status = _status(t);
      switch (status) {
        case 'selesai':
          completed++;
        case 'dalam proses':
          inProgress++;
        case 'baru':
          newCount++;
      }
      final deadline = t.tanggalJatuhTempo;
      if (deadline != null && (status == 'baru' || status == 'dalam proses')) {
        deadlines.add(t);
        if (deadline.isBefore(tomorrow)) dueCount++;
      }
    }

    dated.sort((a, b) {
      final byDate = b.tanggalTransaksi!.compareTo(a.tanggalTransaksi!);
      return byDate == 0 ? b.id.compareTo(a.id) : byDate;
    });
    deadlines.sort((a, b) {
      final byDate = a.tanggalJatuhTempo!.compareTo(b.tanggalJatuhTempo!);
      return byDate == 0 ? a.id.compareTo(b.id) : byDate;
    });
    total = dated.length;
    running = inProgress;
    due = dueCount;
    monthlyCounts = List.unmodifiable(monthly);
    statusCounts = List.unmodifiable([completed, inProgress, newCount]);
    recent = List.unmodifiable(dated.take(5));
    upcoming = List.unmodifiable(deadlines.take(5));
  }

  late final int total, running, due;
  late final List<int> monthlyCounts, statusCounts;
  late final List<Transaksi> recent, upcoming;

  static String _status(Transaksi t) => t.statusTransaksi.trim().toLowerCase();
}
