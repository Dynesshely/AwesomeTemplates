import QtQuick
import QtQuick.Controls

/// Fluent 复选框：18×18 方框 + 勾，支持部分选中（三态）。
///
/// 为什么继承 CheckBox 而不是 AbstractButton：checkState / tristate 是
/// CheckBox 才有的属性（AbstractButton 只有 checkable/checked），而且
/// "未选 → 部分 → 全选"的点击循环、键盘空格、无障碍 role 都由基类维护。
/// 自己拿 AbstractButton 复刻这套状态机，等于把 Qt 已经写对的东西再写一遍。
///
/// 为什么 indicator 自己画：样式层的 indicator 是位图/StyleImage，颜色和
/// 尺寸都绑在 Config 上；这里只需要 18×18 方框 + 描边 + Canvas 勾，
/// 用 Rectangle + Canvas 能把 4px 圆角、hover 底色、focus 边框都控制住。
///
/// 勾用 Canvas 画而不是字体字符：不依赖系统字体是否带 ✓，缩放时也不发虚。
///
/// 约束：方框尺寸固定在 18×18（Fluent 规格），只开放文字与状态。
CheckBox {
    id: control

    /// 屏幕阅读器文本；未设置时退回可见文字。
    property string accessibleLabel: ""

    hoverEnabled: true
    spacing: 8
    padding: 0
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0
    topInset: 0
    bottomInset: 0
    leftInset: 0
    rightInset: 0
    implicitWidth: Math.max(20, contentLabel.implicitWidth)
    implicitHeight: 20

    /// 部分选中是 Qt 三态的一部分，单独暴露只读别名方便外部做条件渲染。
    readonly property bool partiallyChecked: control.checkState === Qt.PartiallyChecked

    Accessible.name: control.accessibleLabel.length > 0 ? control.accessibleLabel : control.text
    Accessible.role: Accessible.CheckBox

    /// 勾/横线的颜色压在 accent 填充上：与按钮同理，深色比白色对比度更高。
    readonly property color markColor: control.enabled ? "#0b1b2a" : "#5a5f64"

    indicator: Item {
        id: boxSlot
        implicitWidth: 18
        implicitHeight: 18
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2

        Rectangle {
            id: box
            anchors.fill: parent
            radius: 4
            color: {
                if (!control.enabled) {
                    return control.checked ? "#2b3949" : "transparent"
                }
                if (control.checked || control.partiallyChecked) {
                    return control.down ? "#3d87e0" : (control.hovered ? "#63a8ff" : "#4c9aff")
                }
                return control.down ? "#242424" : (control.hovered ? "#2a2a2a" : "transparent")
            }
            border.width: control.visualFocus && control.enabled ? 2 : 1
            border.color: {
                if (control.visualFocus && control.enabled) {
                    return "#8ec0ff"
                }
                if (control.checked || control.partiallyChecked) {
                    return "transparent"
                }
                return control.enabled ? "#5a5f64" : "#3a3a3a"
            }

            Behavior on color {
                ColorAnimation { duration: 90 }
            }
        }

        Canvas {
            id: mark
            anchors.fill: parent
            visible: control.checked || control.partiallyChecked
            property int markState: control.checkState
            onMarkStateChanged: requestPaint()
            onVisibleChanged: requestPaint()
            onEnabledChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = control.markColor
                ctx.lineWidth = 2
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()
                if (control.checkState === Qt.PartiallyChecked) {
                    ctx.moveTo(5, 9)
                    ctx.lineTo(13, 9)
                } else {
                    ctx.moveTo(4.6, 9.1)
                    ctx.lineTo(7.4, 12)
                    ctx.lineTo(13.4, 5.8)
                }
                ctx.stroke()
            }
        }
    }

    contentItem: Label {
        id: contentLabel
        leftPadding: control.indicator ? control.indicator.width + control.spacing : 0
        rightPadding: 0
        text: control.text
        font.pixelSize: 13
        color: control.enabled ? "#e6e6e6" : "#5a5f64"
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
