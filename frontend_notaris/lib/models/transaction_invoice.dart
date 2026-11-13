class TransactionInvoice {
  TransactionInvoice({
    required this.number,
    required this.domain,
    required this.applicant,
    required this.address,
    required this.responsibleStaffName,
    required this.transactionDate,
    required this.printDate,
    required this.subtotal,
    required this.discount,
    required this.billed,
    required this.paid,
    required List<InvoiceJob> jobs,
    required List<InvoicePayment> payments,
  }) : jobs = List.unmodifiable(jobs),
       payments = List.unmodifiable(payments);

  final String number;
  final String domain;
  final String applicant;
  final String? address;
  final String? responsibleStaffName;
  final DateTime? transactionDate;
  final DateTime printDate;
  final int subtotal;
  final int discount;
  final int billed;
  final int paid;
  final List<InvoiceJob> jobs;
  final List<InvoicePayment> payments;

  int get remaining => billed - paid;
  bool get isPaid => remaining == 0;
}

class InvoiceJob {
  const InvoiceJob(this.name, this.serviceFee, this.additionalFee, this.total);

  final String name;
  final int serviceFee;
  final int additionalFee;
  final int total;
}

class InvoicePayment {
  const InvoicePayment(this.date, this.method, this.amount);

  final DateTime date;
  final String method;
  final int amount;
}

class TransactionInvoiceUnavailable implements Exception {
  const TransactionInvoiceUnavailable(this.message);

  final String message;
}
