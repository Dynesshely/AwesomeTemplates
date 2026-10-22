#pragma once

namespace winshell::platform
{

/// 当前桌面壁纸的平均感知亮度（0..1，Rec.601 加权）。纯色背景、幻灯片、文件缺失等
/// 读不到壁纸的情况返回 -1，调用方按"未知"处理。
///
/// 用 16×16 采样：壁纸细节被抹平，只留整体明暗，单次加载 + 缩放是毫秒级，
/// 启动时算一次就够（不跟随壁纸切换，够用且没有额外线程）。
double wallpaperLuminance();

/// 由壁纸亮度推面板不透明度（0.35..0.65）：
///  - 亮壁纸：面板要更实——深色文字压在透亮的模糊背景上会很难读；
///  - 暗壁纸：可以更透——Mica 本身就是壁纸的模糊镜像，暗壁纸下更透才能看出明暗层次。
/// luminance < 0（未知）时返回 0.50。
double surfaceAlphaForLuminance(double luminance);

} // namespace winshell::platform
