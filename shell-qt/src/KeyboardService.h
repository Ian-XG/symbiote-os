#pragma once

#include <QObject>
#include <QVariantList>

/*
 * Keyboard layout.
 *
 * The image booted on the US layout with no way to change it. On any other
 * keyboard that means the symbols are not where the keycaps say — and the
 * first place it bites is typing a Wi-Fi password, where the characters are
 * masked and the failure looks like a wrong password rather than a wrong
 * layout.
 *
 * labwc reads XKB_DEFAULT_LAYOUT from ~/.config/labwc/environment at startup.
 * There is no way to change a wlroots compositor's layout without restarting
 * it, so this writes the file and says plainly that it takes effect on the
 * next sign-in rather than pretending otherwise.
 */
class KeyboardService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString layout READ layout NOTIFY changed)
    Q_PROPERTY(QString pendingLayout READ pendingLayout NOTIFY changed)
    /** True when a different layout is saved but not yet in effect. */
    Q_PROPERTY(bool restartNeeded READ restartNeeded NOTIFY changed)
    Q_PROPERTY(QVariantList layouts READ layouts CONSTANT)

public:
    explicit KeyboardService(QObject *parent = nullptr);

    QString layout() const { return m_active; }
    QString pendingLayout() const { return m_pending; }
    bool restartNeeded() const { return m_pending != m_active; }
    QVariantList layouts() const;

    Q_INVOKABLE void setLayout(const QString &code);

signals:
    void changed();

private:
    QString configPath() const;

    // What the running compositor was given, from the environment it inherited.
    QString m_active;
    // What the file says, which is what the next session will get.
    QString m_pending;
};
