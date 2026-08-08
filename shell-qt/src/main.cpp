#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QFontDatabase>
#include <QScreen>
#include <QSurfaceFormat>
#include <QLoggingCategory>
#include <QQuickWindow>
#include <QFile>
#include <QVariant>
#include <QTimer>
#include <memory>

#include "SystemMonitor.h"
#include "SecurityMonitor.h"
#include "ProcessMonitor.h"
#include "NetworkService.h"
#include "BluetoothService.h"
#include "PowerService.h"
#include "AppLauncher.h"
#include "PacedAnimationDriver.h"
#include "PowerActions.h"
#include "PrefsStore.h"
#include "ToplevelManager.h"
#include "MediaService.h"
#include "KeyboardService.h"
#include "LiveMedium.h"

/*
 * Symbiote Shell — Qt/QML.
 *
 * Replaces the Electron shell, which needed ~550 MB across two processes and a
 * whole CPU core to animate the hologram. Everything the shell needs is here in
 * one process: procfs readers, QtDBus clients for NetworkManager/BlueZ/UPower,
 * and a Qt Quick scene graph that keeps the vector geometry on the GPU.
 */

/* On a high-density panel Qt would otherwise draw the 8-11px type at half its
   intended physical size. Same rule the Electron shell ended up with: above
   this pixel width, double it. */
static qreal chooseScale(const QScreen *screen)
{
    /* The session sets QT_SCALE_FACTOR from the panel's own mode, which scales
       the whole toolkit — type included — rather than the handful of layout
       values this function used to feed. Doubling again on top of it would
       give a 4x interface. */
    if (!qgetenv("QT_SCALE_FACTOR").isEmpty())
        return 1.0;

    const QByteArray env = qgetenv("SYMBIOTE_SCALE");
    if (!env.isEmpty()) {
        bool ok = false;
        const qreal v = env.toDouble(&ok);
        if (ok && v >= 0.5 && v <= 4.0)
            return v;
    }
    if (!screen)
        return 1.0;
    const int px = int(screen->geometry().width() * screen->devicePixelRatio());
    return px >= 2200 ? 2.0 : 1.0;
}

int main(int argc, char *argv[])
{
    // Wayland first: the session runs under labwc with no X server behind it.
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM"))
        qputenv("QT_QPA_PLATFORM", "wayland;xcb");

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("Symbiote Shell"));
    app.setDesktopFileName(QStringLiteral("symbiote-shell"));

    // The bundled font is the design's typeface; if the package is missing we
    // still want a monospace, not a proportional fallback.
    if (QFontDatabase::families().contains(QStringLiteral("JetBrains Mono")))
        app.setFont(QFont(QStringLiteral("JetBrains Mono")));

    const qreal scale = chooseScale(app.primaryScreen());

    /* Software rendering has no vsync, so animations and repaints run flat out
       and pin the CPU on a machine with no GPU. Pace them. The rate is
       overridable because the right ceiling depends on what a frame costs on
       the panel in front of you. */
    const bool software = qgetenv("QT_QUICK_BACKEND") == "software"
                          || !qgetenv("QMLSCENE_DEVICE").isEmpty();

    std::unique_ptr<PacedAnimationDriver> pacer;
    if (software) {
        bool ok = false;
        const int hz = qgetenv("SYMBIOTE_ANIM_HZ").toInt(&ok);
        pacer = std::make_unique<PacedAnimationDriver>(ok && hz > 0 ? hz : 12);
        pacer->install();
    }

    SystemMonitor system;
    SecurityMonitor security;
    ProcessMonitor processes;
    NetworkService network;
    BluetoothService bluetooth;
    PowerService power;
    AppLauncher apps;
    PowerActions powerActions;
    PrefsStore prefsStore;
    ToplevelManager toplevels;
    MediaService media;
    KeyboardService keyboard;
    LiveMedium medium;

    QQmlApplicationEngine engine;
    auto *ctx = engine.rootContext();
    ctx->setContextProperty(QStringLiteral("System"), &system);
    ctx->setContextProperty(QStringLiteral("Security"), &security);
    ctx->setContextProperty(QStringLiteral("Processes"), &processes);
    ctx->setContextProperty(QStringLiteral("Network"), &network);
    ctx->setContextProperty(QStringLiteral("Bluetooth"), &bluetooth);
    ctx->setContextProperty(QStringLiteral("Power"), &power);
    ctx->setContextProperty(QStringLiteral("Apps"), &apps);
    ctx->setContextProperty(QStringLiteral("PowerActions"), &powerActions);
    ctx->setContextProperty(QStringLiteral("Store"), &prefsStore);
    ctx->setContextProperty(QStringLiteral("Windows"), &toplevels);
    ctx->setContextProperty(QStringLiteral("Media"), &media);
    ctx->setContextProperty(QStringLiteral("Keyboard"), &keyboard);
    ctx->setContextProperty(QStringLiteral("Medium"), &medium);
    ctx->setContextProperty(QStringLiteral("uiScale"), scale);
    /* Lets the scene decide how much it can afford to draw. A GPU renders the
       hologram for free; rasterising it in software costs two thirds of the
       shell's CPU, so with no GPU it draws a coarser mass rather than dragging
       the whole desktop down. */
    ctx->setContextProperty(QStringLiteral("softwareRender"), software);

    /* Qt Quick's software renderer produces empty layers when the device pixel
       ratio is above 1: at 2x on the laptop's panel every Shape in the shell
       vanished — the whole hologram and every drawn icon — while ordinary
       items still painted. Layers buy frames under software rasterisation, but
       not at the price of drawing nothing, so they are switched off exactly
       where they break. A GPU handles them at any ratio. */
    const qreal dpr = app.primaryScreen() ? app.primaryScreen()->devicePixelRatio() : 1.0;
    ctx->setContextProperty(QStringLiteral("layersSafe"), !(software && dpr > 1.0));
    /* Lets a headless capture open a panel that normally needs a click, so
       Settings and the launcher can be reviewed without booting an ISO.
       Empty in every normal run. */
    ctx->setContextProperty(QStringLiteral("openAtStart"),
                            QString::fromLocal8Bit(qgetenv("SYMBIOTE_OPEN")));
    ctx->setContextProperty(QStringLiteral("accentAtStart"),
                            QString::fromLocal8Bit(qgetenv("SYMBIOTE_ACCENT")));

    // A QML error must not leave a blank screen with no explanation — that is
    // exactly the failure the Electron shell shipped with.
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     []() {
                         qCritical("symbiote: QML failed to load; see messages above");
                         QCoreApplication::exit(2);
                     },
                     Qt::QueuedConnection);

    // Belt and braces alongside QTP0001: search both the current and the
    // legacy resource prefix, so a policy change cannot silently break the
    // import path again.
    engine.addImportPath(QStringLiteral(":/qt/qml"));
    engine.addImportPath(QStringLiteral(":/"));

    engine.loadFromModule("Symbiote", "Main");
    if (engine.rootObjects().isEmpty())
        return 2;

    // Tell the session wrapper the window is really up. Without a positive
    // signal its watchdog could only ask "is the process still alive after 45
    // seconds?" — which is true of every healthy shell, so it fired on success.
    if (auto *w = qobject_cast<QQuickWindow *>(engine.rootObjects().first())) {
        /* Frame counter, for working out what a frame costs.
         *
         * Read it as work-per-frame, never as CPU. The offscreen platform has
         * no vsync, so the render thread runs flat out and pins a core no
         * matter what the scene contains — measuring CPU there says nothing
         * about the shell and everything about the harness. Frame rate is the
         * usable signal: a cheaper frame shows up as a higher number here, and
         * under a real compositor capped at 60 Hz that same saving comes back
         * as idle CPU.
         *
         * Off unless asked for. */
        if (!qgetenv("SYMBIOTE_FPS").isEmpty()) {
            auto *frames = new int(0);
            QObject::connect(w, &QQuickWindow::frameSwapped, &app, [frames] { ++*frames; });
            auto *t = new QTimer(&app);
            QObject::connect(t, &QTimer::timeout, &app, [frames] {
                qInfo("FPS %d", *frames);
                *frames = 0;
            });
            t->start(1000);
        }

        QObject::connect(w, &QQuickWindow::frameSwapped, &app, [] {
            static bool once = false;
            if (once) return;
            once = true;
            QFile f(QStringLiteral("/tmp/symbiote-shell-ready"));
            f.open(QIODevice::WriteOnly);
            f.close();
        });

        /* Self-portrait. Booting an ISO to look at the shell costs 25 minutes;
           this renders the same scene offscreen in seconds, which is the only
           reason the hologram and the glyphs could be iterated on at all.
           Off unless asked for, so it never runs on the real machine. */
        const QByteArray shot = qgetenv("SYMBIOTE_SHOT");
        if (!shot.isEmpty()) {
            /* The offscreen platform reports a small square screen, so a
               fullscreen window is nothing like the 1920x1080 this is designed
               for — and a layout bug that only shows at the real aspect ratio
               would go unseen. Drop out of fullscreen and take the size asked
               for. */
            const QList<QByteArray> wh = qgetenv("SYMBIOTE_SHOT_SIZE").split('x');
            if (wh.size() == 2) {
                w->setVisibility(QWindow::Windowed);
                w->setGeometry(0, 0, wh[0].toInt(), wh[1].toInt());
            }
            const int afterMs = qMax(0, qgetenv("SYMBIOTE_SHOT_DELAY").toInt());
            QTimer::singleShot(afterMs ? afterMs : 1200, &app, [w, shot, &app] {
                w->grabWindow().save(QString::fromUtf8(shot));
                app.quit();
            });
        }
    }

    return app.exec();
}
