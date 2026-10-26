import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Calendar week + pending tasks (what the old clock popup showed)
RowLayout {
    id: root
    property var today: new Date()
    readonly property var pendingTasks: Todo.list.filter(t => !t.done)

    spacing: 16

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.today = new Date()
    }

    // Calendar
    ColumnLayout {
        Layout.alignment: Qt.AlignTop
        spacing: 8

        Row {
            StyledText {
                text: Qt.locale().toString(root.today, "MMMM")
                font.pixelSize: Appearance.font.pixelSize.huge
                font.weight: Font.Bold
                color: NotchPalette.text
            }
            StyledText {
                text: " " + Qt.locale().toString(root.today, "yyyy")
                font.pixelSize: Appearance.font.pixelSize.huge
                color: NotchPalette.textDim
            }
        }

        RowLayout {
            spacing: 4

            Repeater {
                model: 7
                delegate: Rectangle {
                    id: dayCell
                    required property int index
                    readonly property var date: {
                        const d = new Date(root.today)
                        d.setDate(root.today.getDate() - root.today.getDay() + index)
                        return d
                    }
                    readonly property bool isToday: date.toDateString() === root.today.toDateString()

                    implicitWidth: 38
                    implicitHeight: 56
                    radius: Appearance.rounding.normal
                    color: isToday ? NotchPalette.accent : NotchPalette.surface

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Qt.locale().toString(dayCell.date, "ddd").slice(0, 2)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: dayCell.isToday ? Font.Bold : Font.Normal
                            color: dayCell.isToday ? NotchPalette.onAccent : NotchPalette.textDim
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: dayCell.date.getDate()
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: dayCell.isToday ? Font.Bold : Font.Normal
                            color: dayCell.isToday ? NotchPalette.onAccent : NotchPalette.text
                        }
                    }
                }
            }
        }

        RowLayout {
            spacing: 6
            MaterialSymbol {
                text: "timelapse"
                iconSize: Appearance.font.pixelSize.small
                color: NotchPalette.textDim
            }
            StyledText {
                text: Translation.tr("Up %1").arg(DateTime.uptime)
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: NotchPalette.textDim
            }
        }
    }

    // Tasks
    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: 4

        RowLayout {
            Layout.bottomMargin: 4
            spacing: 6
            MaterialSymbol {
                text: "checklist"
                iconSize: Appearance.font.pixelSize.larger
                color: NotchPalette.accent
            }
            StyledText {
                text: Translation.tr("Tasks")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: NotchPalette.text
            }
            StyledText {
                text: root.pendingTasks.length
                font.pixelSize: Appearance.font.pixelSize.normal
                color: NotchPalette.textDim
            }
        }

        Repeater {
            id: taskRepeater
            // Newest first, at most 3
            model: root.pendingTasks.slice(-3).reverse()

            delegate: Rectangle {
                id: taskRow
                required property var modelData
                required property int index
                readonly property bool isFirst: index === 0
                readonly property bool isLast: index === taskRepeater.count - 1
                readonly property real bigRadius: Appearance.rounding.normal
                readonly property real smallRadius: Appearance.rounding.unsharpenmore

                Layout.fillWidth: true
                implicitHeight: 32
                topLeftRadius: isFirst ? bigRadius : smallRadius
                topRightRadius: isFirst ? bigRadius : smallRadius
                bottomLeftRadius: isLast ? bigRadius : smallRadius
                bottomRightRadius: isLast ? bigRadius : smallRadius
                color: NotchPalette.surface

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 6
                        rightMargin: 10
                    }
                    spacing: 6

                    NotchIconButton {
                        implicitWidth: 24
                        implicitHeight: 24
                        icon: hovered ? "check_circle" : "radio_button_unchecked"
                        iconSize: 18
                        colIcon: NotchPalette.accent
                        colBackgroundHover: "transparent"
                        onClicked: Todo.markDone(Todo.list.indexOf(taskRow.modelData))
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: taskRow.modelData.content
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: NotchPalette.text
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 64
            visible: root.pendingTasks.length === 0
            radius: Appearance.rounding.normal
            color: NotchPalette.surface

            StyledText {
                anchors.centerIn: parent
                text: Translation.tr("No pending tasks")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: NotchPalette.textDim
            }
        }
    }
}
