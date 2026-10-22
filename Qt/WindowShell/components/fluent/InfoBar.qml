import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import WindowShell

/// Fluent 信息条：severity 决定颜色与左侧符号，标题/正文 wrap，右侧可关闭。
///
/// 左侧徽标用 Icons 的状态图标：info / success / warning / error 已登记在
/// components/Icons.qml（码位取自上游 ic_fluent_info / checkmark_circle / warning /
/// error_circle）。关闭按钮复用 IconButton + dismiss。
///
/// 为什么 open 放在组件内部管理：关闭按钮必须能立即收起；调用方只需要在
/// 需要重新展示时把 open 设回 true，不必自己维护"已关闭"集合。
///
/// 约束：severity 只认 info / success / warning / error，其他值按 info 处理；
/// 正文为空时不占高度。背景是带色偏的深色面，边框只取 35% 的语义色，
/// 避免四条信息条在暗色页面里互相抢眼。
Rectangle {
    id: bar

    property string severity: "info"
    property string title: ""
    property string text: ""
    /// 是否显示右上角关闭按钮。
    property bool closable: true
    /// 是否展开；关闭按钮把它置为 false，外部可重新置 true。
    property bool open: true

    signal dismissed()

    readonly property color severityColor: {
        switch (bar.severity) {
        case "success":
            return "#6fcf97"
        case "warning":
            return "#d6a01a"
        case "error":
            return "#e06c75"
        default:
            return "#4c9aff"
        }
    }

    readonly property color surfaceTint: {
        switch (bar.severity) {
        case "success":
            return "#1b2821"
        case "warning":
            return "#2a2517"
        case "error":
            return "#2e1f21"
        default:
            return "#1c2430"
        }
    }

    /// 语义图标名（对应 Icons.qml 的 map）；未知 severity 一律按 info 处理。
    readonly property string severityIcon: {
        switch (bar.severity) {
        case "success":
            return "success"
        case "warning":
            return "warning"
        case "error":
            return "error"
        default:
            return "info"
        }
    }

    Icons {
        id: icons
    }

    implicitWidth: 520
    implicitHeight: layout.implicitHeight + 24
    visible: open
    radius: 6
    color: surfaceTint
    border.width: 1
    border.color: Qt.rgba(severityColor.r, severityColor.g, severityColor.b, 0.35)

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Rectangle {
            width: 20
            height: 20
            radius: 10
            color: Qt.rgba(bar.severityColor.r, bar.severityColor.g, bar.severityColor.b, 0.18)
            Layout.alignment: Qt.AlignTop

            Label {
                anchors.centerIn: parent
                text: icons.glyph(bar.severityIcon)
                font.family: icons.fontFamily
                color: bar.severityColor
                font.pixelSize: 14
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 2

            Label {
                visible: bar.title.length > 0
                Layout.fillWidth: true
                text: bar.title
                font.pixelSize: 13
                font.bold: true
                color: "#e6e6e6"
                elide: Text.ElideRight
            }

            Label {
                visible: bar.text.length > 0
                Layout.fillWidth: true
                text: bar.text
                font.pixelSize: 12
                color: "#9aa0a6"
                wrapMode: Text.WordWrap
            }
        }

        IconButton {
            visible: bar.closable
            size: 24
            iconSize: 12
            iconName: "dismiss"
            toolTip: qsTr("关闭")
            Layout.alignment: Qt.AlignTop
            onClicked: {
                bar.open = false
                bar.dismissed()
            }
        }
    }
}
