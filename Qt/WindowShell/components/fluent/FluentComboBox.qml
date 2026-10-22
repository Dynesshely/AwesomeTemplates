import QtQuick
import QtQuick.Controls
import WindowShell

/// Fluent 下拉框：圆角输入面 + 右侧 chevron + 圆角弹层。
///
/// 为什么继承 ComboBox：弹出/收起、键盘上下选择、currentIndex、delegateModel、
/// textRole 这些都由基类维护；自己拼一个 Popup + ListView 会重写一遍焦点与关闭策略。
///
/// 为什么弹层用 independent 的 ListView.delegateModel：ComboBox 的 delegateModel
/// 已经把 model / textRole / currentIndex 都适配好了，弹层只需要负责画。
///
/// 约束：默认按"字符串数组或带 textRole 的模型"使用；delegate 里对数组模型
/// 走 model[textRole]，对字符串模型走 modelData，两种情况都覆盖。
/// 弹层高度上限 240px，避免长列表把窗口顶出去；超出部分在弹层内滚动。
ComboBox {
    id: control

    implicitWidth: 220
    implicitHeight: 32
    leftPadding: 10
    rightPadding: 32
    topPadding: 0
    bottomPadding: 0
    topInset: 0
    bottomInset: 0
    leftInset: 0
    rightInset: 0
    spacing: 0
    font.pixelSize: 13
    hoverEnabled: true

    Icons {
        id: icons
    }

    contentItem: Label {
        text: control.displayText
        font: control.font
        color: control.enabled ? "#e6e6e6" : "#5a5f64"
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Label {
        x: control.width - width - 10
        y: (control.height - height) / 2
        text: icons.glyph("chevron-down")
        font.family: icons.fontFamily
        font.pixelSize: 12
        color: control.enabled ? "#9aa0a6" : "#5a5f64"
        rotation: control.popup.visible ? 180 : 0

        Behavior on rotation {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }

    background: Rectangle {
        implicitWidth: 220
        implicitHeight: 32
        radius: 4
        color: control.enabled ? "#1f1f1f" : "#1c1c1c"
        border.width: 1
        border.color: {
            if (!control.enabled) {
                return "#2e2e2e"
            }
            if (control.popup.visible || control.activeFocus) {
                return "#4c9aff"
            }
            return control.hovered ? "#4a4a4a" : "#3a3a3a"
        }

        Behavior on border.color {
            ColorAnimation { duration: 120 }
        }
    }

    delegate: ItemDelegate {
        id: item

        width: ListView.view ? ListView.view.width : control.width
        height: 30
        text: control.textRole
              ? (Array.isArray(control.model) ? model[control.textRole] : model[control.textRole])
              : modelData
        highlighted: control.highlightedIndex === index
        hoverEnabled: true

        background: Rectangle {
            radius: 4
            color: item.highlighted || item.hovered ? "#2a2a2a" : "transparent"
        }

        contentItem: Label {
            leftPadding: 8
            rightPadding: 8
            text: item.text
            font.pixelSize: 13
            color: item.enabled ? "#e6e6e6" : "#5a5f64"
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    popup: Popup {
        y: control.height + 4
        width: control.width
        padding: 4
        implicitHeight: Math.min(contentItem.implicitHeight + topPadding + bottomPadding, 240)

        background: Rectangle {
            radius: 6
            color: "#232323"
            border.width: 1
            border.color: "#3a3a3a"
        }

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.delegateModel
            currentIndex: control.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
        }
    }
}
