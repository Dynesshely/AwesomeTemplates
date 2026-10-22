<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0ea5e9,100:7c3aed&height=200&section=header&text=AwesomeTemplates&fontSize=52&fontColor=ffffff&animation=fadeIn&fontAlignY=36&desc=UI%20templates%20that%20just%20work&descAlignY=58&descSize=18" width="100%" alt="AwesomeTemplates" />

**每个模板都是一个能跑起来的完整工程，而不是代码片段。**

![Qt](https://img.shields.io/badge/Qt-6.8-41CD52?style=for-the-badge&logo=qt&logoColor=white)
![C++](https://img.shields.io/badge/C%2B%2B-20-00599C?style=for-the-badge&logo=cplusplus&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-11-0078D4?style=for-the-badge&logo=windows11&logoColor=white)
![CMake](https://img.shields.io/badge/CMake-3.24%2B-064F8C?style=for-the-badge&logo=cmake&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-3DA639?style=for-the-badge)
![PRs](https://img.shields.io/badge/PRs-welcome-7c3aed?style=for-the-badge)

</div>

## 模板

| 模板 | 说明 | 预览 |
|---|---|---|
| **[Qt / WindowShell](Qt/WindowShell)** | Qt 6 的 Windows Fluent 窗口壳：自绘标题栏、Snap Layouts、Mica、原生最小化/最大化动画，外加 10 个自绘 Fluent 控件 | <img src="Qt/WindowShell/docs/screenshot.png" width="420" /> |

## 为什么值得用

- **独立可构建**：每个模板自带 `CMakeLists.txt` 与 preset，设好 `QT_ROOT` 就能编译运行，不依赖本仓库其他部分。
- **取舍有据**：窗口壳里每个非常规写法（为什么留 `WS_CAPTION`、为什么去掉 `WS_SYSMENU`、为什么 `WM_NCCALCSIZE` 不能用 `GetWindowRect`）都在 `docs/design-notes.md` 里写了实测结论。
- **不糊弄细节**：Windows 原生行为按真实抓屏和窗口消息验证过，而不是照文档推。

## 快速开始

```powershell
git clone https://github.com/Dynesshely/AwesomeTemplates.git
cd AwesomeTemplates/Qt/WindowShell

$env:QT_ROOT = "C:/Qt/6.8.3/mingw_64"   # 你的 Qt 安装路径
cmake --preset debug
cmake --build --preset debug
.\build\debug\bin\WindowShell.exe
```

依赖：Qt 6.8+、CMake 3.24+、Ninja、C++20 编译器（MinGW / MSVC 均可）。

## 目录约定

```
Qt/<模板名>/
├── CMakeLists.txt / CMakePresets.json   独立构建，GLOB 自动收编源码与 QML
├── src/                                  C++ 侧（Win32 / DWM 交互）
├── <模板 QML 目录>/                      界面
├── assets/                               字体、图标
├── docs/                                 设计与踩坑说明
└── README.md                             该模板的用法
```

## Star History

<a href="https://star-history.com/#Dynesshely/AwesomeTemplates&Date">
  <img src="https://api.star-history.com/svg?repos=Dynesshely/AwesomeTemplates&type=Date" width="600" alt="Star History" />
</a>

## License

[MIT](LICENSE) © 2026 Dynesshely
