import QtQuick
import QtQuick.Controls

/// Fluent 开关：40×20 胶囊 + 12px 圆形滑块，切换动画 120ms。
///
/// 为什么继承 AbstractButton：开关就是二态按钮，checked / clicked / 键盘空格 /
/// 无障碍语义直接复用，不需要自己维护一套状态。
///
/// 为什么滑块用 x 动画而不是缩放/淡入：Fluent 的开关是"扣到另一边"，
/// 不是"长出来"；胶囊圆角由 height/2 推出，不额外保存尺寸常量。
///
/// 尺寸固定 40×20，不开放宽高：一旦开放，内边距、滑块行程、胶囊圆角都得跟着重算，
/// 而展示页只需要一种规格。悬停时滑块 12→14、按下 10，是 Fluent 的原生反馈。
AbstractButton {
    id: control

    /// 屏幕阅读器用；没有可见文字时尤其需要。
    property string accessibleLabel: ""

    implicitWidth: 40
    implicitHeight: 20
    padding: 0
    checkable: true
    hoverEnabled: true

    Accessible.name: control.accessibleLabel
    Accessible.role: Accessible.CheckBox

    readonly property color accentColor: "#4c9aff"
    /// 禁用时轨道压暗、滑块降到弱化灰，不用半透明（半透明会让整个控件脏掉）。
    readonly property color trackColor: {
        if (!control.enabled) {
            return control.checked ? "#2b3949" : "#242424"
        }
        if (control.checked) {
            return control.down ? "#3d87e0" : (control.hovered ? "#63a8ff" : control.accentColor)
        }
        return control.down ? "#2f2f2f" : (control.hovered ? "#3f3f3f" : "#3a3a3a")
    }

    readonly property color knobColor: {
        if (!control.enabled) {
            return "#5a5f64"
        }
        return control.checked ? "#ffffff" : "#9aa0a6"
    }

    /// 滑块直径：悬停放大、按下回落，跟 WinUI 的 Switch 反馈一致。
    readonly property int knobSize: !control.enabled ? 12 : (control.pressed ? 10 : (control.hovered ? 14 : 12))

    contentItem: Item {
        implicitWidth: 40
        implicitHeight: 20

        Rectangle {
            id: track
            anchors.fill: parent
            radius: height / 2
            color: control.trackColor
            border.width: control.visualFocus ? 2 : (control.checked ? 0 : 1)
            border.color: control.visualFocus ? "#8ec0ff" : (control.enabled ? "#5a5f64" : "#3a3a3a")

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }

        Rectangle {
            id: knob
            y: (parent.height - height) / 2
            x: control.checked ? parent.width - 4 - width : 4
            width: control.knobSize
            height: control.knobSize
            radius: width / 2
            color: control.knobColor

            Behavior on x {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }
    }
}
