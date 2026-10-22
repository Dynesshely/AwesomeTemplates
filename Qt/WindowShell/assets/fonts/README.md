# Fluent System Icons（Bosun 内置图标字体）

Bosun 的图标全部来自微软官方的 [Fluent System Icons](https://github.com/microsoft/fluentui-system-icons)，
许可证 MIT，与项目使用的 FluentWinUI3 控件风格同源。

| 文件 | 作用 | 大小 |
| --- | --- | --- |
| `FluentSystemIcons-Resizable.ttf` | 运行时字体，由 `components/Icons.qml` 的 `FontLoader` 加载 | 1,585,940 B |
| `FluentSystemIcons-Resizable.json` | 上游的名字 → 码位映射（构建不读它，只用来查表与升级） | 276,234 B |
| `LICENSE-FluentSystemIcons.txt` | 上游 MIT 许可证原文（分发时必须随字体一起带上） | 1,078 B |

- 上游仓库：<https://github.com/microsoft/fluentui-system-icons>
- 下载来源：`fonts/FluentSystemIcons-Resizable.ttf`、`fonts/FluentSystemIcons-Resizable.json`、`LICENSE`
- 快照：`main` @ `83b26348c811f072429427ff48362238656524fe`（2026-10-19），下载于 2026-10-21
- 字体族名：`FluentSystemIcons-Resizable`（TTF `name` 表 nameID 1；代码里不硬编码，取自 `FontLoader.name`）
- 码位数：JSON 5706 条与 TTF `cmap` 完全一致（脚本逐条比对过，0 缺失）

## 为什么是 Resizable 而不是按字号分档

上游同时提供 `FluentSystemIcons-Regular.ttf`（内含 20/24/32px 三档字形，同一图标在不同字号
档位是**不同码位**）与 `FluentSystemIcons-Resizable.ttf`（一套字形按字号缩放，JSON 里只有
`_20_regular` / `_20_filled` 两档名字）。Bosun 只用一种字号档位（16px 图标 + 少量 12/20px），
用 Resizable 版可以让码位表与字号解耦：改图标大小不需要改映射。

## 升级字体

1. 覆盖上述三个文件（许可证也要一起更新）。
2. 打开 JSON 核对 `components/Icons.qml` 里的码位是否仍然对应得上（上游偶尔会重排码位）。
3. 跑 `build/agent-icon/qrc-check` 那套临时验证工程（见 `docs/notes-iconfont.md` 的「自验证」一节），
   看截图里字形有没有变成豆腐块。
