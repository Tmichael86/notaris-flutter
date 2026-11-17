import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/transaction_review_dialog.dart';
import '../repositories/materai_repository.dart';
import '../repositories/materai_stock_repository.dart';

typedef _Draft = ({
  String operation,
  int predecessor,
  String date,
  int sheets,
  String description,
});

Future<bool?> showMateraiStockDialog(
  BuildContext context,
  MateraiStockRepository repository,
  MateraiStockContext baseline,
) async {
  final file = repository.binding.pendingReceipt;
  _Draft? draft;
  if (file != null &&
      await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const MateraiStockException('Bukti draf tidak dapat diverifikasi.');
    }
    final raw = jsonDecode(await file.readAsString()) as Map;
    if (raw['actor'] != baseline.actorId) {
      throw const MateraiStockException(
        'Draf penerimaan terikat ke akun lain.',
      );
    }
    draft = (
      operation: raw['operation'] as String,
      predecessor: raw['previous'] as int,
      date: raw['date'] as String,
      sheets: raw['quantity'] as int,
      description: raw['description'] as String,
    );
  }
  if (!context.mounted) return null;
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _MateraiStockDialog(repository, baseline, file, draft),
  );
}

class _MateraiStockDialog extends StatefulWidget {
  const _MateraiStockDialog(
    this.repository,
    this.baseline,
    this.file,
    this.saved,
  );
  final MateraiStockRepository repository;
  final MateraiStockContext baseline;
  final File? file;
  final _Draft? saved;

  @override
  State<_MateraiStockDialog> createState() => _MateraiStockDialogState();
}

class _MateraiStockDialogState extends State<_MateraiStockDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _sheets;
  late final TextEditingController _notes;
  late DateTime _date;
  _Draft? _pending;
  MateraiStockResult? _result;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pending = widget.saved;
    _sheets = TextEditingController(text: _pending?.sheets.toString());
    _notes = TextEditingController(text: _pending?.description);
    final earliest = DateTime.parse(widget.baseline.date);
    final now = DateUtils.dateOnly(DateTime.now());
    _date = _pending == null
        ? (now.isBefore(earliest) ? earliest : now)
        : DateTime.parse(_pending!.date);
  }

  @override
  void dispose() {
    _sheets.dispose();
    _notes.dispose();
    super.dispose();
  }

  int? get _quantity => RegExp(r'^[0-9]{1,5}$').hasMatch(_sheets.text)
      ? int.tryParse(_sheets.text)
      : null;

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final prior = _pending;
    final draft =
        prior ??
        (
          operation: const Uuid().v4(),
          predecessor: widget.baseline.predecessor,
          date: materaiCalendarDate(_date),
          sheets: _quantity!,
          description: _notes.text.trim(),
        );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = widget.file;
      if (prior == null && file != null) {
        // A durable intent precedes any ledger write. A truncated intent fails
        // closed when reopened and cannot submit a fresh operation accidentally.
        await file.create(exclusive: true);
        await file.writeAsString(
          jsonEncode({
            'operation': draft.operation,
            'previous': draft.predecessor,
            'date': draft.date,
            'quantity': draft.sheets,
            'description': draft.description,
            'actor': widget.baseline.actorId,
          }),
          flush: true,
        );
      }
      _pending = draft;
      _result = await widget.repository.receive(
        operation: draft.operation,
        expectedPredecessor: draft.predecessor,
        businessDate: draft.date,
        sheets: draft.sheets,
        description: draft.description,
      );
    } catch (error) {
      _error = error is MateraiStockException
          ? error.message
          : 'Hasil belum dapat dipastikan. Buka kembali draf yang sama.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    if (_busy) return;
    final draft = _pending;
    if (draft == null) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final committed =
          _result != null ||
          await widget.repository.receiptExists(draft.operation);
      await widget.file?.delete();
      if (mounted) Navigator.of(context).pop(committed);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is MateraiStockException
            ? error.message
            : 'Draf belum dapat ditutup dengan aman.';
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.parse(widget.baseline.date),
      initialDate: _date,
      lastDate: DateTime(9999, 12, 31),
    );
    if (mounted && picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final baseline = widget.baseline;
    final quantity = _quantity;
    final locked = _busy || _pending != null;
    return PopScope(
      canPop: !_busy && _pending == null,
      child: TransactionReviewDialog(
        title: 'Tambah Stok Materai',
        width: 480,
        canClose: !locked,
        subtitle: 'Tanggal penerimaan harus sama atau setelah mutasi terakhir.',
        body: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Petugas: ${baseline.officer}'),
              Text('Stok terverifikasi: ${baseline.stock} lembar'),
              if (_pending != null && _result == null)
                const Text(
                  'Draf tersimpan. Simpan kembali untuk memeriksa atau menyelesaikan operasi yang sama.',
                ),
              if (_result case final result?)
                Text(
                  'Penerimaan tersimpan. Stok tercatat: ${result.stock} lembar.',
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: locked ? null : _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  'Tanggal penerimaan · ${materaiCalendarDate(_date)}',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sheets,
                readOnly: locked,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jumlah meterai masuk (lembar)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                validator: (_) =>
                    quantity == null ||
                        quantity < 1 ||
                        quantity > materaiReceiptLimit
                    ? 'Masukkan bilangan bulat 1–10.000.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                readOnly: locked,
                maxLength: 250,
                decoration: const InputDecoration(
                  labelText: 'Keterangan (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_pending == null &&
                  quantity != null &&
                  quantity > 0 &&
                  quantity <= materaiReceiptLimit &&
                  baseline.stock <= materaiStockLimit - quantity)
                Text('Proyeksi stok: ${baseline.stock + quantity} lembar'),
              if (_error case final error?)
                Text(
                  error,
                  style: const TextStyle(color: AppColors.primaryDark),
                ),
            ],
          ),
        ),
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            TextButton(
              onPressed: _busy ? null : _close,
              child: Text(_result == null ? 'Batal' : 'Selesai'),
            ),
            if (_result == null)
              FilledButton(
                onPressed: _busy ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                ),
                child: const Text('Simpan'),
              ),
          ],
        ),
      ),
    );
  }
}
