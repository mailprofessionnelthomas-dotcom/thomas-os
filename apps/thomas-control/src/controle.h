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
    Q_PROPERTY(QVariantList temperatures READ temperatures NOTIFY temperaturesChanged)
    Q_PROPERTY(QVariantMap energie READ energie NOTIFY energieChanged)
    Q_PROPERTY(bool jeuAuto READ jeuAuto NOTIFY energieChanged)
    Q_PROPERTY(QVariantMap testReseau READ testReseau NOTIFY reseauChanged)
    Q_PROPERTY(bool mesureEnCours READ mesureEnCours NOTIFY reseauChanged)
    Q_PROPERTY(QVariantMap nettoyage READ nettoyage NOTIFY nettoyageChanged)
    Q_PROPERTY(bool nettoyageEnCours READ nettoyageEnCours NOTIFY nettoyageChanged)
    Q_PROPERTY(QVariantMap systeme READ systeme NOTIFY systemeChanged)
    Q_PROPERTY(QString progressionSysteme READ progressionSysteme NOTIFY systemeChanged)
    Q_PROPERTY(bool attenteSysteme READ attenteSysteme NOTIFY systemeChanged)

public:
    explicit Controle(QObject *parent = nullptr);

    QVariantMap infos() const { return m_infos; }
    QVariantMap carte() const { return m_carte; }
    QVariantList styles() const { return m_styles; }
    QString styleActuel() const { return m_styleActuel; }
    QString rapport() const { return m_rapport; }
    bool coreDisponible() const { return m_coreDisponible; }
    QVariantList temperatures() const { return m_temperatures; }
    QVariantMap energie() const { return m_energie; }
    bool jeuAuto() const { return m_jeuAuto; }
    QVariantMap testReseau() const { return m_testReseau; }
    bool mesureEnCours() const { return m_mesures > 0; }
    QVariantMap nettoyage() const { return m_nettoyage; }
    bool nettoyageEnCours() const { return m_nettoyageEnCours; }
    QVariantMap systeme() const { return m_systeme; }
    QString progressionSysteme() const { return m_progressionSysteme; }
    bool attenteSysteme() const { return m_attenteSysteme; }

    // Phase 9 : aide système (org.thomasos.Systeme, bus système, root) ; polkit demande le mot de passe si besoin
    Q_INVOKABLE void actualiserSysteme();
    Q_INVOKABLE void changerCanal(const QString &canal);
    Q_INVOKABLE void changerVariante(const QString &variante);
    Q_INVOKABLE void redemarrerWindows();

    // Phase 8 : performances, gaming, maintenance, diagnostic réseau (tout passe par Thomas Core)
    Q_INVOKABLE void actualiserTemperatures();
    Q_INVOKABLE void actualiserEnergie();
    Q_INVOKABLE void choisirEnergie(const QString &profil);
    Q_INVOKABLE void changerJeuAuto(bool actif);
    Q_INVOKABLE void lancerTestReseau();
    Q_INVOKABLE void lancerTestDebit();
    Q_INVOKABLE void actualiserNettoyage();
    Q_INVOKABLE void nettoyer();  // service système : le mot de passe administrateur est demandé par KDE

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

private Q_SLOTS:
    void surProgression(const QString &action, const QString &ligne);
    void surFini(const QString &action, bool ok, const QString &texte);

Q_SIGNALS:
    void infosChanged();
    void stylesChanged();
    void rapportChanged();
    void temperaturesChanged();
    void energieChanged();
    void reseauChanged();
    void nettoyageChanged();
    void systemeChanged();
    void erreur(const QString &message);
    void message(const QString &message);

private:
    void appelerCore(const QString &interface, const QString &methode, const QVariantList &args,
                     const std::function<void(const QList<QVariant> &)> &suite, int delaiMs = 30000,
                     const std::function<void()> &siErreur = {});
    void appelerSysteme(const QString &methode, const QVariantList &args);

    QVariantMap m_systeme;
    QString m_progressionSysteme;
    bool m_attenteSysteme = false;
    QVariantList m_temperatures;
    QVariantMap m_energie;
    bool m_jeuAuto = true;
    QVariantMap m_testReseau;
    int m_mesures = 0;
    QVariantMap m_nettoyage;
    bool m_nettoyageEnCours = false;

    QVariantMap m_infos;
    QVariantMap m_carte;
    QVariantList m_styles;
    QString m_styleActuel;
    QString m_rapport;
    bool m_coreDisponible = false;
};
