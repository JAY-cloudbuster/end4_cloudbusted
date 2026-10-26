pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common

Scope {
    id: root
    // tab: "" keeps the current one
    signal togglePinRequested(tab: string)

    Variants {
        // Same monitors as the bar
        model: {
            const screens = Quickshell.screens;
            const list = Config.options.bar.screenList;
            if (!list || list.length === 0)
                return screens;
            return screens.filter(screen => list.includes(screen.name));
        }

        LazyLoader {
            id: notchLoader
            required property ShellScreen modelData
            active: GlobalStates.notchActive && GlobalStates.barOpen
                && !GlobalStates.screenLocked && !GlobalStates.startupLockPending

            component: PanelWindow {
                id: notchWindow
                screen: notchLoader.modelData

                property var monitorData: HyprlandData.monitors.find(m => m.name === notchWindow.screen?.name)
                property bool monitorHasFullscreen: HyprlandData.workspaceById[monitorData?.activeWorkspace?.id]?.hasfullscreen ?? false

                // Overlay so it sits above the bar; hidden for fullscreen apps instead
                visible: !monitorHasFullscreen
                WlrLayershell.namespace: "quickshell:notch"
                WlrLayershell.layer: WlrLayer.Overlay
                exclusionMode: ExclusionMode.Ignore
                exclusiveZone: 0
                color: "transparent"

                // Anchored to the top only, so it is centered horizontally
                anchors.top: true
                implicitWidth: notchBody.implicitWidth + Appearance.sizes.elevationMargin * 2
                implicitHeight: notchBody.implicitHeight + Appearance.sizes.elevationMargin

                // Only the visible notch takes input; the rest of the window clicks through
                mask: Region {
                    item: notchBody.hitArea
                }

                Connections {
                    target: root
                    function onTogglePinRequested(tab) {
                        // Only the notch on the focused monitor reacts
                        if (Hyprland.focusedMonitor?.name !== notchWindow.screen?.name) return
                        if (tab !== "") {
                            notchBody.currentTab = tab
                            notchBody.pinned = true
                        } else {
                            notchBody.pinned = !notchBody.pinned
                        }
                    }
                }

                NotchBody {
                    id: notchBody
                    screen: notchWindow.screen
                    anchors {
                        top: parent.top
                        horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "notch"

        function toggle(): void {
            Config.options.bar.notch.enable = !Config.options.bar.notch.enable
        }

        // Pin/unpin the expanded notch on the focused monitor
        function togglePin(): void {
            root.togglePinRequested("")
        }

        // Pin open on a tab: home, media, shelf, timers
        function open(tab: string): void {
            root.togglePinRequested(tab)
        }
    }
}
