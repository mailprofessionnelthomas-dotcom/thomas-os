// Thomas Studio : lien entre l'interface QML et Thomas Core.
// Le style en cours d'édition (« brouillon ») vit ici ; lire, enregistrer, appliquer, importer, exporter
// passent tous par Thomas Core (D-Bus org.thomasos.Core) : le Studio n'écrit jamais lui-même dans les
// fichiers de KDE ni dans les fichiers de styles.
#pragma once

#include <functional>

#include <QHash>
#include <QObject>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class Studio : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool coreDisponible READ coreDisponible NOTIFY catalogueChanged)
    Q_PROPERTY(QVariantMap catalogue READ catalogue NOTIFY catalogueChanged)
    Q_PROPERTY(QVariantList palette READ palette CONSTANT)
    Q_PROPERTY(QVariantList styles READ styles NOTIFY stylesChanged)
    Q_PROPERTY(QString styleActuel READ styleActuel NOTIFY stylesChanged)
    Q_PROPERTY(bool peutAnnuler READ peutAnnuler NOTIFY stylesChanged)
    Q_PROPERTY(QVariantMap brouillon READ brouillon NOTIFY brouillonChanged)
    Q_PROPERTY(QString idEdite READ idEdite NOTIFY brouillonChanged)
    Q_PROPERTY(QString origine READ origine NOTIFY brouillonChanged)
    Q_PROPERTY(bool modifie READ modifie NOTIFY brouillonChanged)
    Q_PROPERTY(bool occupe READ occupe NOTIFY occupeChanged)

public:
    explicit Studio(QObject *parent = nullptr);

    bool coreDisponible() const { return m_coreDisponible; }
    QVariantMap catalogue() const { return m_catalogue; }
    QVariantList palette() const { return m_palette; }
    QVariantList styles() const { return m_styles; }
    QString styleActuel() const { return m_styleActuel; }
    bool peutAnnuler() const { return m_peutAnnuler; }
    QVariantMap brouillon() const { return m_brouillon; }
    QString idEdite() const { return m_idEdite; }
    QString origine() const { return m_origine; }  // systeme, modifie, perso ou nouveau
    bool modifie() const { return m_modifie; }
    bool occupe() const { return m_appels > 0 || m_application; }

    Q_INVOKABLE void ouvrir(const QString &id);    // id vide = le style actuel
    Q_INVOKABLE void nouveau(const QString &nom);  // copie du brouillon sous un nouveau nom
    Q_INVOKABLE void changer(const QString &section, const QString &cle, const QVariant &valeur);
    Q_INVOKABLE QVariantList options(const QString &section, const QString &cle) const;  // [{valeur, nom}]
    Q_INVOKABLE QVariantList limites(const QString &cle) const;                          // [min, max]
    Q_INVOKABLE QVariantMap appli(const QString &id) const;                              // {nom, icone}
    Q_INVOKABLE void enregistrer(bool puisAppliquer = false);
    Q_INVOKABLE void appliquer();
    Q_INVOKABLE void annuler();
    Q_INVOKABLE void supprimer();
    Q_INVOKABLE void importer(const QUrl &fichier);
    Q_INVOKABLE void exporter(const QUrl &fichier);
    Q_INVOKABLE QString cheminLocal(const QUrl &url) const { return url.toLocalFile(); }
    Q_INVOKABLE QUrl fichierExport() const;  // Documents/<style>.conf, proposé à l'export
    Q_INVOKABLE bool fichierExiste(const QString &chemin) const;

public Q_SLOTS:
    void actualiser();
    void styleApplique(const QString &id);

Q_SIGNALS:
    void catalogueChanged();
    void stylesChanged();
    void brouillonChanged();
    void occupeChanged();
    void styleOuvert(const QString &id);
    void message(const QString &texte);
    void erreur(const QString &texte);
    void corrige(const QStringList &corrections);

private:
    void appelerCore(const QString &methode, const QVariantList &args, const std::function<void(const QList<QVariant> &)> &suite);
    void appliquerId(const QString &id);
    bool existe(const QString &id) const;

    bool m_coreDisponible = false;
    QVariantMap m_catalogue;
    QVariantList m_palette;
    QVariantList m_styles;
    QString m_styleActuel;
    bool m_peutAnnuler = false;
    QVariantMap m_brouillon;
    QString m_idEdite;
    QString m_origine;
    bool m_modifie = false;
    int m_appels = 0;
    bool m_application = false;  // un style est en train d'être appliqué (attente du signal StyleChange)
    bool m_rouvrirApres = false;  // après « Annuler » : relire le style remis
    mutable QHash<QString, QVariantMap> m_applis;
};
