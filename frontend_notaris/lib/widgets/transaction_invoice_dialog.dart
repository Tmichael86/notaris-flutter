import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../models/auth_session.dart';
import '../models/transaction_invoice.dart';
import '../providers/auth_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/transaction_invoice_pdf.dart';
import 'transaction_dialog_section.dart';

class TransactionInvoiceDialog extends ConsumerStatefulWidget {
  const TransactionInvoiceDialog({super.key, required this.transactionId});

  final int transactionId;

  @override
  ConsumerState<TransactionInvoiceDialog> createState() =>
      _TransactionInvoiceDialogState();
}

class _TransactionInvoiceDialogState
    extends ConsumerState<TransactionInvoiceDialog> {
  AuthSession? _openedFor;
  Future<({TransactionInvoice invoice, Uint8List bytes})>? _document;
  bool _printing = false;
  String? _printMessage;

  @override
  void initState() {
    super.initState();
    final session = ref.read(authControllerProvider).session;
    if (session?.hasTransactionAccess() != true) return;
    _openedFor = session;
    _document = _load(session!);
  }

  Future<({TransactionInvoice invoice, Uint8List bytes})> _load(
    AuthSession session,
  ) async {
    final invoice = await ref
        .read(transactionRepositoryProvider)
        .readInvoice(transactionId: widget.transactionId, session: session);
    return (invoice: invoice, bytes: await renderTransactionInvoice(invoice));
  }

  bool _allowed(AuthSession? session) =>
      session?.hasTransactionAccess() == true &&
      session!.userId == _openedFor?.userId &&
      session.groupId == _openedFor?.groupId;

  Future<void> _print(TransactionInvoice invoice, Uint8List bytes) async {
    if (_printing || !_allowed(ref.read(authControllerProvider).session)) {
      return;
    }
    setState(() {
      _printing = true;
      _printMessage = null;
    });
    String? message;
    try {
      final info = await Printing.info();
      if (!mounted) return;
      if (!_allowed(ref.read(authControllerProvider).session)) {
        message = 'Izin baca Transaksi diperlukan.';
      } else if (!info.canPrint) {
        message = 'Pencetakan tidak tersedia pada perangkat ini.';
      } else {
        final sent = await Printing.layoutPdf(
          name: 'Invoice ${invoice.number}',
          format: PdfPageFormat.a4,
          dynamicLayout: false,
          onLayout: (_) => bytes,
        );
        if (!sent) message = 'Pencetakan dibatalkan atau tidak selesai.';
      }
    } catch (_) {
      message = 'Invoice tidak dapat dikirim ke dialog cetak.';
    } finally {
      if (mounted) {
        setState(() {
          _printing = false;
          _printMessage = message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowed = _allowed(ref.watch(authControllerProvider).session);
    return FutureBuilder(
      future: _document,
      builder: (context, snapshot) {
        final document = allowed ? snapshot.data : null;
        final error = snapshot.error;
        return PopScope(
          canPop: !_printing,
          child: AlertDialog(
            title: const Text('Invoice Transaksi'),
            content: document == null
                ? Text(
                    !allowed
                        ? 'Izin baca Transaksi diperlukan.'
                        : error is TransactionInvoiceUnavailable
                        ? error.message
                        : error != null
                        ? 'Invoice tidak dapat dimuat.'
                        : 'Menyiapkan invoice…',
                  )
                : SizedBox(
                    width: 690,
                    height: min(670, MediaQuery.sizeOf(context).height * .57),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TransactionDialogSection(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${document.invoice.domain.toUpperCase()} · ${document.invoice.number}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const Text(
                                'Identitas kantor belum tersedia di konfigurasi lokal.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: PdfPreview(
                            build: (_) => document.bytes,
                            initialPageFormat: PdfPageFormat.a4,
                            useActions: false,
                            allowPrinting: false,
                            allowSharing: false,
                            canChangePageFormat: false,
                            canChangeOrientation: false,
                            canDebug: false,
                            dynamicLayout: false,
                            onError: (_, _) => const Center(
                              child: Text(
                                'Pratinjau PDF tidak dapat ditampilkan.',
                              ),
                            ),
                          ),
                        ),
                        if (_printMessage case final message?) ...[
                          const SizedBox(height: 8),
                          Text(message),
                        ],
                      ],
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: _printing ? null : () => Navigator.of(context).pop(),
                child: const Text('Tutup'),
              ),
              if (document != null)
                FilledButton.icon(
                  onPressed: _printing
                      ? null
                      : () => _print(document.invoice, document.bytes),
                  icon: const Icon(Icons.print_outlined),
                  label: Text(_printing ? 'Membuka dialog cetak…' : 'Cetak'),
                ),
            ],
          ),
        );
      },
    );
  }
}
