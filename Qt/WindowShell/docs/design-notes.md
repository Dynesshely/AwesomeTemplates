# 设计说明：这套窗口壳为什么长这样

> 这里的每条结论都是实测出来的，不是按文档推的。想改壳的人先读一遍，能省掉大部分返工。

## 1. 为什么必须 frameless

Windows 上要让客户区盖住标题栏区域（自绘标题栏、Mica 透到客户区），只能：

- 窗口加 `Qt.FramelessWindowHint`（Qt 才会建成 `WS_EX_LAYERED` 分层窗口，客户区才可能透明）；
- 再用 `WM_NCCALCSIZE` 把客户区扩回整窗。

**必须同时保留 `Qt.Window`**：只写 `FramelessWindowHint` 会把窗口变成工具窗口——
任务栏没有按钮、也抢不回前台，用户会以为程序没启动。

## 2. WM_NCCALCSIZE 里不要用 GetWindowRect

`wParam == TRUE` 时 `rgrc[0]` 已经是系统算好的**新**窗口矩形，直接 `return 0` 保留它即可。
如果这里用 `GetWindowRect()` 再覆盖一遍，交互 resize 时拿到的是**旧**尺寸：
Qt 按旧尺寸渲染、DWM 按新尺寸合成，屏幕上会出现整片竖条纹。

最大化时额外把 `rgrc[0]` 换成 `rcWork`，否则贴边的四边会露出 1~2px 桌面。

## 3. 样式位：一个位都不能随便拿

| 位 | 作用 | 去掉的后果 |
|---|---|---|
| `WS_THICKFRAME` | DWM 阴影 / 圆角 / 缩放边 | 没有阴影和圆角，窗口不能拖边缩放 |
| `WS_MAXIMIZEBOX` | Snap Layouts 悬停面板只对可最大化窗口弹出 | 悬停最大化按钮不弹布局面板 |
| `WS_MINIMIZEBOX` | 系统把它当成可最小化 | 最小化过渡退化 |
| `WS_CAPTION` | **系统窗口过渡动画的前提** | 最小化/最大化/还原全部瞬切 |
| `WS_SYSMENU` | DWM 画 caption 按钮字形 | 保留它 DWM 就会多画一套模糊字形 |

结论（实测）：`WS_CAPTION` 留着、`WS_SYSMENU` 去掉——动画在，重复按钮没了。

## 4. 三个窗口按钮：QML 只画，点击走原生

`WM_NCHITTEST` 在右上角返回 `HTMINBUTTON` / `HTMAXBUTTON` / `HTCLOSE`：

- 系统自己处理点击与 Snap Layouts 悬停面板；
- QML 的自绘三键只负责画字形和 hover，命中区与 C++ 的 46×48 矩形必须完全重合。

三个动作用 `WM_SYSCOMMAND`（`SC_MINIMIZE / SC_MAXIMIZE / SC_RESTORE / SC_CLOSE`）走系统命令，
而不是直接 `ShowWindow`——那才是「用户在点 caption 按钮」的那条路径。

## 5. Mica 与分层窗口

- `QQuickWindow::setDefaultAlphaBuffer(true)` 必须在**第一个 QQuickWindow 创建之前**调用；
- `DWMWA_SYSTEMBACKDROP_TYPE = DWMSBT_MAINWINDOW`（需要 Win11 22621+）；
- `DwmExtendFrameIntoClientArea(-1,-1,-1,-1)` 把整个客户区算作框架区；
- 窗口 `color` 设成 `transparent`，QML 里窗口背景层保持**完全透明**（它垫在所有面板下面，
  任何不透明都会被放大：90% 背景 + 80% 面板 ≈ 98%，backdrop 等于被盖死）。

## 6. 面板透明度按壁纸亮度自适应

`wallpaper_tone.cpp` 读 `SPI_GETDESKWALLPAPER` 的路径，缩到 16×16 取 Rec.601 平均亮度 L，
然后 `surfaceAlpha = 0.35 + 0.30 × L`（读不到壁纸时 0.50）：

- 亮壁纸：面板更实，深色文字压在透亮的模糊背景上才读得清；
- 暗壁纸：面板更透，Mica 的磨砂层次才透得出来。

只在启动时算一次：换壁纸要重启。换来的是一次加载、渲染路径零成本。

## 7. 关闭过渡只能自己演

`QWindow::close()` 直接销毁窗口，DWM 的关闭过渡来不及播（`SC_CLOSE` 也一样）。
所以 `onClosing` 先拒绝这次关闭、跑 130ms 的 `opacity` 动画（分层窗口上走
`SetLayeredWindowAttributes`，是整窗真淡出），结束后置标志位再二次 `close()`。

## 8. 其他踩过的坑

- **给 `ToolBar` 换 `background` 会让它塌高**：隐式高度来自样式的 background，换掉后必须
  显式写回 `implicitHeight`（标题栏 48 DIP，与 C++ 的 `kTitleBarHeightDip` 一致）。
- **标题栏 48 DIP 是硬约定**：C++ 的原生命中区和 QML 布局共用它，改一处要改两处。
- **不要用 QML 改窗口宽高来强制重绘**（宽 1px 再改回来那套）：在 `Component.onCompleted`
  期间改窗口几何会让进程直接退出。需要补帧时调用 `WindowChrome.requestRepaint()`。
- **抓屏验证时先确认窗口真的在前台**：`SetForegroundWindow` 会静默失败，`CopyFromScreen`
  抓到的可能是压在上面的别的窗口。判断用 `GetForegroundWindow() == hwnd`；
  置前用 `AttachThreadInput` + `BringWindowToTop` + `SetForegroundWindow`。
