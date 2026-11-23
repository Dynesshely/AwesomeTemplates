using System.Windows;
using System.Windows.Controls;

namespace WindowShell
{
    public partial class MainWindow : Chrome.ChromeWindow
    {
        private bool _customHeader;

        public MainWindow()
        {
            InitializeComponent();
        }

        private void ToggleMax_Click(object sender, RoutedEventArgs e)
        {
            ToggleMaximize();
        }

        private void ToggleHeader_Click(object sender, RoutedEventArgs e)
        {
            _customHeader = !_customHeader;
            if (_customHeader)
            {
                // 自定义标题栏：直接替换左侧那段内容，右边的三大金刚键保持不动
                var stack = new StackPanel { Orientation = Orientation.Horizontal };
                stack.Children.Add(new TextBlock
                {
                    Text = "自定义标题内容",
                    FontSize = 12.5,
                    VerticalAlignment = VerticalAlignment.Center
                });
                stack.Children.Add(new Border
                {
                    Background = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(0x22, 0x26, 0x2D)),
                    CornerRadius = new CornerRadius(4),
                    Padding = new Thickness(6, 2, 6, 2),
                    Margin = new Thickness(10, 0, 0, 0),
                    VerticalAlignment = VerticalAlignment.Center,
                    Child = new TextBlock { Text = "HeaderContent", FontSize = 10 }
                });
                HeaderContent = stack;
            }
            else
            {
                HeaderContent = null;
            }
        }

        private void About_Click(object sender, RoutedEventArgs e)
        {
            MessageBox.Show(this,
                "WPF 窗口壳模板\n\n自绘标题栏 + 原生窗口动画 + Snap Layouts。\n样式在 Themes/Generic.xaml，逻辑在 Chrome/ChromeWindow.cs。",
                "关于", MessageBoxButton.OK, MessageBoxImage.Information);
        }
    }
}
