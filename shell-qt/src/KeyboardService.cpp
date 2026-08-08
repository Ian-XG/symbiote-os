#include "KeyboardService.h"

#include <QFile>
#include <QDir>
#include <QTextStream>
#include <QRegularExpression>

KeyboardService::KeyboardService(QObject *parent) : QObject(parent)
{
    // What the compositor actually started with.
    m_active = qEnvironmentVariable("XKB_DEFAULT_LAYOUT");
    if (m_active.isEmpty())
        m_active = QStringLiteral("us");

    m_pending = m_active;

    // What the file says, which may already differ if it was set this session.
    QFile f(configPath());
    if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        static const QRegularExpression re(
            QStringLiteral("^XKB_DEFAULT_LAYOUT=(.+)$"),
            QRegularExpression::MultilineOption);
        const auto m = re.match(QString::fromUtf8(f.readAll()));
        if (m.hasMatch())
            m_pending = m.captured(1).trimmed();
    }
}

QVariantList KeyboardService::layouts() const
{
    /* A short list rather than the whole XKB database. Presenting four hundred
       layouts to somebody who wants their own keyboard to work is not help. */
    const QList<QPair<QString, QString>> known = {
        {QStringLiteral("us"),    QStringLiteral("English (US)")},
        {QStringLiteral("latam"), QStringLiteral("Spanish (Latin America)")},
        {QStringLiteral("es"),    QStringLiteral("Spanish (Spain)")},
        {QStringLiteral("gb"),    QStringLiteral("English (UK)")},
        {QStringLiteral("fr"),    QStringLiteral("French")},
        {QStringLiteral("de"),    QStringLiteral("German")},
        {QStringLiteral("it"),    QStringLiteral("Italian")},
        {QStringLiteral("pt"),    QStringLiteral("Portuguese")},
        {QStringLiteral("br"),    QStringLiteral("Portuguese (Brazil)")},
    };

    QVariantList out;
    for (const auto &k : known) {
        QVariantMap m;
        m["code"] = k.first;
        m["name"] = k.second;
        out.append(m);
    }
    return out;
}

QString KeyboardService::configPath() const
{
    return QDir::homePath() + QStringLiteral("/.config/labwc/environment");
}

void KeyboardService::setLayout(const QString &code)
{
    if (code.isEmpty())
        return;

    const QString path = configPath();
    QDir().mkpath(QFileInfo(path).absolutePath());

    /* Rewrite only our own line. The file is the compositor's environment and
       may hold anything else the session needs. */
    QStringList lines;
    QFile in(path);
    if (in.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QString all = QString::fromUtf8(in.readAll());
        for (const QString &l : all.split(QLatin1Char('\n'))) {
            if (!l.startsWith(QLatin1String("XKB_DEFAULT_LAYOUT=")))
                lines << l;
        }
        in.close();
    }
    while (!lines.isEmpty() && lines.last().trimmed().isEmpty())
        lines.removeLast();
    lines << QStringLiteral("XKB_DEFAULT_LAYOUT=%1").arg(code);

    QFile out(path);
    if (!out.open(QIODevice::WriteOnly | QIODevice::Text))
        return;
    QTextStream ts(&out);
    ts << lines.join(QLatin1Char('\n')) << '\n';
    out.close();

    m_pending = code;
    emit changed();
}
