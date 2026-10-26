pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Drop files on the notch to park them here, drag them back out later.
// Shares its items with the desktop drop shelf (DropShelf service).
ColumnLayout {
    id: root
    property bool dragHovering: false
    readonly property real tileSize: 84

    spacing: 8

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: root.tileSize + 16
        radius: Appearance.rounding.normal + 4
        color: root.dragHovering ? NotchPalette.surfaceHigh : NotchPalette.surface
        border.width: root.dragHovering ? 2 : 0
        border.color: NotchPalette.accent

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        ColumnLayout {
            anchors.centerIn: parent
            visible: DropShelf.items.length === 0
            spacing: 2
            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: root.dragHovering ? "download" : "inventory_2"
                iconSize: 30
                color: root.dragHovering ? NotchPalette.accent : NotchPalette.textDim
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: root.dragHovering ? Translation.tr("Drop to add") : Translation.tr("Drag files onto the notch to keep them here")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: NotchPalette.textDim
            }
        }

        ListView {
            anchors {
                fill: parent
                margins: 8
            }
            visible: DropShelf.items.length > 0
            orientation: ListView.Horizontal
            spacing: 8
            clip: true
            model: DropShelf.items

            delegate: Item {
                id: tile
                required property string modelData
                readonly property string path: modelData
                readonly property string fileName: path.replace(/\/$/, "").split("/").pop()
                readonly property bool isImage: /\.(png|jpe?g|webp|bmp|gif|svg)$/i.test(path)

                width: root.tileSize
                height: root.tileSize

                Rectangle {
                    id: tileBg
                    width: tile.width
                    height: tile.height
                    radius: Appearance.rounding.normal
                    color: NotchPalette.surfaceHigh

                    Drag.active: dragArea.drag.active
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction
                    Drag.mimeData: { "text/uri-list": "file://" + tile.path }

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: tileBg.width
                            height: tileBg.height
                            radius: tileBg.radius
                        }
                    }

                    StyledImage {
                        anchors.fill: parent
                        visible: tile.isImage
                        source: tile.isImage ? "file://" + tile.path : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: root.tileSize * 2
                        sourceSize.height: root.tileSize * 2
                        asynchronous: true
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        visible: !tile.isImage
                        spacing: 2
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.path.endsWith("/") ? "folder" : "draft"
                            iconSize: 30
                            color: NotchPalette.accent
                        }
                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: tile.fileName
                            elide: Text.ElideMiddle
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: NotchPalette.text
                        }
                    }

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        drag.target: tileBg
                        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        onReleased: {
                            if (tileBg.Drag.active) tileBg.Drag.drop()
                            tileBg.x = 0
                            tileBg.y = 0
                        }
                    }
                }

                NotchIconButton {
                    anchors {
                        top: parent.top
                        right: parent.right
                        margins: 3
                    }
                    implicitWidth: 22
                    implicitHeight: 22
                    visible: dragArea.containsMouse || hovered
                    icon: "close"
                    iconSize: 14
                    colBackground: "#cc000000"
                    onClicked: DropShelf.removeItem(tile.path)
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: DropShelf.items.length > 0

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("%1 items").arg(DropShelf.items.length)
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: NotchPalette.textDim
        }

        NotchTextButton {
            icon: "content_copy"
            text: Translation.tr("Copy all")
            onClicked: DropShelf.copyAll()
        }
        NotchTextButton {
            icon: "delete_sweep"
            text: Translation.tr("Clear")
            onClicked: DropShelf.clear()
        }
    }
}
