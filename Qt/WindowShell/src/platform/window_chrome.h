#pragma once

#include <QObject>
#include <QPointer>
#include <QRect>
#include <QString>
#include <QtQml/qqmlregistration.h>
// 必须是完整类型：Q_INVOKABLE 带 QQuickWindow* 参数，moc 生成的指针元类型注册
// 需要知道这个类（只前向声明会触发 "Pointer Meta Types ... must point to fully-defined types"）。
#include <QQuickWindow>

namespace winshell::platform
{

/// 给 frameless 窗口补上系统窗口装饰（仅 Windows）：DWM 阴影、圆角、Snap Layouts 悬停面板、
/// 最小化/最大化动画，以及窗口 Active 时的系统强调色边框。
///
/// 为什么需要它：Qt 的 frameless 窗口是 WS_POPUP，DWM 既不画阴影/圆角，也不给贴靠布局。
/// 做法是把窗口样式补成标准可缩放窗口（WS_THICKFRAME | WS_CAPTION），再用 WndProc 子类化
/// 接管 WM_NCCALCSIZE（客户区覆盖整窗）——DWM 仍按"有边框窗口"绘制装饰，客户区仍然是
/// 应用自己的内容；WM_NCHITTEST 负责缩放边与三个 caption 按钮的命中。
///
/// 关键取舍（都是实测结论，细节见 docs/notes-mica.md 第 11 节）：
///  - 必须用 SetWindowLongPtr(GWLP_WNDPROC) 子类化，不能挂在 QAbstractNativeEventFilter 上：
///    过滤器截 WM_NCCALCSIZE 会让 Qt 错过最大化时的尺寸变化，QML 不重排。
///  - 最大化/还原用系统 ShowWindow，不用 QWindow::showMaximized()（后者不同步 QWindow 尺寸）。
///  - 补样式不会破坏 WS_EX_LAYERED，所以 Mica 与这些装饰可以同时存在。
///
/// 约束：
///  - 必须在窗口 show 之后调用（需要原生 HWND）；之后不要再改 Qt 的 window flags，
///    改 flags 会让 Qt 重建窗口、装饰随之丢失。
///  - 只对 frameless 窗口生效；--native-frame 下系统自己就有装饰，不该调用。
///  - 非 Windows / 窗口为空 / 系统拒绝时返回 false，窗口保持原样，不崩。
bool enableSystemDecorations(QQuickWindow *window);

} // namespace winshell::platform

/// 自绘标题栏需要的最小窗口操作，以及原生窗口状态的 QML 镜像。
///
/// 为什么需要这层包装：QWindow::startSystemMove / startSystemResize 不是 Q_INVOKABLE，QML 调不到；
/// 而自己搬坐标会丢掉 Aero Snap、跨屏拖动、系统最小尺寸、最大化动画这些原生行为。
///
/// 为什么还要镜像 active / hover：窗口过程被我们子类化后，DWM 在"客户区覆盖整窗"的窗口上
/// 不画 caption 按钮的 hover 高亮；而 QML 的 window.active 在部分路径上不跟着 WM_ACTIVATE 刷新。
/// 这里把原生侧的真实状态算好，QML 只负责画。
///
/// 约束：
///  - 只接受已创建的顶层窗口；window 为空时全部静默忽略，不会崩。
///  - startSystemMove 必须在鼠标按下的同一次事件里调用：Qt 把这次按下交给系统的移动循环，
///    调用后不要再在同一事件里改窗口几何。
///  - --native-frame 下调用同样安全：系统用自己的标题栏，这些操作只是多余。
class WindowChrome : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    /// 窗口是否真的处于激活状态，跟随原生 WM_ACTIVATE（不是 Qt 的 window.active）。
    Q_PROPERTY(bool windowActive READ windowActive NOTIFY windowActiveChanged)
    /// 鼠标当前悬停的原生 caption 按钮："none" / "minimize" / "maximize" / "close"。
    Q_PROPERTY(QString hoveredCaptionButton READ hoveredCaptionButton NOTIFY hoveredCaptionButtonChanged)

public:
    explicit WindowChrome(QObject *parent = nullptr);

    bool windowActive() const { return m_windowActive; }
    QString hoveredCaptionButton() const { return m_hoveredCaptionButton; }

    /// 三个原生 caption 按钮在窗口内容坐标系里的矩形（逻辑像素），QML 画 hover 高亮用。
    /// button 取 "minimize" / "maximize" / "close"；未知名字返回空矩形。
    Q_INVOKABLE QRect captionButtonRect(const QString &button) const;

    /// 把当前这次按下交给系统的窗口移动循环（保留 Aero Snap 等原生行为）。
    Q_INVOKABLE void startSystemMove(QQuickWindow *window);

    /// edges 取 Qt::Edges 的位掩码（Qt.LeftEdge / Qt.TopEdge / ...），由系统负责缩放。
    Q_INVOKABLE void startSystemResize(QQuickWindow *window, int edges);

    Q_INVOKABLE void minimize(QQuickWindow *window);
    Q_INVOKABLE void toggleMaximize(QQuickWindow *window);
    Q_INVOKABLE void close(QQuickWindow *window);
    Q_INVOKABLE bool isMaximized(QQuickWindow *window) const;

    /// 让系统重取一帧窗口框架（圆角/边框/阴影）并让 Qt 重画整窗。
    /// 用于"首帧之后几何才定下来"的场景（会话恢复会把宽高改成上次保存的值）：DWM 不会
    /// 自动补画窗口最外一圈，表现为边缘残留一条浅色带，直到下一次交互式 resize 才消失。
    /// 只刷新帧、不改几何，所以不会像在 QML 里改窗口宽高那样把启动流程弄崩。
    Q_INVOKABLE void requestRepaint();

    // 以下由原生窗口过程/装饰安装时调用，QML 侧只读。
    /// nativeActivation=true 时激活状态只信原生 WM_ACTIVATE（装饰窗口）；
    /// false 时退回 Qt 的 activeChanged（--native-frame 没有子类化窗口过程）。
    void attachWindow(QQuickWindow *window, bool nativeActivation = false);
    void setWindowActive(bool active);
    void setHoveredCaptionButton(const QString &button);
    /// 分层窗口从最小化恢复时 DWM 可能保留旧帧：强制 DWM 重取一帧并让 Qt 重画。
    /// forceFrame=true 时额外下发 SWP_FRAMECHANGED（只在 show/激活恢复时用，别在 WM_SIZE 里用，
    /// 否则会递归触发尺寸消息）。
    void scheduleRepaint(bool forceFrame = false);

signals:
    void windowActiveChanged();
    void hoveredCaptionButtonChanged();

private:
    QPointer<QQuickWindow> m_window;
    bool m_nativeActivation = false;
    bool m_windowActive = false;
    QString m_hoveredCaptionButton = QStringLiteral("none");
};
