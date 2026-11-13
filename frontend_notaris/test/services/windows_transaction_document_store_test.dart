import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/services/windows_transaction_document_store.dart';
import 'package:path/path.dart' as p;

const _storeId = '1bde7502-4d2a-4a09-af07-0d8d54fbb401';
const _operation = '1bde7502-4d2a-4a09-af07-0d8d54fbb402';
const _otherOperation = '1bde7502-4d2a-4a09-af07-0d8d54fbb403';
const _version = '1bde7502-4d2a-4a09-af07-0d8d54fbb404';

Matcher _failure(String code) => throwsA(
  isA<DocumentFileFailure>().having((error) => error.code, 'code', code),
);

void main() {
  const nativePath = String.fromEnvironment('NOTARIS_DOCUMENT_TEST_DLL');
  group('Windows document store', () {
    late Directory folder;
    late DynamicLibrary library;

    WindowsTransactionDocumentStore store({
      String profile = 'profile A',
      String? base,
    }) => WindowsTransactionDocumentStore(
      verifiedAppDirectory: base ?? folder.path,
      verifiedProfileIdentity: profile,
      storeUuid: _storeId,
      library: library,
    );

    setUp(() {
      library = DynamicLibrary.open(nativePath);
      folder = Directory(Directory.systemTemp.resolveSymbolicLinksSync())
          .createTempSync('notaris-document-fixture-');
    });

    test('copies Unicode source, hashes, publishes without replacing, and reopens by profile', () async {
      final source = File(p.join(folder.path, 'Akta 名.pdf'));
      final data = List<int>.generate(160000, (i) => i % 251);
      await source.writeAsBytes(data);
      final expected = (
        length: data.length,
        sha256: sha256.convert(data).toString(),
      );
      await store().withLease((lease) async {
        expect(lease.stageSource(_operation, source.path), expected);
        expect(lease.readStage(_operation, expected), data);
        expect(
          () => lease.stageSource(_operation, source.path),
          _failure('stage_create'),
        );
        expect(
          () => lease.publish(_operation, _version, DocumentFileType.pdf, (
            length: expected.length,
            sha256: '0' * 64,
          )),
          _failure('stage_integrity'),
        );
        lease.publish(_operation, _version, DocumentFileType.pdf, expected);
        expect(lease.stageSource(_otherOperation, source.path), expected);
        expect(
          () => lease.publish(
            _otherOperation,
            _version,
            DocumentFileType.pdf,
            expected,
          ),
          _failure('publish'),
        );
        expect(lease.readStage(_otherOperation, expected), data);
        await expectLater(
          store().withLease((_) async {}),
          _failure('store_open'),
        );
      });
      expect(await source.readAsBytes(), data);
      await store().withLease((lease) async {
        expect(lease.readBlob(_version, DocumentFileType.pdf, expected), data);
        expect(
          () => lease.readBlob(_version, DocumentFileType.pdf, (
            length: expected.length,
            sha256: '0' * 64,
          )),
          _failure('hash_mismatch'),
        );
      });
      await store(profile: 'profile B').withLease((lease) async {
        expect(
          () => lease.readBlob(_version, DocumentFileType.pdf, expected),
          _failure('blob_open'),
        );
      });
    });

    test(
      'rejects empty, oversized, missing, traversal, network and ADS sources',
      () async {
        final empty = File(p.join(folder.path, 'empty.pdf'))..createSync();
        final large = File(
          p.join(folder.path, 'large.pdf'),
        ).openSync(mode: FileMode.write)..truncateSync(documentByteLimit + 1);
        large.closeSync();
        await store().withLease((lease) async {
          expect(
            () => lease.stageSource(_operation, empty.path),
            _failure('byte_limit'),
          );
          expect(
            () =>
                lease.stageSource(_operation, p.join(folder.path, 'large.pdf')),
            _failure('byte_limit'),
          );
          for (final path in [
            p.join(folder.path, 'missing.pdf'),
            '${folder.path}\\..\\empty.pdf',
            r'\\localhost\share\file.pdf',
            '${empty.path}:hidden',
          ]) {
            expect(
              () => lease.stageSource(_operation, path),
              _failure('source_open'),
            );
          }
          expect(
            () => lease.stageSource('../bad', empty.path),
            _failure('byte_limit'),
          );
        });
      },
    );

    test(
      'refuses managed root junction without creating files at its destination',
      () async {
        final outside = Directory(p.join(folder.path, 'outside'))..createSync();
        final junction = p.join(folder.path, 'transaction-documents');
        String quote(String input) => "'${input.replaceAll("'", "''")}'";
        final setup = await Process.run('powershell.exe', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          '\$ErrorActionPreference="Stop"; New-Item -ItemType Junction -Path '
              '${quote(junction)} -Target ${quote(outside.path)} | Out-Null',
        ]);
        expect(setup.exitCode, 0, reason: '${setup.stderr}');
        await expectLater(
          store().withLease((_) async {}),
          _failure('store_open'),
        );
        expect(outside.listSync(), isEmpty);
      },
    );

    test('refuses an active source writer and detects actual managed-byte tampering', () async {
      final source = File(p.join(folder.path, 'source.png'))
        ..writeAsBytesSync([1, 2, 3, 4]);
      final writer = source.openSync(mode: FileMode.append);
      try {
        await store().withLease((lease) async {
          expect(
            () => lease.stageSource(_operation, source.path),
            _failure('source_open'),
          );
        });
      } finally {
        writer.closeSync();
      }
      final expected = await store().withLease((lease) async {
        expect(
          () => lease.stageSource('../bad', source.path),
          _failure('stage_create'),
        );
        final digest = lease.stageSource(_operation, source.path);
        lease.publish(_operation, _version, DocumentFileType.png, digest);
        return digest;
      });
      final blob = Directory(p.join(folder.path, 'transaction-documents'))
          .listSync(recursive: true)
          .whereType<File>()
          .singleWhere((file) => p.basename(file.path) == '$_version.png');
      await store().withLease((lease) async {
        expect(() => lease.digestSource(blob.path), _failure('source_open'));
      });
      blob.writeAsBytesSync([1, 2, 3, 0]);
      await store().withLease((lease) async {
        expect(
          () => lease.readBlob(_version, DocumentFileType.png, expected),
          _failure('hash_mismatch'),
        );
      });
    });

    test('refuses a changed profile manifest', () async {
      await store().withLease((_) async {});
      final manifest = Directory(p.join(folder.path, 'transaction-documents'))
          .listSync(recursive: true)
          .whereType<File>()
          .singleWhere((file) => p.basename(file.path) == 'manifest.json');
      manifest.writeAsStringSync('{"format":1,"profile_key":"wrong"}');
      await expectLater(
        store().withLease((_) async {}),
        _failure('store_open'),
      );
    });
  }, skip: !Platform.isWindows || nativePath.isEmpty);
}
