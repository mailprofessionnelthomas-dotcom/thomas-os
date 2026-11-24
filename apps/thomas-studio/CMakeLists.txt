# Thomas Studio : crée et modifie les styles de Thomas OS (Qt 6 / QML / Kirigami).
# Compilé pendant le build de l'image (étape « compilation » du Containerfile), jamais sur le PC.
cmake_minimum_required(VERSION 3.20)
project(thomas-studio VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(Qt6 6.6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 DBus)
qt_standard_project_setup(REQUIRES 6.6)

qt_add_executable(thomas-studio src/main.cpp)
qt_add_qml_module(thomas-studio
    URI ThomasStudio
    VERSION 1.0
    SOURCES src/studio.h src/studio.cpp
    QML_FILES
        qml/Main.qml
        qml/Maquette.qml
        qml/Apercu.qml
        qml/ApercuFenetre.qml
        qml/ElementBarre.qml
        qml/Onglet.qml
        qml/ReglageCouleur.qml
        qml/ReglageChoix.qml
        qml/ReglageNombre.qml
        qml/ReglageOuiNon.qml
        qml/ChoixApplis.qml
        qml/BoutonsFenetre.qml
)
target_include_directories(thomas-studio PRIVATE src)  # l'enregistrement QML généré inclut « studio.h »
target_link_libraries(thomas-studio PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::DBus)

install(TARGETS thomas-studio RUNTIME DESTINATION bin)
install(FILES org.thomasos.studio.desktop DESTINATION share/applications)
