#include "studio.h"

#include <QColor>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>

using namespace Qt::StringLiterals;

namespace
{
const QString SERVICE = u"org.thomasos.Core"_s;
const QString CHEMIN = u"/org/thomasos/Core"_s;
const QString STYLE = u"org.thomasos.Style1"_s;
const QString DEFAUT = u"thomas"_s;

// même règle que thomas-style : « Mon Été 2026 » -> « mon-ete-2026 »
QString identifiant(const QString &nom)
{
    QString sortie;
    for (const QChar c : nom.normalized(QString::NormalizationForm_KD).toLower()) {
        if ((c >= u'a' && c <= u'z') || (c >= u'0' && c <= u'9') || c == u'_' || c == u'-') {
            sortie += c;
        } else if (c.unicode() < 128 && !sortie.endsWith(u'-')) {
            sortie += u'-';
        }
    }
    while (sortie.startsWith(u'-')) {
        sortie.remove(0, 1);
    }
    while (sortie.endsWith(u'-')) {
        sortie.chop(1);
    }
    return sortie;
}
} // namespace

Studio::Studio(QObject *parent)
    : QObject(parent)
{
    // couleurs de l'identité Thomas OS : les mêmes jetons que le thème, le logo et le fond
    const QStringList ordre = {u"noir"_s, u"anthracite"_s, u"anthracite_clair"_s, u"gris"_s, u"blanc"_s, u"rouge_sombre"_s, u"rouge"_s};
    const QStringList noms = {u"Noir"_s, u"Anthracite"_s, u"Anthracite clair"_s, u"Gris"_s, u"Blanc"_s, u"Rouge sombre"_s, u"Rouge Thomas OS"_s};
    QFile jetons(u"/usr/share/thomas-os/identite/tokens.json"_s);
    QVariantMap couleurs;
    if (jetons.open(QIODevice::ReadOnly)) {
        couleurs = QJsonDocument::fromJson(jetons.readAll()).object().value(u"couleurs"_s).toObject().toVariantMap();
    }
    for (int i = 0; i < ordre.size(); ++i) {
        const QString c = couleurs.value(ordre.at(i)).toString();
        if (!c.isEmpty()) {
            m_palette.append(QVariantMap{{u"nom"_s, noms.at(i)}, {u"couleur"_s, c}});
        }
    }
    auto bus = QDBusConnection::sessionBus();
    bus.connect(SERVICE, CHEMIN, STYLE, u"StyleChange"_s, this, SLOT(styleApplique(QString)));
    bus.connect(SERVICE, CHEMIN, STYLE, u"ListeChange"_s, this, SLOT(actualiser()));
    actualiser();
}

void Studio::appelerCore(const QString &methode, const QVariantList &args, const std::function<void(const QList<QVariant> &)> &suite)
{
    auto msg = QDBusMessage::createMethodCall(SERVICE, CHEMIN, STYLE, methode);
    msg.setArguments(args);
    ++m_appels;
    Q_EMIT occupeChanged();
    auto *veilleur = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg, 60000), this);
    connect(veilleur, &QDBusPendingCallWatcher::finished, this, [this, methode, suite](QDBusPendingCallWatcher *w) {
        const QDBusMessage rep = w->reply();
        w->deleteLater();
        --m_appels;
        Q_EMIT occupeChanged();
        if (rep.type() == QDBusMessage::ErrorMessage) {
            if (methode == u"Catalogue"_s) {
                m_coreDisponible = false;
                Q_EMIT catalogueChanged();
            }
            Q_EMIT erreur(rep.errorMessage());
            return;
        }
        suite(rep.arguments());
    });
}

void Studio::actualiser()
{
    if (m_catalogue.isEmpty()) {
        appelerCore(u"Catalogue"_s, {}, [this](const QList<QVariant> &r) {
            m_catalogue = QJsonDocument::fromJson(r.value(0).toString().toUtf8()).toVariant().toMap();
            m_coreDisponible = !m_catalogue.isEmpty();
            Q_EMIT catalogueChanged();
        });
    }
    appelerCore(u"Liste"_s, {}, [this](const QList<QVariant> &r) {
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
    appelerCore(u"Actuel"_s, {}, [this](const QList<QVariant> &r) {
        m_styleActuel = r.value(0).toString();
        Q_EMIT stylesChanged();
    });
    appelerCore(u"PeutAnnuler"_s, {}, [this](const QList<QVariant> &r) {
        m_peutAnnuler = r.value(0).toBool();
        Q_EMIT stylesChanged();
    });
}

void Studio::ouvrir(const QString &id)
{
    if (id.isEmpty()) {
        appelerCore(u"Actuel"_s, {}, [this](const QList<QVariant> &r) {
            const QString actuel = r.value(0).toString();
            ouvrir(actuel.isEmpty() ? DEFAUT : actuel);
        });
        return;
    }
    appelerCore(u"Lire"_s, {id}, [this](const QList<QVariant> &r) {
        const QVariantMap j = QJsonDocument::fromJson(r.value(0).toString().toUtf8()).toVariant().toMap();
        m_idEdite = j.value(u"id"_s).toString();
        m_origine = j.value(u"origine"_s).toString();
        m_brouillon = j.value(u"style"_s).toMap();
        m_modifie = false;
        Q_EMIT brouillonChanged();
        Q_EMIT styleOuvert(m_idEdite);
    });
}

bool Studio::existe(const QString &id) const
{
    for (const QVariant &s : m_styles) {
        if (s.toMap().value(u"id"_s).toString() == id) {
            return true;
        }
    }
    return false;
}

void Studio::nouveau(const QString &nom)
{
    const QString propre = nom.trimmed().isEmpty() ? u"Mon style"_s : nom.trimmed();
    QString base = identifiant(propre);
    if (base.isEmpty()) {
        base = u"mon-style"_s;
    }
    QString id = base;
    for (int n = 2; existe(id); ++n) {
        id = base + u'-' + QString::number(n);
    }
    QVariantMap st = m_brouillon.value(u"style"_s).toMap();
    st.insert(u"nom"_s, propre);
    st.insert(u"description"_s, QString());
    m_brouillon.insert(u"style"_s, st);
    m_idEdite = id;
    m_origine = u"nouveau"_s;
    m_modifie = true;
    Q_EMIT brouillonChanged();
}

void Studio::changer(const QString &section, const QString &cle, const QVariant &valeur)
{
    QVariantMap sec = m_brouillon.value(section).toMap();
    const QString v = valeur.typeId() == QMetaType::QColor ? valeur.value<QColor>().name() : valeur.toString();
    if (sec.contains(cle) && sec.value(cle).toString() == v) {
        return;
    }
    sec.insert(cle, v);
    m_brouillon.insert(section, sec);
    m_modifie = true;
    Q_EMIT brouillonChanged();
}

QVariantList Studio::options(const QString &section, const QString &cle) const
{
    const QString k = section + u'.' + cle;
    const QVariantList ids = m_catalogue.value(u"choix"_s).toMap().value(k).toList();
    const QVariantMap noms = m_catalogue.value(u"noms"_s).toMap().value(k).toMap();
    QVariantList sortie;
    for (const QVariant &id : ids) {
        const QString nom = noms.value(id.toString()).toString();
        sortie.append(QVariantMap{{u"valeur"_s, id.toString()}, {u"nom"_s, nom.isEmpty() ? id.toString() : nom}});
    }
    return sortie;
}

QVariantList Studio::limites(const QString &cle) const
{
    const QVariantList l = m_catalogue.value(u"limites"_s).toMap().value(cle).toList();
    return l.size() == 2 ? l : QVariantList{0, 100};
}

QVariantMap Studio::appli(const QString &id) const
{
    const auto trouve = m_applis.constFind(id);
    if (trouve != m_applis.cend()) {
        return *trouve;
    }
    QVariantMap r{{u"nom"_s, id}, {u"icone"_s, u"application-x-executable"_s}};
    if (id == u"home"_s) {
        r = {{u"nom"_s, u"Dossier personnel"_s}, {u"icone"_s, u"user-home"_s}};
    } else if (id == u"trash"_s) {
        r = {{u"nom"_s, u"Corbeille"_s}, {u"icone"_s, u"user-trash"_s}};
    } else {
        // nom et icône lus dans le .desktop de l'appli (RPM ou Flatpak)
        QFile f(QStandardPaths::locate(QStandardPaths::ApplicationsLocation, id + u".desktop"_s));
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            bool entree = false;
            QString nom, nomFr;
            while (!f.atEnd()) {
                const QString l = QString::fromUtf8(f.readLine()).trimmed();
                if (l.startsWith(u'[')) {
                    if (entree) {
                        break;
                    }
                    entree = l == u"[Desktop Entry]"_s;
                } else if (entree && l.startsWith(u"Name="_s)) {
                    nom = l.mid(5);
                } else if (entree && l.startsWith(u"Name[fr]="_s)) {
                    nomFr = l.mid(9);
                } else if (entree && l.startsWith(u"Icon="_s)) {
                    r.insert(u"icone"_s, l.mid(5));
                }
            }
            if (!nomFr.isEmpty() || !nom.isEmpty()) {
                r.insert(u"nom"_s, nomFr.isEmpty() ? nom : nomFr);
            }
        }
    }
    m_applis.insert(id, r);
    return r;
}

void Studio::enregistrer(bool puisAppliquer)
{
    if (m_idEdite.isEmpty()) {
        return;
    }
    const QString texte = QString::fromUtf8(QJsonDocument::fromVariant(m_brouillon).toJson(QJsonDocument::Compact));
    appelerCore(u"Enregistrer"_s, {m_idEdite, texte}, [this, puisAppliquer](const QList<QVariant> &r) {
        const QString id = r.value(0).toString();
        const QStringList corrections = r.value(1).toStringList();
        Q_EMIT corrige(corrections);
        Q_EMIT message(corrections.isEmpty() ? u"Style enregistré"_s
                                             : u"Style enregistré, avec %1 correction(s)"_s.arg(corrections.size()));
        ouvrir(id);  // relit ce qui a vraiment été écrit, corrections comprises
        if (puisAppliquer) {
            appliquerId(id);
        }
    });
}

void Studio::appliquer()
{
    if (m_modifie || m_origine == u"nouveau"_s) {
        enregistrer(true);
    } else {
        appliquerId(m_idEdite);
    }
}

void Studio::appliquerId(const QString &id)
{
    appelerCore(u"Appliquer"_s, {id, QString()}, [this](const QList<QVariant> &) {
        m_application = true;
        Q_EMIT occupeChanged();
        Q_EMIT message(u"Application du style… (quelques secondes)"_s);
    });
}

void Studio::styleApplique(const QString &id)
{
    if (m_application) {
        Q_EMIT message(u"Style appliqué"_s);
    }
    m_application = false;
    Q_EMIT occupeChanged();
    if (m_rouvrirApres) {
        m_rouvrirApres = false;
        ouvrir(id);
    }
    actualiser();
}

void Studio::annuler()
{
    appelerCore(u"Annuler"_s, {}, [this](const QList<QVariant> &) {
        m_application = true;
        m_rouvrirApres = true;
        Q_EMIT occupeChanged();
        Q_EMIT message(u"Retour au style d'avant…"_s);
    });
}

void Studio::supprimer()
{
    if (m_origine == u"nouveau"_s) {
        ouvrir(QString());
        return;
    }
    const bool retourOriginal = m_origine == u"modifie"_s;
    const QString id = m_idEdite;
    appelerCore(u"Supprimer"_s, {id}, [this, retourOriginal, id](const QList<QVariant> &) {
        Q_EMIT message(retourOriginal ? u"Style remis comme à l'origine"_s
                                      : u"Style retiré (une copie reste dans ~/.config/thomas-os/corbeille)"_s);
        ouvrir(retourOriginal ? id : DEFAUT);
    });
}

void Studio::importer(const QUrl &fichier)
{
    appelerCore(u"Importer"_s, {fichier.toLocalFile()}, [this](const QList<QVariant> &r) {
        Q_EMIT corrige(r.value(1).toStringList());
        Q_EMIT message(u"Style importé"_s);
        ouvrir(r.value(0).toString());
    });
}

QUrl Studio::fichierExport() const
{
    return QUrl::fromLocalFile(QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) + u'/' + m_idEdite + u".conf"_s);
}

void Studio::exporter(const QUrl &fichier)
{
    if (m_modifie || m_origine == u"nouveau"_s) {
        Q_EMIT erreur(u"Enregistre d'abord tes changements, puis exporte."_s);
        return;
    }
    const QString chemin = fichier.toLocalFile();
    appelerCore(u"Exporter"_s, {m_idEdite, chemin}, [this, chemin](const QList<QVariant> &) {
        Q_EMIT message(u"Style exporté : %1"_s.arg(chemin));
    });
}
