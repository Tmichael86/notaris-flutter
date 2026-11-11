import '../database/app_database.dart';

// REAL fields from v22 and the current cloud contract can represent these
// integers exactly. Older fractional values are never silently rounded.
const maxExactRupiah = 9007199254740991;

int exactRupiah(num value, String label) {
  if (!value.isFinite ||
      value < 0 ||
      value > maxExactRupiah ||
      value != value.toInt()) {
    throw ArgumentError('$label harus berupa rupiah bulat yang valid.');
  }
  return value.toInt();
}

bool isActivePayment(TransaksiRiwayatPembayaran row) =>
    row.status == 1 && row.deletedAt == null;

int paymentRupiah(TransaksiRiwayatPembayaran row) {
  final mirror = exactRupiah(row.nominal, 'Nominal pembayaran');
  if (mirror == 0 ||
      (row.nominalRupiah != null && row.nominalRupiah != mirror)) {
    throw StateError('Nominal pembayaran historis perlu ditinjau.');
  }
  return row.nominalRupiah ?? mirror;
}

int totalActiveRupiah(Iterable<TransaksiRiwayatPembayaran> payments) {
  var total = 0;
  for (final payment in payments.where(isActivePayment)) {
    total = exactRupiah(total + paymentRupiah(payment), 'Total pembayaran');
  }
  return total;
}

class TransactionPaymentStatement {
  TransactionPaymentStatement(this.transaction, this.payments) {
    try {
      billed = exactRupiah(transaction.total, 'Total tagihan');
      paid = totalActiveRupiah(payments);
    } on ArgumentError {
      issue = 'Tagihan atau nominal historis bukan rupiah bulat yang valid.';
    } on StateError {
      issue = 'Nominal pembayaran historis perlu ditinjau.';
    }
  }

  final Transaksi transaction;
  final List<TransaksiRiwayatPembayaran> payments;
  int? billed;
  int? paid;
  String? issue;
  int? get remaining => billed == null || paid == null ? null : billed! - paid!;
}
