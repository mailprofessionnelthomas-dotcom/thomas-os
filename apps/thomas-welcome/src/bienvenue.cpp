#include "bienvenue.h"

#include <QCoreApplication>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDate>
#include <QFileInfo>
#include <QProcess>
#include <QSettings>
#include <QStandardPaths>

using namespace Qt::StringLiterals;

namespace
{
const QString SERVICE = u"org.thomasos.Core"_s;
const QString CHEMIN = u"/org/thomasos/Core"_s;
const QString SYSTEME = u"org.thomasos.Systeme1"_s;
const QString STYLE = u"org.thomasos.Style1"_s;
const QString CONFIG = u"org.thomasos.Config1"_s;
const QStringList DOSSIERS_KCM = {u"/usr/lib64/qt6/plugins/plasma/kcms/systemsettings"_s,
                                  u"/usr/lib64/qt6/plugins/plasma/kcms/systemsettings_qwidgets"_s,
                                  u"/usr/lib64/qt6/plugins/plasma/kcms"_s};

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

bool Bienvenue::dejaFait()
{
    auto msg = QDBusMessage::createMethodCall(SERVICE, CHEMIN, CONFIG, u"Lire"_s);
    msg.setArguments({u"bienvenue"_s, u"fait"_s});
    const QDBusMessage rep = QDBusConnection::sessionBus().call(msg, QDBus::Block, 8000);
    if (rep.type() == QDBusMessage::ReplyMessage) {
        return rep.arguments().value(0).toString() == u"oui"_s;
    }
    // Thomas Core injoignable : on lit le fichier directement (lecture seule)
    const QSettings fichier(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + u"/thomas-os/thomas.conf"_s,
                            QSettings::IniFormat);
    return fichier.value(u"bienvenue/fait"_s).toString() == u"oui"_s;
}

Bienvenue::Bienvenue(QObject *parent)
    : QObject(parent)
{
    QDBusConnection::sessionBus().connect(SERVICE, CHEMIN, STYLE, u"StyleChange"_s, this, SLOT(styleApplique(QString)));
    actualiser();
    actualiserReseau();
}

void Bienvenue::appelerCore(const QString &interface, const QString &methode, const QVariantList &args,
                            const std::function<void(const QList<QVariant> &)> &suite, const std::function<void()> &siErreur)
{
    auto msg = QDBusMessage::createMethodCall(SERVICE, CHEMIN, interface, methode);
    msg.setArguments(args);
    auto *veilleur = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg, 30000), this);
    connect(veilleur, &QDBusPendingCallWatcher::finished, this, [this, suite, siErreur](QDBusPendingCallWatcher *w) {
        const QDBusMessage rep = w->reply();
        w->deleteLater();
        if (rep.type() == QDBusMessage::ErrorMessage) {
            Q_EMIT erreur(rep.errorMessage());
            if (siErreur) {
                siErreur();
            }
            return;
        }
        suite(rep.arguments());
    });
}

void Bienvenue::actualiser()
{
    appelerCore(SYSTEME, u"Infos"_s, {}, [this](const QList<QVariant> &r) {
        m_infos = dicoTexte(r.value(0));
        m_coreDisponible = !m_infos.isEmpty();
        Q_EMIT infosChanged();
    });
    appelerCore(SYSTEME, u"CarteGraphique"_s, {}, [this](const QList<QVariant> &r) {
        m_carte = dicoTexte(r.value(0));
        Q_EMIT infosChanged();
    });
    appelerCore(STYLE, u"Liste"_s, {}, [this](const QList<QVariant> &r) {
        m_styles.clear();
        if (!r.isEmpty() && r.first().canConvert<QDBusArgument>()) {
            const QDBusArgument arg = r.first().value<QDBusArgument>();
            arg.beginArray();
            while (!arg.atEnd()) {
                QString id, nom;
                arg.beginStructure();
                arg >> id >> nom;
                arg.endStructure();
                m_styles.append(QVariantMap{{u"id"_s, id}, {u"nom"_s, nom}});
            }
            arg.endArray();
        }
        Q_EMIT stylesChanged();
    });
    appelerCore(STYLE, u"Actuel"_s, {}, [this](const QList<QVariant> &r) {
        m_styleActuel = r.value(0).toString();
        Q_EMIT stylesChanged();
    });
}

void Bienvenue::actualiserReseau()
{
    appelerCore(SYSTEME, u"Reseau"_s, {}, [this](const QList<QVariant> &r) {
        m_reseau = dicoTexte(r.value(0));
        Q_EMIT reseauChanged();
    });
}

void Bienvenue::appliquerStyle(const QString &id)
{
    appelerCore(STYLE, u"Appliquer"_s, {id, QString()}, [this, id](const QList<QVariant> &) {
        m_application = true;
        m_styleActuel = id;
        Q_EMIT stylesChanged();
    });
}

void Bienvenue::styleApplique(const QString &id)
{
    m_application = false;
    m_styleActuel = id;
    Q_EMIT stylesChanged();
}

QUrl Bienvenue::apercu(const QString &id) const
{
    const QString chemin = u"/usr/share/thomas-os/apercus/%1.png"_s.arg(id);
    return QFileInfo(chemin).isFile() ? QUrl::fromLocalFile(chemin) : QUrl();
}

bool Bienvenue::reglageExiste(const QString &kcm) const
{
    for (const QString &d : DOSSIERS_KCM) {
        if (QFileInfo::exists(d + u'/' + kcm + u".so"_s)) {
            return true;
        }
    }
    return false;
}

bool Bienvenue::ouvrirReglage(const QString &kcm)
{
    if (!reglageExiste(kcm)) {
        Q_EMIT erreur(u"Réglage indisponible sur ce PC : %1"_s.arg(kcm));
        return false;
    }
    return QProcess::startDetached(u"kcmshell6"_s, {kcm});
}

bool Bienvenue::programmeExiste(const QString &programme) const
{
    return !QStandardPaths::findExecutable(programme).isEmpty();
}

bool Bienvenue::lancer(const QString &programme, const QStringList &arguments)
{
    if (!programmeExiste(programme)) {
        Q_EMIT erreur(u"Programme introuvable : %1"_s.arg(programme));
        return false;
    }
    return QProcess::startDetached(programme, arguments);
}

void Bienvenue::terminer()
{
    // la date d'abord, « fait » ensuite : si l'écriture échoue, l'écran reviendra à la prochaine session
    appelerCore(CONFIG, u"Ecrire"_s, {u"bienvenue"_s, u"date"_s, QDate::currentDate().toString(Qt::ISODate)}, [this](const QList<QVariant> &) {
        appelerCore(CONFIG, u"Ecrire"_s, {u"bienvenue"_s, u"fait"_s, u"oui"_s}, [](const QList<QVariant> &) { QCoreApplication::quit(); },
                    [] { QCoreApplication::quit(); });
    }, [] { QCoreApplication::quit(); });
}
