import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf;

import '../models/transaction_invoice.dart';
import '../models/transaction_payments.dart';

const _maroon = PdfColor.fromInt(0xff6e2331);
const _muted = PdfColor.fromInt(0xff544b4d);
const _tint = PdfColor.fromInt(0xfff4eaec);
const _line = PdfColor.fromInt(0xffe4dadd);

Future<Uint8List> renderTransactionInvoice(TransactionInvoice invoice) async {
  final regular = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
  final bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
  final regularGlyphs = TtfParser(regular).charToGlyphIndexMap;
  final boldGlyphs = TtfParser(bold).charToGlyphIndexMap;
  bool supported(String value, Map<int, int> glyphs) => value.runes.every(
    (rune) => rune == 9 || rune == 10 || rune == 13 || (glyphs[rune] ?? 0) != 0,
  );
  final fields = [
    invoice.number,
    ?invoice.address,
    ...invoice.jobs.map((job) => job.name),
    ...invoice.payments.map((payment) => payment.method),
  ];
  if (!supported(invoice.applicant, boldGlyphs) ||
      fields.any((field) => !supported(field, regularGlyphs))) {
    throw const TransactionInvoiceUnavailable(
      'Ada karakter pada invoice yang belum dapat dicetak dengan font lokal.',
    );
  }
  final document = pdf.Document(
    title: 'Invoice ${invoice.number}',
    theme: pdf.ThemeData.withFont(
      base: pdf.Font.ttf(regular),
      bold: pdf.Font.ttf(bold),
    ),
  );
  document.addPage(
    pdf.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pdf.EdgeInsets.all(42),
      maxPages: 250,
      footer: (context) => pdf.Container(
        padding: const pdf.EdgeInsets.only(top: 8),
        decoration: const pdf.BoxDecoration(
          border: pdf.Border(top: pdf.BorderSide(color: _line)),
        ),
        child: pdf.Row(
          mainAxisAlignment: pdf.MainAxisAlignment.spaceBetween,
          children: [
            pdf.Text('No. Transaksi ${invoice.number}', style: _small),
            pdf.Text(
              '${context.pageNumber} / ${context.pagesCount}',
              style: _small,
            ),
          ],
        ),
      ),
      build: (_) => [
        pdf.Text(
          'SIM NOTARIS & PPAT',
          style: _small.copyWith(
            color: _maroon,
            fontWeight: pdf.FontWeight.bold,
          ),
        ),
        pdf.SizedBox(height: 5),
        pdf.Text(
          'Invoice Transaksi',
          style: pdf.TextStyle(
            fontSize: 25,
            color: _maroon,
            fontWeight: pdf.FontWeight.bold,
          ),
        ),
        pdf.SizedBox(height: 5),
        pdf.Text(
          '${invoice.domain == 'ppat' ? 'PPAT' : 'Notaris'}  |  ${invoice.number}',
          style: _body,
        ),
        pdf.SizedBox(height: 17),
        _section('Pemohon'),
        pdf.Text(
          invoice.applicant,
          style: _body.copyWith(fontWeight: pdf.FontWeight.bold),
        ),
        if (invoice.address?.trim().isNotEmpty == true)
          pdf.Text(invoice.address!, style: _body),
        pdf.SizedBox(height: 9),
        if (invoice.transactionDate case final date?)
          pdf.Text(
            'Tanggal transaksi: ${formatPaymentDate(date)}',
            style: _small,
          ),
        pdf.Text(
          'Tanggal cetak: ${formatPaymentDate(invoice.printDate)}',
          style: _small,
        ),
        pdf.SizedBox(height: 18),
        _section('Rincian Pekerjaan'),
        _table(
          ['Pekerjaan', 'Biaya layanan', 'Biaya tambahan', 'Jumlah'],
          [
            for (final job in invoice.jobs)
              [
                job.name,
                formatPaymentRupiah(job.serviceFee),
                formatPaymentRupiah(job.additionalFee),
                formatPaymentRupiah(job.total),
              ],
          ],
          const [2.1, 1, 1, 1],
          numericColumns: const {1, 2, 3},
        ),
        pdf.SizedBox(height: 16),
        pdf.NewPage(freeSpace: 70),
        _section('Pembayaran Aktif'),
        if (invoice.payments.isEmpty)
          pdf.Text('Belum ada pembayaran aktif.', style: _body)
        else
          _table(
            ['Tanggal', 'Metode', 'Nominal'],
            [
              for (final payment in invoice.payments)
                [
                  formatPaymentDate(payment.date),
                  payment.method,
                  formatPaymentRupiah(payment.amount),
                ],
            ],
            const [1, 2, 1],
            numericColumns: const {2},
          ),
        pdf.SizedBox(height: 16),
        pdf.Inseparable(
          child: pdf.Container(
            padding: const pdf.EdgeInsets.all(12),
            decoration: const pdf.BoxDecoration(color: _tint),
            child: pdf.Column(
              children: [
                _summary('Subtotal pekerjaan', invoice.subtotal),
                _summary('Potongan', invoice.discount),
                _summary('Total tagihan', invoice.billed),
                _summary('Total dibayar', invoice.paid),
                _summary('Sisa tagihan', invoice.remaining, bold: true),
                pdf.SizedBox(height: 3),
                pdf.Align(
                  alignment: pdf.Alignment.centerLeft,
                  child: pdf.Text(
                    invoice.isPaid ? 'Lunas' : 'Belum lunas',
                    style: _small,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
  return document.save();
}

const _body = pdf.TextStyle(fontSize: 10);
const _small = pdf.TextStyle(fontSize: 9, color: _muted);

pdf.Widget _section(String title) => pdf.Padding(
  padding: const pdf.EdgeInsets.only(bottom: 6),
  child: pdf.Text(
    title,
    style: _body.copyWith(fontWeight: pdf.FontWeight.bold, color: _maroon),
  ),
);

pdf.Widget _summary(String label, int amount, {bool bold = false}) {
  final style = bold
      ? _body.copyWith(fontWeight: pdf.FontWeight.bold, color: _maroon)
      : _body;
  return pdf.Padding(
    padding: const pdf.EdgeInsets.symmetric(vertical: 3),
    child: pdf.Row(
      mainAxisAlignment: pdf.MainAxisAlignment.spaceBetween,
      children: [
        pdf.Text(label, style: style),
        pdf.Text(formatPaymentRupiah(amount), style: style),
      ],
    ),
  );
}

pdf.Table _table(
  List<String> labels,
  List<List<String>> rows,
  List<double> widths, {
  required Set<int> numericColumns,
}) {
  pdf.TableRow row(List<String> values, {bool heading = false}) => pdf.TableRow(
    repeat: heading,
    decoration: heading ? const pdf.BoxDecoration(color: _tint) : null,
    children: [
      for (var index = 0; index < values.length; index++)
        pdf.Padding(
          padding: const pdf.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          child: pdf.Text(
            values[index],
            textAlign: numericColumns.contains(index)
                ? pdf.TextAlign.right
                : pdf.TextAlign.left,
            style: heading
                ? _small.copyWith(fontWeight: pdf.FontWeight.bold)
                : _small,
          ),
        ),
    ],
  );
  return pdf.Table(
    columnWidths: {
      for (var index = 0; index < widths.length; index++)
        index: pdf.FlexColumnWidth(widths[index]),
    },
    border: const pdf.TableBorder(
      horizontalInside: pdf.BorderSide(color: _line, width: .45),
    ),
    children: [
      row(labels, heading: true),
      for (final values in rows) row(values),
    ],
  );
}
