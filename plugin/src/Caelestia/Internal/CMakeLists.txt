qml_module(caelestia-internal
    URI Caelestia.Internal
    SOURCES
        cachingimagemanager.hpp cachingimagemanager.cpp
        circularindicatormanager.hpp circularindicatormanager.cpp
        hyprdevices.hpp hyprdevices.cpp
        hyprextras.hpp hyprextras.cpp
        logindmanager.hpp logindmanager.cpp
        ../webpplayer.hpp ../webpplayer.cpp
    LIBRARIES
        Qt::Gui
        Qt::Quick
        Qt::Concurrent
        Qt::Network
        Qt::DBus
        PkgConfig::WebP
        PkgConfig::WebPDemux
)

target_include_directories(caelestia-internal PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/..)
