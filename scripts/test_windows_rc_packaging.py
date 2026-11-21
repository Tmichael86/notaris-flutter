"""Inspect a Windows RC bundle without launching it or accessing any profile."""
import ctypes
from ctypes import wintypes
import os
from pathlib import Path
import re
import struct
import unittest

REPO = Path(__file__).resolve().parents[1]
BUNDLE = Path(os.environ.get('NOTARIS_RC_BUNDLE', REPO / 'frontend_notaris/build/windows/x64/runner/Release')).resolve()
ENDPOINT = b'https://qa-endpoint-unconfigured.invalid/api/v1'
REQUIRED = {
    'frontend_notaris.exe', 'flutter_windows.dll', 'notaris_document_pdf.exe',
    'notaris_document_store.dll', 'file_selector_windows_plugin.dll',
    'flutter_secure_storage_windows_plugin.dll', 'printing_plugin.dll',
    'pdfium.dll', 'sqlite3.dll', 'data/app.so', 'data/icudtl.dat',
    'data/flutter_assets/AssetManifest.bin', 'data/flutter_assets/FontManifest.json',
    'data/flutter_assets/assets/images/app_logo.png',
    'data/flutter_assets/assets/fonts/NotoSans-Regular.ttf',
}


def pe_info(path):
    """Read PE metadata/import names; never LoadLibrary an application binary."""
    b = path.read_bytes()
    if b[:2] != b'MZ':
        raise ValueError('not PE')
    off = struct.unpack_from('<I', b, 0x3c)[0]
    if b[off:off + 4] != b'PE\x00\x00':
        raise ValueError('bad PE signature')
    machine, sections = struct.unpack_from('<HH', b, off + 4)
    optional_size = struct.unpack_from('<H', b, off + 20)[0]
    opt = off + 24
    if struct.unpack_from('<H', b, opt)[0] != 0x20b:
        raise ValueError('not PE32+')
    section_list = []
    for i in range(sections):
        section_list.append(struct.unpack_from('<IIII', b, opt + optional_size + i * 40 + 8))

    def pos(rva):
        for virtual_size, start, size, file_start in section_list:
            if start <= rva < start + max(size, virtual_size):
                return file_start + rva - start
        raise ValueError('RVA outside sections')

    def string(rva):
        start = pos(rva)
        return b[start:b.index(b'\x00', start)].decode('ascii').lower()

    imports = []
    rva = struct.unpack_from('<I', b, opt + 112 + 8)[0]
    if rva:
        at = pos(rva)
        while any(b[at:at + 20]):
            imports.append(string(struct.unpack_from('<I', b, at + 12)[0]))
            at += 20
    return {'machine': machine, 'imports': sorted(set(imports))}


def version_info(path):
    dll = ctypes.WinDLL(str(Path(os.environ['SystemRoot']) / 'System32/version.dll'))
    dll.GetFileVersionInfoSizeW.argtypes = [wintypes.LPCWSTR, ctypes.POINTER(wintypes.DWORD)]
    dll.GetFileVersionInfoSizeW.restype = wintypes.DWORD
    dll.GetFileVersionInfoW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p]
    dll.GetFileVersionInfoW.restype = wintypes.BOOL
    dll.VerQueryValueW.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR, ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(wintypes.UINT)]
    dll.VerQueryValueW.restype = wintypes.BOOL
    size = dll.GetFileVersionInfoSizeW(str(path), None)
    if not size:
        raise ValueError('missing version resource')
    buf = ctypes.create_string_buffer(size)
    if not dll.GetFileVersionInfoW(str(path), 0, size, buf):
        raise ValueError('version resource unreadable')
    ptr, length = ctypes.c_void_p(), wintypes.UINT()
    if not dll.VerQueryValueW(buf, '\\', ctypes.byref(ptr), ctypes.byref(length)):
        raise ValueError('fixed version unreadable')
    fixed = struct.unpack('<13I', ctypes.string_at(ptr, 52))
    if fixed[0] != 0xfeef04bd:
        raise ValueError('bad fixed version signature')
    result = {'version': [fixed[2] >> 16, fixed[2] & 65535, fixed[3] >> 16, fixed[3] & 65535], 'debug': bool(fixed[7] & 1)}
    for name in ['ProductName', 'FileDescription', 'OriginalFilename']:
        if not dll.VerQueryValueW(buf, '\\StringFileInfo\\040904e4\\' + name, ctypes.byref(ptr), ctypes.byref(length)):
            raise ValueError('missing string resource')
        result[name] = ctypes.wstring_at(ptr, length.value).rstrip('\x00')
    return result


class WindowsRCPackaging(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.name != 'nt':
            raise unittest.SkipTest('Windows artifact inspection requires Windows')
        if not BUNDLE.is_dir():
            raise RuntimeError('Build the release bundle first; no debug fallback')

    def test_required_bundle_and_assets_present(self):
        for name in REQUIRED:
            with self.subTest(name=name):
                self.assertTrue((BUNDLE / name).is_file(), name)
                self.assertGreater((BUNDLE / name).stat().st_size, 0)

    def test_pe_architecture_and_no_debug_crt_imports(self):
        native = [p for p in BUNDLE.rglob('*') if p.suffix.lower() in {'.exe', '.dll'}]
        self.assertGreaterEqual(len(native), 9)
        for p in native:
            with self.subTest(binary=p.name):
                meta = pe_info(p)
                self.assertEqual(meta['machine'], 0x8664)
                self.assertFalse(any(re.fullmatch(r'(?:msvcp|vcruntime|ucrtbase|concrt)\d*(?:_\d+)?d\.dll', n) for n in meta['imports']))

    def test_aot_snapshot_is_x64_elf(self):
        b = (BUNDLE / 'data/app.so').read_bytes()
        self.assertEqual(b[:6], b'\x7fELF\x02\x01')
        self.assertEqual(struct.unpack_from('<H', b, 18)[0], 62)

    def test_release_resource_identity(self):
        v = version_info(BUNDLE / 'frontend_notaris.exe')
        self.assertEqual(v['version'], [1, 0, 0, 1])
        self.assertFalse(v['debug'])
        self.assertEqual(v['ProductName'], 'MY NOTARIS - SIM Notaris & PPAT')
        self.assertEqual(v['FileDescription'], v['ProductName'])
        self.assertEqual(v['OriginalFilename'], 'frontend_notaris.exe')

    def test_branding_icon_and_original_png_in_bundle(self):
        original = (REPO / 'frontend_notaris/assets/images/app_logo.png').read_bytes()
        self.assertEqual((BUNDLE / 'data/flutter_assets/assets/images/app_logo.png').read_bytes(), original)
        icon = (REPO / 'frontend_notaris/windows/runner/resources/app_icon.ico').read_bytes()
        reserved, kind, count = struct.unpack_from('<HHH', icon)
        self.assertEqual((reserved, kind), (0, 1))
        sizes = set()
        for i in range(count):
            w, h, _, _, _, bits, size, offset = struct.unpack_from('<BBBBHHII', icon, 6 + i * 16)
            sizes.add((w or 256, h or 256))
            self.assertGreater(size, 0)
            self.assertLessEqual(offset + size, len(icon))
            self.assertEqual(icon[offset:offset + 8], b'\x89PNG\r\n\x1a\n')
        self.assertTrue({(16, 16), (32, 32), (48, 48), (256, 256)} <= sizes)

    def test_unconfigured_endpoint_compiled_not_live(self):
        aot = (BUNDLE / 'data/app.so').read_bytes()
        self.assertTrue(ENDPOINT in aot or ENDPOINT.decode().encode('utf-16le') in aot)

    def test_no_profile_credentials_or_database_files(self):
        forbidden = {'.sqlite', '.db', '.sql', '.dump', '.key', '.pem', '.pfx', '.pgpass', '.wal'}
        basenames = {'session.exe', 'login.private.json', 'credentials.json', '.env', '.env.notarisdev', 'public.key', 'manifest.sig'}
        for p in BUNDLE.rglob('*'):
            with self.subTest(path=str(p.relative_to(BUNDLE))):
                self.assertFalse(p.is_symlink())
                if p.is_file():
                    self.assertNotIn(p.suffix.lower(), forbidden)
                    self.assertNotIn(p.name.lower(), basenames)
                    self.assertNotRegex(p.name.lower(), r'(?:\.sqlite|\.db)-(?:wal|shm)$')

    def test_native_loader_dependencies_are_packaged_or_os_prerequisites(self):
        bundled = {p.name.lower() for p in BUNDLE.rglob('*') if p.is_file()}
        system = Path(os.environ['SystemRoot']) / 'System32'
        for p in BUNDLE.rglob('*'):
            if p.suffix.lower() not in {'.exe', '.dll'}:
                continue
            for dep in pe_info(p)['imports']:
                with self.subTest(binary=p.name, dependency=dep):
                    self.assertTrue(dep in bundled or dep.startswith(('api-ms-', 'ext-ms-')) or (system / dep).is_file(), dep)
        # Host resolution does not certify a clean-machine install or runtime.


if __name__ == '__main__':
    unittest.main()
