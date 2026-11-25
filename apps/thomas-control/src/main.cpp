// Thomas Control : point d'entrée. L'interface est en QML (dossier qml/), la logique dans Controle.
//   thomas-control --capture DOSSIER   ouvre chaque catégorie, la photographie (page-01.png…), puis quitte (tests)
//   thomas-control --page systeme      s'ouvre directement sur une page (ex. depuis Thomas Welcome)
#include <QCommandLineParser>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("thomas-control"));
    app.setOrganizationName(QStringLiteral("Thomas OS"));
    app.setApplicationDisplayName(QStringLiteral("Thomas Control"));
    app.setDesktopFileName(QStringLiteral("org.thomasos.control"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("thomas-os")));
    QCommandLineParser options;
    options.addHelpOption();
    const QCommandLineOption capture(QStringLiteral("capture"), QStringLiteral("Photo de chaque catégorie dans DOSSIER, puis quitte."),
                                     QStringLiteral("DOSSIER"));
    options.addOption(capture);
    const QCommandLineOption page(QStringLiteral("page"), QStringLiteral("Page ouverte au démarrage (systeme, gaming, reseau…)."),
                                  QStringLiteral("PAGE"));
    options.addOption(page);
    options.process(app);
    // Style des contrôles = celui de KDE : il suit les couleurs de Thomas OS (noir, anthracite, rouge)
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
        QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));
    }
    QQmlApplicationEngine moteur;
    moteur.setInitialProperties({{QStringLiteral("dossierCapture"), options.value(capture)},
                                 {QStringLiteral("pageDepart"), options.value(page)}});
    moteur.loadFromModule(QStringLiteral("ThomasControl"), QStringLiteral("Main"));
    if (moteur.rootObjects().isEmpty()) {
        return 1;
    }
    return app.exec();
}
