pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Focus mode: Do Not Disturb + a fresh pomodoro focus round in one toggle.
 * Stopping restores the previous Do Not Disturb state and pauses the pomodoro.
 * State lives in Persistent so a shell reload doesn't drop you out of focus.
 */
Singleton {
    id: root
    readonly property bool active: Persistent.states.focus.active

    function start() {
        if (root.active) return
        Persistent.states.focus.previousSilent = Notifications.silent
        Persistent.states.focus.active = true
        Notifications.silent = true
        TimerService.resetPomodoro()
        TimerService.togglePomodoro()
    }

    function stop() {
        if (!root.active) return
        Persistent.states.focus.active = false
        Notifications.silent = Persistent.states.focus.previousSilent
        if (TimerService.pomodoroRunning) TimerService.togglePomodoro() // pause, keep progress
    }

    function toggle() {
        if (root.active) root.stop()
        else root.start()
    }

    // Called from shell.qml so the shortcut is registered at startup
    function load() {}

    // Do Not Disturb isn't persisted on its own, so re-apply it after a reload
    function reapply() {
        if (Persistent.ready && root.active) Notifications.silent = true
    }
    Component.onCompleted: root.reapply()
    Connections {
        target: Persistent
        function onReadyChanged() { root.reapply() }
    }

    CompositorGlobalShortcut {
        name: "focusModeToggle"
        description: "Toggle focus mode (Do Not Disturb + pomodoro)"
        onPressed: root.toggle()
    }

    IpcHandler {
        target: "focusMode"

        function toggle(): void { root.toggle() }
        function start(): void { root.start() }
        function stop(): void { root.stop() }
    }
}
