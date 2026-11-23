// Thomas Control : lien entre l'interface QML et le système.
// Tout passe par le service Thomas Core (D-Bus org.thomasos.Core) ou par les pages de réglages de KDE :
// Thomas Control ne modifie jamais lui-même les fichiers de configuration.
#pragma once

#include <functional>

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class Controle : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QVariantMap infos READ infos NOTIFY infosChanged)
    Q_PROPERTY(QVariantMap carte READ carte NOTIFY infosChanged)
    Q_PROPERTY(QVariantList styles READ styles NOTIFY stylesChanged)
    Q_PROPERTY(QString styleActuel READ styleActuel NOTIFY stylesChanged)
    Q_PROPERTY(QString rapport READ rapport NOTIFY rapportChanged)
    Q_PROPERTY(bool coreDisponible READ coreDisponible NOTIFY infosChanged)

public:
    explicit Controle(QObject *parent = nullptr);

    QVariantMap infos() const { return m_infos; }
    QVariantMap carte() const { return m_carte; }
    QVariantList styles() const { return m_styles; }
    QString styleActuel() const { return m_styleActuel; }
    QString rapport() const { return m_rapport; }
    bool coreDisponible() const { return m_coreDisponible; }

    Q_INVOKABLE void actualiserRapport();
    Q_INVOKABLE void appliquerStyle(const QString &id);
    Q_INVOKABLE void styleDeSecours();
    // ouvre une page de réglages KDE (kcm_xxx) ; renvoie false si elle n'existe pas sur ce PC
    Q_INVOKABLE bool ouvrirReglage(const QString &kcm);
    Q_INVOKABLE bool reglageExiste(const QString &kcm) const;
    Q_INVOKABLE bool lancer(const QString &programme, const QStringList &arguments = {});
    Q_INVOKABLE bool programmeExiste(const QString &programme) const;

public Q_SLOTS:
    void actualiser();  // relit tout auprès de Thomas Core (aussi appelé quand le style change)

Q_SIGNALS:
    void infosChanged();
    void stylesChanged();
    void rapportChanged();
    void erreur(const QString &message);

private:
    void appelerCore(const QString &interface, const QString &methode, const QVariantList &args,
                     const std::function<void(const QList<QVariant> &)> &suite);

    QVariantMap m_infos;
    QVariantMap m_carte;
    QVariantList m_styles;
    QString m_styleActuel;
    QString m_rapport;
    bool m_coreDisponible = false;
};
