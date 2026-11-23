# 设计说明：为什么这么写

这份文档记录每个「看起来可以更简单」的地方，以及为什么没有用更简单的写法。
每一条都是在 Windows 11（22631）上实测过的结论，不是照文档推的。

## 1. 为什么不用 WindowStyle=None + AllowsTransparency=True

这是 WPF 做无边框窗口最常见的写法，但会同时失去三样东西：

- **系统窗口动画**：最小化/最大化/还原的 DWM 过渡动画消失，窗口瞬间跳变；
- **Snap Layouts**：分层窗口拿不到 HTMAXBUTTON 的系统处理，悬停最大化键不弹快速布局面板；
- **部分合成路径**：透明窗口走分层渲染，字体与阴影表现会变差。

所以这里保留 WindowStyle=SingleBorderWindow，用 WindowChrome 把非客户区“画没”：

``` csharp
WindowChrome.SetWindowChrome(this, new WindowChrome
{
    CaptionHeight = 40,                       // 系统把这块当标题栏（拖动 / 双击最大化）
    ResizeBorderThickness = new Thickness(6), // 边缘拖拽热区
    GlassFrameThickness = new Thickness(0),
    CornerRadius = new CornerRadius(0),
    UseAeroCaptionButtons = false
});
```

WS_CAPTION / WS_THICKFRAME 必须留着 —— 那是 DWM 判断“这是个正常窗口”的依据。

## 2. 为什么最大化键要自己处理点击与 hover

一旦 WM_NCHITTEST 对某块区域返回 HTMAXBUTTON，Windows 就把它当成**非客户区**：
WPF 的鼠标事件（MouseEnter / Click / IsMouseOver）统统收不到。

于是：

- **点击**：在窗口过程里拦 WM_NCLBUTTONDOWN（wParam == HTMAXBUTTON）自己调 ToggleMaximize()，
  并吞掉随后的 WM_NCLBUTTONDBLCLK（否则双击会再触发一次，变成“最大化→还原”）；
- **悬停**：HTMAXBUTTON 区域没有 IsMouseOver，只能 60ms 定时查 GetCursorPos 是否落在按钮矩形内，
  命中后给按钮 Tag = "hover"，由模板触发器补上底色。

这就是 ChromeWindow 里那个 DispatcherTimer 存在的原因，不是偷懒。

## 3. 为什么要处理 WM_GETMINMAXINFO

WindowChrome 不改变窗口尺寸语义：默认最大化会铺满**整个显示器**，把任务栏盖住。
必须自己按工作区回填：

``` csharp
mmi.ptMaxPosition = 工作区左上角相对显示器左上角的偏移;
mmi.ptMaxSize     = 工作区宽高;
```

MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST) + GetMonitorInfo 拿 rcWork，
这样多显示器、任务栏在任意边、DPI 混合缩放都正确。

## 4. 为什么 Themes/Generic.xaml 之外还要一行 ThemeInfo

ChromeWindow 用 DefaultStyleKeyProperty.OverrideMetadata(...) 指向自己，
WPF 会去程序集里找 themes/generic.xaml。**这个查找只在 ThemeInfo 声明了
ResourceDictionaryLocation.SourceAssembly 时才会发生。**

漏了这行的表现非常迷惑：窗口能创建、标题也对，**但内容区完全空白**（没有模板 → 没有 ContentPresenter），
UIA 也查不到任何子元素。加上即可：

``` csharp
[assembly: ThemeInfo(ResourceDictionaryLocation.None, ResourceDictionaryLocation.SourceAssembly)]
```

## 5. 为什么图标既写 ApplicationIcon 又写 Resource

- ApplicationIcon 只决定 **exe 文件在资源管理器里**的图标；
- Window.Icon="pack://application:,,,/assets/app.ico" 需要该文件是**程序集资源**。

SDK 风格工程不会自动把 .ico 收成 Resource，必须显式声明，否则启动即
IOException: 找不到资源 assets/app.ico。

``` xml
<ItemGroup>
  <Resource Include="assets\app.ico" />
</ItemGroup>
```

## 6. 其他小结论

- **标题栏高度必须和 CaptionHeight 一致**：不一致时拖动热区和视觉错位，表现为“标题栏有一截拖不动”。
- **标题栏里的按钮必须 WindowChrome.IsHitTestVisibleInChrome="True"**：否则点击被当成拖动窗口。
- **最大化时把 1px 边框去掉**：否则工作区高度被吃掉 2px，内容贴边出现细缝。
- **深色标题栏属性（19/20/35/36/34）在自绘标题栏下看不见**，但会影响系统菜单、任务栏预览与窗口边框，仍然值得设。
- **最小化/最大化/还原不要自己写动画**：SystemCommands 走的是 WM_SYSCOMMAND，DWM 的动画和“贴边分屏后拖动还原”等系统行为才能正常工作。
