import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/// 图标按钮：图标字形 + 可选文字，带悬停/按下/选中/禁用/键盘焦点态。
///
/// 为什么继承 AbstractButton 而不是自绘 Item + MouseArea：clicked / checkable /
/// checked / enabled / 键盘空格回车 / 无障碍 role 全部直接复用，样式只替换
/// background 与 contentItem，行为一行都不用重写，也就不会漏掉某个状态。
///
/// 用法：
///     IconButton { iconName: "back"; toolTip: qsTr("后退")
///                  enabled: pane.canGoBack; onClicked: pane.goBack() }
///     IconButton { iconName: "hidden"; iconFilled: showHidden; checkable: true
///                  checked: showHidden; onToggled: showHidden = checked }
///     IconButton { iconName: "refresh"; text: qsTr("刷新"); size: 28; iconSize: 14 }
///
/// 尺寸：size 是按钮最小边长（默认 30，对齐现有工具栏 ToolButton 的视觉高度），
/// iconSize 是图标字号（默认 16）。带文字时宽度由内容撑开，高度恒为 size。
/// 颜色沿用现有暗色面板：主体文字 #e6e6e6、次要 #9aa0a6、强调 #4c9aff。
///
/// 约束：iconName 必须是 Icons.qml 表里的键；写错时图标区为空（不是豆腐块），
/// 因为 Icons.glyph() 对未登记名字返回空串。
AbstractButton {
    id: control

    /// 语义图标名，见 components/Icons.qml 的 map；空串表示只显示文字。
    property string iconName: ""
    /// 选中/激活时改用实心字形（上游 filled 版本），纯视觉差异，不改语义。
    property bool iconFilled: false
    /// 悬停提示；空串不弹提示。纯图标按钮的可读性主要靠它。
    property string toolTip: ""

    /// 按钮最小边长（像素）。
    property int size: 30
    /// 图标字号（像素）。
    property int iconSize: 16
    /// 文字字号（像素）。
    property int textSize: 12
    /// 图标与文字之间的间距。
    property int contentSpacing: 6
    /// 圆角。
    property int radius: 4

    readonly property color textColor: {
        if (!control.enabled) {
            return "#5a5f64"
        }
        if (control.checked) {
            return "#8ec0ff"
        }
        if (control.down) {
            return "#ffffff"
        }
        if (control.hovered) {
            return "#f2f3f4"
        }
        return "#d8dbde"
    }

    readonly property color hoverColor: "#2a2a2a"
    readonly property color pressedColor: "#343434"
    readonly property color checkedColor: "#2b3a4d"

    hoverEnabled: true
    leftPadding: control.text.length > 0 ? 10 : 6
    rightPadding: control.text.length > 0 ? 10 : 6
    topPadding: 0
    bottomPadding: 0

    implicitWidth: Math.max(control.size, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: control.size

    /// 屏幕阅读器在纯图标按钮上没有文字可读，退而用 toolTip。
    Accessible.name: control.text.length > 0 ? control.text : control.toolTip

    ToolTip.visible: control.hovered && control.toolTip.length > 0
    ToolTip.text: control.toolTip
    ToolTip.delay: 600

    Icons {
        id: icons
    }

    background: Rectangle {
        implicitWidth: control.size
        implicitHeight: control.size
        radius: control.radius
        color: {
            if (!control.enabled) {
                return control.checked ? "#242424" : "transparent"
            }
            if (control.down) {
                return control.pressedColor
            }
            if (control.checked) {
                return control.checkedColor
            }
            if (control.hovered) {
                return control.hoverColor
            }
            return "transparent"
        }
        border.width: control.visualFocus ? 1 : 0
        border.color: "#4c9aff"

        // 悬停进出微渐变：工具栏上几十个按钮同时硬切会显得闪烁。
        Behavior on color {
            ColorAnimation { duration: 90 }
        }
    }

    contentItem: RowLayout {
        spacing: control.contentSpacing

        Label {
            visible: control.iconName.length > 0
            Layout.alignment: Qt.AlignVCenter
            text: icons.glyph(control.iconName, control.iconFilled)
            font.family: icons.fontFamily
            font.pixelSize: control.iconSize
            color: control.textColor
        }

        Label {
            visible: control.text.length > 0
            Layout.alignment: Qt.AlignVCenter
            text: control.text
            font.pixelSize: control.textSize
            color: control.textColor
        }
    }
}
