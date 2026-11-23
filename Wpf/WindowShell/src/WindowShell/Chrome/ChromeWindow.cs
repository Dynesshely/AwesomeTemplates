using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Shell;
using System.Windows.Threading;

namespace WindowShell.Chrome
{
    /// <summary>
    /// 无边框窗口壳：自绘标题栏 + Win11 Snap Layouts + 系统原生最小化/最大化/还原动画。
    ///
    /// 三条硬性前提（少一条就会退化，详见 docs/design-notes.md）：
    ///  1. 保持 WindowStyle=SingleBorderWindow（保留 WS_CAPTION / WS_THICKFRAME），系统才播过渡动画；
    ///  2. 不要用 AllowsTransparency（会切到分层窗口，动画与 Snap 都会失效）；
    ///  3. 标题栏高度由 WindowChrome.CaptionHeight 决定，画的内容要和它对上。
    /// </summary>
    [TemplatePart(Name = PartMinButton, Type = typeof(Button))]
    [TemplatePart(Name = PartMaxButton, Type = typeof(Button))]
    [TemplatePart(Name = PartCloseButton, Type = typeof(Button))]
    [TemplatePart(Name = PartMaxGlyph, Type = typeof(TextBlock))]
    public class ChromeWindow : Window
    {
        public const string PartMinButton = "PART_MinButton";
        public const string PartMaxButton = "PART_MaxButton";
        public const string PartCloseButton = "PART_CloseButton";
        public const string PartMaxGlyph = "PART_MaxGlyph";

        // ---------- 可主题化的外观属性 ----------
        public static readonly DependencyProperty TitleBarHeightProperty =
            DependencyProperty.Register(nameof(TitleBarHeight), typeof(double), typeof(ChromeWindow),
                new FrameworkPropertyMetadata(40.0, FrameworkPropertyMetadataOptions.AffectsMeasure));

        public static readonly DependencyProperty TitleBarBackgroundProperty =
            DependencyProperty.Register(nameof(TitleBarBackground), typeof(Brush), typeof(ChromeWindow),
                new FrameworkPropertyMetadata(new SolidColorBrush(Color.FromArgb(0xB3, 0x0F, 0x12, 0x16))));

        public static readonly DependencyProperty TitleBarForegroundProperty =
            DependencyProperty.Register(nameof(TitleBarForeground), typeof(Brush), typeof(ChromeWindow),
                new FrameworkPropertyMetadata(new SolidColorBrush(Color.FromRgb(0xD7, 0xDD, 0xE3))));

        public static readonly DependencyProperty WindowBorderBrushProperty =
            DependencyProperty.Register(nameof(WindowBorderBrush), typeof(Brush), typeof(ChromeWindow),
                new FrameworkPropertyMetadata(new SolidColorBrush(Color.FromRgb(0x34, 0x3A, 0x43))));

        public static readonly DependencyProperty HeaderContentProperty =
            DependencyProperty.Register(nameof(HeaderContent), typeof(object), typeof(ChromeWindow),
                new FrameworkPropertyMetadata(null));

        public static readonly DependencyProperty UseDarkTitleBarProperty =
            DependencyProperty.Register(nameof(UseDarkTitleBar), typeof(bool), typeof(ChromeWindow),
                new FrameworkPropertyMetadata(true));

        public double TitleBarHeight { get => (double)GetValue(TitleBarHeightProperty); set => SetValue(TitleBarHeightProperty, value); }
        public Brush TitleBarBackground { get => (Brush)GetValue(TitleBarBackgroundProperty); set => SetValue(TitleBarBackgroundProperty, value); }
        public Brush TitleBarForeground { get => (Brush)GetValue(TitleBarForegroundProperty); set => SetValue(TitleBarForegroundProperty, value); }
        public Brush WindowBorderBrush { get => (Brush)GetValue(WindowBorderBrushProperty); set => SetValue(WindowBorderBrushProperty, value); }
        public object HeaderContent { get => GetValue(HeaderContentProperty); set => SetValue(HeaderContentProperty, value); }
        public bool UseDarkTitleBar { get => (bool)GetValue(UseDarkTitleBarProperty); set => SetValue(UseDarkTitleBarProperty, value); }

        // ---------- 模板部件 ----------
        private Button _minBtn, _maxBtn, _closeBtn;
        private TextBlock _maxGlyph;

        private readonly DispatcherTimer _hoverTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(60) };
        private bool _maxHover;

        static ChromeWindow()
        {
            DefaultStyleKeyProperty.OverrideMetadata(typeof(ChromeWindow),
                new FrameworkPropertyMetadata(typeof(ChromeWindow)));
        }

        public ChromeWindow()
        {
            // 必须保留系统边框样式：WindowChrome 只是把非客户区“画没了”，底层窗口样式不能动
            WindowStyle = WindowStyle.SingleBorderWindow;
            AllowsTransparency = false;

            WindowChrome.SetWindowChrome(this, new WindowChrome
            {
                CaptionHeight = 40,          // 和 TitleBarHeight 一致：这块由系统当作标题栏处理（拖动 / 双击最大化）
                ResizeBorderThickness = new Thickness(6),   // 边缘拖拽改尺寸的热区
                GlassFrameThickness = new Thickness(0),
                CornerRadius = new CornerRadius(0),
                UseAeroCaptionButtons = false
            });

            StateChanged += (s, e) => { UpdateMaxGlyph(); UpdateRootState(); };
            _hoverTimer.Tick += (s, e) => UpdateMaxHoverByCursor();
            Loaded += OnLoadedCore;
            Closed += (s, e) => _hoverTimer.Stop();
        }

        public override void OnApplyTemplate()
        {
            base.OnApplyTemplate();

            DetachParts();
            _minBtn = GetTemplateChild(PartMinButton) as Button;
            _maxBtn = GetTemplateChild(PartMaxButton) as Button;
            _closeBtn = GetTemplateChild(PartCloseButton) as Button;
            _maxGlyph = GetTemplateChild(PartMaxGlyph) as TextBlock;

            if (_minBtn != null) _minBtn.Click += OnMinimize;
            if (_maxBtn != null) _maxBtn.Click += OnToggleMaximize;
            if (_closeBtn != null) _closeBtn.Click += OnClose;
            UpdateMaxGlyph();
            UpdateRootState();
        }

        private void DetachParts()
        {
            if (_minBtn != null) _minBtn.Click -= OnMinimize;
            if (_maxBtn != null) _maxBtn.Click -= OnToggleMaximize;
            if (_closeBtn != null) _closeBtn.Click -= OnClose;
            _minBtn = _maxBtn = _closeBtn = null;
            _maxGlyph = null;
        }

        private void OnLoadedCore(object sender, RoutedEventArgs e)
        {
            if (IsWindows11) _hoverTimer.Start();
        }

        // ---------- 三大金刚键：全部交给系统命令，动画由 DWM 播 ----------
        private void OnMinimize(object sender, RoutedEventArgs e) => SystemCommands.MinimizeWindow(this);

        private void OnToggleMaximize(object sender, RoutedEventArgs e) => ToggleMaximize();

        private void OnClose(object sender, RoutedEventArgs e) => Close();

        public void ToggleMaximize()
        {
            if (WindowState == WindowState.Maximized) SystemCommands.RestoreWindow(this);
            else SystemCommands.MaximizeWindow(this);
        }

        // E922 = 最大化，E923 = 还原
        private void UpdateMaxGlyph()
        {
            if (_maxGlyph == null) return;
            _maxGlyph.Text = WindowState == WindowState.Maximized ? "\uE923" : "\uE922";
        }

        // 最大化时去掉 1px 边框，避免工作区高度被吃掉
        private void UpdateRootState()
        {
            var border = GetTemplateChild("PART_RootBorder") as Border;
            if (border != null)
                border.BorderThickness = WindowState == WindowState.Maximized ? new Thickness(0) : new Thickness(1);
        }

        // ---------- 窗口消息：Snap Layouts / 工作区最大化 ----------

        private const int WM_GETMINMAXINFO = 0x0024;
        private const int WM_NCHITTEST = 0x0084;
        private const int HTMAXBUTTON = 9;
        private const int WM_MOUSEMOVE = 0x0200;
        private const int WM_NCMOUSEMOVE = 0x00A0;
        private const int WM_NCMOUSELEAVE = 0x02A2;
        private const int WM_NCLBUTTONDOWN = 0x00A1;
        private const int WM_NCLBUTTONDBLCLK = 0x00A3;
        private const int MONITOR_DEFAULTTONEAREST = 2;

        protected override void OnSourceInitialized(EventArgs e)
        {
            base.OnSourceInitialized(e);
            if (UseDarkTitleBar) TryDarkTitleBar();
            HookChrome();
        }

        private void HookChrome()
        {
            var handle = new WindowInteropHelper(this).Handle;
            var src = HwndSource.FromHwnd(handle);
            if (src != null) src.AddHook(ChromeWndProc);
        }

        private IntPtr ChromeWndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            // 鼠标落在最大化键上时回 HTMAXBUTTON：Win11 才会弹 Snap Layouts 面板
            if (msg == WM_NCHITTEST && IsWindows11 && _maxBtn != null && _maxBtn.IsVisible)
            {
                int lp = lParam.ToInt32();
                int sx = (short)(lp & 0xFFFF);
                int sy = (short)((lp >> 16) & 0xFFFF);
                if (PointInMaxButton(sx, sy))
                {
                    handled = true;
                    return new IntPtr(HTMAXBUTTON);
                }
            }

            // HTMAXBUTTON 区域不会给 WPF 发 Click，按下/双击都由这里补
            if (msg == WM_NCLBUTTONDOWN && IsWindows11 && wParam.ToInt32() == HTMAXBUTTON)
            {
                ToggleMaximize();
                handled = true;
                return IntPtr.Zero;
            }

            if (msg == WM_NCLBUTTONDBLCLK && IsWindows11 && wParam.ToInt32() == HTMAXBUTTON)
            {
                handled = true;
                return IntPtr.Zero;
            }

            // 同一批区域也不会有 WPF 的 IsMouseOver，hover 只能自己查光标
            if (msg == WM_MOUSEMOVE && _maxHover) SetMaxHover(false);
            if (msg == WM_NCMOUSEMOVE && IsWindows11)
            {
                int lp = lParam.ToInt32();
                SetMaxHover(PointInMaxButton((short)(lp & 0xFFFF), (short)((lp >> 16) & 0xFFFF)));
            }
            else if (msg == WM_NCMOUSELEAVE) SetMaxHover(false);

            // 最大化铺满工作区（默认会把任务栏也盖住）
            if (msg == WM_GETMINMAXINFO)
            {
                var mmi = (MINMAXINFO)Marshal.PtrToStructure(lParam, typeof(MINMAXINFO));
                IntPtr monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
                if (monitor != IntPtr.Zero)
                {
                    var mi = new MONITORINFO();
                    mi.cbSize = Marshal.SizeOf(typeof(MONITORINFO));
                    if (GetMonitorInfo(monitor, ref mi))
                    {
                        mmi.ptMaxPosition.x = mi.rcWork.left - mi.rcMonitor.left;
                        mmi.ptMaxPosition.y = mi.rcWork.top - mi.rcMonitor.top;
                        mmi.ptMaxSize.x = mi.rcWork.right - mi.rcWork.left;
                        mmi.ptMaxSize.y = mi.rcWork.bottom - mi.rcWork.top;
                        Marshal.StructureToPtr(mmi, lParam, true);
                    }
                }
                handled = true;
            }
            return IntPtr.Zero;
        }

        private void UpdateMaxHoverByCursor()
        {
            if (!IsWindows11 || _maxBtn == null) return;
            bool inside = false;
            try
            {
                POINT pt;
                if (GetCursorPos(out pt)) inside = IsActive && PointInMaxButton(pt.x, pt.y);
            }
            catch { }
            SetMaxHover(inside);
        }

        private void SetMaxHover(bool on)
        {
            if (_maxHover == on) return;
            _maxHover = on;
            if (_maxBtn == null) return;
            // 用 Tag 让模板触发器接管，避免和样式里的 Trigger 打架
            _maxBtn.Tag = on ? "hover" : null;
        }

        private bool PointInMaxButton(int sx, int sy)
        {
            if (_maxBtn == null) return false;
            try
            {
                Point tl = _maxBtn.PointToScreen(new Point(0, 0));
                Point br = _maxBtn.PointToScreen(new Point(_maxBtn.ActualWidth, _maxBtn.ActualHeight));
                return sx >= tl.X && sx <= br.X && sy >= tl.Y && sy <= br.Y;
            }
            catch { return false; }
        }

        private static bool IsWindows11
        {
            get { return Environment.OSVersion.Version.Build >= 22000; }
        }

        // ---------- DWM：深色标题栏 ----------
        [DllImport("dwmapi.dll")]
        private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);

        private void TryDarkTitleBar()
        {
            try
            {
                var handle = new WindowInteropHelper(this).Handle;
                int one = 1;
                DwmSetWindowAttribute(handle, 20, ref one, sizeof(int));   // Win10 20H1+
                DwmSetWindowAttribute(handle, 19, ref one, sizeof(int));   // Win10 1809+
                int caption = 0x00292420;
                DwmSetWindowAttribute(handle, 35, ref caption, sizeof(int));
                int textColor = 0x00ECE9E7;
                DwmSetWindowAttribute(handle, 36, ref textColor, sizeof(int));
                int border = 0x00433A34;
                DwmSetWindowAttribute(handle, 34, ref border, sizeof(int));
            }
            catch { }
        }

        // ---------- P/Invoke 结构 ----------
        [StructLayout(LayoutKind.Sequential)]
        private struct POINT { public int x, y; }

        [StructLayout(LayoutKind.Sequential)]
        private struct RECT { public int left, top, right, bottom; }

        [StructLayout(LayoutKind.Sequential)]
        private struct MINMAXINFO
        {
            public POINT ptReserved, ptMaxSize, ptMaxPosition, ptMinTrackSize, ptMaxTrackSize;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct MONITORINFO
        {
            public int cbSize;
            public RECT rcMonitor, rcWork;
            public int dwFlags;
        }

        [DllImport("user32.dll")]
        private static extern IntPtr MonitorFromWindow(IntPtr hwnd, int flags);

        [DllImport("user32.dll")]
        private static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO lpmi);

        [DllImport("user32.dll")]
        private static extern bool GetCursorPos(out POINT lpPoint);
    }
}
