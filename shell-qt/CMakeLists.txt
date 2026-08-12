cmake_minimum_required(VERSION 3.21)
# C as well as CXX: wayland-scanner emits a C source file, and a CXX-only
# project skips it without complaint — which shows up much later as an
# undefined reference to the protocol interface.
project(symbiote-shell-qt VERSION 0.1 LANGUAGES C CXX)

# Qt6 + QML instead of Electron.
#
# The Electron shell needed ~550 MB across two processes and pinned a core to
# animate the hologram, because the browser re-rasterises vector paths as they
# move. Qt Quick uploads the same geometry to the GPU once and animates it with
# a matrix, which is what this UI actually needs.
#
# QtDBus also replaces dbus-next, removing the native usocket module that never
# built against current Node.

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Quick Qml DBus)

# ── Wayland: what windows are open ─────────────────────────────────────────
# The taskbar could only ever show what had been pinned to it, because nothing
# asked the compositor what was actually on screen. That question is only
# answerable over a Wayland protocol.
find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND_CLIENT REQUIRED IMPORTED_TARGET wayland-client)
find_program(WAYLAND_SCANNER wayland-scanner REQUIRED)

set(WLR_XML "${CMAKE_CURRENT_SOURCE_DIR}/protocols/wlr-foreign-toplevel-management-unstable-v1.xml")
set(WLR_HEADER "${CMAKE_CURRENT_BINARY_DIR}/wlr-foreign-toplevel-management-client-protocol.h")
set(WLR_SOURCE "${CMAKE_CURRENT_BINARY_DIR}/wlr-foreign-toplevel-management-protocol.c")

# Generated at build time from the vendored XML rather than committed, so the
# generator and the client library can never disagree about the wire format.
add_custom_command(
    OUTPUT "${WLR_HEADER}"
    COMMAND "${WAYLAND_SCANNER}" client-header "${WLR_XML}" "${WLR_HEADER}"
    DEPENDS "${WLR_XML}" VERBATIM)
add_custom_command(
    OUTPUT "${WLR_SOURCE}"
    COMMAND "${WAYLAND_SCANNER}" private-code "${WLR_XML}" "${WLR_SOURCE}"
    DEPENDS "${WLR_XML}" VERBATIM)

qt_standard_project_setup(REQUIRES 6.4)

# NOT cosmetic. Without this the module's resources land under ':/Symbiote/'
# while the engine only searches ':/qt/qml/', and loadFromModule fails with
# "Module Symbiote contains no type named Main" — a correct qmldir in a place
# nothing looks.
qt_policy(SET QTP0001 NEW)

include_directories("${CMAKE_CURRENT_BINARY_DIR}")

qt_add_executable(symbiote-shell-qt
    src/main.cpp
    src/SystemMonitor.cpp
    src/SecurityMonitor.cpp
    src/ProcessMonitor.cpp
    src/NetworkService.cpp
    src/BluetoothService.cpp
    src/DisplayService.cpp
    src/TimeService.cpp
    src/NotificationService.cpp
    src/VpnService.cpp
    src/BluetoothAgent.cpp
    src/PacedAnimationDriver.h
    src/PowerActions.h
    src/PrefsStore.h
    src/ToplevelManager.cpp
    src/MediaService.cpp
    src/KeyboardService.cpp
    src/LiveMedium.cpp
    ${WLR_HEADER}
    ${WLR_SOURCE}
    src/PowerService.cpp
    src/AppLauncher.cpp
)

# Qt derives a QML type's name from the file's path relative to the module
# root. Listed as qml/Main.qml and qml/components/Panel.qml, nothing landed at
# the root, and the engine reported: Module "Symbiote" contains no type named
# "Main". QT_RESOURCE_ALIAS flattens them so every component is a type of the
# module regardless of where its source lives on disk.
# The mass as a bitmap, for the launcher button. Everything else in the shell
# is drawn; this one is the product's own mark and is not something to redraw
# in line art.
qt_add_resources(symbiote-shell-qt "assets"
    PREFIX "/assets"
    # Without BASE the paths keep their directory and land at
    # /assets/assets/..., which fails at runtime as "Cannot open" and nowhere
    # earlier.
    BASE "assets"
    FILES
        assets/symbiote-64.png
        assets/symbiote-128.png
)

set(SYMBIOTE_QML
    qml/Main.qml
    qml/Theme.qml
    qml/Prefs.qml
    qml/components/Panel.qml
    qml/components/Brackets.qml
    qml/components/GlyphIcon.qml
    qml/components/AppLauncher.qml
    qml/components/BluetoothPanel.qml
    qml/components/ContextMenu.qml
    qml/components/WifiPopup.qml
    qml/components/BluetoothPopup.qml
    qml/components/SecondaryShell.qml
    qml/components/BatteryGauge.qml
    qml/components/PowerMenu.qml
    qml/components/AppIcon.qml
    qml/components/MediaPopup.qml
    qml/components/Notifications.qml
    qml/components/MicroReadout.qml
    qml/components/StatusList.qml
    qml/components/ProcessList.qml
    qml/components/Waveform.qml
    qml/components/Hologram.qml
    qml/components/DesktopIcons.qml
    qml/components/Taskbar.qml
    qml/components/SettingsWindow.qml
    qml/components/HudButton.qml
    qml/components/HudSlider.qml
    qml/components/HudToggle.qml
    qml/components/HudDropdown.qml
    qml/components/HudSegmented.qml
    qml/components/HudField.qml
    qml/components/SettingRow.qml
    qml/components/SettingGroup.qml
    qml/components/TraySheet.qml
    qml/components/NetworkPanel.qml
)
foreach(f IN LISTS SYMBIOTE_QML)
    get_filename_component(base "${f}" NAME)
    set_source_files_properties("${f}" PROPERTIES QT_RESOURCE_ALIAS "${base}")
endforeach()

# Theme is `pragma Singleton`; without this the engine refuses to resolve it.
set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/Prefs.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(symbiote-shell-qt
    URI Symbiote
    VERSION 1.0
    QML_FILES ${SYMBIOTE_QML}
)

target_link_libraries(symbiote-shell-qt PRIVATE
    Qt6::Core Qt6::Gui Qt6::Quick Qt6::Qml Qt6::DBus
    Qt6::GuiPrivate
    PkgConfig::WAYLAND_CLIENT
)

install(TARGETS symbiote-shell-qt RUNTIME DESTINATION /opt/symbiote/shell-qt)
