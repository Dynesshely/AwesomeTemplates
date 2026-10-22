#include "platform/mica_effect.h"

#include <QtGlobal>

#ifdef Q_OS_WIN

#include <QDebug>
#include <QThread>
#include <QWindow>

#include <cstring>

#ifndef WIN32_LEAN_AND_MEAN
#    define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#    define NOMINMAX
#endif
#include <windows.h>

#include <winternl.h>

namespace
{

/// DWM 属性号与取值是稳定 ABI，但老 SDK 头文件里没有声明，所以本地写死常量，
/// 不依赖 windows.h 的版本（MinGW 13.1 的 SDK 里就没有 DWMWA_SYSTEMBACKDROP_TYPE）。
constexpr DWORD kDwmwaUseImmersiveDarkMode = 20;
constexpr DWORD kDwmwaUseImmersiveDarkModePre20H1 = 19;
constexpr DWORD kDwmwaSystemBackdropType = 38;
constexpr DWORD kDwmwaWindowCornerPreference = 33;
constexpr DWORD kDwmwaBorderColor = 34;

constexpr int kDwmWcpDoNotRound = 1;
constexpr int kDwmWcpRound = 2;
constexpr DWORD kDwmColorNone = 0xFFFFFFFE;
/// 失活态边框色：COLORREF 0x00BBGGRR，#1B1B1B（与面板底色一致）。
constexpr DWORD kDwmBorderDark = 0x001B1B1B;

constexpr int kDwmsbtMainWindow = 2;      // Mica
constexpr int kDwmsbtTransientWindow = 3; // Acrylic
constexpr int kDwmsbtTabbedWindow = 4;    // MicaAlt

/// DWMWA_SYSTEMBACKDROP_TYPE 从 Win11 22621（22H2）开始生效；22000 上设了也不画。
constexpr DWORD kFirstBuildWithSystemBackdrop = 22621;

/// 圆角与边框色属性从 Win11 22000（21H2）开始支持。
constexpr DWORD kFirstBuildWithWindowFrameAttributes = 22000;

/// 与 dwmapi.h 的 MARGINS 二进制布局一致；不直接 include 该头文件，是为了让"动态加载"
/// 这个决定在源码里保持完整——头文件只提供类型，链接时仍然不依赖 dwmapi.lib。
struct DwmMargins
{
    int left;
    int top;
    int right;
    int bottom;
};

/// 不链接 dwmapi：CMakeLists 不归本模块维护，而且动态解析让缺失该 DLL 的环境
/// （理论上只可能是被裁剪过的系统）也能干净地返回 false 而不是加载失败。
struct DwmApi
{
    using SetWindowAttributeFn = HRESULT(WINAPI *)(HWND, DWORD, LPCVOID, DWORD);
    using ExtendFrameIntoClientAreaFn = HRESULT(WINAPI *)(HWND, const DwmMargins *);
    using GetColorizationColorFn = HRESULT(WINAPI *)(DWORD *, BOOL *);

    HMODULE library = nullptr;
    SetWindowAttributeFn setWindowAttribute = nullptr;
    ExtendFrameIntoClientAreaFn extendFrameIntoClientArea = nullptr;
    GetColorizationColorFn getColorizationColor = nullptr;
};

/// GetProcAddress 返回 FARPROC，直接 reinterpret_cast 到具体签名会被 -Wcast-function-type
/// 判为"不兼容函数类型转换"；FARPROC 与函数指针同宽，按位拷贝即可，且不会触发该告警。
template <typename Function>
Function resolveFunction(HMODULE module, const char *name)
{
    const FARPROC address = GetProcAddress(module, name);
    Function function = nullptr;
    static_assert(sizeof(function) == sizeof(address), "FARPROC 必须与函数指针同宽");
    std::memcpy(&function, &address, sizeof(function));
    return function;
}

const DwmApi &dwmApi()
{
    // 进程内解析一次即可；故意不 FreeLibrary：模块句柄随进程结束回收，
    // 卸载反而会让已下发的函数指针悬空。
    static const DwmApi api = []() {
        DwmApi loaded;
        loaded.library = LoadLibraryW(L"dwmapi.dll");
        if (loaded.library == nullptr) {
            return loaded;
        }
        loaded.setWindowAttribute =
            resolveFunction<DwmApi::SetWindowAttributeFn>(loaded.library, "DwmSetWindowAttribute");
        loaded.extendFrameIntoClientArea =
            resolveFunction<DwmApi::ExtendFrameIntoClientAreaFn>(loaded.library,
                                                                 "DwmExtendFrameIntoClientArea");
        loaded.getColorizationColor = resolveFunction<DwmApi::GetColorizationColorFn>(
            loaded.library, "DwmGetColorizationColor");
        return loaded;
    }();
    return api;
}

/// GetVersionEx 在没声明 Windows 10/11 兼容性的清单里会谎报版本（Win11 报 6.2），
/// RtlGetVersion 返回内核真实版本号，不依赖应用清单。
DWORD windowsBuildNumber()
{
    static const DWORD build = []() -> DWORD {
        const HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
        if (ntdll == nullptr) {
            return 0;
        }
        using RtlGetVersionFn = LONG(WINAPI *)(PRTL_OSVERSIONINFOW);
        const auto rtlGetVersion = resolveFunction<RtlGetVersionFn>(ntdll, "RtlGetVersion");
        if (rtlGetVersion == nullptr) {
            return 0;
        }
        RTL_OSVERSIONINFOW info{};
        info.dwOSVersionInfoSize = sizeof(info);
        if (rtlGetVersion(&info) != 0) {
            return 0;
        }
        return static_cast<DWORD>(info.dwBuildNumber);
    }();
    return build;
}

QString hresultText(HRESULT result)
{
    return QStringLiteral("0x%1").arg(static_cast<quint32>(result), 8, 16, QLatin1Char('0'));
}

QString backdropName(winshell::platform::Backdrop kind)
{
    switch (kind) {
    case winshell::platform::Backdrop::Mica:
        return QStringLiteral("Mica");
    case winshell::platform::Backdrop::MicaAlt:
        return QStringLiteral("MicaAlt");
    case winshell::platform::Backdrop::Acrylic:
        return QStringLiteral("Acrylic");
    }
    return QStringLiteral("Unknown");
}

int backdropAttributeValue(winshell::platform::Backdrop kind)
{
    switch (kind) {
    case winshell::platform::Backdrop::Mica:
        return kDwmsbtMainWindow;
    case winshell::platform::Backdrop::MicaAlt:
        return kDwmsbtTabbedWindow;
    case winshell::platform::Backdrop::Acrylic:
        return kDwmsbtTransientWindow;
    }
    return kDwmsbtMainWindow;
}

/// 系统强调色，转成 DWM 边框属性要的 COLORREF（0x00BBGGRR）。
/// 注册表 AccentColor 是 ABGR（0xAABBGGRR）：Win11 改了强调色这里会立刻更新，
/// 比 DwmGetColorizationColor（会被"透明效果/着色"二次混合）更接近设置里的色板。
DWORD accentColorRef()
{
    DWORD abgr = 0;
    DWORD size = sizeof(abgr);
    HKEY key = nullptr;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, L"Software\\Microsoft\\Windows\\DWM", 0,
                      KEY_QUERY_VALUE, &key)
        == ERROR_SUCCESS) {
        if (RegQueryValueExW(key, L"AccentColor", nullptr, nullptr,
                             reinterpret_cast<LPBYTE>(&abgr), &size)
            != ERROR_SUCCESS) {
            abgr = 0;
        }
        RegCloseKey(key);
    }
    if (abgr != 0) {
        const DWORD red = abgr & 0xFF;
        const DWORD green = (abgr >> 8) & 0xFF;
        const DWORD blue = (abgr >> 16) & 0xFF;
        return red | (green << 8) | (blue << 16);
    }

    const DwmApi &api = dwmApi();
    if (api.getColorizationColor != nullptr) {
        DWORD argb = 0;
        BOOL opaque = FALSE;
        if (SUCCEEDED(api.getColorizationColor(&argb, &opaque))) {
            const DWORD red = (argb >> 16) & 0xFF;
            const DWORD green = (argb >> 8) & 0xFF;
            const DWORD blue = argb & 0xFF;
            return red | (green << 8) | (blue << 16);
        }
    }
    return 0;
}

/// 新属性共用同一套前置检查：窗口为空、跨线程、没有原生句柄都拒绝，返回 false 由调用方忽略。
bool resolveWindowHandle(QWindow *window, const char *what, HWND *hwnd)
{
    if (window == nullptr || hwnd == nullptr) {
        qWarning().noquote() << "[mica]" << what << "窗口为空";
        return false;
    }
    if (window->thread() != QThread::currentThread()) {
        qWarning().noquote() << "[mica]" << what << "必须在窗口所属线程调用";
        return false;
    }
    *hwnd = reinterpret_cast<HWND>(window->winId());
    return *hwnd != nullptr;
}

/// 暗色标题栏：Win10 1809 起就有（属性 20），更老的 1803 用 19。
/// 失败不算错——Win7/8 根本没有这个能力，返回 false 由调用方决定是否在意。
bool applyDarkMode(const DwmApi &api, HWND hwnd, bool darkMode)
{
    if (api.setWindowAttribute == nullptr) {
        return false;
    }
    const BOOL value = darkMode ? TRUE : FALSE;
    const HRESULT modern =
        api.setWindowAttribute(hwnd, kDwmwaUseImmersiveDarkMode, &value, sizeof(value));
    if (SUCCEEDED(modern)) {
        return true;
    }
    return SUCCEEDED(
        api.setWindowAttribute(hwnd, kDwmwaUseImmersiveDarkModePre20H1, &value, sizeof(value)));
}

} // namespace

namespace winshell::platform
{

bool isBackdropSupported()
{
    static const bool supported = []() {
        if (windowsBuildNumber() < kFirstBuildWithSystemBackdrop) {
            return false;
        }
        const DwmApi &api = dwmApi();
        return api.setWindowAttribute != nullptr;
    }();
    return supported;
}

bool applySystemBackdrop(QWindow *window, Backdrop kind, bool darkMode)
{
    if (window == nullptr) {
        qWarning().noquote() << "[mica] 窗口为空，跳过 backdrop";
        return false;
    }

    // DWM 属性落在 HWND 上，只能在创建它的 GUI 线程设置；跨线程调用没有意义。
    if (window->thread() != QThread::currentThread()) {
        qWarning().noquote() << "[mica] 必须在窗口所属线程调用 applySystemBackdrop";
        return false;
    }

    const DwmApi &api = dwmApi();
    if (api.setWindowAttribute == nullptr) {
        qWarning().noquote() << "[mica] 无法从 dwmapi.dll 解析 DwmSetWindowAttribute，降级为普通窗口";
        return false;
    }

    // 窗口尚未创建时 winId() 会触发原生窗口创建：属性必须落在真实 HWND 上。
    const HWND hwnd = reinterpret_cast<HWND>(window->winId());
    if (hwnd == nullptr) {
        qWarning().noquote() << "[mica] 窗口没有原生句柄，降级为普通窗口";
        return false;
    }

    if (!applyDarkMode(api, hwnd, darkMode)) {
        qWarning().noquote() << "[mica] 暗色标题栏属性设置失败（不影响 backdrop 尝试）";
    }

    // 系统背景画在窗口内容之下，只有客户区真正透明（逐像素 alpha）才看得见。
    // Qt 的 Windows QPA 只在 frameless 窗口上创建分层窗口（WS_EX_LAYERED）；带原生标题栏时
    // 客户区永远不透明，此时下发 backdrop 只会让调用方误以为 Mica 可见，所以直接拒绝。
    const auto exStyle = static_cast<DWORD>(GetWindowLongPtrW(hwnd, GWL_EXSTYLE));
    if ((exStyle & WS_EX_LAYERED) == 0) {
        qWarning().noquote()
            << "[mica] 窗口不是分层窗口，客户区无法透明（需要 frameless + 透明清屏色），跳过 backdrop";
        return false;
    }

    if (!isBackdropSupported()) {
        // Win10 只有暗色标题栏可用；返回 false 让调用方继续用普通窗口。
        qWarning().noquote() << "[mica] 系统不支持系统 backdrop（需要 Win11 22621+），使用暗色标题栏";
        return false;
    }

    // Mica 只透出"没有内容覆盖"的像素，DWM 需要把边框扩展到整个客户区，
    // 应用才能用透明背景把系统背景露出来。失败不致命：backdrop 仍会在标题栏生效。
    // 边距 -1 = 整个客户区都算系统框架区，这是 Mica 在客户区透出的前提（微软示例同款）。
    const DwmMargins margins{-1, -1, -1, -1};
    if (api.extendFrameIntoClientArea != nullptr) {
        const HRESULT frameResult = api.extendFrameIntoClientArea(hwnd, &margins);
        if (FAILED(frameResult)) {
            qWarning().noquote() << "[mica] DwmExtendFrameIntoClientArea 失败:"
                                 << hresultText(frameResult) << "（Mica 可能只出现在标题栏）";
        }
    }

    const int value = backdropAttributeValue(kind);
    const HRESULT result =
        api.setWindowAttribute(hwnd, kDwmwaSystemBackdropType, &value, sizeof(value));
    if (FAILED(result)) {
        qWarning().noquote() << "[mica] 设置" << backdropName(kind)
                             << "backdrop 失败:" << hresultText(result) << "，降级为普通窗口";
        return false;
    }
    return true;
}

bool setRoundedCorners(QWindow *window, bool rounded)
{
    if (windowsBuildNumber() < kFirstBuildWithWindowFrameAttributes) {
        return false;
    }
    const DwmApi &api = dwmApi();
    if (api.setWindowAttribute == nullptr) {
        return false;
    }
    HWND hwnd = nullptr;
    if (!resolveWindowHandle(window, "圆角", &hwnd)) {
        return false;
    }
    const int preference = rounded ? kDwmWcpRound : kDwmWcpDoNotRound;
    return SUCCEEDED(api.setWindowAttribute(hwnd, kDwmwaWindowCornerPreference, &preference,
                                            sizeof(preference)));
}

bool setWindowBorder(QWindow *window, WindowBorder border)
{
    if (windowsBuildNumber() < kFirstBuildWithWindowFrameAttributes) {
        return false;
    }
    const DwmApi &api = dwmApi();
    if (api.setWindowAttribute == nullptr) {
        return false;
    }
    HWND hwnd = nullptr;
    if (!resolveWindowHandle(window, "边框色", &hwnd)) {
        return false;
    }

    DWORD color = kDwmBorderDark;
    if (border == WindowBorder::None) {
        color = kDwmColorNone;
    } else if (border == WindowBorder::Accent) {
        const DWORD accent = accentColorRef();
        if (accent != 0) {
            color = accent;
        }
    }
    return SUCCEEDED(api.setWindowAttribute(hwnd, kDwmwaBorderColor, &color, sizeof(color)));
}

} // namespace winshell::platform

#else // Q_OS_WIN

namespace winshell::platform
{

bool isBackdropSupported()
{
    return false;
}

bool applySystemBackdrop(QWindow *, Backdrop, bool)
{
    // 非 Windows 平台没有系统 backdrop 的概念，QML 侧的半透明面板保持原样即可
    //（没有合成背景可透出时，半透明面板会叠在窗口底色上，仍然可读）。
    return false;
}

bool setRoundedCorners(QWindow *, bool)
{
    return false;
}

bool setWindowBorder(QWindow *, WindowBorder)
{
    return false;
}

} // namespace winshell::platform

#endif // Q_OS_WIN
