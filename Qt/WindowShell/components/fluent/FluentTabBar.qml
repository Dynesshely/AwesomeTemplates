import QtQuick
import QtQuick.Controls

/// Fluent 标签条：横向标签、悬停底色、选中项下方 2px 强调色下划线。
///
/// 为什么不用 TabBar/TabButton：这里只需要"一条可点的标签"，
/// 不需要 StackLayout 绑定；自己用 Row + Repeater 更轻，也便于把下划线宽度
/// 控制成文字宽度（Fluent 的指示条比整格窄）。
///
/// 为什么改用 currentIndex + tabActivated 而不是 checked：标签是单选语义，
/// 用索引比让每个 TabButton 自己维护 checked 更难出现"两个同时选中"。
///
/// 约束：tabs 是字符串数组，顺序即索引；currentIndex 越界时没有标签选中，
/// 但不会崩（绑定方自行保证范围）。字号固定 13，与页面正文一致。
Item {
    id: bar

    /// 标签文字数组，例如 ["常规", "外观", "高级"]。
    property var tabs: []
    /// 当前选中索引。
    property int currentIndex: 0
    /// 标签字号。
    property int fontSize: 13
    /// 强调色（下划线）。
    property color accentColor: "#4c9aff"
    /// 未选中文字色。
    property color textColor: "#9aa0a6"
    /// 选中文字色。
    property color selectedTextColor: "#e6e6e6"
    /// 悬停底色。
    property color hoverColor: "#2a2a2a"

    signal tabActivated(int index)

    implicitWidth: tabRow.implicitWidth
    implicitHeight: 40

    Row {
        id: tabRow
        height: parent.height

        Repeater {
            model: bar.tabs

            delegate: Item {
                id: tab
                width: Math.max(88, tabLabel.implicitWidth + 28)
                height: bar.height

                Rectangle {
                    anchors.fill: parent
                    anchors.bottomMargin: 2
                    radius: 4
                    color: tabTouch.containsMouse && index !== bar.currentIndex ? bar.hoverColor : "transparent"
                }

                Label {
                    id: tabLabel
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: bar.fontSize
                    color: index === bar.currentIndex ? bar.selectedTextColor : bar.textColor

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: tabLabel.implicitWidth + 10
                    height: 2
                    radius: 1
                    color: bar.accentColor
                    visible: index === bar.currentIndex
                }

                MouseArea {
                    id: tabTouch
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        bar.currentIndex = index
                        bar.tabActivated(index)
                    }
                }
            }
        }
    }
}
