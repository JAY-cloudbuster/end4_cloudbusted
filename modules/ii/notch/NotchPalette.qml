pragma Singleton
import QtQuick
import Quickshell
import qs.modules.common

// The notch is always black like real hardware, so it uses its own fixed
// light-on-black palette instead of the light/dark theme layers.
// Accents still follow the wallpaper via the "fixed" Material tones,
// which stay light in both light and dark mode.
Singleton {
    readonly property color background: "#000000"
    readonly property color surface: "#161618"
    readonly property color surfaceHigh: "#242427"
    readonly property color surfaceHover: "#2e2e32"
    readonly property color text: "#ffffff"
    readonly property color textDim: "#9b9ba1"
    readonly property color accent: Appearance.m3colors.m3primaryFixedDim
    readonly property color onAccent: Appearance.m3colors.m3onPrimaryFixed
    readonly property color success: "#34c759"
    readonly property color warning: "#ff9f0a"
    readonly property color error: "#ff453a"
}
