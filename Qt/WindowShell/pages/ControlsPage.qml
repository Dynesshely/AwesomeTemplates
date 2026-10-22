import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import WindowShell

/// Fluent 控件展示页：每个控件一组，组本身用 FluentCard（默认属性即内容列），
/// 让"分组标题 + 说明 + 可交互示例"的结构在源码里就能读出来。
///
/// 为什么用 Flickable + ColumnLayout 而不是 ListView：页面是静态的十来组控件，
/// 没有复用需求；ColumnLayout 让每组的隐式高度自然撑开，改一个示例不用同步 model。
///
/// 为什么所有卡片都传 surfaceColor：页面要能贴在任何面板色上（Main.qml 的
/// surfaceColor 在 Mica 下是半透明的），卡片和背景同色、靠 1px 描边分层，
/// 这样不会出现"卡片比窗口更暗"的割裂感。
///
/// 为什么示例状态放在页面根上：控件之间没有依赖，状态集中在这里，
/// 交互结果用旁边的 Label 回显，一眼能看出事件确实进了控件。
///
/// 约束：只依赖 QtQuick / Controls / Layouts 与 components/ 下已注册的类型；
/// 新增控件请先在 components/fluent/ 下建独立 .qml，再回来加一组。
Flickable {
    id: page

    /// 卡片底色；由页面统一声明，方便将来跟随窗口壳的 Mica 面板色替换。
    property color surfaceColor: "#1b1b1b"

    // 交互回显用的页面状态（只服务展示，不承载业务）。
    property int clickCount: 0
    property bool notificationsOn: true
    property bool autoUpdate: false
    property bool gridOn: true
    property real volumeValue: 60
    property bool progressIndeterminate: false
    property string fieldText: ""
    property int tabIndex: 0

    contentWidth: width
    contentHeight: body.implicitHeight + 48
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    ColumnLayout {
        id: body

        // 居中并限制最大宽度：卡片铺满 1280 时文字行太长，读起来会累。
        width: Math.max(0, Math.min(page.width - 48, 960))
        x: (page.width - width) / 2
        anchors.top: parent.top
        anchors.topMargin: 24
        spacing: 16

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

        // ── FluentButton ──────────────────────────────────────────────
        FluentCard {
            Layout.fillWidth: true
            color: page.surfaceColor
            spacing: 16

            Label {
                text: qsTr("按钮")
                font.pixelSize: 13
                color: "#e6e6e6"
            }
            Label {
                Layout.fillWidth: true
                text: qsTr("FluentButton：kind = accent / default / danger，圆角 4，"
                           + "带悬停、按下、禁用与键盘焦点态；可选 iconName 复用 Icons 字形。")
                font.pixelSize: 11
                color: "#9aa0a6"
                wrapMode: Text.WordWrap
            }
            RowLayout {
                spacing: 12

                FluentButton {
                    kind: "accent"
                    text: qsTr("确定")
                    onClicked: page.clickCount += 1
                }
                FluentButton {
                    text: qsTr("取消")
                    onClicked: page.clickCount += 1
                }
                FluentButton {
                    kind: "danger"
                    text: qsTr("删除")
                    onClicked: page.clickCount += 1
                }
                FluentButton {
                    text: qsTr("刷新")
                    iconName: "refresh"
                    toolTip: qsTr("刷新列表")
                    onClicked: page.clickCount += 1
                }
                FluentButton {
                    text: qsTr("禁用")
                    enabled: false
                }
            }
            Label {
                text: qsTr("已点击 %1 次").arg(page.clickCount)
                font.pixelSize: 11
                color: "#5a5f64"
            }
        }

        // ── ToggleSwitch ──────────────────────────────────────────────
        FluentCard {
            Layout.fillWidth: true
            color: page.surfaceColor
            spacing: 16

            Label {
                text: qsTr("开关")
                font.pixelSize: 13
                color: "#e6e6e6"
            }
            Label {
                Layout.fillWidth: true
                text: qsTr("ToggleSwitch：40×20 胶囊 + 圆形滑块，切换动画 120ms；"
                           + "悬停滑块放大、按下回落。")
                font.pixelSize: 11
                color: "#9aa0a6"
                wrapMode: Text.WordWrap
            }
            RowLayout {
                spacing: 32

                RowLayout {
                    spacing: 10
                    Label {
                        text: qsTr("通知")
                        font.pixelSize: 13
                        color: "#e6e6e6"
                        Layout.alignment: Qt.AlignVCenter
                    }
                    ToggleSwitch {
                        checked: page.notificationsOn
                        accessibleLabel: qsTr("通知")
                        Layout.alignment: Qt.AlignVCenter
                        onToggled: page.notificationsOn = checked
                    }
                }

                RowLayout {
                    spacing: 10
                    Label {
                        text: qsTr("自动更新")
                        font.pixelSize: 13
                        color: "#e6e6e6"
                        Layout.alignment: Qt.AlignVCenter
                    }
                    ToggleSwitch {
                        checked: page.autoUpdate
                        accessibleLabel: qsTr("自动更新")
                        Layout.alignment: Qt.AlignVCenter
                        onToggled: page.autoUpdate = checked
                    }
                }

                Label {
                    text: qsTr("通知：%1").arg(page.notificationsOn ? qsTr("开") : qsTr("关"))
                    font.pixelSize: 11
                    color: "#9aa0a6"
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        // ── FluentCheckBox ────────────────────────────────────────────
        FluentCard {
            Layout.fillWidth: true
            color: page.surfaceColor
            spacing: 16

            Label {
                text: qsTr("复选框")
                font.pixelSize: 13
                color: "#e6e6e6"
            }
            Label {
                Layout.fillWidth: true
                text: qsTr("FluentCheckBox：18×18 方框 + 勾；tristate 打开时点击按"
                           + "未选 → 部分 → 全选循环，部分选中画一条横线。")
                font.pixelSize: 11
                color: "#9aa0a6"
                wrapMode: Text.WordWrap
            }
            RowLayout {
                spacing: 24

                FluentCheckBox {
                    text: qsTr("自动保存")
                    checked: true
                    Layout.alignment: Qt.AlignVCenter
                }
                FluentCheckBox {
                    text: qsTr("显示网格")
                    checked: page.gridOn
                    Layout.alignment: Qt.AlignVCenter
                    onToggled: page.gridOn = checked
                }
                FluentCheckBox {
                    text: qsTr("部分选中（三态）")
                    tristate: true
                    checkState: Qt.PartiallyChecked
                    Layout.alignment: Qt.AlignVCenter
                }
                FluentCheckBox {
                    text: qsTr("禁用")
                    checked: true
                    enabled: false
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        // ── FluentSlider ──────────────────────────────────────────────
        FluentCard {
            Layout.fillWidth: true
            color: page.surfaceColor
            spacing: 16

            Label {
                text: qsTr("滑块")
                font.pixelSize: 13
                color: "#e6e6e6"
            }
            Label {
                Layout.fillWidth: true
                text: qsTr("FluentSlider：4px 轨道 + accent 填充 + 圆形手柄，"
                           + "悬停时手柄 14→18；拖动、方向键、Home/End 都由 Slider 基类提供。")
                font.pixelSize: 11
                color: "#9aa0a6"
                wrapMode: Text.WordWrap
            }
            RowLayout {
                spacing: 16

                FluentSlider {
                    id: volumeSlider
                    Layout.preferredWidth: 320
                    Layout.alignment: Qt.AlignVCenter
                    from: 0
                    to: 100
                    stepSize: 1
                    value: page.volumeValue
                    onMoved: page.volumeValue = value
                }
                Label {
                    text: Math.round(page.volumeValue) + " %"
                    font.pixelSize: 13
                    color: "#9aa0a6"
                    Layout.preferredWidth: 56
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        // ── FluentProgressBar ─────────────────────────────────────────
        FluentCard {
            Layout.fillWidth: true
            color: page.surfaceColor
            spacing: 16

            Label {
                text: qsTr("进度条")
                font.pixelSize: 13
                color: "#e6e6e6"
            }
            Label {
                Layout.fillWidth: true
                text: qsTr("FluentProgressBar：determinate 按 value/position 推进；"
                           + "indeterminate 时一段 35% 宽的色块循环扫过轨道。")
                font.pixelSize: 11
                color: "#9aa0a6"
                wrapMode: Text.WordWrap
            }
            RowLayout {
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    FluentProgressBar {
                        Layout.fillWidth: true
                        value: 0.35
                    }
                    FluentProgressBar {
                        Layout.fillWidth: true
                        indeterminate: page.progressIndeterminate
                    }
                }

                RowLayout {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    Label {
                        text: qsTr("不确定态")
                        font.pixelSize: 13
                        color: "#e6e6e6"
                        Layout.alignment: Qt.AlignVCenter
                    }
                    ToggleSwitch {
                        checked: page.progressIndeterminate
                        accessibleLabel: qsTr("不确定态")
                        Layout.alignment: Qt.AlignVCenter
                        onToggled: page.progressIndeterminate = checked
                    }
                }
            }
        }

        // ── FluentTextField ───────────────────────────────────────────
        FluentCard {
            Layout.fillWidth: true
            color: page.surfaceColor
            spacing: 16

            Label {
                text: qsTr("输入框")
                font.pixelSize: 13
                color: "#e6e6e6"
            }
            Label {
                Layout.fillWidth: true
                text: qsTr("FluentTextField：4px 圆角、#1f1f1f 底、1px 描边；"
                           + "获得焦点时底部亮起 2px accent 强调线。")
                font.pixelSize: 11
                color: "#9aa0a6"
                wrapMode: Text.WordWrap
            }
            RowLayout {
                spacing: 16

                FluentTextField {
                    Layout.preferredWidth: 280
                    Layout.alignment: Qt.AlignVCenter
                    placeholderText: qsTr("输入内容…")
                    onTextChanged: page.fieldText = text
                }
                FluentTextField {
                    Layout.preferredWidth: 200
                    Layout.alignment: Qt.AlignVCenter
                    placeholderText: qsTr("密码")
                    echoMode: TextInput.Password
                }
                FluentTextField {
                    Layout.preferredWidth: 200
                    Layout.alignment: Qt.AlignVCenter
                    text: qsTr("只读内容")
                    readOnly: true
                    enabled: false
                }
            }
            Label {
                text: qsTr("实时回显：%1").arg(page.fieldText.length > 0 ? page.fieldText : qsTr("（空）"))
                font.pixelSize: 11
                color: "#5a5f64"
            }
        }

        // ── FluentComboBox ────────────────────────────────────────────
        FluentCard {
            Layout.fillWidth: true
            color: page.surfaceColor
            spacing: 16

            Label {
                text: qsTr("下拉框")
                font.pixelSize: 13
                color: "#e6e6e6"
            }
            Label {
                Layout.fillWidth: true
                text: qsTr("FluentComboBox：圆角输入面 + chevron（展开时旋转 180°）+"
                           + " 6px 圆角弹层；支持字符串数组或带 textRole 的模型。")
                font.pixelSize: 11
                color: "#9aa0a6"
                wrapMode: Text.WordWrap
            }
            RowLayout {
                spacing: 16

                FluentComboBox {
                    id: themeCombo
                    Layout.preferredWidth: 220
                    Layout.alignment: Qt.AlignVCenter
                    model: [qsTr("跟随系统"), qsTr("浅色"), qsTr("深色")]
                    currentIndex: 0
                }
                Label {
                    text: qsTr("当前选择：%1").arg(themeCombo.currentText)
                    font.pixelSize: 13
                    color: "#9aa0a6"
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        // ── InfoBar ───────────────────────────────────────────────────
        FluentCard {
            Layout.fillWidth: true
            color: page.surfaceColor
            spacing: 16

            Label {
                text: qsTr("信息条")
                font.pixelSize: 13
                color: "#e6e6e6"
            }
            Label {
                Layout.fillWidth: true
                text: qsTr("InfoBar：severity = info / success / warning / error，"
                           + "左侧带色徽标 + 标题 + 正文 + 关闭按钮；关闭后把 open 设回 true 即可恢复。")
                font.pixelSize: 11
                color: "#9aa0a6"
                wrapMode: Text.WordWrap
            }
            InfoBar {
                id: infoBarInfo
                Layout.fillWidth: true
                severity: "info"
                title: qsTr("信息")
                text: qsTr("这是一条普通提示，用于说明当前操作的结果。")
            }
            InfoBar {
                id: infoBarSuccess
                Layout.fillWidth: true
                severity: "success"
                title: qsTr("成功")
                text: qsTr("设置已保存，新的外观会在下一次启动时生效。")
            }
            InfoBar {
                id: infoBarWarning
                Layout.fillWidth: true
                severity: "warning"
                title: qsTr("警告")
                text: qsTr("部分文件被其他程序占用，修改可能不会立即同步。")
            }
            InfoBar {
                id: infoBarError
                Layout.fillWidth: true
                severity: "error"
                title: qsTr("错误")
                text: qsTr("无法写入目标目录，请检查权限后重试。")
            }
            RowLayout {
                spacing: 12

                FluentButton {
                    text: qsTr("重新显示全部提示条")
                    onClicked: {
                        infoBarInfo.open = true
                        infoBarSuccess.open = true
                        infoBarWarning.open = true
                        infoBarError.open = true
                    }
                }
                Label {
                    text: qsTr("点右侧 × 关闭单条提示")
                    font.pixelSize: 11
                    color: "#5a5f64"
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        // ── FluentCard ────────────────────────────────────────────────
        FluentCard {
            Layout.fillWidth: true
            color: page.surfaceColor
            spacing: 16

            Label {
                text: qsTr("卡片")
                font.pixelSize: 13
                color: "#e6e6e6"
            }
            Label {
                Layout.fillWidth: true
                text: qsTr("FluentCard：圆角 8、1px 描边、默认属性 alias 到内部 ColumnLayout；"
                           + "直接写子项即可，标题/说明/示例本身就是卡片的默认内容。")
                font.pixelSize: 11
                color: "#9aa0a6"
                wrapMode: Text.WordWrap
            }
            FluentCard {
                Layout.fillWidth: true
                color: page.surfaceColor
                borderColor: "#4a4a4a"
                spacing: 8

                Label {
                    text: qsTr("嵌套卡片")
                    font.pixelSize: 13
                    color: "#e6e6e6"
                }
                Label {
                    Layout.fillWidth: true
                    text: qsTr("这一段是直接写进 FluentCard 的内容：没有外层 ColumnLayout，"
                               + "内边距与间距由卡片自己提供。")
                    font.pixelSize: 11
                    color: "#9aa0a6"
                    wrapMode: Text.WordWrap
                }
            }
        }

        // ── FluentTabBar ──────────────────────────────────────────────
        FluentCard {
            Layout.fillWidth: true
            color: page.surfaceColor
            spacing: 16

            Label {
                text: qsTr("标签条")
                font.pixelSize: 13
                color: "#e6e6e6"
            }
            Label {
                Layout.fillWidth: true
                text: qsTr("FluentTabBar：横向标签，选中项下方 2px accent 下划线；"
                           + "点击切换只看当前索引，不绑定页面栈。")
                font.pixelSize: 11
                color: "#9aa0a6"
                wrapMode: Text.WordWrap
            }
            FluentTabBar {
                id: tabBarDemo
                Layout.fillWidth: true
                tabs: [qsTr("常规"), qsTr("外观"), qsTr("高级")]
                currentIndex: page.tabIndex
                onTabActivated: function (index) { page.tabIndex = index }
            }
            Label {
                text: qsTr("当前标签：%1").arg(tabBarDemo.tabs[tabBarDemo.currentIndex])
                font.pixelSize: 11
                color: "#5a5f64"
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
        }
    }
}
