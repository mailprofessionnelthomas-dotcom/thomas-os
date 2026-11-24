# Thomas Welcome : écran de bienvenue du 1er démarrage (Qt 6 / QML / Kirigami).
# Compilé pendant le build de l'image (étape « compilation » du Containerfile), jamais sur le PC.
cmake_minimum_required(VERSION 3.20)
project(thomas-welcome VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(Qt6 6.6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 DBus)
qt_standard_project_setup(REQUIRES 6.6)

qt_add_executable(thomas-welcome src/main.cpp)
qt_add_qml_module(thomas-welcome
    URI ThomasWelcome
    VERSION 1.0
    SOURCES src/bienvenue.h src/bienvenue.cpp
    QML_FILES
        qml/Main.qml
        qml/Etape.qml
        qml/Point.qml
)
target_include_directories(thomas-welcome PRIVATE src)  # l'enregistrement QML généré inclut « bienvenue.h »
target_link_libraries(thomas-welcome PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::DBus)

install(TARGETS thomas-welcome RUNTIME DESTINATION bin)
install(FILES org.thomasos.welcome.desktop DESTINATION share/applications)
