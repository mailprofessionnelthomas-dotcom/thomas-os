# Thomas Control : centre de contrôle de Thomas OS (Qt 6 / QML / Kirigami).
# Compilé pendant le build de l'image (étape « compilation » du Containerfile), jamais sur le PC.
cmake_minimum_required(VERSION 3.20)
project(thomas-control VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(Qt6 6.6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 DBus)
qt_standard_project_setup(REQUIRES 6.6)

qt_add_executable(thomas-control src/main.cpp)
qt_add_qml_module(thomas-control
    URI ThomasControl
    VERSION 1.0
    SOURCES src/controle.h src/controle.cpp
    QML_FILES
        qml/Main.qml
        qml/PageAccueil.qml
        qml/PageCategorie.qml
        qml/PageApparence.qml
        qml/PageSysteme.qml
        qml/PagePerformances.qml
        qml/PageGaming.qml
        qml/PageMaintenance.qml
        qml/PageReseau.qml
        qml/Carte.qml
)
target_include_directories(thomas-control PRIVATE src)  # l'enregistrement QML généré inclut « controle.h »
target_link_libraries(thomas-control PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::DBus)

install(TARGETS thomas-control RUNTIME DESTINATION bin)
install(FILES org.thomasos.control.desktop DESTINATION share/applications)
