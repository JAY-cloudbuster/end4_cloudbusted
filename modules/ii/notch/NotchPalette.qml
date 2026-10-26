pragma Singleton
import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.functions

// The notch is always dark like real hardware, so it uses its own fixed
// light-on-dark palette instead of the light/dark theme layers.
// Accents still follow the wallpaper via the "fixed" Material tones,
// which stay light in both light and dark mode.
Singleton {
    // Frosted glass: a translucent fill that Hyprland blurs behind (layer rule
    // for quickshell:.*), same as the bar and sidebars when transparency is on
    readonly property bool glass: Config.options.bar.notch.glass
        && Config.options.appearance.transparency.enable
    readonly property real glassOpacity: Math.max(0.8, Math.min(1, Config.options.bar.notch.glassOpacity))
    // Wallpaper-tinted dark in dark mode; near-black in light mode so text stays readable
    readonly property color glassTint: Appearance.m3colors.darkmode ? Appearance.colors.colLayer0Base : "#101012"

    readonly property color background: glass
        ? ColorUtils.transparentize(glassTint, 1 - glassOpacity)
        : "#000000"
    // Translucent white layers read as raised glass on any background
    readonly property color surface: Qt.rgba(1, 1, 1, 0.07)
    readonly property color surfaceHigh: Qt.rgba(1, 1, 1, 0.11)
    readonly property color surfaceHover: Qt.rgba(1, 1, 1, 0.16)
    readonly property color text: "#ffffff"
    readonly property color textDim: "#a5a5ab"
    readonly property color accent: Appearance.m3colors.m3primaryFixedDim
    readonly property color onAccent: Appearance.m3colors.m3onPrimaryFixed
    readonly property color success: "#34c759"
    readonly property color warning: "#ff9f0a"
    readonly property color error: "#ff453a"
}
