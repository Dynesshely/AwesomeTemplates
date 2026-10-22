import QtQuick
import QtQuick.Controls

/// Fluent 进度条：determinate 显示 value/position，indeterminate 用一段 35% 宽的
/// 色块循环扫过轨道。
///
/// 为什么继承 ProgressBar：value/from/to/position 的归一化以及 indeterminate
/// （Qt 6.7 起是 ProgressBar 自己的属性）都由基类维护，这里只重画轨道与填充。
///
/// 为什么 indeterminate 的动画写在 background 里：ProgressBar 的 contentItem
/// 由样式负责，重复接管容易和基类的 position 绑定打架；轨道是纯视觉层，
/// 把扫动色块放进去最省事，也不影响 value 语义。
///
/// 约束：from/to 保持基类默认 0/1，展示页用 0..1 的小数；需要百分比时由调用方换算。
ProgressBar {
    id: control

    property int trackHeight: 4
    property color trackColor: "#3a3a3a"
    property color progressColor: "#4c9aff"

    implicitWidth: 240
    implicitHeight: trackHeight
    padding: 0
    topInset: 0
    bottomInset: 0
    leftInset: 0
    rightInset: 0

    background: Rectangle {
        implicitWidth: 240
        implicitHeight: control.trackHeight
        radius: control.trackHeight / 2
        color: control.enabled ? control.trackColor : "#2e2e2e"
        clip: true

        /// determinate：宽度跟着 visualPosition 走，并做 120ms 补间，
        /// 让程序化改 value 时也是"推进"而不是"跳变"。
        Rectangle {
            id: determinateFill
            visible: !control.indeterminate
            width: Math.max(0, Math.min(1, control.visualPosition)) * parent.width
            height: parent.height
            radius: parent.radius
            color: control.enabled ? control.progressColor : "#5a5f64"

            Behavior on width {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
        }

        /// indeterminate：色块从轨道左侧外滑到右侧外，循环往复。
        /// 色块宽度取轨道 35%，保证任意时刻都能同时看到"有进度"和"在动"。
        Rectangle {
            id: sweep
            visible: control.indeterminate
            width: parent.width * 0.35
            height: parent.height
            radius: parent.radius
            color: control.enabled ? control.progressColor : "#5a5f64"
            x: -width

            NumberAnimation on x {
                running: control.indeterminate && control.visible
                loops: Animation.Infinite
                from: -sweep.width
                to: control.background.width
                duration: 1400
                easing.type: Easing.InOutQuad
            }
        }
    }

    contentItem: Item {
        implicitWidth: 0
        implicitHeight: 0
    }
}
