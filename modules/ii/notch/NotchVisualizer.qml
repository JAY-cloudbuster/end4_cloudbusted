import QtQuick
import qs
import qs.modules.common

// Tiny equalizer bars for the compact notch. Uses cava levels when available,
// otherwise fakes a gentle bounce while playing.
Row {
    id: root
    property bool playing: false
    property int barCount: 4
    property real barWidth: 3
    property real minBarHeight: 3
    property real maxBarHeight: 16
    property real maxVisualizerValue: 1000
    readonly property list<real> points: GlobalStates.visualizerPoints
    property var fakeLevels: [0.3, 0.6, 0.4, 0.8]

    spacing: 2
    height: maxBarHeight

    Timer {
        running: root.playing && root.points.length === 0
        interval: 180
        repeat: true
        onTriggered: root.fakeLevels = root.fakeLevels.map(() => 0.2 + Math.random() * 0.8)
    }

    Repeater {
        model: root.barCount
        delegate: Rectangle {
            required property int index
            anchors.verticalCenter: parent.verticalCenter
            width: root.barWidth
            radius: width / 2
            color: NotchPalette.accent
            height: {
                if (!root.playing) return root.minBarHeight
                let level
                if (root.points.length > 0) {
                    const idx = Math.floor(index * root.points.length / root.barCount)
                    level = (root.points[idx] ?? 0) / root.maxVisualizerValue
                } else {
                    level = root.fakeLevels[index % root.fakeLevels.length]
                }
                return Math.max(root.minBarHeight, Math.min(1, level) * root.maxBarHeight)
            }
            Behavior on height {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }
    }
}
