using System.Windows;

// 让 WPF 到本程序集里找 Themes/Generic.xaml（窗口壳的默认样式就在那里）。
// 没有这行，ChromeWindow 的 DefaultStyleKey 会找不到模板，窗口渲染成空白。
[assembly: ThemeInfo(
    ResourceDictionaryLocation.None,
    ResourceDictionaryLocation.SourceAssembly)]
