#include "platform/window_chrome.h"

#include "platform/mica_effect.h"

#include <QCoreApplication>
#include <QMetaObject>
#include <QQuickWindow>
#include <QThread>
#include <QtGlobal>

#ifdef Q_OS_WIN

#    include <QGuiApplication>
#    include <QHash>
#    include <QSet>

#    ifndef WIN32_LEAN_AND_MEAN
#        define WIN32_LEAN_AND_MEAN
#    endif
#    ifndef NOMINMAX
#        define NOMINMAX
#    endif
#    include <windows.h>
#    include <windowsx.h>

namespace
{

/// 窗口四边/四角缩放热区（DIP）。装饰之后客户区覆盖了整窗，系统默认的边框命中被
/// WM_NCCALCSIZE 抹掉了，只能自己回答；8 DIP 是 Windows 常见的缩放边宽度。
constexpr int kResizeBorderDip = 8;

/// caption 按钮的布局（DIP）：每个 46 宽、**高度等于整条顶栏**，右起依次关闭/最大化/最小化，
/// 贴住客户区右上角、无缝隙。QML 按同一份矩形自绘（captionButtonRect()），命中区也用它。
constexpr int kCaptionButtonWidthDip = 46;

/// Main.qml 标题栏右侧给原生按钮预留的宽度（3 × 46 + 余量）。
constexpr int kCaptionStripWidthDip = 150;
/// Main.qml 的 header 高度：caption 按钮与 HTCAPTION 预留条都用它。
constexpr int kTitleBarHeightDip = 48;

/// Main.qml 里 caption hover 高亮画在 header(ToolBar) 的 contentItem 内；Fluent 样式的 header
/// 内容区自带 8 DIP 内边距（ToolBar 的 leftPadding/topPadding = 8），所以 contentItem 里的 y=0
/// 对应窗口 y=8。captionButtonRect() 返回的是 contentItem 坐标，QML 直接摆放就能盖住 DWM 按钮。
constexpr int kHeaderContentInsetDip = 8;

QSet<quintptr> &decoratedHandles()
{
    static QSet<quintptr> handles;
    return handles;
}

/// 被替换掉的原窗口过程（Qt 的），所有不处理的消息都链式交回给它。
QHash<quintptr, WNDPROC> &originalProcedures()
{
    static QHash<quintptr, WNDPROC> procedures;
    return procedures;
}

QWindow *windowForHandle(quintptr handle)
{
    const auto windows = QGuiApplication::topLevelWindows();
    for (QWindow *window : windows) {
        if (window->winId() == reinterpret_cast<WId>(handle)) {
            return window;
        }
    }
    return nullptr;
}

/// QML 里的 WindowChrome 实例（Main.qml: WindowChrome { id: titleChrome }）。
/// 窗口过程用它把原生状态（激活、caption hover）同步给 QML。
WindowChrome *chromeForWindow(QWindow *window)
{
    return window != nullptr ? window->findChild<WindowChrome *>() : nullptr;
}

/// 上一次真正下发过的 DWM 边框状态。交互 resize 期间 WM_WINDOWPOSCHANGED 每帧都来，
/// 每帧都调 DwmSetWindowAttribute 会拖慢 DWM 合成，在分层窗口上表现为撕裂/条纹，
/// 所以只有状态真的变化时才下发。
struct FrameState
{
    bool valid = false;
    bool maximized = false;
    bool active = false;
};

QHash<quintptr, FrameState> &frameStates()
{
    static QHash<quintptr, FrameState> states;
    return states;
}

/// 正在被用户拖动缩放的窗口（WM_ENTERSIZEMOVE 到 WM_EXITSIZEMOVE 之间）。
/// 期间不主动投递重绘：Qt 自己的 resize 重绘足够，额外的 update/FRAMECHANGED 会和
/// DWM 的合成抢帧，出现条纹。
QSet<quintptr> &interactiveResizes()
{
    static QSet<quintptr> handles;
    return handles;
}

/// 最大化/还原与激活状态变化时刷新 DWM 边框属性。
/// 最大化的窗口贴着屏幕边缘：必须去掉边框、切成直角，否则边缘会露出 1~2 px 亮线。
/// active 用我们跟踪的原生状态，不用 QWindow::isActive()（子类化窗口上它会滞后）。
void updateFrameState(QWindow *window, bool active)
{
    if (window == nullptr) {
        return;
    }
    const quintptr handle = reinterpret_cast<quintptr>(window->winId());
    const bool maximized = window->visibility() == QWindow::Maximized;
    FrameState &state = frameStates()[handle];
    if (state.valid && state.maximized == maximized && state.active == active) {
        return;
    }
    state.valid = true;
    state.maximized = maximized;
    state.active = active;

    winshell::platform::setRoundedCorners(window, !maximized);
    if (maximized) {
        winshell::platform::setWindowBorder(window, winshell::platform::WindowBorder::None);
    } else {
        winshell::platform::setWindowBorder(window,
                                         active ? winshell::platform::WindowBorder::Accent
                                                : winshell::platform::WindowBorder::Dark);
    }
}

/// caption 按钮的位置。按钮由 QML 自绘（DWM 的 caption 已用去掉 WS_SYSMENU 的方式停画），
/// 所以几何完全由这里定义，QML 和命中测试共用同一份：右起三个 46×48 DIP 的矩形
/// （宽度固定、高度等于整条顶栏），**贴住客户区右上角、无缝隙、无额外边距**
/// （客户区覆盖整窗，见 WM_NCCALCSIZE）。
struct CaptionMetrics
{
    int closeRight = 0;
    int stripLeft = 0;
    int stripRight = 0;
    int buttonWidth = 0;
    int buttonHeight = 0;
};

bool captionMetrics(QWindow *window, HWND hwnd, CaptionMetrics *metrics)
{
    if (window == nullptr || metrics == nullptr) {
        return false;
    }
    RECT client{};
    if (!GetClientRect(hwnd, &client)) {
        return false;
    }

    const qreal dpr = window->devicePixelRatio();
    metrics->buttonWidth = qRound(kCaptionButtonWidthDip * dpr);
    // 高度 = 整条顶栏：QML 把三个按钮从顶栏顶边画到底边，命中区必须一样高，
    // 否则按钮下半截点不到。
    metrics->buttonHeight = qRound(kTitleBarHeightDip * dpr);
    metrics->stripRight = client.right;
    metrics->stripLeft = metrics->stripRight - qRound(kCaptionStripWidthDip * dpr);
    metrics->closeRight = metrics->stripRight;
    return true;
}

enum class CaptionButton
{
    None,
    Minimize,
    Maximize,
    Close
};

/// point 是客户区坐标（物理像素）。三键紧邻、右起关闭/最大化/最小化。
CaptionButton captionButtonAt(const CaptionMetrics &metrics, const POINT &point)
{
    if (point.y < 0 || point.y >= metrics.buttonHeight) {
        return CaptionButton::None;
    }
    const int closeLeft = metrics.closeRight - metrics.buttonWidth;
    const int maximizeLeft = closeLeft - metrics.buttonWidth;
    const int minimizeLeft = maximizeLeft - metrics.buttonWidth;
    if (point.x >= closeLeft && point.x < metrics.closeRight) {
        return CaptionButton::Close;
    }
    if (point.x >= maximizeLeft && point.x < closeLeft) {
        return CaptionButton::Maximize;
    }
    if (point.x >= minimizeLeft && point.x < maximizeLeft) {
        return CaptionButton::Minimize;
    }
    return CaptionButton::None;
}

/// 把"鼠标在哪个 caption 按钮上"算出来并同步给 QML（高亮由 QML 画）。
/// DWM 在客户区覆盖整窗的窗口上不画 caption hover，所以这部分只能自己算。
void updateCaptionHover(HWND hwnd, QWindow *window, const POINT &clientPoint)
{
    WindowChrome *chrome = chromeForWindow(window);
    if (chrome == nullptr) {
        return;
    }
    QString name = QStringLiteral("none");
    CaptionMetrics metrics;
    if (window != nullptr && captionMetrics(window, hwnd, &metrics)) {
        switch (captionButtonAt(metrics, clientPoint)) {
        case CaptionButton::Minimize:
            name = QStringLiteral("minimize");
            break;
        case CaptionButton::Maximize:
            name = QStringLiteral("maximize");
            break;
        case CaptionButton::Close:
            name = QStringLiteral("close");
            break;
        case CaptionButton::None:
            break;
        }
    }
    chrome->setHoveredCaptionButton(name);
}

/// 让系统在鼠标离开客户区/非客户区时发 WM_*MOUSELEAVE，用来清空 hover 状态。
void armMouseLeave(HWND hwnd, bool nonClient)
{
    TRACKMOUSEEVENT track{};
    track.cbSize = sizeof(track);
    track.dwFlags = TME_LEAVE;
    if (nonClient) {
        track.dwFlags |= TME_NONCLIENT;
    }
    track.hwndTrack = hwnd;
    TrackMouseEvent(&track);
}

/// 四边/四角缩放（只在非最大化/全屏时生效）。point 是客户区坐标（物理像素），
/// 热区限定在最外 8 DIP，避免吞掉 caption 按钮和标题栏的点击。
bool resizeBorderHit(QWindow *window, const RECT &client, const POINT &point, qintptr *result)
{
    if ((window->flags() & Qt::FramelessWindowHint) == 0
        || window->visibility() == QWindow::Maximized
        || window->visibility() == QWindow::FullScreen) {
        return false;
    }

    const int border = qRound(kResizeBorderDip * window->devicePixelRatio());
    const bool onLeft = point.x >= client.left && point.x < client.left + border;
    const bool onRight = point.x < client.right && point.x >= client.right - border;
    const bool onTop = point.y >= client.top && point.y < client.top + border;
    const bool onBottom = point.y < client.bottom && point.y >= client.bottom - border;

    if (!onLeft && !onRight && !onTop && !onBottom) {
        return false;
    }

    if (onTop && onLeft) {
        *result = HTTOPLEFT;
    } else if (onTop && onRight) {
        *result = HTTOPRIGHT;
    } else if (onBottom && onLeft) {
        *result = HTBOTTOMLEFT;
    } else if (onBottom && onRight) {
        *result = HTBOTTOMRIGHT;
    } else if (onLeft) {
        *result = HTLEFT;
    } else if (onRight) {
        *result = HTRIGHT;
    } else if (onTop) {
        *result = HTTOP;
    } else {
        *result = HTBOTTOM;
    }
    return true;
}

/// 自定义窗口过程：用子类化（而不是 QAbstractNativeEventFilter）接管 NC 计算。
/// 过滤器会在 Qt 处理窗口消息之前截走 WM_NCCALCSIZE，实测会让 Qt 错过那次尺寸变化
/// （最大化后 QWindow 停在旧尺寸、QML 不重排）；子类化只改客户区，其余消息原样交回 Qt。
LRESULT CALLBACK chromeWindowProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
{
    const quintptr handle = reinterpret_cast<quintptr>(hwnd);
    const auto previous = originalProcedures().value(handle, nullptr);
    QWindow *window = windowForHandle(handle);

    switch (message) {
    case WM_NCCALCSIZE:
        if (wParam == TRUE) {
            auto *params = reinterpret_cast<NCCALCSIZE_PARAMS *>(lParam);
            if (params == nullptr) {
                break;
            }
            // 客户区 = 整窗：rgrc[0] 里已经是系统提出的**新**窗口矩形，直接保留即可
            // （典型无边框窗口做法：不改它，相当于客户区覆盖整窗）。
            // 这里**不要**用 GetWindowRect() 再覆盖：交互 resize 时它还是旧尺寸，
            // 会让 Qt 按旧尺寸渲染、DWM 按新尺寸合成，出现整片竖条纹。
            if (IsZoomed(hwnd)) {
                MONITORINFO monitor{};
                monitor.cbSize = sizeof(monitor);
                if (GetMonitorInfoW(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST), &monitor)) {
                    params->rgrc[0] = monitor.rcWork;
                }
            }
            return 0;
        }
        break;
    case WM_NCHITTEST: {
        if (window == nullptr || (window->flags() & Qt::FramelessWindowHint) == 0) {
            break;
        }
        POINT point{GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam)};
        if (!ScreenToClient(hwnd, &point)) {
            break;
        }
        RECT client{};
        if (!GetClientRect(hwnd, &client)) {
            break;
        }

        // 1) caption 按钮优先：自绘按钮贴住客户区右上角，不能被顶部/右侧的缩放热区吞掉
        //    （Windows 原生窗口也是按钮盖住边框角）。
        CaptionMetrics metrics;
        if (!captionMetrics(window, hwnd, &metrics)) {
            break;
        }
        switch (captionButtonAt(metrics, point)) {
        case CaptionButton::Close:
            return HTCLOSE;
        case CaptionButton::Maximize:
            return HTMAXBUTTON;
        case CaptionButton::Minimize:
            return HTMINBUTTON;
        case CaptionButton::None:
            break;
        }

        // 2) 边框缩放（最外 8 DIP）；最大化/全屏时自动跳过。
        qintptr hit = HTCLIENT;
        if (resizeBorderHit(window, client, point, &hit)) {
            return hit;
        }

        // 3) 按钮左侧的预留条剩余部分交给系统当标题栏（拖动/双击最大化）；
        //    其余标题栏保持 HTCLIENT，避免吞掉搜索框与品牌按钮的点击。
        if (point.y >= 0 && point.y < qRound(kTitleBarHeightDip * window->devicePixelRatio())
            && point.x >= metrics.stripLeft && point.x < metrics.stripRight) {
            return HTCAPTION;
        }
        break;
    }
    case WM_NCLBUTTONDOWN: {
        // DWM 的 caption 已停画（去掉 WS_SYSMENU），按钮是 QML 自绘的；没有 WS_SYSMENU 时
        // DefWindowProc 不会替我们执行这些动作，所以这里直接做。Snap Layouts 的悬停面板是
        // 系统按 WM_NCHITTEST=HTMAXBUTTON 自己弹的，与这里的点击处理无关。
        switch (wParam) {
        case HTCLOSE:
            // 和 min/max 一样走系统命令：SC_CLOSE 由 DefWindowProc 派发 WM_CLOSE，
            // Qt 照常收到 closeEvent（会话保存不受影响），DWM 也能播关闭过渡。
            SendMessageW(hwnd, WM_SYSCOMMAND, SC_CLOSE, 0);
            return 0;
        case HTMINBUTTON:
            // 用系统命令而不是直接 ShowWindow：SC_* 由 DefWindowProc 处理，走完整的窗口状态
            // 切换流程，DWM 的 minimize/maximize 过渡才不会在这一步被跳过。
            SendMessageW(hwnd, WM_SYSCOMMAND, SC_MINIMIZE, 0);
            return 0;
        case HTMAXBUTTON:
            SendMessageW(hwnd, WM_SYSCOMMAND, IsZoomed(hwnd) ? SC_RESTORE : SC_MAXIMIZE, 0);
            return 0;
        default:
            break;
        }
        break;
    }
    case WM_WINDOWPOSCHANGED: {
        // 先让 Qt 处理几何，再按最新状态刷新 DWM 边框属性。
        const LRESULT result = previous != nullptr
                                   ? CallWindowProcW(previous, hwnd, message, wParam, lParam)
                                   : DefWindowProcW(hwnd, message, wParam, lParam);
        WindowChrome *chrome = chromeForWindow(window);
        updateFrameState(window, chrome != nullptr ? chrome->windowActive()
                                                   : (window != nullptr && window->isActive()));
        return result;
    }
    case WM_ACTIVATE: {
        // 激活状态以原生 WM_ACTIVATE 为准：同步给 QML（windowActive），刷新强调色边框。
        const LRESULT result = previous != nullptr
                                   ? CallWindowProcW(previous, hwnd, message, wParam, lParam)
                                   : DefWindowProcW(hwnd, message, wParam, lParam);
        const bool active = LOWORD(wParam) != WA_INACTIVE;
        WindowChrome *chrome = chromeForWindow(window);
        if (chrome != nullptr) {
            chrome->setWindowActive(active);
            if (active) {
                // 从最小化/后台恢复时补一次重绘，避免分层窗口停在旧帧。
                chrome->scheduleRepaint(true);
            }
        }
        updateFrameState(window, active);
        return result;
    }
    case WM_SHOWWINDOW: {
        const LRESULT result = previous != nullptr
                                   ? CallWindowProcW(previous, hwnd, message, wParam, lParam)
                                   : DefWindowProcW(hwnd, message, wParam, lParam);
        WindowChrome *chrome = chromeForWindow(window);
        if (chrome != nullptr) {
            if (wParam != FALSE) {
                // 最小化还原后画面空白：强制 DWM 重取一帧并让 Qt 重新上屏。
                chrome->scheduleRepaint(true);
            } else {
                chrome->setHoveredCaptionButton(QStringLiteral("none"));
            }
        }
        return result;
    }
    case WM_ENTERSIZEMOVE: {
        // 用户开始拖拽缩放：期间禁止我们自己投递重绘，否则会和 DWM 合成抢帧，
        // 在分层窗口上表现为整片竖条纹。Qt 自己的 resize 重绘继续走。
        interactiveResizes().insert(reinterpret_cast<quintptr>(hwnd));
        break;
    }
    case WM_EXITSIZEMOVE: {
        const LRESULT result = previous != nullptr
                                   ? CallWindowProcW(previous, hwnd, message, wParam, lParam)
                                   : DefWindowProcW(hwnd, message, wParam, lParam);
        interactiveResizes().remove(reinterpret_cast<quintptr>(hwnd));
        // 缩放结束后补一帧并强制 DWM 重取，回收 resize 期间可能残留的旧帧。
        WindowChrome *chrome = chromeForWindow(window);
        if (chrome != nullptr) {
            chrome->scheduleRepaint(true);
        }
        return result;
    }
    case WM_SIZE: {
        const LRESULT result = previous != nullptr
                                   ? CallWindowProcW(previous, hwnd, message, wParam, lParam)
                                   : DefWindowProcW(hwnd, message, wParam, lParam);
        // 尺寸变化（还原/最大化/拖拽）之后让 Qt 补一帧；只投递 update，不再触发 FRAMECHANGED。
        // 交互 resize 期间完全不投递（见 WM_ENTERSIZEMOVE）。
        if (!interactiveResizes().contains(reinterpret_cast<quintptr>(hwnd))) {
            if (WindowChrome *chrome = chromeForWindow(window)) {
                chrome->scheduleRepaint(false);
            }
        }
        return result;
    }
    case WM_DWMCOLORIZATIONCOLORCHANGED: {
        const LRESULT result = previous != nullptr
                                   ? CallWindowProcW(previous, hwnd, message, wParam, lParam)
                                   : DefWindowProcW(hwnd, message, wParam, lParam);
        WindowChrome *chrome = chromeForWindow(window);
        updateFrameState(window, chrome != nullptr ? chrome->windowActive()
                                                   : (window != nullptr && window->isActive()));
        return result;
    }
    case WM_MOUSEMOVE: {
        // 客户区内的移动：清掉 caption hover（按钮本身走 WM_NCMOUSEMOVE）。
        POINT point{GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam)};
        updateCaptionHover(hwnd, window, point);
        armMouseLeave(hwnd, false);
        break;
    }
    case WM_NCMOUSEMOVE: {
        POINT point{GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam)};
        if (!ScreenToClient(hwnd, &point)) {
            break;
        }
        updateCaptionHover(hwnd, window, point);
        armMouseLeave(hwnd, true);
        break;
    }
    case WM_NCACTIVATE: {
        // DWM 在激活状态变化时也会发 WM_NCACTIVATE（最小化还原、任务栏点击都会走到），
        // 用它兜底一次激活状态，避免只依赖 WM_ACTIVATE 的到达时机。
        const LRESULT result = previous != nullptr
                                   ? CallWindowProcW(previous, hwnd, message, wParam, lParam)
                                   : DefWindowProcW(hwnd, message, wParam, lParam);
        const bool active = wParam != FALSE;
        WindowChrome *chrome = chromeForWindow(window);
        if (chrome != nullptr) {
            chrome->setWindowActive(active);
        }
        updateFrameState(window, active);
        return result;
    }
    case WM_MOUSELEAVE:
    case WM_NCMOUSELEAVE: {
        WindowChrome *chrome = chromeForWindow(window);
        if (chrome != nullptr) {
            chrome->setHoveredCaptionButton(QStringLiteral("none"));
        }
        break;
    }
    default:
        break;
    }

    if (previous != nullptr) {
        return CallWindowProcW(previous, hwnd, message, wParam, lParam);
    }
    return DefWindowProcW(hwnd, message, wParam, lParam);
}

} // namespace

namespace winshell::platform
{

bool enableSystemDecorations(QQuickWindow *window)
{
    if (window == nullptr) {
        return false;
    }
    if (window->thread() != QThread::currentThread()) {
        qWarning().noquote() << "[chrome] enableSystemDecorations 必须在窗口所属线程调用";
        return false;
    }

    // 先把窗口挂到 QML 的 WindowChrome 上：即使 --native-frame 不做装饰，
    // QML 也需要 windowActive 这个可靠来源。
    const bool frameless = (window->flags() & Qt::FramelessWindowHint) != 0;
    if (WindowChrome *chrome = chromeForWindow(window)) {
        chrome->attachWindow(window, frameless);
    }
    if (!frameless) {
        // 原生标题栏已经有系统装饰，重复补样式只会打架。
        return false;
    }

    const HWND hwnd = reinterpret_cast<HWND>(window->winId());
    if (hwnd == nullptr) {
        qWarning().noquote() << "[chrome] 窗口没有原生句柄，跳过系统装饰";
        return false;
    }

    const quintptr handle = reinterpret_cast<quintptr>(hwnd);
    decoratedHandles().insert(handle);

    // 先换窗口过程：后面的 SetWindowPos(SWP_FRAMECHANGED) 会立刻触发 WM_NCCALCSIZE。
    const auto previous = reinterpret_cast<WNDPROC>(
        SetWindowLongPtrW(hwnd, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(&chromeWindowProc)));
    if (previous != nullptr) {
        originalProcedures().insert(handle, previous);
    }

    // WS_POPUP 换成标准可缩放窗口，DWM 才会画阴影/圆角/贴靠布局；客户区由上面的
    // WM_NCCALCSIZE 扩回整窗，所以不会出现原生标题栏。
    //
    // 保留 WS_THICKFRAME | WS_MAXIMIZEBOX | WS_MINIMIZEBOX，其余用于"系统标题栏"的位全部去掉：
    //  - WS_THICKFRAME：DWM 阴影 / 圆角 / 缩放边的前提；
    //  - WS_MAXIMIZEBOX：Snap Layouts 面板只对"可最大化"的窗口弹出（去掉后实测面板不再出现）；
    //  - WS_CAPTION / WS_SYSMENU：DWM 画 caption 按钮与 caption hover 的来源。去掉 WS_SYSMENU
    //    字形就没了，但 DWM 仍会给关闭按钮画 hover 红底（位置是它自己的旧布局，和自绘按钮错开），
    //    所以连 WS_CAPTION 一起去掉——实测阴影、圆角、贴靠面板都还在，hover 也彻底干净。
    // 关键：**保留 WS_CAPTION | WS_SYSMENU**。Windows 只给"标准窗口"播
    // minimize/maximize/restore 过渡；把这两个位去掉后，系统把窗口当成没有标题栏的
    // 裸窗口，三种状态切换一律瞬切（实测：去掉后怎么调 ShowWindow/SC_* 都没有动画）。
    // 客户区仍由上面的 WM_NCCALCSIZE 扩回整窗，DWM 不会真的画出标题栏。
    LONG_PTR style = GetWindowLongPtrW(hwnd, GWL_STYLE);
    style &= ~static_cast<LONG_PTR>(WS_POPUP);
    // 只保留 WS_CAPTION（窗口过渡动画需要它），**不加 WS_SYSMENU**：DWM 画 caption 按钮
    // 字形靠的是 WS_SYSMENU，去掉后它不再画（最多在 hover 时画一圈红底，位置也由我们的
    // WM_NCHITTEST 控制）。
    style |= WS_THICKFRAME | WS_MAXIMIZEBOX | WS_MINIMIZEBOX | WS_CAPTION;
    SetWindowLongPtrW(hwnd, GWL_STYLE, style);
    SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                 SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);

    if (!setRoundedCorners(window, true)) {
        qWarning().noquote() << "[chrome] 系统不支持圆角属性（需要 Win11 22000+），窗口保持直角";
    }

    // 把窗口挂到 QML 的 WindowChrome 实例上：原生状态（激活、caption hover）要靠它回传 QML。
    WindowChrome *chrome = chromeForWindow(window);
    const bool active = window->isActive();
    if (chrome != nullptr) {
        chrome->attachWindow(window);
        chrome->setWindowActive(active);
    }
    updateFrameState(window, active);
    return true;
}

} // namespace winshell::platform

#else // Q_OS_WIN

namespace winshell::platform
{

bool enableSystemDecorations(QQuickWindow *)
{
    // 非 Windows 平台没有 DWM 装饰，窗口保持 Qt 的默认外观。
    return false;
}

} // namespace winshell::platform

#endif // Q_OS_WIN

WindowChrome::WindowChrome(QObject *parent)
    : QObject(parent)
{
}

void WindowChrome::attachWindow(QQuickWindow *window, bool nativeActivation)
{
    if (m_window == window) {
        return;
    }
    m_window = window;
    m_nativeActivation = nativeActivation;
    if (window == nullptr) {
        return;
    }

    // --native-frame 没有 WndProc 子类化，只能退回 Qt 的激活信号。
    QObject::connect(window, &QWindow::activeChanged, this, [this, window]() {
        if (!m_nativeActivation) {
            setWindowActive(window->isActive());
        }
    });
    setWindowActive(window->isActive());
}

void WindowChrome::setWindowActive(bool active)
{
    if (m_windowActive == active) {
        return;
    }
    m_windowActive = active;
    emit windowActiveChanged();
}

void WindowChrome::setHoveredCaptionButton(const QString &button)
{
    if (m_hoveredCaptionButton == button) {
        return;
    }
    m_hoveredCaptionButton = button;
    emit hoveredCaptionButtonChanged();
}

void WindowChrome::scheduleRepaint(bool forceFrame)
{
#ifdef Q_OS_WIN
    if (m_window == nullptr) {
        return;
    }
    QQuickWindow *window = m_window;
    if (forceFrame) {
        const HWND hwnd = reinterpret_cast<HWND>(window->winId());
        if (hwnd != nullptr) {
            // 分层窗口从最小化恢复时 DWM 会保留旧帧：补一次 FRAMECHANGED 让合成器重新取帧。
            SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                         SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE
                             | SWP_FRAMECHANGED);
        }
    }
    // 只投递一帧：额外排队 update 容易和 DWM 合成抢帧（resize 时出现条纹）。
    window->update();
#else
    Q_UNUSED(forceFrame);
#endif
}

void WindowChrome::requestRepaint()
{
#ifdef Q_OS_WIN
    if (m_window != nullptr) {
        // 先丢掉帧状态缓存再重算一遍：启动时窗口往往还没激活，DWM 会退回默认边框色
        // （浅灰），在深色界面外圈就是用户说的"灰圈"。重算会重新下发圆角与边框色，
        // 等价于用户拖拽一次 resize 触发的那次刷新。
        frameStates().remove(reinterpret_cast<quintptr>(m_window->winId()));
        updateFrameState(m_window, m_windowActive);
    }
#endif
    scheduleRepaint(true);
}

QRect WindowChrome::captionButtonRect(const QString &button) const
{
#ifdef Q_OS_WIN
    if (m_window == nullptr) {
        return QRect();
    }
    const HWND hwnd = reinterpret_cast<HWND>(m_window->winId());
    if (hwnd == nullptr) {
        return QRect();
    }
    CaptionMetrics metrics;
    if (!captionMetrics(m_window, hwnd, &metrics)) {
        return QRect();
    }

    int fromRight = -1;
    if (button == QStringLiteral("close")) {
        fromRight = 0;
    } else if (button == QStringLiteral("maximize")) {
        fromRight = 1;
    } else if (button == QStringLiteral("minimize")) {
        fromRight = 2;
    }
    if (fromRight < 0) {
        return QRect();
    }

    const qreal dpr = m_window->devicePixelRatio();
    const int right = metrics.closeRight - fromRight * metrics.buttonWidth;
    const int left = right - metrics.buttonWidth;
    // 换成 header contentItem 坐标（QML 的高亮层在 contentItem 里，见 kHeaderContentInsetDip）。
    const int inset = qRound(kHeaderContentInsetDip * dpr);
    return QRect(qRound((left - inset) / dpr), -kHeaderContentInsetDip,
                 qRound(metrics.buttonWidth / dpr), qRound(metrics.buttonHeight / dpr));
#else
    Q_UNUSED(button);
    return QRect();
#endif
}

void WindowChrome::startSystemMove(QQuickWindow *window)
{
    if (window == nullptr) {
        return;
    }
    window->startSystemMove();
}

void WindowChrome::startSystemResize(QQuickWindow *window, int edges)
{
    if (window == nullptr) {
        return;
    }
    window->startSystemResize(Qt::Edges(edges));
}

void WindowChrome::minimize(QQuickWindow *window)
{
    if (window == nullptr) {
        return;
    }
#ifdef Q_OS_WIN
    // 和 maximize 一样走系统命令：SC_MINIMIZE 让窗口过程拿到完整的最小化流程，
    // DWM 才会播过渡动画（QWindow::showMinimized 在子类化窗口上会跳过一部分）。
    if (const HWND hwnd = reinterpret_cast<HWND>(window->winId())) {
        SendMessageW(hwnd, WM_SYSCOMMAND, SC_MINIMIZE, 0);
        return;
    }
#endif
    window->showMinimized();
}

void WindowChrome::toggleMaximize(QQuickWindow *window)
{
    if (window == nullptr) {
        return;
    }
#ifdef Q_OS_WIN
    // 补过系统装饰的窗口上，Qt 的 frameless 最大化只改原生 HWND、不同步 QWindow，
    // QML 会停在旧尺寸。直接走系统最大化（ShowWindow）：Windows 会发 WM_SIZE(SIZE_MAXIMIZED)，
    // Qt 自己把窗口状态和尺寸一起更新，最大化/还原动画也交回系统。
    const HWND hwnd = reinterpret_cast<HWND>(window->winId());
    if (hwnd == nullptr) {
        return;
    }
    SendMessageW(hwnd, WM_SYSCOMMAND, IsZoomed(hwnd) ? SC_RESTORE : SC_MAXIMIZE, 0);
#else
    if (window->visibility() == QWindow::Maximized) {
        window->showNormal();
    } else {
        window->showMaximized();
    }
#endif
}

void WindowChrome::close(QQuickWindow *window)
{
    if (window == nullptr) {
        return;
    }
#ifdef Q_OS_WIN
    // 走系统命令而不是 QWindow::close()：后者直接销毁窗口，DWM 的关闭过渡来不及播。
    if (const HWND hwnd = reinterpret_cast<HWND>(window->winId())) {
        SendMessageW(hwnd, WM_SYSCOMMAND, SC_CLOSE, 0);
        return;
    }
#endif
    window->close();
}

bool WindowChrome::isMaximized(QQuickWindow *window) const
{
    return window != nullptr && window->visibility() == QWindow::Maximized;
}
