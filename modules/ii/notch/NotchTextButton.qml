import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root
    property string icon: ""
    property string text: ""
    property bool primary: false
    signal clicked()

    implicitWidth: row.implicitWidth + 24
    implicitHeight: 32
    radius: height / 2
    opacity: enabled ? 1 : 0.4
    color: primary
        ? NotchPalette.accent
        : (mouseArea.containsMouse ? NotchPalette.surfaceHover : NotchPalette.surfaceHigh)

    Behavior on color {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
        MaterialSymbol {
            visible: root.icon !== ""
            text: root.icon
            iconSize: 16
            color: root.primary ? NotchPalette.onAccent : NotchPalette.text
        }
        StyledText {
            text: root.text
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: root.primary ? NotchPalette.onAccent : NotchPalette.text
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onPressed: root.scale = 0.94
        onReleased: root.scale = 1
        onCanceled: root.scale = 1
    }

    Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutBack }
    }
}
