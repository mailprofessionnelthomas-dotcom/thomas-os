// Thomas Studio : point d'entrée. L'interface est en QML (dossier qml/), la logique dans Studio.
//   thomas-studio [STYLE]                       ouvre le Studio sur ce style (par défaut : le style actuel)
//   thomas-studio --apercu FICHIER.png STYLE    enregistre la maquette du style puis quitte (tests)
//       [--menu] [--ecran 1920x1080]            … avec le menu ouvert, pour un écran de cette taille
//   thomas-studio --capture FICHIER.png STYLE   photo de la fenêtre du Studio après 4 s, puis quitte (tests)
#include <QCommandLineParser>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("thomas-studio"));
    app.setOrganizationName(QStringLiteral("Thomas OS"));
    app.setApplicationDisplayName(QStringLiteral("Thomas Studio"));
    app.setDesktopFileName(QStringLiteral("org.thomasos.studio"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("thomas-os")));

    QCommandLineParser options;
    options.setApplicationDescription(QStringLiteral("Thomas Studio : crée et modifie les styles de Thomas OS"));
    options.addHelpOption();
    const QCommandLineOption apercu(QStringLiteral("apercu"), QStringLiteral("Enregistre la maquette du style dans FICHIER (PNG) puis quitte."),
                                    QStringLiteral("FICHIER"));
    const QCommandLineOption menu(QStringLiteral("menu"), QStringLiteral("Maquette : avec le menu ouvert."));
    const QCommandLineOption ecran(QStringLiteral("ecran"), QStringLiteral("Maquette : taille de l'écran (ex. 1920x1080)."), QStringLiteral("TAILLE"));
    const QCommandLineOption taille(QStringLiteral("taille"), QStringLiteral("Maquette : taille de l'image enregistrée (ex. 640x360)."),
                                    QStringLiteral("TAILLE"));
    const QCommandLineOption capture(QStringLiteral("capture"), QStringLiteral("Photo de la fenêtre dans FICHIER (PNG) puis quitte."),
                                     QStringLiteral("FICHIER"));
    options.addOptions({apercu, menu, ecran, taille, capture});
    options.addPositionalArgument(QStringLiteral("style"), QStringLiteral("Style à ouvrir (par défaut : le style actuel)."));
    options.process(app);
    const QString style = options.positionalArguments().value(0);

    // Style des contrôles = celui de KDE : il suit les couleurs de Thomas OS (noir, anthracite, rouge)
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
        QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));
    }
    QQmlApplicationEngine moteur;
    if (options.isSet(apercu)) {
        moteur.setInitialProperties({{QStringLiteral("styleDemande"), style},
                                     {QStringLiteral("fichierApercu"), options.value(apercu)},
                                     {QStringLiteral("menuOuvert"), options.isSet(menu)},
                                     {QStringLiteral("ecran"), options.value(ecran)},
                                     {QStringLiteral("tailleImage"), options.value(taille)}});
        moteur.loadFromModule(QStringLiteral("ThomasStudio"), QStringLiteral("Maquette"));
    } else {
        moteur.setInitialProperties({{QStringLiteral("styleDemande"), style}, {QStringLiteral("fichierCapture"), options.value(capture)}});
        moteur.loadFromModule(QStringLiteral("ThomasStudio"), QStringLiteral("Main"));
    }
    if (moteur.rootObjects().isEmpty()) {
        return 1;
    }
    return app.exec();
}
