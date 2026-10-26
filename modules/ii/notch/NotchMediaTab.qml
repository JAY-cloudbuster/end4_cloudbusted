pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Mpris
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Every running media player, not just the active one
Item {
    id: root
    readonly property var players: MprisController.players
    readonly property real cardHeight: 76
    readonly property real cardSpacing: 6
    readonly property int maxVisibleCards: 3

    implicitHeight: players.length === 0
        ? 96
        : Math.min(players.length, maxVisibleCards) * (cardHeight + cardSpacing) - cardSpacing

    // Mpris doesn't push position updates, so poll while visible
    Timer {
        running: root.visible && root.players.some(p => p.isPlaying)
        interval: 1000
        repeat: true
        onTriggered: root.players.forEach(p => { if (p.isPlaying) p.positionChanged() })
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: root.players.length === 0
        spacing: 4
        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "music_off"
            iconSize: 32
            color: NotchPalette.textDim
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Translation.tr("Nothing playing")
            color: NotchPalette.textDim
        }
    }

    StyledListView {
        anchors.fill: parent
        visible: root.players.length > 0
        clip: true
        spacing: root.cardSpacing
        model: root.players

        delegate: Rectangle {
            id: card
            required property MprisPlayer modelData
            readonly property MprisPlayer player: modelData
            readonly property bool isActive: player === MprisController.activePlayer
            readonly property string artUrl: player?.trackArtUrl ?? ""
            readonly property real progress: (player?.length ?? 0) > 0 ? player.position / player.length : 0

            width: ListView.view.width
            height: root.cardHeight
            radius: Appearance.rounding.normal + 4
            color: cardMouse.containsMouse ? NotchPalette.surfaceHigh : NotchPalette.surface
            border.width: isActive && root.players.length > 1 ? 1 : 0
            border.color: NotchPalette.accent

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }

            // Click a card to make it the player the compact notch follows
            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: MprisController.setActivePlayer(card.player)
            }

            RowLayout {
                anchors {
                    fill: parent
                    margins: 8
                }
                spacing: 10

                Rectangle {
                    id: art
                    implicitWidth: 60
                    implicitHeight: 60
                    radius: Appearance.rounding.normal
                    color: NotchPalette.surfaceHigh

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: art.width
                            height: art.height
                            radius: art.radius
                        }
                    }

                    StyledImage {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        source: card.artUrl
                        sourceSize.width: 120
                        sourceSize.height: 120
                        visible: card.artUrl !== ""
                    }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: card.artUrl === ""
                        text: "music_note"
                        iconSize: 26
                        color: NotchPalette.textDim
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: card.player?.trackTitle || Translation.tr("Unknown Title")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: NotchPalette.text
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: [card.player?.trackArtist, card.player?.identity].filter(s => s && s.length > 0).join("  •  ")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: NotchPalette.textDim
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        spacing: 8
                        visible: (card.player?.length ?? 0) > 0

                        // Seek bar
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 12

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 4
                                radius: 2
                                color: NotchPalette.surfaceHover

                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, card.progress))
                                    height: parent.height
                                    radius: parent.radius
                                    color: NotchPalette.accent
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: card.player?.canSeek ?? false
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                function seek(mouseX) {
                                    card.player.position = Math.max(0, Math.min(1, mouseX / width)) * card.player.length
                                }
                                onPressed: (mouse) => seek(mouse.x)
                                onPositionChanged: (mouse) => { if (pressed) seek(mouse.x) }
                            }
                        }

                        StyledText {
                            text: `${StringUtils.friendlyTimeForSeconds(card.player?.position)} / ${StringUtils.friendlyTimeForSeconds(card.player?.length)}`
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.features: { "tnum": 1 }
                            color: NotchPalette.textDim
                        }
                    }
                }

                RowLayout {
                    spacing: 2

                    NotchIconButton {
                        icon: "skip_previous"
                        filled: true
                        enabled: card.player?.canGoPrevious ?? false
                        onClicked: card.player.previous()
                    }
                    NotchIconButton {
                        implicitWidth: 40
                        implicitHeight: 40
                        icon: card.player?.isPlaying ? "pause" : "play_arrow"
                        iconSize: 24
                        toggled: true
                        enabled: card.player?.canTogglePlaying ?? false
                        onClicked: card.player.togglePlaying()
                    }
                    NotchIconButton {
                        icon: "skip_next"
                        filled: true
                        enabled: card.player?.canGoNext ?? false
                        onClicked: card.player.next()
                    }
                }
            }
        }
    }
}
