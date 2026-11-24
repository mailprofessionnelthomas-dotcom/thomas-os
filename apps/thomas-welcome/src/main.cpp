// Thomas Welcome : point d'entrée. L'interface est en QML (dossier qml/), la logique dans Bienvenue.
//   thomas-welcome                       ouvre l'écran de bienvenue (depuis le menu, à tout moment)
//   thomas-welcome --premier-lancement   lancé à l'ouverture de session : ne s'ouvre que la 1re fois
//   thomas-welcome --capture DOSSIER     photo de chaque étape dans DOSSIER, puis quitte (tests)
#include <QCommandLineParser>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

#include "bienvenue.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("thomas-welcome"));
    app.setOrganizationName(QStringLiteral("Thomas OS"));
    app.setApplicationDisplayName(QStringLiteral("Bienvenue dans Thomas OS"));
    app.setDesktopFileName(QStringLiteral("org.thomasos.welcome"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("thomas-os")));

    QCommandLineParser options;
    options.setApplicationDescription(QStringLiteral("Thomas Welcome : les premiers réglages de Thomas OS"));
    options.addHelpOption();
    const QCommandLineOption premier(QStringLiteral("premier-lancement"), QStringLiteral("Ne s'ouvre que si l'écran de bienvenue n'a jamais été fini."));
    const QCommandLineOption capture(QStringLiteral("capture"), QStringLiteral("Photo de chaque étape dans DOSSIER, puis quitte."),
                                     QStringLiteral("DOSSIER"));
    options.addOptions({premier, capture});
    options.process(app);

    if (options.isSet(premier) && Bienvenue::dejaFait()) {
        return 0;  // déjà vu : rien à faire à cette ouverture de session
    }
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
        QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));
    }
    QQmlApplicationEngine moteur;
    moteur.setInitialProperties({{QStringLiteral("dossierCapture"), options.value(capture)}});
    moteur.loadFromModule(QStringLiteral("ThomasWelcome"), QStringLiteral("Main"));
    if (moteur.rootObjects().isEmpty()) {
        return 1;
    }
    return app.exec();
}
