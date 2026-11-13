#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <fcntl.h>
#include <io.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

namespace {
constexpr uint32_t kMaxBytes = 20 * 1024 * 1024;
constexpr int kMaxSide = 1536;
constexpr int kMaxPixels = 2 * 1024 * 1024;
constexpr uint32_t kInspect = UINT32_MAX;
constexpr size_t kWorkerMemory = 256 * 1024 * 1024;

// The parser runs in a one-process job. The Flutter caller also enforces a
// wall-clock deadline and caps the bytes it accepts from this process.
bool ConstrainProcess() {
  const HANDLE job = CreateJobObjectW(nullptr, nullptr);
  if (!job) return false;
  JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
  limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_PROCESS_MEMORY |
      JOB_OBJECT_LIMIT_PROCESS_TIME | JOB_OBJECT_LIMIT_ACTIVE_PROCESS;
  limits.BasicLimitInformation.ActiveProcessLimit = 1;
  limits.BasicLimitInformation.PerProcessUserTimeLimit.QuadPart = 5LL * 10000000;
  limits.ProcessMemoryLimit = kWorkerMemory;
  const bool applied = SetInformationJobObject(job, JobObjectExtendedLimitInformation,
      &limits, sizeof(limits)) && AssignProcessToJobObject(job, GetCurrentProcess());
  JOBOBJECT_EXTENDED_LIMIT_INFORMATION actual{};
  BOOL member = FALSE;
  const bool verified = applied && IsProcessInJob(GetCurrentProcess(), job, &member) && member &&
      QueryInformationJobObject(job, JobObjectExtendedLimitInformation, &actual,
                                sizeof(actual), nullptr) &&
      (actual.BasicLimitInformation.LimitFlags & limits.BasicLimitInformation.LimitFlags) ==
          limits.BasicLimitInformation.LimitFlags && actual.ProcessMemoryLimit == kWorkerMemory;
  CloseHandle(job);
  return verified;
}

template <typename Function>
Function Symbol(HMODULE module, const char* name) {
  const auto address = GetProcAddress(module, name);
  Function result = nullptr;
  static_assert(sizeof(address) == sizeof(result));
  std::memcpy(&result, &address, sizeof(result));
  return result;
}

struct Pdfium {
  using Doc = void*;
  using Page = void*;
  using Bitmap = void*;
  struct Size { float width, height; };

  HMODULE module;
  void (WINAPI* init)() = Symbol<decltype(init)>(module, "FPDF_InitLibrary");
  void (WINAPI* destroy)() = Symbol<decltype(destroy)>(module, "FPDF_DestroyLibrary");
  Doc (WINAPI* load)(const void*, size_t, const char*) = Symbol<decltype(load)>(module, "FPDF_LoadMemDocument64");
  void (WINAPI* close)(Doc) = Symbol<decltype(close)>(module, "FPDF_CloseDocument");
  int (WINAPI* count)(Doc) = Symbol<decltype(count)>(module, "FPDF_GetPageCount");
  int (WINAPI* security)(Doc) = Symbol<decltype(security)>(module, "FPDF_GetSecurityHandlerRevision");
  int (WINAPI* javascript)(Doc) = Symbol<decltype(javascript)>(module, "FPDFDoc_GetJavaScriptActionCount");
  int (WINAPI* attachments)(Doc) = Symbol<decltype(attachments)>(module, "FPDFDoc_GetAttachmentCount");
  int (WINAPI* size)(Doc, int, Size*) = Symbol<decltype(size)>(module, "FPDF_GetPageSizeByIndexF");
  Page (WINAPI* page)(Doc, int) = Symbol<decltype(page)>(module, "FPDF_LoadPage");
  void (WINAPI* close_page)(Page) = Symbol<decltype(close_page)>(module, "FPDF_ClosePage");
  Bitmap (WINAPI* bitmap)(int, int, int, void*, int) = Symbol<decltype(bitmap)>(module, "FPDFBitmap_CreateEx");
  void (WINAPI* close_bitmap)(Bitmap) = Symbol<decltype(close_bitmap)>(module, "FPDFBitmap_Destroy");
  void (WINAPI* render)(Bitmap, Page, int, int, int, int, int, int) = Symbol<decltype(render)>(module, "FPDF_RenderPageBitmap");

  bool Ready() const {
    return init && destroy && load && close && count && security && javascript &&
        attachments && size && page && close_page && bitmap && close_bitmap && render;
  }
};

struct PdfSession {
  explicit PdfSession(Pdfium api) : pdf(api) { pdf.init(); }
  ~PdfSession() {
    if (bitmap) pdf.close_bitmap(bitmap);
    if (page) pdf.close_page(page);
    if (document) pdf.close(document);
    pdf.destroy();
  }
  Pdfium pdf;
  Pdfium::Doc document = nullptr;
  Pdfium::Page page = nullptr;
  Pdfium::Bitmap bitmap = nullptr;
};

int Report(uint32_t status, uint32_t pages = 0, uint32_t width = 0,
           uint32_t height = 0, const std::vector<uint8_t>* bytes = nullptr) {
  const uint32_t header[] = {status, pages, width, height};
  if (std::fwrite(header, sizeof(uint32_t), 4, stdout) != 4) return 1;
  if (bytes && std::fwrite(bytes->data(), 1, bytes->size(), stdout) != bytes->size()) return 1;
  return std::fflush(stdout) == 0 ? 0 : 1;
}

bool HasPdfEnvelope(const std::vector<uint8_t>& data) {
  if (data.size() < 12 || std::memcmp(data.data(), "%PDF-", 5) != 0) return false;
  auto end = data.size();
  while (end > 0 && (data[end - 1] == '\r' || data[end - 1] == '\n' ||
                     data[end - 1] == ' ' || data[end - 1] == '\t')) --end;
  return end >= 5 && std::memcmp(data.data() + end - 5, "%%EOF", 5) == 0;
}

int Preview(const Pdfium& api, const std::vector<uint8_t>& data, uint32_t index) {
  // Declared before the session so the external pixel buffer outlives bitmap.
  std::vector<uint8_t> pixels;
  PdfSession session(api);
  session.document = api.load(data.data(), data.size(), nullptr);
  if (!session.document || api.security(session.document) != -1 ||
      api.javascript(session.document) != 0 || api.attachments(session.document) != 0) {
    return Report(1);
  }
  const int pages = api.count(session.document);
  if (pages < 1) return Report(1);
  if (index == kInspect) return Report(0, static_cast<uint32_t>(pages));
  if (index >= static_cast<uint32_t>(pages)) return Report(2);
  const int page_index = static_cast<int>(index);
  Pdfium::Size size{};
  if (!api.size(session.document, page_index, &size) ||
      !std::isfinite(size.width) || !std::isfinite(size.height) ||
      size.width <= 0 || size.height <= 0) return Report(2);

  const double width = size.width, height = size.height;
  const double scale = std::min({1.5, kMaxSide / width, kMaxSide / height,
                                 std::sqrt(kMaxPixels / (width * height))});
  if (!std::isfinite(scale) || scale <= 0 || width * scale < 1 || height * scale < 1) return Report(2);
  const auto w = static_cast<int>(std::floor(width * scale));
  const auto h = static_cast<int>(std::floor(height * scale));
  if (w < 1 || h < 1 || w > kMaxSide || h > kMaxSide || w > kMaxPixels / h) return Report(2);
  session.page = api.page(session.document, page_index);
  if (!session.page) return Report(2);
  pixels.resize(static_cast<size_t>(w) * h * 4, 0xff);
  session.bitmap = api.bitmap(w, h, 4 /* BGRA */, pixels.data(), w * 4);
  if (!session.bitmap) return Report(2);
  // No form-fill environment, JavaScript, link navigation, or annotations.
  api.render(session.bitmap, session.page, 0, 0, w, h, 0, 0);
  return Report(0, static_cast<uint32_t>(pages), static_cast<uint32_t>(w), static_cast<uint32_t>(h), &pixels);
}
}  // namespace

int wmain(int argc, wchar_t** argv) {
  if (!ConstrainProcess()) return 11;
  if (argc == 2 && std::wstring(argv[1]) == L"--verify-memory-limit") {
    // Commit without touching pages. The OS must reject a request over quota.
    void* control = VirtualAlloc(nullptr, 65536, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);
    if (!control) return 15;
    VirtualFree(control, 0, MEM_RELEASE);
    void* allocation = VirtualAlloc(nullptr, kWorkerMemory + 65536,
                                    MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);
    if (allocation) {
      VirtualFree(allocation, 0, MEM_RELEASE);
      return 14;
    }
    return 0;
  }
  if (argc != 1) return 16;
  if (_setmode(_fileno(stdin), _O_BINARY) == -1 ||
      _setmode(_fileno(stdout), _O_BINARY) == -1) return 10;
  uint32_t header[2]{};
  if (std::fread(header, sizeof(uint32_t), 2, stdin) != 2 ||
      header[0] == 0 || header[0] > kMaxBytes) return Report(1);
  std::vector<uint8_t> input(header[0]);
  if (std::fread(input.data(), 1, input.size(), stdin) != input.size() ||
      std::fgetc(stdin) != EOF || !HasPdfEnvelope(input)) return Report(1);

  wchar_t executable[32768]{};
  const DWORD size = GetModuleFileNameW(nullptr, executable, ARRAYSIZE(executable));
  if (size == 0 || size >= ARRAYSIZE(executable)) return 1;
  std::wstring path(executable, size);
  const auto separator = path.rfind(L'\\');
  if (separator == path.npos) return 1;
  path.resize(separator + 1);
  path += L"pdfium.dll";
  const HMODULE module = LoadLibraryExW(path.c_str(), nullptr,
      LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
  if (!module) return 12;
  const Pdfium pdf{module};
  const int result = pdf.Ready() ? Preview(pdf, input, header[1]) : 13;
  FreeLibrary(module);
  return result;
}
