#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>

#include "platform/mica_effect.h"
#include "platform/wallpaper_tone.h"
#include "platform/window_chrome.h"

/// 模板入口：只负责"把窗口壳装到 QML 窗口上"，不掺业务。
///
/// 顺序不能换：alpha buffer 必须在第一个 QQuickWindow 创建之前打开（否则 Mica 透不出来），
/// 系统装饰与 backdrop 必须等窗口有原生 HWND 之后（objectCreated）再下发。
int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("WindowShell"));
    QGuiApplication::setApplicationDisplayName(QStringLiteral("WindowShell"));
    QGuiApplication::setOrganizationName(QStringLiteral("AwesomeTemplates"));
    QGuiApplication::setApplicationVersion(QStringLiteral("1.0.0"));

    QCommandLineParser parser;
    parser.setApplicationDescription(
        QStringLiteral("仿 Windows Fluent 的自定义窗口壳（frameless + Mica + 原生窗口动画）。"));
    parser.addHelpOption();
    parser.addVersionOption();

    const QCommandLineOption nativeFrameOption(
        QStringLiteral("native-frame"),
        QStringLiteral("保留系统标题栏，用来和自绘标题栏做对照（调试窗口行为的退路）。"));
    const QCommandLineOption noMicaOption(
        QStringLiteral("no-mica"), QStringLiteral("关闭 Mica，窗口退回不透明。"));
    parser.addOption(nativeFrameOption);
    parser.addOption(noMicaOption);
    parser.process(app);

    const bool framelessWindow = !parser.isSet(nativeFrameOption);
    const bool micaRequested = !parser.isSet(noMicaOption) && framelessWindow
                               && winshell::platform::isBackdropSupported();

    // 只在窗口创建之前生效：透明客户区（Mica 的前提）靠它。
    QQuickWindow::setDefaultAlphaBuffer(micaRequested);

    QQuickStyle::setStyle(QStringLiteral("FluentWinUI3"));

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("framelessWindow"), framelessWindow);
    engine.rootContext()->setContextProperty(QStringLiteral("micaEnabled"), false);
    engine.rootContext()->setContextProperty(QStringLiteral("qtVersion"),
                                             QString::fromLatin1(qVersion()));
    engine.rootContext()->setContextProperty(QStringLiteral("appVersion"),
                                             QGuiApplication::applicationVersion());

    // 面板不透明度按壁纸整体明暗自适应：亮壁纸更实、暗壁纸更透。
    const double wallpaperLuminance = winshell::platform::wallpaperLuminance();
    engine.rootContext()->setContextProperty(
        QStringLiteral("surfaceAlpha"),
        winshell::platform::surfaceAlphaForLuminance(wallpaperLuminance));

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreated, &app,
        [micaRequested, &engine](QObject *object, const QUrl &) {
            auto *window = qobject_cast<QQuickWindow *>(object);
            if (window == nullptr) {
                return;
            }
            // 补系统装饰：DWM 阴影、圆角、Snap Layouts、窗口过渡动画、原生边框色。
            winshell::platform::enableSystemDecorations(window);

            if (!micaRequested || !winshell::platform::applySystemBackdrop(window)) {
                return;
            }
            window->setColor(Qt::transparent);
            engine.rootContext()->setContextProperty(QStringLiteral("micaEnabled"), true);
        },
        Qt::QueuedConnection);

    engine.loadFromModule("WindowShell", "Main");
    return app.exec();
}
