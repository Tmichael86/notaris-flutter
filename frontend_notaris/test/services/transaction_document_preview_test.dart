import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/services/transaction_document_preview.dart';
import 'package:frontend_notaris/services/windows_transaction_document_store.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<Uint8List> samplePdf(double width, double height) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(width, height),
      build: (_) => pw.Container(width: 10, height: 10, color: PdfColors.black),
    ),
  );
  return pdf.save();
}

Uint8List actionPdf(
  String catalog,
  String page,
  List<String> extras, {
  String trailer = '',
}) {
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R $catalog >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 120 100] $page >>',
    ...extras,
  ];
  final pdf = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (final (index, object) in objects.indexed) {
    offsets.add(pdf.length);
    pdf.write('${index + 1} 0 obj\n$object\nendobj\n');
  }
  final start = pdf.length;
  pdf.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final offset in offsets) {
    pdf.writeln('${offset.toString().padLeft(10, '0')} 00000 n ');
  }
  pdf.write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R $trailer >>\nstartxref\n$start\n%%EOF\n',
  );
  return Uint8List.fromList(ascii.encode(pdf.toString()));
}

Uint8List sampleJpeg() => base64Decode(
  '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDABQODxIPDRQSEBIXFRQYHjIhHhwcHj0sLiQySUBM'
  'S0dARkVQWnNiUFVtVkVGZIhlbXd7gYKBTmCNl4x9lnN+gXz/2wBDARUXFx4aHjshITt8U0ZT'
  'fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHx8fHz/wAAR'
  'CAACAAIDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAX/xAAUEAEAAAAAAAAAAAAA'
  'AAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAgX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oA'
  'DAMBAAIRAxEAPwCKACk//9k=',
);

int pngCrc32(Uint8List bytes, int start, int end) {
  var crc = 0xffffffff;
  for (var i = start; i < end; i++) {
    crc ^= bytes[i];
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc >>> 1) ^ ((crc & 1) == 0 ? 0 : 0xedb88320);
    }
  }
  return crc ^ 0xffffffff;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const worker = String.fromEnvironment('NOTARIS_DOCUMENT_TEST_PDF');
  final preview = TransactionDocumentPreview(pdfWorker: worker);
  const png =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aXioAAAAASUVORK5CYII=';

  test('validates JPEG bytes and rejects a missing end marker', () async {
    final bytes = sampleJpeg();
    expect(await preview.validate('Foto.JPEG', bytes), DocumentFileType.jpeg);
    await expectLater(
      preview.validate(
        'Foto.jpg',
        Uint8List.sublistView(bytes, 0, bytes.length - 2),
      ),
      throwsA(isA<DocumentFileFailure>()),
    );
  });

  test('JPEG dimensions are rejected before pixel decode', () async {
    final bytes = sampleJpeg();
    final frame = Iterable<int>.generate(bytes.length - 7).firstWhere(
      (index) => index > 0 && bytes[index - 1] == 0xff && bytes[index] == 0xc0,
    );
    ByteData.sublistView(bytes).setUint16(frame + 6, 9000);
    await expectLater(
      preview.validate('large.jpg', bytes),
      throwsA(
        isA<DocumentFileFailure>().having(
          (error) => error.code,
          'code',
          'image_decode_limit',
        ),
      ),
    );
  });

  test(
    'validates and decodes PNG, rejects mismatched and truncated content',
    () async {
      // Produce a valid fixture using the same engine that supplies previews.
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder)
          .drawColor(const ui.Color(0xff202020), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(2, 2);
      picture.dispose();
      final data = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      image.dispose();
      expect(
        await preview.validate('Salinan 名.png', data),
        DocumentFileType.png,
      );
      await expectLater(
        preview.validate('false.jpg', data),
        throwsA(isA<DocumentFileFailure>()),
      );
      await expectLater(
        preview.validate(
          'truncated.png',
          Uint8List.sublistView(data, 0, data.length - 5),
        ),
        throwsA(isA<DocumentFileFailure>()),
      );
      final oversized = base64Decode(png);
      ByteData.sublistView(oversized)
        ..setUint32(16, 9000)
        ..setUint32(29, pngCrc32(oversized, 12, 29));
      await expectLater(
        preview.validate('unsafe.png', oversized),
        throwsA(
          isA<DocumentFileFailure>().having(
            (error) => error.code,
            'code',
            'image_decode_limit',
          ),
        ),
      );
    },
  );

  group('Windows PDF worker', () {
    test('Windows refuses committed memory above the worker quota', () async {
      final result = await Process.run(worker, ['--verify-memory-limit']);
      expect(result.exitCode, 0);
    });

    test('deadline terminates and reaps the PDF worker', () async {
      final pdf = await samplePdf(595, 842);
      final timed = TransactionDocumentPreview(
        pdfWorker: worker,
        deadline: Duration.zero,
      );
      await expectLater(
        timed.pdfPage(pdf, 0),
        throwsA(
          isA<DocumentFileFailure>().having(
            (error) => error.code,
            'code',
            'preview_timeout',
          ),
        ),
      );
      expect((await preview.pdfPage(pdf, 0)).pageCount, 1);
    });

    test('raster preview leaves open, page and form actions inert', () async {
      final listener = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => listener.close(force: true));
      var requests = 0;
      listener.listen((request) async {
        requests++;
        await request.response.close();
      });
      final url = 'http://127.0.0.1:${listener.port}/pdf-action-fixture';
      for (final action in [
        '<< /S /URI /URI ($url) >>',
        '<< /S /JavaScript /JS (app.launchURL\\("$url"\\);) >>',
        '<< /S /Launch /F ($url) >>',
        '<< /S /SubmitForm /F ($url) >>',
      ]) {
        final data = actionPdf(
          '/OpenAction 4 0 R /AA << /WC 4 0 R >> /AcroForm << /Fields [5 0 R] >>',
          '/AA << /O 4 0 R /C 4 0 R >> /Annots [5 0 R]',
          [
            action,
            '<< /Type /Annot /Subtype /Widget /FT /Btn /T (Action fixture) /Rect [1 1 10 10] /A 4 0 R /AA << /Fo 4 0 R >> >>',
          ],
        );
        expect((await preview.pdfPage(data, 0)).pageCount, 1);
      }
      expect(requests, 0);
    });

    test('PDF attachments and encrypted input are refused', () async {
      final attachment = actionPdf(
        '/Names << /EmbeddedFiles << /Names [(harmless.txt) 4 0 R] >> >>',
        '',
        [
          '<< /Type /Filespec /F (harmless.txt) /EF << /F 5 0 R >> >>',
          '<< /Type /EmbeddedFile /Length 1 >>\nstream\nx\nendstream',
        ],
      );
      final encrypted = actionPdf('', '', [
        '<< /Filter /Standard /V 1 /R 2 /P -4 /O <${'00' * 32}> /U <${'00' * 32}> >>',
      ], trailer: '/Encrypt 4 0 R /ID [<0000> <0000>]');
      for (final bytes in [attachment, encrypted]) {
        await expectLater(
          preview.pdfPage(bytes, 0),
          throwsA(
            isA<DocumentFileFailure>().having(
              (error) => error.code,
              'code',
              'invalid_pdf',
            ),
          ),
        );
      }
    });
    test('validates ordinary PDF and rasterizes one bounded page', () async {
      final pdf = await samplePdf(595, 842);
      expect(await preview.validate('Akta.pdf', pdf), DocumentFileType.pdf);
      final result = await preview.pdfPage(pdf, 0);
      expect(result.pageCount, 1);
      expect(result.width, greaterThan(0));
      expect(result.height, greaterThan(0));
      expect(result.bgra.length, result.width * result.height * 4);
      expect(result.bgra.any((value) => value == 0), isTrue);
    });

    test('oversized PDF dimensions cannot exceed the bitmap budget', () async {
      final pdf = await samplePdf(99999, 99999);
      final result = await preview.pdfPage(pdf, 0);
      expect(result.width, lessThanOrEqualTo(documentPreviewMaxSide));
      expect(result.height, lessThanOrEqualTo(documentPreviewMaxSide));
      expect(
        result.width * result.height,
        lessThanOrEqualTo(documentPreviewMaxPixels),
      );
      await expectLater(
        preview.pdfPage(pdf, 1),
        throwsA(isA<DocumentFileFailure>()),
      );
    });

    test('malformed and truncated PDFs are rejected by the worker', () async {
      final fake = Uint8List.fromList(
        ascii.encode('%PDF-1.4\n invalid\n%%EOF\n'),
      );
      await expectLater(
        preview.validate('bad.pdf', fake),
        throwsA(isA<DocumentFileFailure>()),
      );
      final pdf = await samplePdf(595, 842);
      await expectLater(
        preview.validate(
          'truncated.pdf',
          Uint8List.sublistView(pdf, 0, pdf.length - 12),
        ),
        throwsA(isA<DocumentFileFailure>()),
      );
    });
  }, skip: !Platform.isWindows || worker.isEmpty);
}
