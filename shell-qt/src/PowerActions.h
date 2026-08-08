#pragma once

#include <QObject>
#include <QProcess>

/*
 * Shutdown, restart, log out.
 *
 * The shell had no way to turn the machine off. On a live image the only exit
 * was holding the power button, which on a laptop running from a USB stick is
 * how you corrupt the stick.
 *
 * systemctl talks to logind, which authorises through polkit; the rule shipped
 * in /etc/polkit-1/rules.d grants these three to the operator. Nothing here
 * runs through a shell, so no argument can be interpreted as one.
 */
class PowerActions : public QObject
{
    Q_OBJECT

public:
    using QObject::QObject;

    /* Lock and capture are not systemctl verbs; they are the session's own
       helpers, and they run detached so the shell is not their parent. */
    Q_INVOKABLE void lockScreen()
    {
        QProcess::startDetached(QStringLiteral("symbiote-lock"), {});
    }
    Q_INVOKABLE void screenshot(const QString &mode)
    {
        QProcess::startDetached(QStringLiteral("symbiote-shot"), {mode});
    }

    Q_INVOKABLE void powerOff() { run(QStringLiteral("poweroff")); }
    Q_INVOKABLE void restart()  { run(QStringLiteral("reboot")); }
    /* Ends the session; greetd starts a fresh one, which is the closest thing
       to logging out on an image with a single autologin user. */
    Q_INVOKABLE void logOut()   { run(QStringLiteral("--user"), QStringLiteral("exit")); }

private:
    void run(const QString &verb, const QString &extra = QString())
    {
        QStringList args;
        if (!extra.isEmpty())
            args << verb << extra;
        else
            args << verb;
        QProcess::startDetached(QStringLiteral("systemctl"), args);
    }
};
