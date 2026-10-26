import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root
    property string icon: ""
    property real iconSize: 20
    property bool toggled: false
    property bool filled: toggled
    property color colIcon: toggled ? NotchPalette.onAccent : NotchPalette.text
    property color colBackground: "transparent"
    property color colBackgroundHover: NotchPalette.surfaceHover
    property color colBackgroundToggled: NotchPalette.accent
    readonly property bool hovered: mouseArea.containsMouse
    signal clicked()

    implicitWidth: 32
    implicitHeight: 32
    radius: height / 2
    opacity: enabled ? 1 : 0.4
    color: toggled ? colBackgroundToggled : (mouseArea.containsMouse ? colBackgroundHover : colBackground)

    Behavior on color {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: root.icon
        iconSize: root.iconSize
        fill: root.filled ? 1 : 0
        color: root.colIcon
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        // Squish a little on press, like the rest of the notch
        onPressed: root.scale = 0.9
        onReleased: root.scale = 1
        onCanceled: root.scale = 1
    }

    Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutBack }
    }
}
