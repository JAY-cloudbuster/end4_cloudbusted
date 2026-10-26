pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Mac-style notch hugging the top edge.
 * Collapsed: black pill with the clock and a live activity on each side
 *            (volume/brightness, charging, running timer, media).
 * Expanded:  hover to peek, click to pin open. Tabs for home (calendar + tasks),
 *            media (all players), file shelf and timers.
 */
Item {
    id: root
    required property ShellScreen screen

    // Geometry
    readonly property real compactHeight: 32
    readonly property real headerHeight: 44
    readonly property real expandedWidth: 600
    readonly property real contentPadding: 16
    readonly property real earSize: 12
    readonly property real maxExpandedHeight: 360
    readonly property real compactRadius: 14
    readonly property real expandedRadius: 30

    // Expansion state
    property bool pinned: false
    property bool hoverOpen: false
    property bool dragHovering: false
    readonly property bool expanded: pinned || hoverOpen || dragHovering || dropHoldTimer.running
    property string currentTab: "home"

    readonly property var tabs: [
        { id: "home",   icon: "calendar_month", component: homeTab },
        { id: "media",  icon: "music_note",     component: mediaTab },
        { id: "shelf",  icon: "inventory_2",    component: shelfTab },
        { id: "timers", icon: "timer",          component: timersTab },
    ]

    // ── Live activity sources ─────────────────────────────────────────────
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool hasMedia: activePlayer !== null
        && ((activePlayer.trackTitle ?? "") !== "" || activePlayer.isPlaying)
    readonly property bool mediaPlaying: activePlayer?.isPlaying ?? false

    readonly property string runningTimer: TimerService.pomodoroRunning ? "pomodoro"
        : TimerService.countdownRunning ? "countdown"
        : TimerService.stopwatchRunning ? "stopwatch"
        : ""

    property string batteryAlert: "" // "charging", "low", "critical"
    Timer {
        id: batteryAlertTimer
        interval: 4000
        onTriggered: root.batteryAlert = ""
    }
    function showBatteryAlert(kind) {
        root.batteryAlert = kind
        batteryAlertTimer.restart()
    }
    Connections {
        target: Battery
        function onIsPluggedInChanged() {
            if (Battery.isPluggedIn) root.showBatteryAlert("charging")
        }
        function onIsLowAndNotChargingChanged() {
            if (Battery.isLowAndNotCharging && !Battery.isCriticalAndNotCharging) root.showBatteryAlert("low")
        }
        function onIsCriticalAndNotChargingChanged() {
            if (Battery.isCriticalAndNotCharging) root.showBatteryAlert("critical")
        }
    }

    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(root.screen)
    readonly property real osdValue: GlobalStates.osdIndicatorType === "brightness"
        ? (brightnessMonitor?.brightness ?? 0)
        : GlobalStates.osdIndicatorType === "gamma"
            ? (Hyprsunset.gamma ?? 100) / 100
            : (Audio.sink?.audio?.volume ?? 0)

    // Highest priority first
    readonly property string activity: GlobalStates.osdVolumeOpen ? "osd"
        : batteryAlert !== "" ? "battery"
        : FocusMode.active ? "focus"
        : runningTimer !== "" ? "timer"
        : hasMedia ? "media"
        : "idle"

    readonly property real sideWidth: ({
        "osd": 92,
        "battery": 60,
        "focus": 70,
        "timer": 70,
        "media": 46,
        "idle": 0,
    })[activity]

    // ── Helpers ───────────────────────────────────────────────────────────
    function osdIcon() {
        switch (GlobalStates.osdIndicatorType) {
            case "brightness": return "light_mode"
            case "gamma": return "wb_twilight"
        }
        if (Audio.sink?.audio?.muted || root.osdValue <= 0.001) return "volume_off"
        if (root.osdValue < 0.5) return "volume_down"
        return "volume_up"
    }

    function batteryIcon() {
        if (Battery.isCharging) return "battery_android_frame_bolt"
        const pct = Battery.percentage
        if (pct <= 0.1) return "battery_android_frame_alert"
        if (pct <= 0.2) return "battery_android_frame_1"
        if (pct <= 0.4) return "battery_android_frame_2"
        if (pct <= 0.6) return "battery_android_frame_3"
        if (pct <= 0.8) return "battery_android_frame_4"
        if (pct < 1) return "battery_android_frame_5"
        return "battery_android_full"
    }

    function batteryColor() {
        if (Battery.isCharging || Battery.isPluggedIn) return NotchPalette.success
        if (Battery.isCritical) return NotchPalette.error
        if (Battery.isLow) return NotchPalette.warning
        return NotchPalette.text
    }

    function timerIcon() {
        switch (root.runningTimer) {
            case "pomodoro": return TimerService.pomodoroBreak ? "coffee" : "self_improvement"
            case "countdown": return "hourglass_top"
            default: return "timer"
        }
    }

    function timerText() {
        switch (root.runningTimer) {
            case "pomodoro": return TimerService.formatSeconds(TimerService.pomodoroSecondsLeft)
            case "countdown": return TimerService.formatSeconds(TimerService.countdownSecondsLeft)
            default: return TimerService.formatSeconds(TimerService.stopwatchTime / 100)
        }
    }

    // ── Size ──────────────────────────────────────────────────────────────
    readonly property real compactWidth: clockText.implicitWidth + 32 + sideWidth * 2
    readonly property real expandedHeight: Math.min(root.maxExpandedHeight,
        root.headerHeight + (tabLoader.item?.implicitHeight ?? 0) + root.contentPadding)

    implicitWidth: root.expandedWidth + root.earSize * 2
    implicitHeight: root.maxExpandedHeight

    // ── Hover / pin behaviour ─────────────────────────────────────────────
    Timer {
        id: openTimer
        interval: Config.options.bar.notch.hoverOpenDelay
        onTriggered: root.hoverOpen = true
    }
    Timer {
        id: closeTimer
        interval: Config.options.bar.notch.hoverCloseDelay
        onTriggered: root.hoverOpen = false
    }
    // Keeps the shelf visible for a moment after a drop, since hover
    // events don't resume until the pointer moves again
    Timer {
        id: dropHoldTimer
        interval: 1500
    }

    // Exposed for the window's input mask
    readonly property Item hitArea: body

    // Ears: concave corners that melt the notch into the top edge
    RoundCorner {
        anchors {
            top: body.top
            right: body.left
        }
        implicitSize: root.earSize
        color: NotchPalette.background
        corner: RoundCorner.CornerEnum.TopRight
    }
    RoundCorner {
        anchors {
            top: body.top
            left: body.right
        }
        implicitSize: root.earSize
        color: NotchPalette.background
        corner: RoundCorner.CornerEnum.TopLeft
    }

    // The shadow fills under the body too, so it would make glass look solid
    StyledRectangularShadow {
        target: body
        visible: !NotchPalette.glass
        opacity: root.expanded ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 250 }
        }
    }

    Rectangle {
        id: body
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
        }
        width: root.expanded ? root.expandedWidth : root.compactWidth
        height: root.expanded ? root.expandedHeight : root.compactHeight
        color: NotchPalette.background
        clip: true

        property real bottomRadius: root.expanded ? root.expandedRadius : root.compactRadius
        radius: bottomRadius
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: bottomRadius
        bottomRightRadius: bottomRadius

        // Springy: the expressive curves overshoot slightly, then settle
        Behavior on width {
            NumberAnimation {
                duration: Appearance.animationCurves.expressiveDefaultSpatialDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: Appearance.animationCurves.expressiveDefaultSpatialDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
            }
        }
        Behavior on bottomRadius {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        HoverHandler {
            id: hoverHandler
            onHoveredChanged: {
                if (hovered) {
                    closeTimer.stop()
                    openTimer.restart()
                } else {
                    openTimer.stop()
                    closeTimer.restart()
                }
            }
        }

        // Clicking empty space toggles the pin. Buttons inside sit above this
        // and take their own clicks.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton || root.pinned) {
                    root.pinned = false
                } else {
                    root.pinned = true
                }
            }
        }

        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onEntered: (drag) => {
                drag.accepted = drag.hasUrls
                if (!drag.hasUrls) return
                root.dragHovering = true
                root.currentTab = "shelf"
            }
            onExited: root.dragHovering = false
            onDropped: (drop) => {
                root.dragHovering = false
                if (!drop.hasUrls) {
                    drop.accepted = false
                    return
                }
                DropShelf.addItems(drop.urls)
                drop.accept()
                dropHoldTimer.restart()
            }
        }

        // ── Clock (shared by both states, so it never jumps) ─────────────
        StyledText {
            id: clockText
            anchors.horizontalCenter: parent.horizontalCenter
            y: (root.expanded ? root.headerHeight : root.compactHeight) / 2 - height / 2
            text: DateTime.time
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: NotchPalette.text

            Behavior on y {
                NumberAnimation {
                    duration: Appearance.animationCurves.expressiveDefaultSpatialDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                }
            }
        }

        // ── Compact live activity ────────────────────────────────────────
        Item {
            id: compactContent
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: root.compactHeight
            opacity: root.expanded ? 0 : 1
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }

            Loader {
                anchors {
                    left: parent.left
                    leftMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                sourceComponent: ({
                    "osd": osdLeft,
                    "battery": batteryLeft,
                    "focus": focusLeft,
                    "timer": timerLeft,
                    "media": mediaLeft,
                })[root.activity] ?? null
            }

            Loader {
                anchors {
                    right: parent.right
                    rightMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                sourceComponent: ({
                    "osd": osdRight,
                    "battery": batteryRight,
                    "focus": focusRight,
                    "timer": timerRight,
                    "media": mediaRight,
                })[root.activity] ?? null
            }
        }

        // ── Expanded ─────────────────────────────────────────────────────
        Item {
            id: expandedContent
            width: root.expandedWidth
            height: root.expandedHeight
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: root.expanded ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation { duration: root.expanded ? 300 : 120 }
            }

            // Header: tabs | clock | battery + pin
            RowLayout {
                anchors {
                    left: parent.left
                    leftMargin: root.contentPadding - 4
                    top: parent.top
                    topMargin: (root.headerHeight - 32) / 2
                }
                spacing: 2

                Repeater {
                    model: root.tabs
                    delegate: NotchIconButton {
                        required property var modelData
                        icon: modelData.icon
                        iconSize: 18
                        toggled: root.currentTab === modelData.id
                        onClicked: root.currentTab = modelData.id
                    }
                }
            }

            RowLayout {
                anchors {
                    right: parent.right
                    rightMargin: root.contentPadding - 4
                    top: parent.top
                    topMargin: (root.headerHeight - 32) / 2
                }
                spacing: 6

                RowLayout {
                    visible: Battery.available
                    spacing: 2
                    MaterialSymbol {
                        text: root.batteryIcon()
                        iconSize: 18
                        fill: 1
                        color: root.batteryColor()
                    }
                    StyledText {
                        text: `${Math.round(Battery.percentage * 100)}%`
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.features: { "tnum": 1 }
                        color: root.batteryColor()
                    }
                }

                NotchIconButton {
                    icon: "do_not_disturb_on"
                    iconSize: 18
                    toggled: FocusMode.active
                    onClicked: FocusMode.toggle()
                }

                NotchIconButton {
                    icon: "push_pin"
                    iconSize: 18
                    toggled: root.pinned
                    onClicked: root.pinned = !root.pinned
                }
            }

            Loader {
                id: tabLoader
                anchors {
                    top: parent.top
                    topMargin: root.headerHeight
                    left: parent.left
                    right: parent.right
                    leftMargin: root.contentPadding
                    rightMargin: root.contentPadding
                }
                // Keep loaded while collapsed so the height is known before expanding
                sourceComponent: root.tabs.find(t => t.id === root.currentTab)?.component ?? homeTab

                onLoaded: {
                    tabSwitchAnim.restart()
                    if (item) item.width = Qt.binding(() => tabLoader.width)
                }

                ParallelAnimation {
                    id: tabSwitchAnim
                    NumberAnimation { target: tabLoader; property: "opacity"; from: 0; to: 1; duration: 200 }
                    NumberAnimation {
                        target: tabLoader; property: "anchors.topMargin"
                        from: root.headerHeight + 8; to: root.headerHeight
                        duration: 300; easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    // ── Tabs ──────────────────────────────────────────────────────────────
    Component { id: homeTab; NotchHomeTab {} }
    Component { id: mediaTab; NotchMediaTab {} }
    Component { id: shelfTab; NotchShelfTab { dragHovering: root.dragHovering } }
    Component { id: timersTab; NotchTimersTab {} }

    // ── Compact slots ─────────────────────────────────────────────────────
    Component {
        id: osdLeft
        MaterialSymbol {
            text: root.osdIcon()
            iconSize: 18
            fill: 1
            color: NotchPalette.text
        }
    }
    Component {
        id: osdRight
        Rectangle {
            implicitWidth: 64
            implicitHeight: 6
            radius: 3
            color: NotchPalette.surfaceHover
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.osdValue))
                height: parent.height
                radius: parent.radius
                color: NotchPalette.text
                Behavior on width {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    Component {
        id: batteryLeft
        MaterialSymbol {
            text: root.batteryAlert === "charging" ? "bolt" : root.batteryIcon()
            iconSize: 18
            fill: 1
            color: root.batteryColor()
        }
    }
    Component {
        id: batteryRight
        StyledText {
            text: `${Math.round(Battery.percentage * 100)}%`
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: root.batteryColor()
        }
    }

    Component {
        id: focusLeft
        MaterialSymbol {
            text: TimerService.pomodoroBreak ? "coffee" : "do_not_disturb_on"
            iconSize: 18
            fill: 1
            color: NotchPalette.accent
        }
    }
    Component {
        id: focusRight
        StyledText {
            text: TimerService.formatSeconds(TimerService.pomodoroSecondsLeft)
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: NotchPalette.accent
        }
    }

    Component {
        id: timerLeft
        MaterialSymbol {
            text: root.timerIcon()
            iconSize: 18
            fill: 1
            color: NotchPalette.accent
        }
    }
    Component {
        id: timerRight
        StyledText {
            text: root.timerText()
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: NotchPalette.accent
        }
    }

    Component {
        id: mediaLeft
        Rectangle {
            id: miniArt
            readonly property string artUrl: root.activePlayer?.trackArtUrl ?? ""
            implicitWidth: 22
            implicitHeight: 22
            radius: 6
            color: NotchPalette.surfaceHigh

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: miniArt.width
                    height: miniArt.height
                    radius: miniArt.radius
                }
            }

            StyledImage {
                anchors.fill: parent
                visible: miniArt.artUrl !== ""
                source: miniArt.artUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 44
                sourceSize.height: 44
            }
            MaterialSymbol {
                anchors.centerIn: parent
                visible: miniArt.artUrl === ""
                text: "music_note"
                iconSize: 14
                color: NotchPalette.textDim
            }
        }
    }
    Component {
        id: mediaRight
        NotchVisualizer {
            playing: root.mediaPlaying
        }
    }
}
