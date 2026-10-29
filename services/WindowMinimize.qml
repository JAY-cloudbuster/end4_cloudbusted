pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Makes apps' minimize buttons work on Hyprland, which has no minimized state.
 * A minimize request moves the window to a hidden special workspace; focusing it again
 * from anywhere (Alt+Tab, launcher, dock) moves it back to the current workspace.
 * Maximize/restore is handled on the Hyprland side (custom/productivity.lua).
 */
Singleton {
    id: root
    readonly property string workspaceName: "special:minimized"

    // Called from shell.qml so the event listener is active from startup
    function load() {}

    // Hyprland events give addresses without the 0x prefix
    function normalizeAddress(address) {
        return address.startsWith("0x") ? address : `0x${address}`
    }

    // Windows this service minimized. Tracked here instead of reading HyprlandData, whose
    // cached window list can lag behind events: a stale "still minimized" answer made
    // restore() re-focus the window, which fired another focus event, in a loop.
    property var minimizedAddresses: []

    function isMinimized(address) {
        return root.minimizedAddresses.includes(root.normalizeAddress(address))
    }

    function minimize(address) {
        const normalized = root.normalizeAddress(address)
        if (!root.isMinimized(normalized)) root.minimizedAddresses = [...root.minimizedAddresses, normalized]
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${root.workspaceName}", follow = false, window = "address:${normalized}" })`)
    }

    function restore(address) {
        const normalized = root.normalizeAddress(address)
        // Forget it first so the focus event this causes can't trigger another restore
        root.minimizedAddresses = root.minimizedAddresses.filter(a => a !== normalized)
        const target = HyprlandData.monitors.find(m => m.focused)?.activeWorkspace?.id ?? HyprlandData.activeWorkspace?.id
        if (target === undefined) return
        const window = `address:${normalized}`
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${target}, window = "${window}" })`)
        Hyprland.dispatch(`hl.dsp.focus({ window = "${window}" })`)
    }

    IpcHandler {
        target: "windowMinimize"

        // For a "minimize" keybind; restore by focusing it (Alt+Tab, launcher, dock)
        function minimizeActive(): void {
            const address = HyprlandData.windowList.find(w => w.focusHistoryID === 0)?.address
            if (address) root.minimize(address)
        }
        function minimize(address: string): void { root.minimize(address) }
        function restore(address: string): void { root.restore(address) }
    }

    Connections {
        target: WM.compositor === "hyprland" ? Hyprland : null
        function onRawEvent(event) {
            if (event.name === "minimized") {
                // data: ADDRESS,0|1
                const [address, state] = event.data.split(",")
                if (state === "1") root.minimize(address)
            } else if (event.name === "activewindowv2") {
                // Focusing a minimized window from anywhere un-minimizes it
                if (event.data && root.isMinimized(event.data)) root.restore(event.data)
            } else if (event.name === "closewindow") {
                root.minimizedAddresses = root.minimizedAddresses.filter(a => a !== root.normalizeAddress(event.data))
            }
        }
    }
}
