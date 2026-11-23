#include "controle.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QFileInfo>
#include <QProcess>
#include <QStandardPaths>

namespace
{
const QString SERVICE = QStringLiteral("org.thomasos.Core");
const QString CHEMIN = QStringLiteral("/org/thomasos/Core");
const QStringList DOSSIERS_KCM = {QStringLiteral("/usr/lib64/qt6/plugins/plasma/kcms/systemsettings"),
                                  QStringLiteral("/usr/lib64/qt6/plugins/plasma/kcms/systemsettings_qwidgets"),
                                  QStringLiteral("/usr/lib64/qt6/plugins/plasma/kcms")};

QVariantMap dicoTexte(const QVariant &v)
{
    QVariantMap sortie;
    if (v.canConvert<QDBusArgument>()) {
        QMap<QString, QString> m;
        v.value<QDBusArgument>() >> m;
        for (auto it = m.cbegin(); it != m.cend(); ++it) {
            sortie.insert(it.key(), it.value());
        }
    }
    return sortie;
}
} // namespace

Controle::Controle(QObject *parent)
    : QObject(parent)
{
    QDBusConnection::sessionBus().connect(SERVICE, CHEMIN, QStringLiteral("org.thomasos.Style1"), QStringLiteral("StyleChange"),
                                          this, SLOT(actualiser()));
    actualiser();
}

void Controle::appelerCore(const QString &interface, const QString &methode, const QVariantList &args,
                           const std::function<void(const QList<QVariant> &)> &suite)
{
    auto msg = QDBusMessage::createMethodCall(SERVICE, CHEMIN, interface, methode);
    msg.setArguments(args);
    auto *veilleur = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg, 30000), this);
    connect(veilleur, &QDBusPendingCallWatcher::finished, this, [this, suite](QDBusPendingCallWatcher *w) {
        const QDBusMessage rep = w->reply();
        w->deleteLater();
        if (rep.type() == QDBusMessage::ErrorMessage) {
            Q_EMIT erreur(rep.errorMessage());
            return;
        }
        suite(rep.arguments());
    });
}

void Controle::actualiser()
{
    appelerCore(QStringLiteral("org.thomasos.Systeme1"), QStringLiteral("Infos"), {}, [this](const QList<QVariant> &r) {
        m_infos = r.isEmpty() ? QVariantMap() : dicoTexte(r.first());
        m_coreDisponible = !m_infos.isEmpty();
        Q_EMIT infosChanged();
    });
    appelerCore(QStringLiteral("org.thomasos.Systeme1"), QStringLiteral("CarteGraphique"), {}, [this](const QList<QVariant> &r) {
        m_carte = r.isEmpty() ? QVariantMap() : dicoTexte(r.first());
        Q_EMIT infosChanged();
    });
    appelerCore(QStringLiteral("org.thomasos.Style1"), QStringLiteral("Liste"), {}, [this](const QList<QVariant> &r) {
        m_styles.clear();
        if (!r.isEmpty() && r.first().canConvert<QDBusArgument>()) {
            const QDBusArgument arg = r.first().value<QDBusArgument>();
            arg.beginArray();
            while (!arg.atEnd()) {
                QString id, nom;
                arg.beginStructure();
                arg >> id >> nom;
                arg.endStructure();
                m_styles.append(QVariantMap{{QStringLiteral("id"), id}, {QStringLiteral("nom"), nom}});
            }
            arg.endArray();
        }
        Q_EMIT stylesChanged();
    });
    appelerCore(QStringLiteral("org.thomasos.Style1"), QStringLiteral("Actuel"), {}, [this](const QList<QVariant> &r) {
        m_styleActuel = r.isEmpty() ? QString() : r.first().toString();
        Q_EMIT stylesChanged();
    });
}

void Controle::actualiserRapport()
{
    appelerCore(QStringLiteral("org.thomasos.Diagnostic1"), QStringLiteral("Rapport"), {}, [this](const QList<QVariant> &r) {
        m_rapport = r.isEmpty() ? QString() : r.first().toString();
        Q_EMIT rapportChanged();
    });
}

void Controle::appliquerStyle(const QString &id)
{
    appelerCore(QStringLiteral("org.thomasos.Style1"), QStringLiteral("Appliquer"), {id, QString()}, [](const QList<QVariant> &) {});
}

void Controle::styleDeSecours()
{
    appelerCore(QStringLiteral("org.thomasos.Style1"), QStringLiteral("Secours"), {}, [](const QList<QVariant> &) {});
}

bool Controle::reglageExiste(const QString &kcm) const
{
    for (const QString &d : DOSSIERS_KCM) {
        if (QFileInfo::exists(d + QLatin1Char('/') + kcm + QStringLiteral(".so"))) {
            return true;
        }
    }
    return false;
}

bool Controle::ouvrirReglage(const QString &kcm)
{
    if (!reglageExiste(kcm)) {
        Q_EMIT erreur(QStringLiteral("Réglage indisponible sur ce PC : %1").arg(kcm));
        return false;
    }
    return QProcess::startDetached(QStringLiteral("kcmshell6"), {kcm});
}

bool Controle::programmeExiste(const QString &programme) const
{
    return !QStandardPaths::findExecutable(programme).isEmpty();
}

bool Controle::lancer(const QString &programme, const QStringList &arguments)
{
    if (!programmeExiste(programme)) {
        Q_EMIT erreur(QStringLiteral("Programme introuvable : %1").arg(programme));
        return false;
    }
    return QProcess::startDetached(programme, arguments);
}
