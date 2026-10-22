#pragma once

class QWindow;

namespace winshell::platform
{

/// Windows 11 的系统 backdrop 类型。Mica 是桌面壁纸的模糊采样，最贴合文件管理器；
/// MicaAlt 是 Tabbed 变体，对比度更高；Acrylic 是磨砂半透明，视觉上最"重"。
enum class Backdrop
{
    Mica,
    MicaAlt,
    Acrylic
};

/// 给窗口套上 DWM 绘制的系统 backdrop（不是 QML 自绘的假毛玻璃）。
///
/// 为什么需要它：Win11 22621+ 的 DWMWA_SYSTEMBACKDROP_TYPE 是唯一能拿到"系统原生 Mica"
/// 的接口，自绘方案既跟不准壁纸，也不会随系统主题/强调色变化。Win10 及更早系统没有这个
/// 属性，此时返回 false，调用方继续用普通窗口，不做任何破坏性改动。
///
/// 不满足前置条件时只是"看不到 Mica"，不会崩溃、不会弹窗：
///  - 必须在窗口所属的 GUI 线程调用；DWM 属性绑定在 HWND 上，跨线程调用没有意义。
///  - 窗口背景必须透明：QML 根节点画不透明底色会把它整个盖住，调用方需要
///    QQuickWindow::setDefaultAlphaBuffer(true) + setColor(Qt::transparent)，并留出
///    半透明的面板底色，否则 Mica 只会在标题栏区域可见。
///  - 函数会通过 winId() 确保原生窗口已创建；窗口被重建（换 flag、换父窗口）后属性丢失，
///    需要重新调用。
///  - darkMode 只影响系统绘制的标题栏/边框；QML 内容的深浅由应用自己负责。
///
/// 返回 true 表示 backdrop 属性已成功下发；系统不支持、窗口不可用或 DWM 拒绝时返回 false。
bool applySystemBackdrop(QWindow *window, Backdrop kind = Backdrop::Mica, bool darkMode = true);

/// 当前系统是否支持系统 backdrop（Win11 22621+ 且能解析到 dwmapi 接口）。
/// 调用方可以先用它决定是否要为了 backdrop 打开窗口透明，避免在 Win10 上白折腾。
bool isBackdropSupported();

/// 系统圆角开关（DWMWA_WINDOW_CORNER_PREFERENCE）。
/// rounded=true 用 DWMWCP_ROUND，false 用 DWMWCP_DONOTROUND（最大化时用，避免屏幕边缘出现圆角）。
/// 只对普通（有边框）窗口有意义：WS_POPUP 的 frameless 窗口 DWM 根本不给圆角，
/// 所以调用方必须先补窗口样式（见 winshell::platform::enableSystemDecorations）。
/// Win11 22000+ 之外返回 false，窗口保持现状。
bool setRoundedCorners(QWindow *window, bool rounded);

/// 窗口边框颜色档位。最大化时用 None：窗口贴住屏幕边缘，留 1 px 边框会变成"亮边"。
enum class WindowBorder
{
    None,
    /// 失活态的显式深色。不能用系统默认（DWMWA_COLOR_DEFAULT）：窗口去掉 WS_CAPTION 后，
    /// 系统默认边框是浅色的，会在窗口四周留一圈白线。
    Dark,
    Accent
};

/// 设置窗口边框颜色：Accent 取系统强调色（HKCU\Software\Microsoft\Windows\DWM\AccentColor，
/// ABGR），Dark 用固定深色（#1B1B1B，与面板底色一致），None 去掉边框（DWMWA_COLOR_NONE）。
/// 切换窗口激活状态、最大化状态或系统强调色变化时由调用方重新调用。
/// Win11 之外属性不被支持，返回 false。
bool setWindowBorder(QWindow *window, WindowBorder border);

} // namespace winshell::platform
