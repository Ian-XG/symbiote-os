#pragma once

#include <QAnimationDriver>
#include <QElapsedTimer>
#include <QTimer>

/*
 * Caps every QML animation to a fixed rate.
 *
 * Qt Quick's software backend has no vsync — presenting a frame is a memcpy,
 * so the render loop advances animations and redraws as fast as the CPU
 * allows. On a machine with no GPU that means the shell repaints flat out
 * forever: measured idle on the live image at 127% of two cores, worse than
 * the Electron build it replaced, with nobody touching it.
 *
 * Driving the animation clock from a timer instead puts a ceiling on it.
 * Between ticks nothing in the scene changes, so nothing is repainted. The
 * hologram takes thirty seconds for one turn; at 24 Hz that reads exactly the
 * same as at 200, for an eighth of the work.
 *
 * Only installed when rendering in software. With a GPU, vsync already does
 * this job and the driver would only cost frames.
 */
class PacedAnimationDriver : public QAnimationDriver
{
    Q_OBJECT

public:
    explicit PacedAnimationDriver(int hz, QObject *parent = nullptr)
        : QAnimationDriver(parent), m_interval(1000 / qMax(1, hz))
    {
        m_timer.setTimerType(Qt::PreciseTimer);
        connect(&m_timer, &QTimer::timeout, this, [this] { advance(); });
    }

    void start() override
    {
        m_elapsed.start();
        m_timer.start(m_interval);
        QAnimationDriver::start();
    }

    void stop() override
    {
        m_timer.stop();
        QAnimationDriver::stop();
    }

    /* The animation system asks what time it is; answering with the wall clock
       keeps animation durations honest even though we tick coarsely. */
    qint64 elapsed() const override { return m_elapsed.elapsed(); }

private:
    QTimer m_timer;
    QElapsedTimer m_elapsed;
    int m_interval;
};
