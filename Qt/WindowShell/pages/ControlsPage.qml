import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import WindowShell

/// 控件展示页的骨架：分组 + 说明文字。
/// 具体控件由 components/ 下的原子组件拼出来。
Flickable {
    id: page

    contentWidth: width
    contentHeight: body.implicitHeight + 48
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: body
        width: page.width
        anchors.top: parent.top
        anchors.topMargin: 24
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 18

        Label {
            text: qsTr("WindowShell")
            font.pixelSize: 26
            font.bold: true
            color: "#e6e6e6"
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("仿 Windows Fluent UI 的自定义窗口壳：自绘标题栏、Snap Layouts、Mica、"
                       + "原生最小化/最大化/还原动画，以及按壁纸亮度自适应的面板透明度。")
            font.pixelSize: 13
            color: "#9aa0a6"
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#26ffffff"
        }
        Label {
            text: qsTr("控件展示区（待填充）")
            font.pixelSize: 13
            color: "#7f868c"
        }
        Item { Layout.fillWidth: true; Layout.preferredHeight: 24 }
    }
}
