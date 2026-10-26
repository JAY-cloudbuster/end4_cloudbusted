import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Pomodoro, countdown and stopwatch, shared with the sidebar timers (TimerService)
RowLayout {
    id: root
    spacing: 8

    function stopwatchText() {
        const t = TimerService.stopwatchTime // 10ms units
        const cs = (t % 100).toString().padStart(2, "0")
        return `${TimerService.formatSeconds(Math.floor(t / 100))}.${cs}`
    }

    component TimerCard: Rectangle {
        id: card
        property string icon
        property string title
        property string timeText
        property bool running
        default property alias buttons: buttonRow.data

        Layout.fillWidth: true
        Layout.preferredWidth: 1 // equal widths
        implicitHeight: 128
        radius: Appearance.rounding.normal + 4
        color: NotchPalette.surface
        border.width: running ? 1 : 0
        border.color: NotchPalette.accent

        ColumnLayout {
            anchors {
                fill: parent
                margins: 10
            }
            spacing: 2

            RowLayout {
                spacing: 6
                MaterialSymbol {
                    text: card.icon
                    iconSize: 18
                    fill: card.running ? 1 : 0
                    color: card.running ? NotchPalette.accent : NotchPalette.textDim
                }
                StyledText {
                    text: card.title
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: NotchPalette.textDim
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: card.timeText
                font.pixelSize: 30
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: NotchPalette.text
            }

            RowLayout {
                id: buttonRow
                Layout.alignment: Qt.AlignRight
                spacing: 2
            }
        }
    }

    TimerCard {
        icon: TimerService.pomodoroBreak ? "coffee" : "self_improvement"
        title: TimerService.pomodoroLongBreak ? Translation.tr("Long break")
            : TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Focus")
        timeText: TimerService.formatSeconds(TimerService.pomodoroSecondsLeft)
        running: TimerService.pomodoroRunning

        NotchIconButton {
            icon: "restart_alt"
            onClicked: TimerService.resetPomodoro()
        }
        NotchIconButton {
            icon: TimerService.pomodoroRunning ? "pause" : "play_arrow"
            toggled: true
            onClicked: TimerService.togglePomodoro()
        }
    }

    TimerCard {
        icon: "hourglass_top"
        title: Translation.tr("Timer")
        timeText: TimerService.formatSeconds(TimerService.countdownSecondsLeft)
        running: TimerService.countdownRunning

        NotchTextButton {
            implicitHeight: 28
            text: "+1"
            onClicked: TimerService.addCountdownMinutes(1)
        }
        NotchTextButton {
            implicitHeight: 28
            text: "+5"
            onClicked: TimerService.addCountdownMinutes(5)
        }
        NotchIconButton {
            icon: "restart_alt"
            onClicked: TimerService.resetCountdown()
        }
        NotchIconButton {
            icon: TimerService.countdownRunning ? "pause" : "play_arrow"
            toggled: true
            enabled: TimerService.countdownDuration > 0
            onClicked: TimerService.toggleCountdown()
        }
    }

    TimerCard {
        icon: "timer"
        title: Translation.tr("Stopwatch")
        timeText: root.stopwatchText()
        running: TimerService.stopwatchRunning

        NotchIconButton {
            icon: "restart_alt"
            onClicked: TimerService.stopwatchReset()
        }
        NotchIconButton {
            icon: TimerService.stopwatchRunning ? "pause" : "play_arrow"
            toggled: true
            onClicked: TimerService.toggleStopwatch()
        }
    }
}
