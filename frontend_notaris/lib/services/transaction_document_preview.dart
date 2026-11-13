import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;

import 'windows_transaction_document_store.dart';

const documentPreviewMaxSide = 1536;
const documentPreviewMaxPixels = 2 * 1024 * 1024;
const documentImageMaxSourceSide = 8192;
const documentImageMaxSourcePixels = 16 * 1024 * 1024;

class TransactionDocumentPreview {
  TransactionDocumentPreview({String? pdfWorker, Duration? deadline})
    : _pdfWorker =
          pdfWorker ??
          p.join(
            p.dirname(Platform.resolvedExecutable),
            'notaris_document_pdf.exe',
          ),
      _deadline = deadline != null && deadline < const Duration(seconds: 10)
          ? deadline
          : const Duration(seconds: 10);

  final String _pdfWorker;
  final Duration _deadline;

  Future<DocumentFileType> validate(String displayName, Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > documentByteLimit) {
      throw const DocumentFileFailure('byte_limit');
    }
    final extension = p.extension(displayName).toLowerCase();
    final type = switch (extension) {
      '.pdf' when _starts(bytes, [37, 80, 68, 70, 45]) => DocumentFileType.pdf,
      '.jpeg' ||
      '.jpg' when _starts(bytes, [255, 216, 255]) => DocumentFileType.jpeg,
      '.png' when _starts(bytes, [137, 80, 78, 71, 13, 10, 26, 10]) =>
        DocumentFileType.png,
      _ => throw const DocumentFileFailure('unsupported_content'),
    };
    if (type == DocumentFileType.pdf) {
      await _pdf(bytes, 0xffffffff);
    } else {
      final decoded = await image(bytes, type);
      decoded.dispose();
    }
    return type;
  }

  /// The encoded image descriptor exposes dimensions before allocating pixels.
  /// Its source budget also bounds decoders that cannot subsample in place.
  Future<ui.Image> image(Uint8List bytes, DocumentFileType type) async {
    if (bytes.isEmpty || bytes.length > documentByteLimit) {
      throw const DocumentFileFailure('byte_limit');
    }
    final prefix = switch (type) {
      DocumentFileType.jpeg => const [255, 216, 255],
      DocumentFileType.png => const [137, 80, 78, 71, 13, 10, 26, 10],
      _ => throw const DocumentFileFailure('unsupported_content'),
    };
    final suffix = switch (type) {
      DocumentFileType.jpeg => const [255, 217],
      DocumentFileType.png => const [
        0,
        0,
        0,
        0,
        73,
        69,
        78,
        68,
        174,
        66,
        96,
        130,
      ],
      _ => throw const DocumentFileFailure('unsupported_content'),
    };
    if (!_starts(bytes, prefix) ||
        !_starts(bytes, suffix, bytes.length - suffix.length)) {
      throw const DocumentFileFailure('invalid_image');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        final width = descriptor.width;
        final height = descriptor.height;
        if (width <= 0 ||
            height <= 0 ||
            width > documentImageMaxSourceSide ||
            height > documentImageMaxSourceSide ||
            width > documentImageMaxSourcePixels ~/ height) {
          throw const DocumentFileFailure('image_decode_limit');
        }
        final scale = math.min(
          1.0,
          math.min(
            documentPreviewMaxSide / math.max(width, height),
            math.sqrt(documentPreviewMaxPixels / (width * height)),
          ),
        );
        final codec = await descriptor.instantiateCodec(
          targetWidth: math.max(1, (width * scale).floor()),
          targetHeight: math.max(1, (height * scale).floor()),
        );
        try {
          if (codec.frameCount != 1) {
            throw const DocumentFileFailure('unsupported_content');
          }
          final frame = await codec.getNextFrame();
          if (frame.image.width > documentPreviewMaxSide ||
              frame.image.height > documentPreviewMaxSide ||
              frame.image.width >
                  documentPreviewMaxPixels ~/ frame.image.height) {
            frame.image.dispose();
            throw const DocumentFileFailure('image_decode_limit');
          }
          return frame.image;
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor.dispose();
      }
    } on DocumentFileFailure {
      rethrow;
    } on Exception {
      throw const DocumentFileFailure('invalid_image');
    } finally {
      buffer.dispose();
    }
  }

  Future<DocumentPdfPage> pdfPage(Uint8List bytes, int page) {
    if (page < 0 || page >= 0xffffffff) {
      throw const DocumentFileFailure('preview_unavailable');
    }
    return _pdf(bytes, page);
  }

  Future<DocumentPdfPage> _pdf(Uint8List bytes, int page) async {
    if (!Platform.isWindows ||
        !p.isAbsolute(_pdfWorker) ||
        p.basename(_pdfWorker).toLowerCase() != 'notaris_document_pdf.exe') {
      throw const DocumentFileFailure('preview_unavailable');
    }
    if (bytes.isEmpty || bytes.length > documentByteLimit) {
      throw const DocumentFileFailure('byte_limit');
    }
    try {
      final systemRoot = Platform.environment['SystemRoot'];
      if (systemRoot == null || systemRoot.isEmpty) {
        throw const DocumentFileFailure('preview_unavailable');
      }
      final process = await Process.start(
        _pdfWorker,
        const [],
        environment: {'SystemRoot': systemRoot},
        includeParentEnvironment: false,
      );
      try {
        final header = ByteData(8)
          ..setUint32(0, bytes.length, Endian.little)
          ..setUint32(4, page, Endian.little);
        Future<void> send() async {
          process.stdin.add(header.buffer.asUint8List());
          await process.stdin.addStream(Stream.value(bytes));
          await process.stdin.close();
        }

        final results = await Future.wait<Object?>([
          _readWorkerOutput(process.stdout),
          process.stderr.drain<void>(),
          process.exitCode,
          send().then<Object?>((_) => null, onError: (Object error) => error),
        ], eagerError: true).timeout(_deadline);
        if (results[2] != 0) {
          throw DocumentFileFailure('preview_unavailable', results[2] as int);
        }
        if (results[3] != null) {
          throw const DocumentFileFailure('preview_unavailable');
        }
        final packet = results.first as Uint8List;
        if (packet.length < 16) {
          throw const DocumentFileFailure('preview_unavailable');
        }
        final result = ByteData.sublistView(packet, 0, 16);
        final status = result.getUint32(0, Endian.little);
        if (status == 1) throw const DocumentFileFailure('invalid_pdf');
        if (status != 0) throw const DocumentFileFailure('preview_unavailable');
        final pages = result.getUint32(4, Endian.little);
        final width = result.getUint32(8, Endian.little);
        final height = result.getUint32(12, Endian.little);
        final inspectOnly = page == 0xffffffff;
        if (pages == 0 ||
            (inspectOnly
                ? width != 0 || height != 0
                : page >= pages ||
                      width == 0 ||
                      height == 0 ||
                      width > documentPreviewMaxSide ||
                      height > documentPreviewMaxSide ||
                      width > documentPreviewMaxPixels ~/ height) ||
            packet.length != 16 + width * height * 4) {
          throw const DocumentFileFailure('preview_unavailable');
        }
        return DocumentPdfPage(
          pages,
          width,
          height,
          Uint8List.sublistView(packet, 16),
        );
      } finally {
        // No shell fallback. On timeout or pipe failure, terminate the worker.
        process.kill(ProcessSignal.sigkill);
        await process.exitCode;
      }
    } on DocumentFileFailure {
      rethrow;
    } on TimeoutException {
      throw const DocumentFileFailure('preview_timeout');
    } on ProcessException catch (error) {
      throw DocumentFileFailure('preview_unavailable', error.errorCode);
    } on FileSystemException catch (error) {
      throw DocumentFileFailure(
        'preview_unavailable',
        error.osError?.errorCode,
      );
    } on Exception {
      throw const DocumentFileFailure('preview_unavailable');
    }
  }

  Future<Uint8List> _readWorkerOutput(Stream<List<int>> stream) async {
    final output = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (output.length + chunk.length > 16 + documentPreviewMaxPixels * 4) {
        throw const DocumentFileFailure('preview_unavailable');
      }
      output.add(chunk);
    }
    return output.takeBytes();
  }
}

class DocumentPdfPage {
  const DocumentPdfPage(this.pageCount, this.width, this.height, this.bgra);
  final int pageCount, width, height;
  final Uint8List bgra;
}

bool _starts(Uint8List bytes, List<int> signature, [int offset = 0]) {
  if (offset < 0 || offset + signature.length > bytes.length) return false;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[offset + i] != signature[i]) return false;
  }
  return true;
}
