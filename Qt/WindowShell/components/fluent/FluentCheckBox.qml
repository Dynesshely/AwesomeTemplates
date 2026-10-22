import QtQuick
import QtQuick.Controls

/// Fluent 复选框：18×18 方框 + 勾，支持部分选中（三态）。
///
/// 为什么继承 AbstractButton 而不是 CheckBox：CheckBox 的样式把 indicator、
/// 背景和 focus 框都绑在样式配置上，覆写要跟一整套 config 打交道；这里只要一个
/// 方框、一个勾和一行文字，AbstractButton 的 checkable / tristate / checkState
/// 已经覆盖全部交互语义，代码反而更短、更可控。
///
/// 部分选中直接复用 Qt 的 checkState：tristate: true 时点击会按
/// Unchecked → PartiallyChecked → Checked 循环，不需要自己造一个 bool。
/// 勾用 Canvas 画而不是字体字符：不依赖系统字体是否带 ✓，缩放下也不发虚。
///
/// 约束：方框尺寸固定在 18×18（Fluent 规格），只开放文字与状态。
AbstractButton {
    id: control

    /// 屏幕阅读器文本；未设置时退回可见文字。
    property string accessibleLabel: ""

    checkable: true
    hoverEnabled: true
    padding: 0
    implicitWidth: contentArea.implicitWidth
    implicitHeight: 20

    /// 部分选中是 Qt 三态的一部分，单独暴露只读别名方便外部做条件渲染。
    readonly property bool partiallyChecked: control.checkState === Qt.PartiallyChecked

    Accessible.name: control.accessibleLabel.length > 0 ? control.accessibleLabel : control.text
    Accessible.role: Accessible.CheckBox

    /// 勾/横线的颜色压在 accent 填充上：与按钮同理，深色比白色对比度更高。
    readonly property color markColor: control.enabled ? "#0b1b2a" : "#5a5f64"

    contentItem: Item {
        id: contentArea
        implicitWidth: contentRow.implicitWidth
        implicitHeight: 20

        Row {
            id: contentRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Item {
                id: boxSlot
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter

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

            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: control.text.length > 0
                text: control.text
                font.pixelSize: 13
                color: control.enabled ? "#e6e6e6" : "#5a5f64"
            }
        }
    }
}
