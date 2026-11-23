import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

const documentByteLimit = 20 * 1024 * 1024;
const _chunkSize = 64 * 1024;

enum DocumentFileType {
  pdf('application/pdf'),
  jpeg('image/jpeg'),
  png('image/png');

  const DocumentFileType(this.mediaType);
  final String mediaType;
  int get _nativeCode => index + 1;
}

typedef DocumentDigest = ({int length, String sha256});

class DocumentFileFailure implements Exception {
  const DocumentFileFailure(this.code, [this.nativeCode]);

  final String code;
  final int? nativeCode;

  @override
  String toString() => 'DocumentFileFailure($code, $nativeCode)';
}

/// The caller must derive the profile identity from its verified DB binding.
/// A caller-supplied path must never come from the document picker or a row.
class WindowsTransactionDocumentStore {
  static String? pickSource() => using((arena) {
    const capacity = 32768;
    final path = arena<Uint16>(capacity).cast<Utf16>();
    final pick = _loadNative()
        .lookupFunction<
          Uint32 Function(Pointer<Utf16>, Uint32),
          int Function(Pointer<Utf16>, int)
        >('notaris_document_pick');
    _check('file_picker', pick(path, capacity));
    final selected = path.toDartString();
    return selected.isEmpty ? null : selected;
  });

  WindowsTransactionDocumentStore({
    required String verifiedAppDirectory,
    required String verifiedProfileIdentity,
    required this.storeUuid,
    DynamicLibrary? library,
  }) : _base = verifiedAppDirectory,
       _profileKey = sha256
           .convert(utf8.encode(verifiedProfileIdentity))
           .toString(),
       _native = _DocumentNative(library ?? _loadNative()) {
    if (verifiedProfileIdentity.isEmpty ||
        !p.windows.isAbsolute(_base) ||
        _base.contains('\u0000') ||
        storeUuid.contains('\u0000')) {
      throw const DocumentFileFailure('invalid_profile');
    }
  }

  static DynamicLibrary _loadNative() {
    if (!Platform.isWindows) {
      throw const DocumentFileFailure('unsupported_platform');
    }
    return DynamicLibrary.open(
      p.join(
        p.dirname(Platform.resolvedExecutable),
        'notaris_document_store.dll',
      ),
    );
  }

  final String _base, _profileKey, storeUuid;
  final _DocumentNative _native;

  /// The exclusive native lease spans filesystem operations and their SQLite
  /// transaction. An interrupted process releases the lock through Windows.
  Future<T> withLease<T>(Future<T> Function(DocumentStoreLease) action) async {
    final store = using((arena) {
      final error = arena<Uint32>();
      final handle = _native.open(
        _base.toNativeUtf16(allocator: arena),
        _profileKey.toNativeUtf16(allocator: arena),
        storeUuid.toNativeUtf16(allocator: arena),
        error,
      );
      if (handle == nullptr) _throwNative('store_open', error.value);
      return handle;
    });
    final lease = DocumentStoreLease._(_native, store);
    try {
      return await action(lease);
    } finally {
      lease._handle = nullptr;
      _native.closeStore(store);
    }
  }
}

class DocumentStoreLease {
  DocumentStoreLease._(this._native, this._handle);

  final _DocumentNative _native;
  Pointer<Void> _handle;

  Pointer<Void> get _openHandle {
    if (_handle == nullptr) throw const DocumentFileFailure('store_closed');
    return _handle;
  }

  /// Copies a source opened without write/delete sharing. Neither the path
  /// nor the display name becomes a managed filename.
  DocumentDigest stageSource(String operationUuid, String selectedPath) =>
      using((arena) {
        if (selectedPath.contains('\u0000') ||
            operationUuid.contains('\u0000')) {
          throw const DocumentFileFailure('source_open');
        }
        final store = _openHandle;
        final error = arena<Uint32>();
        final source = _native.source(
          store,
          selectedPath.toNativeUtf16(allocator: arena),
          error,
        );
        if (source == nullptr) _throwNative('source_open', error.value);
        try {
          final initial = _fileInfo(source, arena);
          _validateLength(initial.length);
          final stage = _native.stage(
            store,
            operationUuid.toNativeUtf16(allocator: arena),
            1,
            error,
          );
          if (stage == nullptr) _throwNative('stage_create', error.value);
          try {
            final copied = _scan(source, arena, output: stage);
            _check('source_rewind', _native.rewind(source));
            if (initial != _fileInfo(source, arena) ||
                copied.length != initial.length ||
                _scan(source, arena) != copied ||
                initial != _fileInfo(source, arena)) {
              throw const DocumentFileFailure('source_changed');
            }
            _check('stage_rewind', _native.rewind(stage));
            if (_scan(stage, arena) != copied) {
              throw const DocumentFileFailure('stage_integrity');
            }
            return copied;
          } finally {
            _native.closeFile(stage);
          }
        } finally {
          _native.closeFile(source);
        }
      });

  DocumentDigest digestSource(String selectedPath) => using((arena) {
    if (selectedPath.contains('\u0000')) {
      throw const DocumentFileFailure('source_open');
    }
    final error = arena<Uint32>();
    final source = _native.source(
      _openHandle,
      selectedPath.toNativeUtf16(allocator: arena),
      error,
    );
    if (source == nullptr) _throwNative('source_open', error.value);
    try {
      final initial = _fileInfo(source, arena);
      _validateLength(initial.length);
      final digest = _scan(source, arena);
      if (initial != _fileInfo(source, arena) ||
          digest.length != initial.length) {
        throw const DocumentFileFailure('source_changed');
      }
      return digest;
    } finally {
      _native.closeFile(source);
    }
  });

  Uint8List readStage(String operationUuid, DocumentDigest expected) =>
      _withStage(
        operationUuid,
        (file, arena) => _verifiedBytes(file, arena, expected),
      );

  void publish(
    String operationUuid,
    String versionUuid,
    DocumentFileType type,
    DocumentDigest expected,
  ) => _withStage(operationUuid, (file, arena) {
    if (_scan(file, arena) != expected) {
      throw const DocumentFileFailure('stage_integrity');
    }
    _check(
      'publish',
      _native.publish(
        file,
        versionUuid.toNativeUtf16(allocator: arena),
        type._nativeCode,
      ),
    );
    _check('blob_rewind', _native.rewind(file));
    if (_scan(file, arena) != expected) {
      throw const DocumentFileFailure('blob_integrity');
    }
  });

  Uint8List readBlob(
    String versionUuid,
    DocumentFileType type,
    DocumentDigest expected,
  ) => using((arena) {
    final error = arena<Uint32>();
    final blob = _native.blob(
      _openHandle,
      versionUuid.toNativeUtf16(allocator: arena),
      type._nativeCode,
      error,
    );
    if (blob == nullptr) _throwNative('blob_open', error.value);
    try {
      return _verifiedBytes(blob, arena, expected);
    } finally {
      _native.closeFile(blob);
    }
  });

  T _withStage<T>(String id, T Function(Pointer<Void>, Arena) action) =>
      using((arena) {
        final error = arena<Uint32>();
        final stage = _native.stage(
          _openHandle,
          id.toNativeUtf16(allocator: arena),
          0,
          error,
        );
        if (stage == nullptr) _throwNative('stage_open', error.value);
        try {
          return action(stage, arena);
        } finally {
          _native.closeFile(stage);
        }
      });

  Uint8List _verifiedBytes(
    Pointer<Void> file,
    Arena arena,
    DocumentDigest expected,
  ) {
    _validateLength(expected.length);
    if (_fileInfo(file, arena).length != expected.length) {
      throw const DocumentFileFailure('byte_length_mismatch');
    }
    final bytes = Uint8List(expected.length);
    if (_scan(file, arena, bytes: bytes) != expected) {
      throw const DocumentFileFailure('hash_mismatch');
    }
    return bytes;
  }

  ({int length, int modified}) _fileInfo(Pointer<Void> file, Arena arena) {
    final length = arena<Int64>();
    final modified = arena<Int64>();
    _check('file_info', _native.info(file, length, modified));
    return (length: length.value, modified: modified.value);
  }

  DocumentDigest _scan(
    Pointer<Void> input,
    Arena arena, {
    Pointer<Void>? output,
    Uint8List? bytes,
  }) {
    final buffer = arena<Uint8>(_chunkSize);
    final count = arena<Uint32>();
    final written = arena<Uint32>();
    final sink = _DigestSink();
    final digest = sha256.startChunkedConversion(sink);
    var length = 0;
    while (true) {
      _check('file_read', _native.read(input, buffer, _chunkSize, count));
      final size = count.value;
      if (size == 0) break;
      final next = length + size;
      _validateLength(next);
      final chunk = buffer.asTypedList(size);
      digest.add(chunk);
      if (output != null) {
        _check('stage_write', _native.write(output, buffer, size, written));
        if (written.value != size) {
          throw const DocumentFileFailure('stage_short_write');
        }
      }
      if (bytes != null) {
        if (next > bytes.length) {
          throw const DocumentFileFailure('byte_length_mismatch');
        }
        bytes.setRange(length, next, chunk);
      }
      length = next;
    }
    _validateLength(length);
    digest.close();
    return (length: length, sha256: sink.value.toString());
  }
}

void _validateLength(int length) {
  if (length <= 0 || length > documentByteLimit) {
    throw const DocumentFileFailure('byte_limit');
  }
}

void _check(String operation, int error) {
  if (error != 0) _throwNative(operation, error);
}

Never _throwNative(String operation, int error) =>
    throw DocumentFileFailure(operation, error);

class _DigestSink implements Sink<Digest> {
  late Digest value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

typedef _StoreOpenNative = Pointer<Void> Function(
  Pointer<Utf16>,
  Pointer<Utf16>,
  Pointer<Utf16>,
  Pointer<Uint32>,
);
typedef _SourceOpenNative = Pointer<Void> Function(
  Pointer<Void>,
  Pointer<Utf16>,
  Pointer<Uint32>,
);
typedef _EntryOpenNative = Pointer<Void> Function(
  Pointer<Void>,
  Pointer<Utf16>,
  Int32,
  Pointer<Uint32>,
);
typedef _EntryOpen = Pointer<Void> Function(
  Pointer<Void>,
  Pointer<Utf16>,
  int,
  Pointer<Uint32>,
);
typedef _IoNative = Uint32 Function(
  Pointer<Void>,
  Pointer<Uint8>,
  Uint32,
  Pointer<Uint32>,
);
typedef _Io = int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Uint32>);

class _DocumentNative {
  _DocumentNative(this._library);
  final DynamicLibrary _library;

  late final open = _library.lookupFunction<_StoreOpenNative, _StoreOpenNative>(
    'notaris_store_open',
  );
  late final source = _library
      .lookupFunction<_SourceOpenNative, _SourceOpenNative>(
        'notaris_store_source',
      );
  late final stage = _library.lookupFunction<_EntryOpenNative, _EntryOpen>(
    'notaris_store_stage',
  );
  late final blob = _library.lookupFunction<_EntryOpenNative, _EntryOpen>(
    'notaris_store_blob',
  );
  late final publish = _library
      .lookupFunction<
        Uint32 Function(Pointer<Void>, Pointer<Utf16>, Int32),
        int Function(Pointer<Void>, Pointer<Utf16>, int)
      >('notaris_store_publish');
  late final rewind = _library
      .lookupFunction<
        Uint32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('notaris_store_rewind');
  late final info = _library
      .lookupFunction<
        Uint32 Function(Pointer<Void>, Pointer<Int64>, Pointer<Int64>),
        int Function(Pointer<Void>, Pointer<Int64>, Pointer<Int64>)
      >('notaris_store_info');
  late final read = _library.lookupFunction<_IoNative, _Io>(
    'notaris_store_read',
  );
  late final write = _library.lookupFunction<_IoNative, _Io>(
    'notaris_store_write',
  );
  late final closeStore = _library
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('notaris_store_close');
  late final closeFile = _library
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('notaris_store_file_close');
}
