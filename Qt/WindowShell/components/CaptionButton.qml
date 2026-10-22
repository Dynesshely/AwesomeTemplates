import QtQuick
import QtQuick.Controls

/// 标题栏右上角的窗口按钮。
///
/// 现在这三个按钮由 QML 绘制、但**点击不经过 QML**：C++ 侧把右上角 46x32 的区域作为原生 NC 命中区
/// （HTMINBUTTON/HTMAXBUTTON/HTCLOSE），系统直接处理最小化/最大化/关闭与 Snap Layouts，
/// 所以这里只需要画字形和 hover 高亮。hover 由 WindowChrome.hoveredCaptionButton 提供，
/// 因为鼠标在 NC 区域时 Qt 收不到 enter/leave。
AbstractButton {
    id: control

    property string glyph: ""
    property bool danger: false
    property bool systemHover: false

    implicitWidth: 46
    implicitHeight: 32
    padding: 0
    focusPolicy: Qt.NoFocus

    readonly property bool lit: control.systemHover || control.hovered

    contentItem: Label {
        text: control.glyph
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.family: "Segoe Fluent Icons"
        font.pixelSize: 10
        color: control.danger && control.lit ? "#ffffff" : "#e6e6e6"
    }

    background: Rectangle {
        color: control.lit ? (control.danger ? "#c42b1c" : "#1affffff") : "transparent"
    }
}