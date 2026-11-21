import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

final class _FileInfo extends Struct {
  @Uint32()
  external int attributes;
  @Uint32()
  external int creationLow;
  @Uint32()
  external int creationHigh;
  @Uint32()
  external int accessLow;
  @Uint32()
  external int accessHigh;
  @Uint32()
  external int writeLow;
  @Uint32()
  external int writeHigh;
  @Uint32()
  external int volume;
  @Uint32()
  external int sizeHigh;
  @Uint32()
  external int sizeLow;
  @Uint32()
  external int links;
  @Uint32()
  external int indexHigh;
  @Uint32()
  external int indexLow;
}

final class _Blob extends Struct {
  @Uint32()
  external int length;
  external Pointer<Uint8> bytes;
}

/// OS-owned Windows paths and current-user DPAPI, not an authentication provider.
/// No default secure-storage container or historical key is opened here.
class WindowsQaProfileIo {
  static final _kernel = DynamicLibrary.open('kernel32.dll');
  static final _crypt = DynamicLibrary.open('crypt32.dll');

  static String identity(String path, {required bool directory}) {
    if (!Platform.isWindows) throw StateError('qa_windows_required');
    return using((arena) {
      final open = _kernel
          .lookupFunction<
            IntPtr Function(
              Pointer<Utf16>,
              Uint32,
              Uint32,
              Pointer<Void>,
              Uint32,
              Uint32,
              IntPtr,
            ),
            int Function(Pointer<Utf16>, int, int, Pointer<Void>, int, int, int)
          >('CreateFileW');
      final close = _kernel
          .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
            'CloseHandle',
          );
      final info = _kernel
          .lookupFunction<
            Int32 Function(IntPtr, Pointer<_FileInfo>),
            int Function(int, Pointer<_FileInfo>)
          >('GetFileInformationByHandle');
      final handle = open(
        path.toNativeUtf16(allocator: arena),
        0x80, // FILE_READ_ATTRIBUTES, including ancestor directories.
        7,
        nullptr,
        3,
        0x02200000,
        0,
      );
      if (handle == -1 || handle == 0) throw StateError('qa_path_unreadable');
      try {
        final result = arena<_FileInfo>();
        if (info(handle, result) == 0 ||
            result.ref.attributes & 0x400 != 0 ||
            (result.ref.attributes & 0x10 != 0) != directory ||
            (!directory && result.ref.links != 1)) {
          throw StateError('qa_link_or_type_rejected');
        }
        return '${result.ref.volume.toRadixString(16)}:'
            '${result.ref.indexHigh.toRadixString(16)}:'
            '${result.ref.indexLow.toRadixString(16)}';
      } finally {
        close(handle);
      }
    });
  }

  static Uint8List protect(Uint8List bytes, String binding) =>
      _dpapi(bytes, binding, seal: true);
  static Uint8List unprotect(Uint8List bytes, String binding) =>
      _dpapi(bytes, binding, seal: false);

  static Uint8List _dpapi(
    Uint8List bytes,
    String binding, {
    required bool seal,
  }) {
    if (!Platform.isWindows || bytes.isEmpty || bytes.length > 1024 * 1024) {
      throw StateError('qa_auth_blob_invalid');
    }
    return using((arena) {
      Pointer<_Blob> blob(Uint8List data) {
        final b = arena<_Blob>();
        b.ref.length = data.length;
        b.ref.bytes = arena<Uint8>(data.length);
        b.ref.bytes.asTypedList(data.length).setAll(0, data);
        return b;
      }

      final input = blob(bytes);
      final entropy = blob(Uint8List.fromList(utf8.encode(binding)));
      final output = arena<_Blob>();
      final localFree = _kernel
          .lookupFunction<
            Pointer<Void> Function(Pointer<Void>),
            Pointer<Void> Function(Pointer<Void>)
          >('LocalFree');
      final protect = _crypt
          .lookupFunction<
            Int32 Function(
              Pointer<_Blob>,
              Pointer<Utf16>,
              Pointer<_Blob>,
              Pointer<Void>,
              Pointer<Void>,
              Uint32,
              Pointer<_Blob>,
            ),
            int Function(
              Pointer<_Blob>,
              Pointer<Utf16>,
              Pointer<_Blob>,
              Pointer<Void>,
              Pointer<Void>,
              int,
              Pointer<_Blob>,
            )
          >('CryptProtectData');
      final unprotect = _crypt
          .lookupFunction<
            Int32 Function(
              Pointer<_Blob>,
              Pointer<Pointer<Utf16>>,
              Pointer<_Blob>,
              Pointer<Void>,
              Pointer<Void>,
              Uint32,
              Pointer<_Blob>,
            ),
            int Function(
              Pointer<_Blob>,
              Pointer<Pointer<Utf16>>,
              Pointer<_Blob>,
              Pointer<Void>,
              Pointer<Void>,
              int,
              Pointer<_Blob>,
            )
          >('CryptUnprotectData');
      final ok = seal
          ? protect(input, nullptr, entropy, nullptr, nullptr, 1, output)
          : unprotect(input, nullptr, entropy, nullptr, nullptr, 1, output);
      try {
        if (ok == 0 ||
            output.ref.length == 0 ||
            output.ref.length > 1024 * 1024) {
          throw StateError('qa_auth_unseal_failed');
        }
        return Uint8List.fromList(
          output.ref.bytes.asTypedList(output.ref.length),
        );
      } finally {
        if (output.ref.bytes != nullptr) localFree(output.ref.bytes.cast());
      }
    });
  }
}
