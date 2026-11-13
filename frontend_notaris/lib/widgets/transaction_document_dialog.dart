import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../providers/auth_provider.dart';
import '../providers/transaction_document_provider.dart';
import '../providers/transaction_provider.dart';
import '../repositories/transaction_document_repository.dart';
import '../services/windows_transaction_document_store.dart';

class TransactionDocumentDialog extends ConsumerStatefulWidget {
  const TransactionDocumentDialog({
    super.key,
    required this.transactionId,
    this.pickSource,
  });
  final int transactionId;
  final String? Function()? pickSource;

  @override
  ConsumerState<TransactionDocumentDialog> createState() =>
      _DocumentDialogState();
}

class _DocumentDialogState extends ConsumerState<TransactionDocumentDialog> {
  late final TransactionDocumentRepository _repository;
  DocumentOwner? _owner;
  List<TransactionDocument> _documents = [];
  bool _busy = false;
  String? _message;
  TransactionDocument? _selected;
  ui.Image? _image;
  int _page = 0, _pages = 0;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(transactionDocumentRepositoryProvider)!;
    _load();
  }

  Future<void> _load() => _run(() async {
    final session = ref.read(authControllerProvider).session;
    final row = await ref
        .read(transactionRepositoryProvider)
        .findById(widget.transactionId);
    if (row == null) throw const DocumentFileFailure('invalid_owner');
    final owner = (id: row.id, uuid: row.uuid, domain: row.jenisTransaksi);
    final documents = await _repository.listActive(owner);
    if (!mounted || ref.read(authControllerProvider).session != session) return;
    _owner = owner;
    _documents = documents;
  });

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on DocumentFileFailure catch (error) {
      _message = switch (error.code) {
        'blob_open' when error.nativeCode == 2 || error.nativeCode == 3 =>
          'File tersimpan tidak ditemukan.',
        'byte_length_mismatch' ||
        'hash_mismatch' => 'File tersimpan rusak atau telah berubah.',
        'invalid_pdf' || 'invalid_image' || 'unsupported_content' =>
          'Isi dokumen rusak atau formatnya tidak didukung.',
        'byte_limit' => 'Ukuran dokumen harus antara 1 byte dan 20 MiB.',
        'preview_timeout' || 'preview_unavailable' || 'image_decode_limit' =>
          'Preview tidak tersedia dalam batas pemrosesan.',
        'permission' || 'session_changed' =>
          'Sesi berubah atau izin Transaksi tidak mencukupi.',
        _ => 'Operasi dokumen gagal. Muat ulang sebelum mencoba lagi.',
      };
    } on Exception {
      _message = 'Operasi dokumen gagal. Muat ulang sebelum mencoba lagi.';
    } on ArgumentError {
      _message = 'Penyimpanan dokumen Windows tidak tersedia.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() => _run(() async {
    final owner = _owner!;
    final session = ref.read(authControllerProvider).session;
    final pick =
        widget.pickSource ?? WindowsTransactionDocumentStore.pickSource;
    final path = pick();
    if (path == null ||
        !mounted ||
        ref.read(authControllerProvider).session != session) {
      return;
    }
    await _repository.importFile(
      owner: owner,
      operationUuid: const Uuid().v4(),
      sourcePath: path,
    );
    if (!mounted || ref.read(authControllerProvider).session != session) return;
    final documents = await _repository.listActive(owner);
    if (mounted && ref.read(authControllerProvider).session == session) {
      _documents = documents;
    }
  });

  Future<void> _preview(TransactionDocument document, int page) =>
      _run(() async {
        final session = ref.read(authControllerProvider).session;
        _selected = document;
        _image?.dispose();
        _image = null;
        _pages = 0;
        final result = await _repository.previewActive(
          _owner!,
          document.uuid,
          page: page,
        );
        final pdf = result.pdf;
        ui.Image? image = result.image;
        if (pdf != null) {
          final buffer = await ui.ImmutableBuffer.fromUint8List(pdf.bgra);
          try {
            final descriptor = ui.ImageDescriptor.raw(
              buffer,
              width: pdf.width,
              height: pdf.height,
              pixelFormat: ui.PixelFormat.bgra8888,
            );
            try {
              final codec = await descriptor.instantiateCodec();
              try {
                image = (await codec.getNextFrame()).image;
              } finally {
                codec.dispose();
              }
            } finally {
              descriptor.dispose();
            }
          } finally {
            buffer.dispose();
          }
        }
        if (!mounted || ref.read(authControllerProvider).session != session) {
          image?.dispose();
          return;
        }
        _image = image;
        _page = page;
        _pages = pdf?.pageCount ?? 0;
      });

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).session;
    ref.listen(authControllerProvider, (previous, next) {
      if (previous?.session == next.session) return;
      _image?.dispose();
      _image = null;
      _selected = null;
      _documents = [];
      _owner = null;
    });
    final canRead = session?.hasTransactionAccess() == true;
    final canImport = session?.hasTransactionAccess(update: true) == true;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Kelola Dokumen'),
        content: SizedBox(
          width: 610,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_busy) const LinearProgressIndicator(),
                if (_message case final message?)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(message),
                  ),
                if (canRead) ...[
                  if (_selected case final document?) ...[
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _selected = null;
                              _image?.dispose();
                              _image = null;
                              _message = null;
                            }),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Daftar dokumen'),
                    ),
                    Text(_display(document.displayName)),
                    if (_image case final image?)
                      SizedBox(
                        height: 300,
                        child: RawImage(image: image, fit: BoxFit.contain),
                      ),
                    if (_pages > 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: 'Halaman sebelumnya',
                            onPressed: _busy || _page == 0
                                ? null
                                : () => _preview(document, _page - 1),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text('${_page + 1} / $_pages'),
                          IconButton(
                            tooltip: 'Halaman berikutnya',
                            onPressed: _busy || _page + 1 == _pages
                                ? null
                                : () => _preview(document, _page + 1),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                  ] else ...[
                    if (!_busy && _message == null && _documents.isEmpty)
                      const Text('Belum ada dokumen.'),
                    for (final document in _documents)
                      ListTile(
                        title: Text(
                          _display(document.displayName),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${document.type.name.toUpperCase()} · ${document.digest.length} byte · '
                          '${MaterialLocalizations.of(context).formatShortDate(document.importedAt.toLocal())}'
                          '${document.detailUuid == null ? ' · Transaksi' : ' · Detail pekerjaan'}',
                        ),
                        trailing: OutlinedButton(
                          onPressed: _busy ? null : () => _preview(document, 0),
                          child: const Text('Preview'),
                        ),
                      ),
                  ],
                ] else
                  const Text('Izin baca Transaksi diperlukan.'),
              ],
            ),
          ),
        ),
        actions: [
          if (canRead && _selected == null)
            TextButton(
              onPressed: _busy ? null : _load,
              child: const Text('Muat ulang'),
            ),
          if (canImport && _selected == null)
            FilledButton(
              onPressed: _busy || _owner == null ? null : _import,
              child: const Text('Impor dokumen'),
            ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}

String _display(String name) => name.replaceAll(
  RegExp(r'[\x00-\x1f\x7f\u202a-\u202e\u2066-\u2069]'),
  '\uFFFD',
);
