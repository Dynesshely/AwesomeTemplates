import QtQuick
import QtQuick.Controls

/// Fluent 输入框：4px 圆角、#1f1f1f 底、1px 描边，获得焦点时底部 2px accent 强调线。
///
/// 为什么继承 TextField：输入法、选区、密码模式、撤销、拖选全部现成；
/// 只替换 background 就能保住这些行为。
///
/// 为什么强调线画在背景内部的下沿而不是整圈变粗：Fluent 的输入框焦点反馈是
/// "底部一条线亮起"，整圈加粗会让布局里的相邻控件看起来在跳动；这里用 opacity
/// 过渡，边框宽度始终是 1px，不会引起重排。
///
/// 约束：高度固定 32；左右内边距 10，保持和按钮同一条视觉基线。
TextField {
    id: control

    implicitWidth: 240
    implicitHeight: 32
    leftPadding: 10
    rightPadding: 10
    topPadding: 0
    bottomPadding: 0
    topInset: 0
    bottomInset: 0
    leftInset: 0
    rightInset: 0
    font.pixelSize: 13
    color: control.enabled ? "#e6e6e6" : "#5a5f64"
    placeholderTextColor: "#5a5f64"
    selectionColor: "#4c9aff"
    selectedTextColor: "#0b1b2a"
    verticalAlignment: Text.AlignVCenter
    hoverEnabled: true

    background: Rectangle {
        implicitWidth: 240
        implicitHeight: 32
        radius: 4
        color: control.enabled ? "#1f1f1f" : "#1c1c1c"
        border.width: 1
        border.color: {
            if (!control.enabled) {
                return "#2e2e2e"
            }
            if (control.activeFocus) {
                return "#4c9aff"
            }
            return control.hovered ? "#4a4a4a" : "#3a3a3a"
        }

        Behavior on border.color {
            ColorAnimation { duration: 120 }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            anchors.bottomMargin: 1
            height: 2
            radius: 1
            color: control.enabled ? "#4c9aff" : "#5a5f64"
            opacity: control.activeFocus && control.enabled ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
