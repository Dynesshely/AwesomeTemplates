import QtQuick

/// 图标字体的唯一入口：把字体注册进 Qt，并把语义名字翻译成码位。
///
/// 为什么不做成 QML singleton：Qt 的 singleton 必须在模块的 qmldir 里声明，而
/// Bosun 的 qmldir 由 CMakeLists.txt 的 QML_FILES 自动生成，新增 singleton 就得
/// 连带改构建脚本；普通组件谁用谁实例化，代价只有一个空 QObject。FontLoader 按
/// source URL 全局去重，所以每个 IconButton 各带一个 Icons 实例不会重复解析字体。
///
/// 用法（不需要按钮、只想在任意 Label 里放个图标时）：
///     Icons { id: icons }
///     Label {
///         text: icons.glyph("refresh")
///         font.family: icons.fontFamily
///         font.pixelSize: 16
///     }
///
/// 约束：FontLoader.source 相对本文件解析，所以本文件必须留在 QML 目录的
/// components/ 下、字体必须留在 assets/fonts/ 下。进 Qt 资源后两者的相对关系
/// 不变，同一份相对路径在源码树和 qrc 里都成立。
QtObject {
    id: icons

    /// QtObject 没有默认属性，FontLoader 不能像视觉子项那样裸写在大括号里，
    /// 只能作为属性初始化。对外只暴露读接口，字体实例本身是私有细节。
    property FontLoader fontLoader: FontLoader {
        id: loader
        source: "../assets/fonts/FluentSystemIcons-Resizable.ttf"
    }

    /// 字体族名取自 FontLoader 而不硬编码：上游改字体族名时这里不用跟着改。
    readonly property string fontFamily: loader.name
    /// 字体是否已注册。false 时 glyph() 仍返回字符，只是会落到回退字体上（豆腐块）。
    readonly property bool ready: loader.status === FontLoader.Ready

    /// 语义名 → [regular, filled] 码位。
    ///
    /// 码位来自 assets/fonts/FluentSystemIcons-Resizable.json 里的
    /// ic_fluent_<上游名>_20_regular / _20_filled。这里把两个值都显式写出来而不是
    /// 用「filled = regular - 1」去算：上游当前恰好相邻，但没有这个约定。
    /// 名字用连字符而不是下划线，是为了让 "new-folder" 这种语义名读起来和图标本体
    /// 分开，别和上游 ic_fluent_* 混淆。
    readonly property var map: ({
        "back":          [0xE115, 0xE114],
        "forward":       [0xE141, 0xE140],
        "up":            [0xE1A7, 0xE1A6],
        "refresh":       [0xE0BF, 0xE0BE],
        "new-folder":    [0xE8ED, 0xE8EC],
        "hidden":        [0xE889, 0xE888],
        "visible":       [0xE883, 0xE882],
        "view-list":     [0xF30C, 0xF30B],
        "view-grid":     [0xE9C1, 0xE9C0],
        "search":        [0xEFD7, 0xEFD6],
        "settings":      [0xF00F, 0xF00E],
        "add":           [0xE00D, 0xE00C],
        "dismiss":       [0xE6D3, 0xE6D2],
        "filter":        [0xE8A7, 0xE8A6],
        "more":          [0xEC74, 0xEC73],
        "chevron-down":  [0xE488, 0xE487],
        "chevron-up":    [0xE490, 0xE48F],
        "chevron-right": [0xE48E, 0xE48D],
        "sort":          [0xE14F, 0xE14E],
        "folder":        [0xE8EB, 0xE8EA],
        "document":      [0xE6E9, 0xE6E8],
        "sync":          [0xE171, 0xE170],
        "apps":          [0xE07D, 0xE07C],
        // 自绘标题栏的窗口控制：Fluent 上游名分别是 subtract / square /
        // square_multiple / dismiss 的 _20_ 版本，这里是它们 20px 的 regular 与 filled 码位。
        "minimize":      [0xF1A3, 0xF1A2],
        "maximize":      [0xF133, 0xF132],
        "restore":       [0xF149, 0xF148],
        "close":         [0xE6D3, 0xE6D2]
    })

    /// 表里是否登记了该名字。
    function has(name) {
        return Object.prototype.hasOwnProperty.call(icons.map, name)
    }

    /// 码位；未登记的名字返回 0（调用方据此判断拼错，而不是静默显示豆腐块）。
    function codepoint(name, filled) {
        const entry = icons.map[name]
        if (entry === undefined) {
            return 0
        }
        return filled ? entry[1] : entry[0]
    }

    /// 直接可放进 Label.text 的字符；未登记的名字返回空串。
    function glyph(name, filled) {
        const cp = icons.codepoint(name, filled)
        return cp === 0 ? "" : String.fromCodePoint(cp)
    }

    /// 已登记的语义名（顺序与上表一致），docs 与验证页用。
    readonly property var names: Object.keys(icons.map)
}
