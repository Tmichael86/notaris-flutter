#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <aclapi.h>
#include <commdlg.h>
#include <sddl.h>
#include <winternl.h>

#include <cstddef>
#include <memory>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace {
class Handle {
 public:
  explicit Handle(HANDLE value = INVALID_HANDLE_VALUE) : value_(value) {}
  ~Handle() { if (valid()) CloseHandle(value_); }
  Handle(Handle&& other) noexcept
      : value_(std::exchange(other.value_, INVALID_HANDLE_VALUE)) {}
  Handle(const Handle&) = delete;
  HANDLE get() const { return value_; }
  bool valid() const { return value_ != INVALID_HANDLE_VALUE; }
 private:
  HANDLE value_;
};

struct LocalAllocation {
  void* value = nullptr;
  ~LocalAllocation() { if (value) LocalFree(value); }
};

bool IsHex(wchar_t c) {
  return (c >= L'0' && c <= L'9') || (c >= L'a' && c <= L'f');
}

bool IsUuid(std::wstring_view value) {
  if (value.size() != 36) return false;
  for (size_t i = 0; i < value.size(); ++i) {
    const bool dash = i == 8 || i == 13 || i == 18 || i == 23;
    if (dash ? value[i] != L'-' : !IsHex(value[i])) return false;
  }
  return true;
}

bool IsProfileKey(std::wstring_view value) {
  if (value.size() != 64) return false;
  for (const auto c : value) if (!IsHex(c)) return false;
  return true;
}

bool IsComponent(std::wstring_view name) {
  if (name.empty() || name.size() > 255 || name.back() == L'.' ||
      name.back() == L' ' || name.find_first_of(L"\\/:*?\"<>|") != name.npos) {
    return false;
  }
  for (const auto c : name) if (c < 32) return false;
  return true;
}

// Single component, rooted in an already-open directory. The final entry is
// opened without reparse processing and inspected through that same handle.
Handle OpenRelative(HANDLE parent, std::wstring_view name, ACCESS_MASK access,
                    ULONG share, ULONG disposition, bool directory,
                    PSECURITY_DESCRIPTOR descriptor, DWORD& error,
                    bool* created = nullptr) {
  if (!IsComponent(name)) {
    error = ERROR_INVALID_NAME;
    return Handle();
  }
  const auto bytes = static_cast<USHORT>(name.size() * sizeof(wchar_t));
  UNICODE_STRING path{bytes, bytes, const_cast<wchar_t*>(name.data())};
  OBJECT_ATTRIBUTES attributes;
  InitializeObjectAttributes(&attributes, &path, OBJ_CASE_INSENSITIVE,
                             parent, descriptor);
  IO_STATUS_BLOCK io{};
  HANDLE file = INVALID_HANDLE_VALUE;
  const NTSTATUS status = NtCreateFile(
      &file, access | SYNCHRONIZE, &attributes, &io, nullptr,
      FILE_ATTRIBUTE_NORMAL, share, disposition,
      FILE_OPEN_REPARSE_POINT | FILE_SYNCHRONOUS_IO_NONALERT |
          (directory ? FILE_DIRECTORY_FILE : FILE_NON_DIRECTORY_FILE),
      nullptr, 0);
  if (status < 0) {
    error = RtlNtStatusToDosError(status);
    return Handle();
  }
  Handle result(file);
  BY_HANDLE_FILE_INFORMATION info{};
  if (!GetFileInformationByHandle(file, &info)) {
    error = GetLastError();
    return Handle();
  }
  const DWORD flags = info.dwFileAttributes;
  if ((flags & FILE_ATTRIBUTE_REPARSE_POINT) ||
      ((flags & FILE_ATTRIBUTE_DIRECTORY) != 0) != directory ||
      GetFileType(file) != FILE_TYPE_DISK ||
      (!directory && descriptor && info.nNumberOfLinks != 1)) {
    error = ERROR_ACCESS_DENIED;
    return Handle();
  }
  if (created) *created = io.Information == FILE_CREATED;
  return result;
}

// Resolve from a fixed local drive. No UNC paths, ADS, or dot components.
// Keep ancestor handles open without FILE_SHARE_DELETE during the operation.
std::vector<Handle> OpenAncestors(std::wstring_view path, DWORD& error) {
  if (path.size() < 3 || path[1] != L':' || path[2] != L'\\' ||
      !((path[0] >= L'A' && path[0] <= L'Z') ||
        (path[0] >= L'a' && path[0] <= L'z'))) {
    error = ERROR_INVALID_NAME;
    return {};
  }
  const std::wstring drive(path.substr(0, 3));
  if (GetDriveTypeW(drive.c_str()) != DRIVE_FIXED) {
    error = ERROR_NOT_SUPPORTED;
    return {};
  }
  Handle root(CreateFileW(drive.c_str(), FILE_TRAVERSE | FILE_READ_ATTRIBUTES,
      FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING,
      FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, nullptr));
  BY_HANDLE_FILE_INFORMATION root_info{};
  // A DOS drive alias (SUBST) must not be accepted as an independent root.
  wchar_t target[8]{};
  if (!root.valid() || !GetFileInformationByHandle(root.get(), &root_info) ||
      (root_info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) ||
      GetFinalPathNameByHandleW(root.get(), target, ARRAYSIZE(target), 0) != 7 ||
      _wcsicmp(target, (L"\\\\?\\" + drive).c_str()) != 0) {
    error = ERROR_ACCESS_DENIED;
    return {};
  }
  std::vector<Handle> parents;
  parents.push_back(std::move(root));
  for (size_t start = 3; start < path.size();) {
    const size_t end = path.find(L'\\', start);
    auto child = OpenRelative(parents.back().get(), path.substr(start,
        end == path.npos ? path.size() - start : end - start),
        FILE_TRAVERSE | FILE_READ_ATTRIBUTES, FILE_SHARE_READ | FILE_SHARE_WRITE,
        FILE_OPEN, true, nullptr, error);
    if (!child.valid()) return {};
    parents.push_back(std::move(child));
    if (end == path.npos) break;
    start = end + 1;
  }
  return parents;
}

class PrivateAcl {
 public:
  bool Initialize() {
    HANDLE token = INVALID_HANDLE_VALUE;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return false;
    const Handle token_handle(token);
    DWORD size = 0;
    GetTokenInformation(token, TokenUser, nullptr, 0, &size);
    if (size == 0) return false;
    user_.resize(size);
    if (!GetTokenInformation(token, TokenUser, user_.data(), size, &size)) return false;
    LocalAllocation sid_text;
    if (!ConvertSidToStringSidW(sid(), reinterpret_cast<LPWSTR*>(&sid_text.value))) return false;
    const auto owner = static_cast<const wchar_t*>(sid_text.value);
    const std::wstring sddl = std::wstring(L"O:") + owner + L"D:P(A;;FA;;;" + owner + L")";
    return ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl.c_str(),
        SDDL_REVISION_1, &descriptor_.value, nullptr) != 0;
  }

  PSECURITY_DESCRIPTOR descriptor() const { return descriptor_.value; }

  DWORD Verify(HANDLE file) const {
    LocalAllocation security;
    PSID owner = nullptr;
    PACL dacl = nullptr;
    const DWORD result = GetSecurityInfo(file, SE_FILE_OBJECT,
          OWNER_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION,
          &owner, nullptr, &dacl, nullptr, &security.value);
    if (result != ERROR_SUCCESS) return result;
    if (!owner || !EqualSid(owner, sid())) return ERROR_INVALID_OWNER;
    if (!dacl || dacl->AceCount != 1) return ERROR_INVALID_ACL;
    SECURITY_DESCRIPTOR_CONTROL control = 0;
    DWORD revision = 0;
    void* raw = nullptr;
    if (!GetSecurityDescriptorControl(security.value, &control, &revision)) return GetLastError();
    if (!(control & SE_DACL_PROTECTED) || !GetAce(dacl, 0, &raw)) return ERROR_INVALID_SECURITY_DESCR;
    const auto* ace = static_cast<ACCESS_ALLOWED_ACE*>(raw);
    return ace->Header.AceType == ACCESS_ALLOWED_ACE_TYPE &&
        ace->Header.AceFlags == 0 && ace->Mask == FILE_ALL_ACCESS &&
        EqualSid(const_cast<DWORD*>(&ace->SidStart), sid()) ? ERROR_SUCCESS : ERROR_INVALID_ACL;
  }

 private:
  PSID sid() const { return reinterpret_cast<const TOKEN_USER*>(user_.data())->User.Sid; }
  std::vector<BYTE> user_;
  LocalAllocation descriptor_;
};

struct Store {
  PrivateAcl acl;
  std::vector<Handle> folders;
  size_t managed = 0;
  size_t stages = 0;
  size_t blobs = 0;
  std::unique_ptr<Handle> lock;
};

struct FileHandle {
  Handle file;
  Store* stage_owner;
};

Handle PrivateEntry(Store& store, HANDLE parent, std::wstring_view name,
                    ACCESS_MASK access, ULONG share, ULONG disposition,
                    bool directory, DWORD& error, bool* created = nullptr) {
  auto entry = OpenRelative(parent, name, access | READ_CONTROL, share,
                            disposition, directory, store.acl.descriptor(), error, created);
  if (entry.valid()) {
    error = store.acl.Verify(entry.get());
    if (error != ERROR_SUCCESS) return Handle();
  }
  return entry;
}

bool VerifyManifest(Store& store, HANDLE home, std::wstring_view profile,
                    std::wstring_view uuid, bool new_store, DWORD& error) {
  // The profile key and store UUID contain only ASCII after validation.
  const auto ascii = [](std::wstring_view value) {
    std::string result;
    for (const auto c : value) result.push_back(static_cast<char>(c));
    return result;
  };
  const std::string expected = "{\"format\":1,\"profile_key\":\"" +
      ascii(profile) + "\",\"store_uuid\":\"" + ascii(uuid) + "\"}\n";
  auto manifest = PrivateEntry(store, home, L"manifest.json", FILE_READ_DATA | FILE_READ_ATTRIBUTES,
      FILE_SHARE_READ, FILE_OPEN, false, error);
  const DWORD bytes = static_cast<DWORD>(expected.size());
  if (!manifest.valid()) {
    if (!new_store || error != ERROR_FILE_NOT_FOUND) return false;
    auto created = PrivateEntry(store, home, L"manifest.json", FILE_READ_ATTRIBUTES | FILE_WRITE_DATA,
        0, FILE_CREATE, false, error);
    if (!created.valid()) return false;
    DWORD written = 0;
    if (!WriteFile(created.get(), expected.data(), bytes, &written, nullptr) ||
        written != bytes || !FlushFileBuffers(created.get())) {
      error = ERROR_WRITE_FAULT;
      return false;
    }
    return true;
  }
  char actual[256]{};
  DWORD count = 0;
  if (!ReadFile(manifest.get(), actual, ARRAYSIZE(actual), &count, nullptr) ||
      count != bytes || std::string_view(actual, count) != expected) {
    error = ERROR_INVALID_DATA;
    return false;
  }
  return true;
}

const wchar_t* Extension(int type) {
  switch (type) {
    case 1: return L".pdf";
    case 2: return L".jpg";
    case 3: return L".png";
    default: return nullptr;
  }
}
}  // namespace

#define DOCUMENT_API extern "C" __declspec(dllexport)

DOCUMENT_API DWORD notaris_document_pick(wchar_t* path, DWORD capacity) {
  const HWND owner = GetForegroundWindow();
  DWORD owner_process = 0;
  GetWindowThreadProcessId(owner, &owner_process);
  if (!owner || owner_process != GetCurrentProcessId() || capacity == 0) {
    return ERROR_INVALID_WINDOW_HANDLE;
  }
  OPENFILENAMEW options{};
  options.lStructSize = sizeof(options);
  options.hwndOwner = owner;
  options.lpstrFilter = L"Dokumen (PDF, JPEG, PNG)\0*.pdf;*.jpg;*.jpeg;*.png\0";
  options.lpstrFile = path;
  options.nMaxFile = capacity;
  options.Flags = OFN_EXPLORER | OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST |
                  OFN_NOCHANGEDIR | OFN_NODEREFERENCELINKS;
  if (GetOpenFileNameW(&options)) return ERROR_SUCCESS;
  return CommDlgExtendedError();
}

DOCUMENT_API Store* notaris_store_open(const wchar_t* base, const wchar_t* profile,
                                     const wchar_t* uuid, DWORD* error) {
  *error = ERROR_SUCCESS;
  if (!IsProfileKey(profile) || !IsUuid(uuid)) {
    *error = ERROR_INVALID_NAME;
    return nullptr;
  }
  auto store = std::make_unique<Store>();
  store->folders = OpenAncestors(base, *error);
  if (store->folders.empty()) return nullptr;
  wchar_t filesystem[32]{};
  if (!GetVolumeInformationByHandleW(store->folders.back().get(), nullptr, 0,
      nullptr, nullptr, nullptr, filesystem, ARRAYSIZE(filesystem)) ||
      _wcsicmp(filesystem, L"NTFS") != 0 || !store->acl.Initialize()) {
    *error = ERROR_NOT_SUPPORTED;
    return nullptr;
  }
  const auto add_dir = [&](HANDLE parent, std::wstring_view name, bool* created = nullptr) {
    auto dir = PrivateEntry(*store, parent, name,
        FILE_TRAVERSE | FILE_READ_ATTRIBUTES | FILE_ADD_FILE | FILE_ADD_SUBDIRECTORY,
        FILE_SHARE_READ | FILE_SHARE_WRITE, FILE_OPEN_IF, true, *error, created);
    if (!dir.valid()) return false;
    store->folders.push_back(std::move(dir));
    return true;
  };
  if (!add_dir(store->folders.back().get(), L"transaction-documents")) return nullptr;
  store->managed = store->folders.size() - 1;
  if (!add_dir(store->folders.back().get(), profile)) return nullptr;
  const auto profile_dir = store->folders.back().get();
  auto lock = PrivateEntry(*store, profile_dir, std::wstring(uuid) + L".lock",
      FILE_READ_DATA | FILE_READ_ATTRIBUTES, 0, FILE_OPEN_IF, false, *error);
  if (!lock.valid()) return nullptr;
  store->lock = std::make_unique<Handle>(std::move(lock));
  bool new_store = false;
  if (!add_dir(profile_dir, uuid, &new_store)) return nullptr;
  const auto home = store->folders.back().get();
  if (!VerifyManifest(*store, home, profile, uuid, new_store, *error)) return nullptr;
  if (!add_dir(home, L"staging")) return nullptr;
  store->stages = store->folders.size() - 1;
  if (!add_dir(home, L"blobs")) return nullptr;
  store->blobs = store->folders.size() - 1;
  return store.release();
}

DOCUMENT_API void notaris_store_close(Store* store) { delete store; }

DOCUMENT_API FileHandle* notaris_store_source(Store* store, const wchar_t* source, DWORD* error) {
  const std::wstring_view path(source);
  const auto split = path.rfind(L'\\');
  if (split == path.npos || split < 2) { *error = ERROR_INVALID_NAME; return nullptr; }
  const auto parent = path.substr(0, split == 2 ? 3 : split);
  auto parents = OpenAncestors(parent, *error);
  if (parents.empty()) return nullptr;
  BY_HANDLE_FILE_INFORMATION managed{};
  if (!GetFileInformationByHandle(store->folders[store->managed].get(), &managed)) {
    *error = GetLastError();
    return nullptr;
  }
  for (const auto& directory : parents) {
    BY_HANDLE_FILE_INFORMATION candidate{};
    if (!GetFileInformationByHandle(directory.get(), &candidate)) {
      *error = GetLastError();
      return nullptr;
    }
    if (candidate.dwVolumeSerialNumber == managed.dwVolumeSerialNumber &&
        candidate.nFileIndexHigh == managed.nFileIndexHigh &&
        candidate.nFileIndexLow == managed.nFileIndexLow) {
      *error = ERROR_ACCESS_DENIED;
      return nullptr;
    }
  }
  auto file = OpenRelative(parents.back().get(), path.substr(split + 1),
      FILE_READ_DATA | FILE_READ_ATTRIBUTES, FILE_SHARE_READ, FILE_OPEN,
      false, nullptr, *error);
  if (!file.valid()) return nullptr;
  BY_HANDLE_FILE_INFORMATION info{};
  if (!GetFileInformationByHandle(file.get(), &info) || info.nNumberOfLinks != 1) {
    *error = ERROR_ACCESS_DENIED;
    return nullptr;
  }
  return new FileHandle{std::move(file), nullptr};
}

DOCUMENT_API FileHandle* notaris_store_stage(Store* store, const wchar_t* uuid,
                                            int create, DWORD* error) {
  if (!IsUuid(uuid)) { *error = ERROR_INVALID_NAME; return nullptr; }
  const auto name = std::wstring(uuid) + L".part";
  auto file = PrivateEntry(*store, store->folders[store->stages].get(), name,
      FILE_READ_DATA | FILE_READ_ATTRIBUTES | FILE_WRITE_DATA | DELETE,
      0, create ? FILE_CREATE : FILE_OPEN, false, *error);
  if (!file.valid()) return nullptr;
  return new FileHandle{std::move(file), store};
}

DOCUMENT_API FileHandle* notaris_store_blob(Store* store, const wchar_t* uuid,
                                           int type, DWORD* error) {
  const auto ext = Extension(type);
  if (!IsUuid(uuid) || !ext) { *error = ERROR_INVALID_NAME; return nullptr; }
  const auto name = std::wstring(uuid) + ext;
  auto file = PrivateEntry(*store, store->folders[store->blobs].get(), name,
      FILE_READ_DATA | FILE_READ_ATTRIBUTES, FILE_SHARE_READ, FILE_OPEN,
      false, *error);
  if (!file.valid()) return nullptr;
  return new FileHandle{std::move(file), nullptr};
}

DOCUMENT_API DWORD notaris_store_publish(FileHandle* handle, const wchar_t* uuid, int type) {
  const auto ext = Extension(type);
  if (!handle->stage_owner || !IsUuid(uuid) || !ext) return ERROR_INVALID_NAME;
  if (!FlushFileBuffers(handle->file.get())) return GetLastError();
  const auto name = std::wstring(uuid) + ext;
  // FileRenameInformation (10) with a relative name on the locked target
  // directory. The source handle stays open and ReplaceIfExists stays FALSE.
  struct RenameInfo {
    DWORD flags;
    HANDLE root;
    ULONG name_bytes;
    wchar_t name[41];  // UUID plus a four-character extension and terminator.
  } rename{};
  rename.root = handle->stage_owner->folders[handle->stage_owner->blobs].get();
  rename.name_bytes = static_cast<ULONG>(name.size() * sizeof(wchar_t));
  name.copy(rename.name, name.size());
  using SetInformation = NTSTATUS (NTAPI*)(HANDLE, PIO_STATUS_BLOCK, PVOID, ULONG, FILE_INFORMATION_CLASS);
  const auto set_info = reinterpret_cast<SetInformation>(
      GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "NtSetInformationFile"));
  if (!set_info) return ERROR_NOT_SUPPORTED;
  IO_STATUS_BLOCK io{};
  const NTSTATUS status = set_info(handle->file.get(), &io, &rename,
      sizeof(rename), static_cast<FILE_INFORMATION_CLASS>(10));
  if (status < 0) return RtlNtStatusToDosError(status);
  handle->stage_owner = nullptr;
  return ERROR_SUCCESS;
}

DOCUMENT_API DWORD notaris_store_rewind(FileHandle* handle) {
  LARGE_INTEGER zero{};
  return SetFilePointerEx(handle->file.get(), zero, nullptr, FILE_BEGIN)
      ? ERROR_SUCCESS : GetLastError();
}

DOCUMENT_API DWORD notaris_store_info(FileHandle* handle, LONGLONG* length, LONGLONG* modified) {
  BY_HANDLE_FILE_INFORMATION info{};
  if (!GetFileInformationByHandle(handle->file.get(), &info)) return GetLastError();
  *length = (static_cast<LONGLONG>(info.nFileSizeHigh) << 32) | info.nFileSizeLow;
  *modified = (static_cast<LONGLONG>(info.ftLastWriteTime.dwHighDateTime) << 32) |
      info.ftLastWriteTime.dwLowDateTime;
  return ERROR_SUCCESS;
}

DOCUMENT_API DWORD notaris_store_read(FileHandle* handle, BYTE* buffer, DWORD size, DWORD* count) {
  return ReadFile(handle->file.get(), buffer, size, count, nullptr)
      ? ERROR_SUCCESS : GetLastError();
}

DOCUMENT_API DWORD notaris_store_write(FileHandle* handle, const BYTE* buffer, DWORD size, DWORD* count) {
  if (!handle->stage_owner) return ERROR_ACCESS_DENIED;
  return WriteFile(handle->file.get(), buffer, size, count, nullptr)
      ? ERROR_SUCCESS : GetLastError();
}

DOCUMENT_API void notaris_store_file_close(FileHandle* handle) { delete handle; }
