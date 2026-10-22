#include "platform/wallpaper_tone.h"

#include <QtGlobal>

#ifdef Q_OS_WIN

#include <QImage>
#include <QString>

#ifndef WIN32_LEAN_AND_MEAN
#    define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#    define NOMINMAX
#endif
#include <windows.h>

namespace
{

double sampleLuminance(const QImage &image)
{
    if (image.isNull()) {
        return -1.0;
    }
    const QImage scaled = image.scaled(16, 16, Qt::IgnoreAspectRatio, Qt::SmoothTransformation)
                              .convertToFormat(QImage::Format_RGB32);
    double sum = 0.0;
    for (int y = 0; y < scaled.height(); ++y) {
        for (int x = 0; x < scaled.width(); ++x) {
            const QRgb pixel = scaled.pixel(x, y);
            sum += 0.299 * qRed(pixel) + 0.587 * qGreen(pixel) + 0.114 * qBlue(pixel);
        }
    }
    return sum / (scaled.width() * scaled.height()) / 255.0;
}

} // namespace

namespace winshell::platform
{

double wallpaperLuminance()
{
    wchar_t path[MAX_PATH] = {};
    if (SystemParametersInfoW(SPI_GETDESKWALLPAPER, MAX_PATH, path, 0) == FALSE) {
        return -1.0;
    }
    if (path[0] == L'\0') {
        return -1.0;
    }
    return sampleLuminance(QImage(QString::fromWCharArray(path)));
}

double surfaceAlphaForLuminance(double luminance)
{
    if (luminance < 0.0) {
        return 0.50;
    }
    // 0.35..0.65：暗壁纸下透出六成，Mica 的磨砂层次和壁纸明暗都能看出来；
    // 亮壁纸收到 0.65，深色文字压在透亮背景上仍然可读。
    return 0.35 + 0.30 * qBound(0.0, luminance, 1.0);
}

} // namespace winshell::platform

#else // Q_OS_WIN

namespace winshell::platform
{

double wallpaperLuminance()
{
    return -1.0;
}

double surfaceAlphaForLuminance(double luminance)
{
    Q_UNUSED(luminance);
    return 0.65;
}

} // namespace winshell::platform

#endif // Q_OS_WIN
