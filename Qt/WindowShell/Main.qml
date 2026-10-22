import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import WindowShell

/// 窗口壳示例：自绘标题栏 + Mica + 原生窗口动画。
/// 业务内容全部交给 pages/ 下的展示页，这里只负责"壳"。
ApplicationWindow {
    id: root

    width: 1280
    height: 820
    visible: true
    title: qsTr("WindowShell")

    /// 自绘标题栏（frameless）是 Mica 与原生窗口动画的前提。
    /// 必须保留 Qt.Window：只写 FramelessWindowHint 会把窗口变成工具窗口（任务栏没有按钮）。
    flags: framelessWindow ? (Qt.Window | Qt.FramelessWindowHint) : Qt.Window
    /// Mica 开启时窗口必须真正透明；关闭时用不透明深色底。
    color: micaEnabled ? "transparent" : "#1b1b1b"

    /// 窗口真的处于激活态：由 WindowChrome 从原生 WM_ACTIVATE 跟踪，
    /// 比 QWindow::active 可靠（子类化窗口过程后 Qt 的 active 会滞后）。
    readonly property bool windowActive: titleChrome.windowActive

    /// 面板色：Mica 模式下带 surfaceAlpha（按壁纸亮度自适应，见 src/platform/wallpaper_tone.cpp）。
    readonly property color surfaceColor: micaEnabled
                                          ? Qt.rgba(0.10588, 0.10588, 0.10588, surfaceAlpha)
                                          : "#1b1b1b"
    /// 同色但更深一档，用于标题栏/工具栏这类要压暗的区域。
    readonly property color surfaceDeepColor: micaEnabled
                                              ? Qt.rgba(0.07059, 0.07059, 0.07059, surfaceAlpha)
                                              : "#151515"

    /// 这一层必须铺满整窗：Mica 模式下它保持全透明（垫在面板下面，不能挡 backdrop）；
    /// 非 Mica 模式下它是窗口底色。
    background: Rectangle {
        anchors.fill: parent
        color: micaEnabled ? "transparent" : "#1b1b1b"
    }

    WindowChrome {
        id: titleChrome
    }

    // 关闭过渡：自绘窗口上系统不播关闭动画（Qt 直接销毁窗口），先淡出 130ms 再真正关闭。
    // 分层窗口上 Window::opacity 走 SetLayeredWindowAttributes，是整窗真淡出。
    property bool closingFadeDone: false
    onClosing: function (close) {
        if (root.closingFadeDone) {
            return
        }
        close.accepted = false
        closingFade.start()
    }

    NumberAnimation {
        id: closingFade
        target: root
        property: "opacity"
        to: 0
        duration: 130
        easing.type: Easing.InQuad
        onFinished: {
            root.closingFadeDone = true
            root.close()
        }
    }

    // 首帧之后几何才定下来的场景（会话恢复改宽高）DWM 不会补画窗口框架：
    // 让系统重取一帧，避免最外一圈停在旧色。
    Timer {
        interval: 260
        running: true
        repeat: false
        onTriggered: titleChrome.requestRepaint()
    }

    /// 自绘标题栏：拖动、双击最大化、三个窗口按钮都在这里。
    header: ToolBar {
        id: titleBar
        padding: 0
        // ToolBar 的隐式高度来自样式自己的 background；换成自定义 Rectangle 后必须写回，
        // 否则高度塌到 contentItem 的隐式高度（标题栏被内容侵占）。
        implicitHeight: 48

        background: Rectangle {
            implicitHeight: 48
            color: root.surfaceColor
        }

        contentItem: Item {
            // 拖动区放在底层：按钮和输入框优先收事件，空白处的按下交给系统移动窗口。
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onPressed: titleChrome.startSystemMove(root)
                onDoubleClicked: titleChrome.toggleMaximize(root)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 150   // 3 × 46 的原生 caption 按钮 + 余量
                spacing: 10

                Rectangle {
                    id: brandArea
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: brandRow.implicitWidth + 16
                    radius: 6
                    color: brandMouse.containsMouse ? "#1affffff" : "transparent"

                    Row {
                        id: brandRow
                        anchors.centerIn: parent
                        spacing: 8

                        Image {
                            source: "qrc:/qt/qml/WindowShell/assets/logo/app-64.png"
                            sourceSize.width: 18
                            sourceSize.height: 18
                            width: 18
                            height: 18
                            anchors.verticalCenter: parent.verticalCenter
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                        Label {
                            text: qsTr("WindowShell")
                            font.pixelSize: 12
                            font.bold: true
                            opacity: 0.85
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: brandMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: aboutDialog.open()
                    }
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: micaEnabled ? qsTr("Mica") : qsTr("不透明")
                    font.pixelSize: 11
                    opacity: 0.45
                }
            }

            // 三个窗口按钮：贴右上角 46×48，与 C++ 里的原生 NC 命中区重合。
            // 这里只画字形与 hover 高亮——点击由系统按 WM_NCHITTEST 处理（Snap Layouts 也靠它）。
            Row {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: -8
                anchors.rightMargin: -8
                height: 48
                spacing: 0

                CaptionButton {
                    height: 48
                    glyph: "\uE921"
                    systemHover: titleChrome.hoveredCaptionButton === "minimize"
                }
                CaptionButton {
                    height: 48
                    glyph: root.visibility === Window.Maximized ? "\uE923" : "\uE922"
                    systemHover: titleChrome.hoveredCaptionButton === "maximize"
                }
                CaptionButton {
                    height: 48
                    glyph: "\uE8BB"
                    danger: true
                    systemHover: titleChrome.hoveredCaptionButton === "close"
                }
            }
        }
    }

    ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ControlsPage {
            width: scroll.availableWidth
        }
    }

    footer: ToolBar {
        implicitHeight: 28
        padding: 0

        background: Rectangle {
            implicitHeight: 28
            color: root.surfaceDeepColor
        }

        contentItem: RowLayout {
            spacing: 12

            Label {
                text: micaEnabled ? qsTr("Mica · surfaceAlpha %1").arg(surfaceAlpha.toFixed(2))
                                  : qsTr("Opaque")
                font.pixelSize: 11
                opacity: 0.45
                Layout.leftMargin: 12
            }
            Item { Layout.fillWidth: true }
            Label {
                text: "WindowShell " + appVersion + " · Qt " + qtVersion
                font.pixelSize: 11
                opacity: 0.4
                Layout.rightMargin: 12
            }
        }
    }

    AboutDialog {
        id: aboutDialog
    }
}
