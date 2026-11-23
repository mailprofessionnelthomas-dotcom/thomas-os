// Thomas Control : point d'entrée. L'interface est en QML (dossier qml/), la logique dans Controle.
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
    // Style des contrôles = celui de KDE : il suit les couleurs de Thomas OS (noir, anthracite, rouge)
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
        QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));
    }
    QQmlApplicationEngine moteur;
    moteur.loadFromModule(QStringLiteral("ThomasControl"), QStringLiteral("Main"));
    if (moteur.rootObjects().isEmpty()) {
        return 1;
    }
    return app.exec();
}
