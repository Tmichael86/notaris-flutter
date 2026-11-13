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
  String? _transactionNumber;
  List<TransactionDocument> _documents = [];
  bool _archived = false;
  List<TransactionDocument>? _history;
  TransactionDocument? _correctionTarget;
  String? _correction;
  final _title = TextEditingController();
  final _notes = TextEditingController();
  bool _historicalPreview = false;
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
    final documents = _archived
        ? await _repository.listArchived(owner)
        : await _repository.listActive(owner);
    if (!mounted || ref.read(authControllerProvider).session != session) return;
    _owner = owner;
    _transactionNumber = row.noAkta;
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
        'document_changed' =>
          'Dokumen sudah berubah. Muat ulang sebelum melanjutkan.',
        'already_archived' => 'Dokumen sudah diarsipkan.',
        'already_restored' => 'Dokumen sudah aktif.',
        'reason_required' => 'Alasan wajib diisi.',
        'invalid_owner' ||
        'document_not_found' => 'Dokumen tidak tersedia pada transaksi ini.',
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

  Future<void> _preview(TransactionDocument document, int page) => _run(
    () async {
      final session = ref.read(authControllerProvider).session;
      _selected = document;
      _image?.dispose();
      _image = null;
      _pages = 0;
      final result = _historicalPreview
          ? await _repository.previewVersion(
              _owner!,
              document.uuid,
              document.versionUuid,
              page: page,
            )
          : await _repository.previewActive(_owner!, document.uuid, page: page);
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
    },
  );

  @override
  void dispose() {
    _image?.dispose();
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _beginCorrection(TransactionDocument document, String action) =>
      setState(() {
        _correctionTarget = document;
        _correction = action;
        _title.text = document.title ?? document.originalName;
        _notes.text = action == 'edit' ? document.description ?? '' : '';
        _message = null;
      });

  Future<void> _confirmCorrection() => _run(() async {
    final session = ref.read(authControllerProvider).session;
    final owner = _owner!;
    final document = _correctionTarget!;
    final action = _correction!;
    final operation = const Uuid().v4();
    if (action == 'replace') {
      final pending = await _repository.pendingReplacement(
        owner,
        document.uuid,
      );
      if (!mounted || ref.read(authControllerProvider).session != session) {
        return;
      }
      if (pending != null) {
        await _repository.resumeReplacement(
          owner: owner,
          uuid: document.uuid,
          expectedRevision: pending.revision,
          operationUuid: pending.operationUuid,
        );
      } else {
        if (!mounted) return;
        final path =
            (widget.pickSource ?? WindowsTransactionDocumentStore.pickSource)();
        if (path == null ||
            !mounted ||
            ref.read(authControllerProvider).session != session) {
          return;
        }
        await _repository.replace(
          owner: owner,
          uuid: document.uuid,
          expectedRevision: document.revision,
          operationUuid: operation,
          sourcePath: path,
        );
      }
    } else {
      await _repository.correct(
        owner: owner,
        uuid: document.uuid,
        expectedRevision: document.revision,
        operationUuid: operation,
        action: DocumentCorrection.values.byName(action),
        title: _title.text,
        description: _notes.text,
        reason: _notes.text,
      );
    }
    final documents = _archived
        ? await _repository.listArchived(owner)
        : await _repository.listActive(owner);
    if (!mounted || _owner != owner) return;
    _documents = documents;
    _correction = null;
    _correctionTarget = null;
    _message = 'Perubahan dokumen tersimpan.';
  });

  Future<void> _showHistory(TransactionDocument document) => _run(() async {
    final owner = _owner!;
    final versions = await _repository.history(owner, document.uuid);
    if (mounted && _owner == owner) _history = versions;
  });

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
      _history = null;
      _correction = null;
      _correctionTarget = null;
      _archived = false;
    });
    final canRead = session?.hasTransactionAccess() == true;
    final canImport = session?.hasTransactionAccess(update: true) == true;
    final canCorrect = _repository.canCorrect;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(
          _transactionNumber == null
              ? 'Kelola Dokumen'
              : 'Kelola Dokumen · ${_owner?.domain.toUpperCase() ?? ''} $_transactionNumber',
        ),
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
                  if (canCorrect && _correction != null) ...[
                    Text(_display(_correctionTarget!.displayName)),
                    if (_correction == 'edit') ...[
                      TextField(
                        controller: _title,
                        enabled: !_busy,
                        maxLength: 255,
                        decoration: const InputDecoration(
                          labelText: 'Judul dokumen',
                        ),
                      ),
                      TextField(
                        controller: _notes,
                        enabled: !_busy,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'Deskripsi',
                        ),
                      ),
                    ] else if (_correction == 'replace')
                      const Text(
                        'Buat versi baru atau lanjutkan penggantian yang tertunda. Versi lama tetap tersimpan.',
                      )
                    else
                      TextField(
                        controller: _notes,
                        enabled: !_busy,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: _correction == 'archive'
                              ? 'Alasan arsip'
                              : 'Alasan restore',
                        ),
                      ),
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _correction = null;
                                  _correctionTarget = null;
                                }),
                          child: const Text('Batal'),
                        ),
                        FilledButton(
                          onPressed: _busy ? null : _confirmCorrection,
                          child: const Text('Konfirmasi'),
                        ),
                      ],
                    ),
                  ] else if (_selected case final document?
                      when !_historicalPreview || canCorrect) ...[
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _selected = null;
                              _historicalPreview = false;
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
                  ] else if (canCorrect && _history != null) ...[
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _history = null),
                      child: const Text('Kembali ke daftar'),
                    ),
                    for (final version in _history!)
                      ListTile(
                        title: Text(
                          'Versi ${version.versionNumber}${version.current ? ' · Aktif' : ''} · ${_display(version.originalName)}',
                        ),
                        subtitle: SelectableText(
                          '${MaterialLocalizations.of(context).formatShortDate(version.importedAt.toLocal())} · Aktor ${version.actor} · ${version.digest.length} byte\nSHA-256 ${version.digest.sha256}',
                        ),
                        trailing: TextButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  _historicalPreview = true;
                                  _preview(version, 0);
                                },
                          child: const Text('Preview'),
                        ),
                      ),
                  ] else if (!_archived || canCorrect) ...[
                    if (canCorrect)
                      TextButton(
                        onPressed: _busy || _owner == null
                            ? null
                            : () {
                                setState(() {
                                  _archived = !_archived;
                                  _documents = [];
                                });
                                _load();
                              },
                        child: Text(
                          _archived ? 'Tampilkan aktif' : 'Tampilkan arsip',
                        ),
                      ),
                    if (!_busy && _message == null && _documents.isEmpty)
                      const Text('Belum ada dokumen.'),
                    for (final document in _documents) ...[
                      ListTile(
                        title: Text(
                          _display(document.displayName),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Versi ${document.versionNumber} · ${document.type.name.toUpperCase()} · ${document.digest.length} byte · '
                          '${MaterialLocalizations.of(context).formatShortDate(document.importedAt.toLocal())}'
                          '${document.detailUuid == null ? ' · Transaksi' : ' · Detail pekerjaan'}'
                          '${document.description == null ? '' : '\n${_display(document.description!)}'}',
                        ),
                        trailing: _archived
                            ? null
                            : OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _preview(document, 0),
                                child: const Text('Preview'),
                              ),
                      ),
                      if (canCorrect)
                        Wrap(
                          children: [
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _showHistory(document),
                              child: Text(
                                'Riwayat · ${_display(document.displayName)}',
                              ),
                            ),
                            if (_archived)
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () =>
                                          _beginCorrection(document, 'restore'),
                                child: const Text('Restore'),
                              )
                            else
                              for (final (action, label) in [
                                ('edit', 'Edit metadata'),
                                ('replace', 'Ganti file'),
                                ('archive', 'Arsipkan'),
                              ])
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () =>
                                            _beginCorrection(document, action),
                                  child: Text(label),
                                ),
                          ],
                        ),
                    ],
                  ],
                ] else
                  const Text('Izin baca Transaksi diperlukan.'),
              ],
            ),
          ),
        ),
        actions: [
          if (canRead &&
              _selected == null &&
              _history == null &&
              _correction == null &&
              (!_archived || canCorrect))
            TextButton(
              onPressed: _busy ? null : _load,
              child: const Text('Muat ulang'),
            ),
          if (canImport &&
              _selected == null &&
              _history == null &&
              _correction == null &&
              !_archived)
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
