import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/// 仿 Apple「关于本机」面板：居中卡片、大图标、居中排版、克制到几乎只有信息本身。
/// 卡片自己画在 contentItem 里（Popup 的 background 尺寸跟随在某些样式下不可靠）。
Dialog {
    id: dialog

    property string productName: "WindowShell"
    property string tagline: qsTr("仿 Windows Fluent 的自定义窗口壳模板")
    property string copyright: qsTr("© 2026 AwesomeTemplates")
    property url iconSource: "qrc:/qt/qml/WindowShell/assets/logo/app-256.png"

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    padding: 0
    width: 360
    height: 452
    anchors.centerIn: Overlay.overlay

    Overlay.modal: Rectangle { color: "#66000000" }

    contentItem: Rectangle {
        radius: 20
        color: "#F51E1E20"
        border.width: 1
        border.color: "#26FFFFFF"

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 130
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#12FFFFFF" }
                GradientStop { position: 1.0; color: "#00FFFFFF" }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Item { Layout.preferredHeight: 34 }

            Image {
                source: dialog.iconSource
                sourceSize.width: 112
                sourceSize.height: 112
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 112
                Layout.preferredHeight: 112
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Item { Layout.preferredHeight: 20 }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: dialog.productName
                font.pixelSize: 21
                font.weight: Font.DemiBold
                color: "#F5F5F7"
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6
                text: qsTr("版本 %1").arg(Qt.application.version)
                font.pixelSize: 11
                color: "#98989D"
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 12
                text: dialog.tagline
                font.pixelSize: 12
                color: "#C7C7CC"
            }

            Item { Layout.fillHeight: true }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 26
                Layout.rightMargin: 26
                Layout.preferredHeight: 1
                color: "#1FFFFFFF"
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 11
                text: dialog.copyright
                font.pixelSize: 10
                color: "#7C7C82"
            }

            Button {
                id: okButton
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 13
                Layout.bottomMargin: 24
                implicitWidth: 104
                implicitHeight: 30
                text: qsTr("好")
                onClicked: dialog.close()

                background: Rectangle {
                    radius: 15
                    color: okButton.down ? "#2F5FD0" : okButton.hovered ? "#4A79E8" : "#3A6CE2"
                }
                contentItem: Label {
                    text: okButton.text
                    color: "white"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}