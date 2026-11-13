import 'dart:ffi';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/payment_demo_main.dart';
import 'package:frontend_notaris/repositories/transaction_document_repository.dart';
import 'package:frontend_notaris/repositories/transaction_document_cloud_guard.dart';
import 'package:frontend_notaris/services/transaction_document_preview.dart';
import 'package:frontend_notaris/services/windows_transaction_document_store.dart';
import 'package:path/path.dart' as p;

import '../services/transaction_document_preview_test.dart' show samplePdf;
import '../support/transaction_ui_test_support.dart' show uiSession;
import 'recycle_bin_repository_test.dart' show recoverySession, seedTransaction;

const _operation = '3e3c0d11-2192-4abb-aa24-be593d5f0d01';
const _otherOperation = '3e3c0d11-2192-4abb-aa24-be593d5f0d02';

Matcher _failure(String code) => throwsA(
  isA<DocumentFileFailure>().having((error) => error.code, 'code', code),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const dllPath = String.fromEnvironment('NOTARIS_DOCUMENT_TEST_DLL');
  const worker = String.fromEnvironment('NOTARIS_DOCUMENT_TEST_PDF');
  group('Phase A document repository', () {
    late Directory folder;
    late AppDatabase db;
    late File databaseFile;
    late File source;
    late AuthSession? session;
    late DocumentOwner notaris, ppat;
    late DynamicLibrary library;

    TransactionDocumentRepository repository({String? path}) =>
        TransactionDocumentRepository(
          db: db,
          session: () => session,
          verifiedDatabasePath: path ?? databaseFile.path,
          verifiedAppDirectory: folder.path,
          storageLibrary: library,
          preview: TransactionDocumentPreview(pdfWorker: worker),
        );

    Future<DocumentOwner> seed(String domain) async {
      final id = await seedTransaction(db, domain);
      final row = await (db.select(
        db.transaksis,
      )..where((r) => r.id.equals(id))).getSingle();
      return (id: id, uuid: row.uuid, domain: domain);
    }

    setUp(() async {
      library = DynamicLibrary.open(dllPath);
      folder = Directory(Directory.systemTemp.resolveSymbolicLinksSync())
          .createTempSync('notaris-document-repository-');
      databaseFile = File(p.join(folder.path, 'offline.sqlite'));
      db = DocumentProfileDatabase(NativeDatabase(databaseFile));
      notaris = await seed('notaris');
      ppat = await seed('ppat');
      session = uiSession(userId: 37);
      source = File(p.join(folder.path, 'Lampiran 名.png'));
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder)
          .drawColor(const ui.Color(0xff222222), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(3, 3);
      picture.dispose();
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      image.dispose();
      await source.writeAsBytes(png);
    });
    tearDown(() => db.close());

    test('v25 migration, metadata audit, archive and restore preserve original bytes and cloud block', () async {
      final imported = await repository().importFile(
        owner: notaris,
        operationUuid: _operation,
        sourcePath: source.path,
      );
      final original = await source.readAsBytes();
      final tables = [
        'transaksis',
        'transaksi_details',
        'transaksi_proses',
        'transaksi_riwayat_pembayaran',
        'transaksi_serah_terima',
        'transaction_cloud_identity',
        'transaction_cloud_pending',
        'transaction_cloud_feed',
        'transaction_document_versions',
      ];
      Future<List<Object>> snapshot() async => [
        for (final table in tables)
          (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
              .map((r) => r.data)
              .toList(),
      ];
      final before = await snapshot();
      await db.close();
      db = DocumentProfileDatabase(
        NativeDatabase(databaseFile),
        lifecycle: true,
      );
      final repo = repository();
      Future<void> edit(int rev) => repo.correct(
        owner: notaris,
        uuid: imported.uuid,
        expectedRevision: rev,
        operationUuid: _otherOperation,
        action: DocumentCorrection.edit,
        title: 'Judul baru',
        description: 'Catatan dokumen',
      );
      expect(await snapshot(), before);
      await expectLater(edit(1), _failure('permission'));
      session = recoverySession(update: false, only: 'transaksi');
      await expectLater(
        repo.history(notaris, imported.uuid),
        _failure('permission'),
      );
      final readOnly = session!;
      session = AuthSession.fromJson({
        ...readOnly.toJson(),
        'groupType': 'superadmin',
        'verifiedAt': DateTime.now().toUtc().toIso8601String(),
      });
      await expectLater(edit(1), _failure('permission'));
      session = ExpiringPaymentDemoSession(
        uiSession(groupType: 'superadmin'),
        DateTime.now().subtract(const Duration(seconds: 1)),
      );
      await expectLater(edit(1), _failure('permission'));
      session = uiSession(userId: 42, groupType: 'superadmin');
      await edit(1);
      await edit(1);
      await expectLater(edit(2), _failure('operation_mismatch'));
      final audit = await db
          .customSelect('SELECT * FROM transaction_document_audit')
          .getSingle();
      expect(jsonDecode(audit.read<String>('before_state'))['title'], isNull);
      expect(
        jsonDecode(audit.read<String>('after_state'))['title'],
        'Judul baru',
      );
      final edited = (await repo.listActive(notaris)).single;
      expect(
        (edited.revision, edited.versionUuid, edited.digest),
        (2, imported.versionUuid, imported.digest),
      );
      const archive = '3e3c0d11-2192-4abb-aa24-be593d5f0d03';
      const restore = '3e3c0d11-2192-4abb-aa24-be593d5f0d04';
      Future<void> archiveAt(int rev) => repo.correct(
        owner: notaris,
        uuid: imported.uuid,
        expectedRevision: rev,
        operationUuid: archive,
        action: DocumentCorrection.archive,
        reason: 'Salah transaksi',
      );
      await expectLater(archiveAt(1), _failure('document_changed'));
      await archiveAt(2);
      await archiveAt(2);
      expect(await repo.listActive(notaris), isEmpty);
      expect(
        await transactionDocumentUploadBlockReason(db, notaris.uuid),
        transactionDocumentUploadBlock,
      );
      expect(await transactionDocumentUploadBlockReason(db, ppat.uuid), isNull);
      await expectLater(
        repo.readActive(notaris, imported.uuid),
        _failure('document_not_found'),
      );
      expect(
        (await repo.listArchived(notaris)).single.versionUuid,
        imported.versionUuid,
      );
      await expectLater(
        repo.history(ppat, imported.uuid),
        _failure('document_not_found'),
      );
      await repo.correct(
        owner: notaris,
        uuid: imported.uuid,
        expectedRevision: 3,
        operationUuid: restore,
        action: DocumentCorrection.restore,
        reason: 'Koreksi arsip',
      );
      expect((await repo.readActive(notaris, imported.uuid)).bytes, original);
      expect(await snapshot(), before);
      expect(
        (await db
                .customSelect(
                  'SELECT action,reason FROM transaction_document_audit ORDER BY rowid',
                )
                .get())
            .map((r) => r.data),
        [
          {'action': 'edit', 'reason': null},
          {'action': 'archive', 'reason': 'Salah transaksi'},
          {'action': 'restore', 'reason': 'Koreksi arsip'},
        ],
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        (await db.customSelect('PRAGMA integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
      );
      await db.close();
      db = DocumentProfileDatabase(
        NativeDatabase(databaseFile),
        lifecycle: true,
      );
      expect((await repository().listActive(notaris)).single.revision, 4);
    });

    test('replacement rolls back on commit failure and resumes the same immutable version', () async {
      await db.close();
      db = DocumentProfileDatabase(
        NativeDatabase(databaseFile),
        lifecycle: true,
      );
      final repo = repository();
      final first = await repo.importFile(
        owner: ppat,
        operationUuid: _operation,
        sourcePath: source.path,
      );
      final replacement = File(p.join(folder.path, 'New.png'));
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder)
          .drawColor(const ui.Color(0xff445566), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final replacementImage = await picture.toImage(2, 2);
      picture.dispose();
      try {
        await replacement.writeAsBytes(
          (await replacementImage.toByteData(format: ui.ImageByteFormat.png))!
              .buffer
              .asUint8List(),
        );
      } finally {
        replacementImage.dispose();
      }
      session = uiSession(userId: 42, groupType: 'superadmin');
      Future<TransactionDocument> replace() => repo.replace(
        owner: ppat,
        uuid: first.uuid,
        expectedRevision: 1,
        operationUuid: _otherOperation,
        sourcePath: replacement.path,
      );
      await db.customStatement(
        '''CREATE TRIGGER fixture_reject_replace BEFORE INSERT ON transaction_document_audit
        WHEN NEW.action='replace' BEGIN SELECT RAISE(ABORT,'fixture failure'); END''',
      );
      await expectLater(replace(), throwsException);
      expect(
        (await repo.listActive(ppat)).single.versionUuid,
        first.versionUuid,
      );
      expect(
        (await repo.pendingReplacement(ppat, first.uuid))?.operationUuid,
        _otherOperation,
      );
      await db.customStatement('DROP TRIGGER fixture_reject_replace');
      await db.close();
      db = DocumentProfileDatabase(
        NativeDatabase(databaseFile),
        lifecycle: true,
      );
      final reopened = repository();
      final latest = await reopened.resumeReplacement(
        owner: ppat,
        uuid: first.uuid,
        expectedRevision: 1,
        operationUuid: _otherOperation,
      );
      expect(latest.uuid, first.uuid);
      expect(latest.versionUuid, isNot(first.versionUuid));
      expect((latest.versionNumber, latest.revision), (2, 2));
      expect(latest.digest.sha256, isNot(first.digest.sha256));
      expect(
        await transactionDocumentUploadBlockReason(db, ppat.uuid),
        transactionDocumentUploadBlock,
      );
      expect(
        latest.digest.sha256,
        sha256.convert(replacement.readAsBytesSync()).toString(),
      );
      expect(
        (await reopened.replace(
          owner: ppat,
          uuid: first.uuid,
          expectedRevision: 1,
          operationUuid: _otherOperation,
          sourcePath: replacement.path,
        )).versionUuid,
        latest.versionUuid,
      );
      await expectLater(
        reopened.replace(
          owner: ppat,
          uuid: first.uuid,
          expectedRevision: 1,
          operationUuid: '3e3c0d11-2192-4abb-aa24-be593d5f0d05',
          sourcePath: replacement.path,
        ),
        _failure('document_changed'),
      );
      expect(
        (await reopened.history(
          ppat,
          first.uuid,
        )).map((v) => (v.versionNumber, v.current)),
        [(2, true), (1, false)],
      );
      final image = (await reopened.previewVersion(
        ppat,
        first.uuid,
        first.versionUuid,
      )).image!;
      expect((image.width, image.height), (3, 3));
      image.dispose();
      session = uiSession(userId: 37);
      await expectLater(
        reopened.previewVersion(ppat, first.uuid, first.versionUuid),
        _failure('permission'),
      );
      expect(
        (await reopened.listActive(ppat)).single.versionUuid,
        latest.versionUuid,
      );
    });

    test('imports into both domains, permits authorized read, and persists on reopen', () async {
      final before = await source.readAsBytes();
      final repo = repository();
      final first = await repo.importFile(
        owner: notaris,
        operationUuid: _operation,
        sourcePath: source.path,
      );
      final second = await repo.importFile(
        owner: ppat,
        operationUuid: _otherOperation,
        sourcePath: source.path,
      );
      expect(first.actor, 37);
      expect(first.displayName, 'Lampiran 名.png');
      expect(first.digest.sha256, sha256.convert(before).toString());
      expect(second.versionUuid, isNot(first.versionUuid));
      expect(await source.readAsBytes(), before);
      expect(
        (await repo.importFile(
          owner: notaris,
          operationUuid: _operation,
          sourcePath: source.path,
        )).uuid,
        first.uuid,
      );
      await expectLater(
        repo.readActive(ppat, first.uuid),
        _failure('document_not_found'),
      );
      await expectLater(
        repo.importFile(
          owner: ppat,
          operationUuid: _operation,
          sourcePath: source.path,
        ),
        _failure('operation_mismatch'),
      );
      await db.close();
      db = DocumentProfileDatabase(NativeDatabase(databaseFile));
      session = recoverySession(update: false, only: 'transaksi');
      final reader = repository();
      expect((await reader.listActive(notaris)).single.uuid, first.uuid);
      expect((await reader.readActive(notaris, first.uuid)).bytes, before);
      expect((await reader.readActive(ppat, second.uuid)).bytes, before);
      final image = (await reader.previewActive(ppat, second.uuid)).image!;
      expect((image.width, image.height), (3, 3));
      image.dispose();
      await expectLater(
        reader.importFile(
          owner: notaris,
          operationUuid: _operation,
          sourcePath: source.path,
        ),
        _failure('permission'),
      );
      await expectLater(
        repository(path: p.join(folder.path, 'other.sqlite'))
            .listActive(notaris),
        _failure('invalid_profile'),
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    });

    test('imports and renders PDF through the authorized repository', () async {
      final pdf = await samplePdf(595, 842);
      final file = File(p.join(folder.path, 'Salinan Akta.pdf'))
        ..writeAsBytesSync(pdf);
      final repo = repository();
      final doc = await repo.importFile(
        owner: notaris,
        operationUuid: _operation,
        sourcePath: file.path,
      );
      expect(doc.type, DocumentFileType.pdf);
      expect((await repo.readActive(notaris, doc.uuid)).bytes, pdf);
      final page = (await repo.previewActive(notaris, doc.uuid)).pdf!;
      expect(
        page.width * page.height,
        lessThanOrEqualTo(documentPreviewMaxPixels),
      );
      await expectLater(
        repo.previewActive(notaris, doc.uuid, page: 1),
        _failure('preview_unavailable'),
      );
      expect((await repo.listActive(notaris)).single.uuid, doc.uuid);
      expect((await repo.readActive(notaris, doc.uuid)).bytes, pdf);
    }, skip: worker.isEmpty);

    test('reports corrupt and missing managed files without dropping their metadata', () async {
      final repo = repository();
      final doc = await repo.importFile(
        owner: notaris,
        operationUuid: _operation,
        sourcePath: source.path,
      );
      final managed = Directory(p.join(folder.path, 'transaction-documents'))
          .listSync(recursive: true)
          .whereType<File>()
          .singleWhere(
            (file) => p.basename(file.path) == '${doc.versionUuid}.png',
          );
      final bytes = await managed.readAsBytes();
      bytes[bytes.length - 1] ^= 1;
      await managed.writeAsBytes(bytes);
      await expectLater(
        repo.previewActive(notaris, doc.uuid),
        _failure('hash_mismatch'),
      );
      await managed.rename('${managed.path}.retained-fixture');
      await expectLater(
        repo.previewActive(notaris, doc.uuid),
        _failure('blob_open'),
      );
      expect((await repo.listActive(notaris)).single.uuid, doc.uuid);
    });

    test('failed metadata commit preserves verified blob for explicit restart recovery', () async {
      await db.customStatement('''CREATE TRIGGER fixture_failed_commit BEFORE INSERT ON transaction_document_versions
        BEGIN SELECT RAISE(ABORT,'fixture commit failure'); END''');
      final repo = repository();
      await expectLater(
        repo.importFile(
          owner: notaris,
          operationUuid: _operation,
          sourcePath: source.path,
        ),
        throwsException,
      );
      expect(await repo.listActive(notaris), isEmpty);
      final intent = await db
          .customSelect('SELECT state FROM transaction_document_operations')
          .getSingle();
      expect(intent.read<String>('state'), 'verified');
      await db.close();
      db = DocumentProfileDatabase(NativeDatabase(databaseFile));
      await db.customStatement('DROP TRIGGER fixture_failed_commit');
      final reopened = repository();
      final recovered = await reopened.resumeVerifiedImport(
        owner: notaris,
        operationUuid: _operation,
      );
      expect(
        (await reopened.readActive(notaris, recovered.uuid)).bytes,
        await source.readAsBytes(),
      );
      expect(
        (await reopened.resumeVerifiedImport(
          owner: notaris,
          operationUuid: _operation,
        )).uuid,
        recovered.uuid,
      );
      expect((await reopened.listActive(notaris)).length, 1);
    });

    test('rejects owner detail mismatch and invalid content without visible metadata', () async {
      final wrong = await (db.select(
        db.transaksiDetails,
      )..where((r) => r.transaksiId.equals(ppat.id))).getSingle();
      final repo = repository();
      await expectLater(
        repo.importFile(
          owner: notaris,
          detailUuid: wrong.uuid,
          operationUuid: _operation,
          sourcePath: source.path,
        ),
        _failure('invalid_owner'),
      );
      final bad = File(p.join(folder.path, 'bad.png'))
        ..writeAsStringSync('Not a PNG');
      await expectLater(
        repo.importFile(
          owner: notaris,
          operationUuid: _operation,
          sourcePath: bad.path,
        ),
        _failure('unsupported_content'),
      );
      expect(await repo.listActive(notaris), isEmpty);
    });
  }, skip: !Platform.isWindows || dllPath.isEmpty);
}
