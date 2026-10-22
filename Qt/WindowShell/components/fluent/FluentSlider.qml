import QtQuick
import QtQuick.Controls

/// Fluent 水平滑块：4px 轨道 + accent 填充 + 圆形手柄，悬停时手柄 14→18。
///
/// 为什么继承 Slider：拖动、步进、键盘方向键、pageScroll 这套行为已经完整，
/// 换掉 background 与 handle 即可；自己写 MouseArea 很容易在拖动时丢事件。
///
/// 为什么给左右各 10px 内边距：手柄是 20px 的槽位，视觉圆点在里面缩放。
/// 有了这段 padding，手柄中心正好落在轨道两端，不会在 0/100% 处探出轨道外；
/// 同时也让点击区域比 4px 的细轨宽得多。
///
/// 约束：只实现了水平布局（展示页只有横向滑块）。竖向滑块的 padding/坐标
/// 需要另一套计算，这里不假装支持。
Slider {
    id: control

    property int trackHeight: 4
    /// 手柄槽位直径，也是悬停时的最大视觉直径。
    property int handleSize: 20
    /// 视觉圆点的常态直径。
    property int dotSize: 14
    /// 悬停时视觉圆点直径。
    property int dotHoverSize: 18
    property color accentColor: "#4c9aff"
    property color trackColor: "#3a3a3a"

    implicitWidth: 240
    implicitHeight: 28
    hoverEnabled: true
    leftPadding: handleSize / 2
    rightPadding: handleSize / 2
    topPadding: 0
    bottomPadding: 0
    topInset: 0
    bottomInset: 0
    leftInset: 0
    rightInset: 0

    background: Item {
        Rectangle {
            id: track
            x: control.leftPadding
            width: control.availableWidth
            height: control.trackHeight
            anchors.verticalCenter: parent.verticalCenter
            radius: control.trackHeight / 2
            color: control.enabled ? control.trackColor : "#2e2e2e"
        }

        Rectangle {
            id: fill
            x: control.leftPadding
            width: control.visualPosition * control.availableWidth
            height: control.trackHeight
            anchors.verticalCenter: parent.verticalCenter
            radius: control.trackHeight / 2
            color: control.enabled ? control.accentColor : "#5a5f64"
        }
    }

    handle: Item {
        id: handleSlot
        width: control.handleSize
        height: control.handleSize
        x: control.leftPadding + control.visualPosition * control.availableWidth - width / 2
        y: control.topPadding + (control.availableHeight - height) / 2

        Rectangle {
            id: dot
            anchors.centerIn: parent
            width: control.enabled ? (control.pressed ? control.dotSize - 2 : (control.hovered ? control.dotHoverSize : control.dotSize))
                                   : control.dotSize - 2
            height: width
            radius: width / 2
            color: control.enabled ? control.accentColor : "#5a5f64"
            border.width: control.visualFocus && control.enabled ? 2 : 0
            border.color: "#8ec0ff"

            Behavior on width {
                NumberAnimation {
                    duration: 90
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: 90
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
