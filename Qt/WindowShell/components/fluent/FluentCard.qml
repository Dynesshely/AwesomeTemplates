import QtQuick
import QtQuick.Layouts

/// Fluent 卡片：圆角 + 1px 描边 + 统一内边距，默认属性直接就是内容列。
///
/// 为什么默认属性 alias 到内部 ColumnLayout：调用方写
///     FluentCard { Label {...}; FluentButton {...} }
/// 就能按列排布，不需要再包一层 ColumnLayout，也不用记住 contentItem 这个约定名。
///
/// 为什么 implicitHeight 由内容列算出来：卡片放在 ColumnLayout/Flickable 里时，
/// 高度必须随内容（尤其是换行文字）自己长，调用方不该手写 preferredHeight。
///
/// 约束：背景 Rectangle 必须先于内容列声明，否则会盖在内容上；内容列用 anchors
/// 填满减去 padding 的区域，所以子项不要再手动设置 x/y。
Item {
    id: card

    /// 圆角。
    property int radius: 8
    /// 卡片底色；展示页统一传 surfaceColor。
    property color color: "#232323"
    /// 描边颜色。
    property color borderColor: "#3a3a3a"
    /// 描边宽度。
    property int borderWidth: 1
    /// 四周内边距。
    property int padding: 20
    /// 内容列间距。
    property alias spacing: cardColumn.spacing

    /// 默认属性：所有裸写进来的子项都进内容列。
    default property alias content: cardColumn.data

    implicitWidth: cardColumn.implicitWidth + padding * 2
    implicitHeight: cardColumn.implicitHeight + padding * 2

    Rectangle {
        anchors.fill: parent
        radius: card.radius
        color: card.color
        border.width: card.borderWidth
        border.color: card.borderColor
    }

    ColumnLayout {
        id: cardColumn
        anchors.fill: parent
        anchors.margins: card.padding
        spacing: 16
    }
}
