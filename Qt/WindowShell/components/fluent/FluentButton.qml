import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import WindowShell

/// Fluent 按钮：同一套几何与状态机承载 accent / default / danger 三种语义。
///
/// 为什么用 kind 而不是拆成三个组件：三者的差别只有配色，拆开会让
/// hover / pressed / disabled / focus / 图标排版被复制三遍，改一处颜色要改三处。
///
/// 为什么继承 AbstractButton：clicked / down / hovered / enabled / 键盘回车空格 /
/// 无障碍 role 全部现成，这里只替换 background 与 contentItem。
///
/// 尺寸：高 32、圆角 4、水平内边距 14，对齐 Fluent 常规按钮的视觉高度。
/// 配色：accent #4c9aff、danger #e06c75、default 用 #2a2a2a 面板色 + #3a3a3a 描边。
/// accent / danger 上的文字刻意用深色 #0b1b2a：这两个填充色都很亮，
/// 白字对比度只有 3:1 左右，深字约 6:1，暗色主题下反而更清楚。
///
/// 约束：kind 只认 accent / default / danger，拼错按 default 渲染（不抛错）；
/// iconName 必须是 Icons.qml 表里登记过的名字，未登记时图标区留空而不是豆腐块。
AbstractButton {
    id: control

    /// 按钮语义：accent 主操作、default 次操作、danger 破坏性操作。
    property string kind: "default"
    /// 可选图标名，见 components/Icons.qml；空串表示纯文字按钮。
    property string iconName: ""
    /// 选中/激活时改用实心字形，纯视觉差异。
    property bool iconFilled: false
    /// 悬停提示；空串不弹。
    property string toolTip: ""
    /// 圆角。
    property int radius: 4
    /// 文字字号。
    property int fontSize: 13
    /// 图标字号。
    property int iconSize: 16
    /// 图标与文字间距。
    property int contentSpacing: 8
    /// 水平内边距（不能叫 horizontalPadding：那是 Control 的 FINAL 属性）。
    property int sidePadding: 14

    readonly property bool accentKind: kind === "accent"
    readonly property bool dangerKind: kind === "danger"

    /// 底色按语义 × 状态展开。禁用态单独压暗，避免用 opacity 把描边一起淡掉。
    readonly property color baseColor: {
        if (!control.enabled) {
            return control.accentKind ? "#2b3949" : (control.dangerKind ? "#3a2a2c" : "#242424")
        }
        if (control.accentKind) {
            return control.down ? "#3d87e0" : (control.hovered ? "#63a8ff" : "#4c9aff")
        }
        if (control.dangerKind) {
            return control.down ? "#c65a64" : (control.hovered ? "#ea7f87" : "#e06c75")
        }
        return control.down ? "#242424" : (control.hovered ? "#333333" : "#2a2a2a")
    }

    readonly property color lineColor: {
        if (!control.enabled) {
            return control.accentKind || control.dangerKind ? "transparent" : "#2e2e2e"
        }
        if (control.accentKind || control.dangerKind) {
            return "transparent"
        }
        return control.hovered ? "#4a4a4a" : "#3a3a3a"
    }

    readonly property color labelColor: {
        if (!control.enabled) {
            return "#5a5f64"
        }
        if (control.accentKind || control.dangerKind) {
            return "#0b1b2a"
        }
        return "#e6e6e6"
    }

    hoverEnabled: true
    leftPadding: control.sidePadding
    rightPadding: control.sidePadding
    topPadding: 0
    bottomPadding: 0
    implicitWidth: contentArea.implicitWidth + leftPadding + rightPadding
    implicitHeight: 32

    Accessible.name: control.text.length > 0 ? control.text : control.toolTip

    ToolTip.visible: control.hovered && control.toolTip.length > 0
    ToolTip.text: control.toolTip
    ToolTip.delay: 600

    Icons {
        id: icons
    }

    background: Rectangle {
        radius: control.radius
        color: control.baseColor
        border.width: control.visualFocus ? 2 : (control.accentKind || control.dangerKind ? 0 : 1)
        border.color: control.visualFocus ? "#8ec0ff" : control.lineColor

        Behavior on color {
            ColorAnimation { duration: 90 }
        }
        Behavior on border.color {
            ColorAnimation { duration: 90 }
        }
    }

    contentItem: Item {
        id: contentArea
        implicitWidth: contentRow.implicitWidth
        implicitHeight: contentRow.implicitHeight

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: control.iconName.length > 0 ? control.contentSpacing : 0

            Label {
                visible: control.iconName.length > 0
                text: icons.glyph(control.iconName, control.iconFilled)
                font.family: icons.fontFamily
                font.pixelSize: control.iconSize
                color: control.labelColor
            }

            Label {
                text: control.text
                font.pixelSize: control.fontSize
                color: control.labelColor
            }
        }
    }
}
