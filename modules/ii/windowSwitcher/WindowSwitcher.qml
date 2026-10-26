pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Alt+Tab window switcher with live previews.
 * Hold Alt, tap Tab (Shift+Tab backwards) to cycle, release Alt to switch.
 * The Alt release comes from a Hyprland release bind (windowSwitcherRelease).
 */
Scope {
    id: root
    property bool open: false
    property int selectedIndex: 0
    // Snapshot taken on open, so the order doesn't shuffle while cycling
    property var windows: []

    readonly property real previewHeight: 150
    readonly property real cardPadding: 8

    function snapshotWindows() {
        return HyprlandData.windowList
            .filter(w => w.mapped && !w.hidden)
            .slice()
            .sort((a, b) => a.focusHistoryID - b.focusHistoryID) // most recent first
    }

    function step(delta) {
        if (!root.open) {
            root.windows = root.snapshotWindows()
            if (root.windows.length === 0) return
            // First Tab goes to the previous window, Shift+Tab to the oldest
            root.selectedIndex = root.windows.length === 1 ? 0
                : delta > 0 ? 1 : root.windows.length - 1
            root.open = true
            return
        }
        const n = root.windows.length
        if (n === 0) return
        root.selectedIndex = (root.selectedIndex + delta + n) % n
    }

    function confirm() {
        if (!root.open) return
        const win = root.windows[root.selectedIndex]
        root.open = false
        // Focus after the switcher gives keyboard focus back
        if (win && HyprlandData.windowByAddress[win.address])
            Qt.callLater(() => WM.focusWindow(win.address))
    }

    function cancel() {
        root.open = false
    }

    function workspaceLabel(win) {
        const name = win.workspace?.name ?? ""
        if (name.startsWith("special:")) return name.slice(8) === "special" ? "S" : name.slice(8, 9).toUpperCase()
        return `${win.workspace?.id ?? ""}`
    }

    LazyLoader {
        active: root.open

        component: PanelWindow {
            id: switcherWindow
            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:windowSwitcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // Click outside to cancel
            MouseArea {
                anchors.fill: parent
                onClicked: root.cancel()
            }

            Item {
                id: keyHandler
                anchors.fill: parent
                focus: true
                Keys.onPressed: (event) => {
                    switch (event.key) {
                    case Qt.Key_Escape: root.cancel(); break
                    case Qt.Key_Return:
                    case Qt.Key_Enter: root.confirm(); break
                    case Qt.Key_Right:
                    case Qt.Key_Tab: root.step(1); break
                    case Qt.Key_Left:
                    case Qt.Key_Backtab: root.step(-1); break
                    default: return
                    }
                    event.accepted = true
                }
                // Backup for the Hyprland release bind
                Keys.onReleased: (event) => {
                    if (event.key === Qt.Key_Alt) root.confirm()
                }
            }

            StyledRectangularShadow {
                target: panel
            }

            Rectangle {
                id: panel
                anchors.centerIn: parent
                width: cardList.width + root.cardPadding * 2 + 16
                height: cardList.height + root.cardPadding * 2 + 16
                radius: Appearance.rounding.screenRounding
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                // Swallow clicks so they don't cancel
                MouseArea {
                    anchors.fill: parent
                }

                ListView {
                    id: cardList
                    anchors.centerIn: parent
                    width: Math.min(contentWidth, switcherWindow.width - 80 - root.cardPadding * 2 - 16)
                    height: root.previewHeight + root.cardPadding * 2 + 30
                    orientation: ListView.Horizontal
                    spacing: 6
                    clip: true
                    model: root.windows
                    currentIndex: root.selectedIndex
                    highlightFollowsCurrentItem: true
                    highlightMoveDuration: 150
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property bool selected: index === root.selectedIndex
                        readonly property var toplevel: ToplevelManager.toplevels.values.find(
                            t => `0x${t.HyprlandToplevel?.address}` === modelData.address) ?? null
                        readonly property real aspect: Math.max(0.6, Math.min(2.2,
                            (modelData.size?.[0] ?? 16) / Math.max(1, modelData.size?.[1] ?? 9)))

                        width: root.previewHeight * aspect + root.cardPadding * 2
                        height: ListView.view.height
                        radius: Appearance.rounding.large
                        color: selected ? Appearance.colors.colSecondaryContainer
                            : cardMouse.containsMouse ? Appearance.colors.colLayer1Hover
                            : "transparent"

                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.selectedIndex = card.index
                            onClicked: {
                                root.selectedIndex = card.index
                                root.confirm()
                            }
                        }

                        ColumnLayout {
                            anchors {
                                fill: parent
                                margins: root.cardPadding
                            }
                            spacing: 6

                            Rectangle {
                                id: previewFrame
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.previewHeight
                                radius: Appearance.rounding.normal
                                color: Appearance.colors.colLayer1

                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle {
                                        width: previewFrame.width
                                        height: previewFrame.height
                                        radius: previewFrame.radius
                                    }
                                }

                                ScreencopyView {
                                    id: preview
                                    anchors.fill: parent
                                    captureSource: card.toplevel
                                    live: true
                                }

                                // Fallback when there's no capture yet
                                IconImage {
                                    anchors.centerIn: parent
                                    visible: !preview.hasContent
                                    implicitSize: 56
                                    source: Quickshell.iconPath(AppSearch.guessIcon(card.modelData.class), "image-missing")
                                }

                                // Workspace badge (skipped for odd internal ids)
                                Rectangle {
                                    visible: wsText.text.length > 0 && wsText.text.length <= 3
                                    anchors {
                                        top: parent.top
                                        right: parent.right
                                        margins: 6
                                    }
                                    implicitWidth: Math.max(22, wsText.implicitWidth + 10)
                                    implicitHeight: 22
                                    radius: height / 2
                                    color: Appearance.colors.colLayer0
                                    StyledText {
                                        id: wsText
                                        anchors.centerIn: parent
                                        text: root.workspaceLabel(card.modelData)
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colOnLayer0
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                IconImage {
                                    implicitSize: 18
                                    source: Quickshell.iconPath(AppSearch.guessIcon(card.modelData.class), "image-missing")
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: card.modelData.title || card.modelData.class
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: card.selected ? Font.DemiBold : Font.Normal
                                    color: card.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer0
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    CompositorGlobalShortcut {
        name: "windowSwitcherNext"
        description: "Window switcher: next window"
        onPressed: root.step(1)
    }

    CompositorGlobalShortcut {
        name: "windowSwitcherPrev"
        description: "Window switcher: previous window"
        onPressed: root.step(-1)
    }

    CompositorGlobalShortcut {
        name: "windowSwitcherRelease"
        description: "Window switcher: switch to selection (bind to Alt release)"
        onPressed: root.confirm()
    }

    IpcHandler {
        target: "windowSwitcher"

        function next(): void { root.step(1) }
        function prev(): void { root.step(-1) }
        function confirm(): void { root.confirm() }
        function cancel(): void { root.cancel() }
    }
}
