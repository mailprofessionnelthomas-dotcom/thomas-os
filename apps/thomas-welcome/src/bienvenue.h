// Thomas Welcome : lien entre l'interface QML et le système.
// Tout passe par Thomas Core (D-Bus org.thomasos.Core) ou par les pages de réglages de KDE :
// l'écran de bienvenue ne modifie jamais lui-même les fichiers de configuration.
#pragma once

#include <functional>

#include <QObject>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class Bienvenue : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QVariantMap infos READ infos NOTIFY infosChanged)
    Q_PROPERTY(QVariantMap carte READ carte NOTIFY infosChanged)
    Q_PROPERTY(QVariantMap reseau READ reseau NOTIFY reseauChanged)
    Q_PROPERTY(QVariantList styles READ styles NOTIFY stylesChanged)
    Q_PROPERTY(QString styleActuel READ styleActuel NOTIFY stylesChanged)
    Q_PROPERTY(bool application READ application NOTIFY stylesChanged)
    Q_PROPERTY(bool coreDisponible READ coreDisponible NOTIFY infosChanged)

public:
    explicit Bienvenue(QObject *parent = nullptr);

    // l'écran de bienvenue a-t-il déjà été fini ? (appel direct, avant d'ouvrir la moindre fenêtre)
    static bool dejaFait();

    QVariantMap infos() const { return m_infos; }
    QVariantMap carte() const { return m_carte; }
    QVariantMap reseau() const { return m_reseau; }
    QVariantList styles() const { return m_styles; }
    QString styleActuel() const { return m_styleActuel; }
    bool application() const { return m_application; }
    bool coreDisponible() const { return m_coreDisponible; }

    Q_INVOKABLE void actualiserReseau();
    Q_INVOKABLE void appliquerStyle(const QString &id);
    Q_INVOKABLE QUrl apercu(const QString &id) const;  // maquette du style dessinée au build, ou vide
    Q_INVOKABLE bool reglageExiste(const QString &kcm) const;
    Q_INVOKABLE bool ouvrirReglage(const QString &kcm);
    Q_INVOKABLE bool programmeExiste(const QString &programme) const;
    Q_INVOKABLE bool lancer(const QString &programme, const QStringList &arguments = {});
    Q_INVOKABLE void terminer();  // retient « bienvenue faite » puis ferme

public Q_SLOTS:
    void actualiser();
    void styleApplique(const QString &id);

Q_SIGNALS:
    void infosChanged();
    void reseauChanged();
    void stylesChanged();
    void erreur(const QString &message);

private:
    void appelerCore(const QString &interface, const QString &methode, const QVariantList &args,
                     const std::function<void(const QList<QVariant> &)> &suite, const std::function<void()> &siErreur = {});

    QVariantMap m_infos;
    QVariantMap m_carte;
    QVariantMap m_reseau;
    QVariantList m_styles;
    QString m_styleActuel;
    bool m_application = false;
    bool m_coreDisponible = false;
};
