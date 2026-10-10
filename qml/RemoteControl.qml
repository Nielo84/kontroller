import QtQuick 2.6
import QtFeedback 5.0
import harbour.eu.tgcm 1.0
import Sailfish.Silica 1.0
import "."
import "./components"

Page {
    id: page
    allowedOrientations: Orientation.Portrait

    property var player: null
    property bool hidePanel: true // Combined remote has its own playback and volume controls.
    property int initialRefreshAttempts: 0

    // Refresh active playback state whenever this combined page opens.
    function syncActivePlayer() {
        player = appClient.playerService.activePlayer
        if (player)
            player.refreshPlayerStatus()
    }

    function startInitialPlayerRefresh() {
        initialRefreshAttempts = 0
        syncActivePlayer()
        appClient.playerService.refreshPlayerInfo()
        initialPlayerRefresh.restart()
    }

    Timer {
        id: initialPlayerRefresh
        interval: 500
        repeat: true
        onTriggered: {
            initialRefreshAttempts++
            syncActivePlayer()
            appClient.playerService.refreshPlayerInfo()
            if ((player && player.type !== "") || initialRefreshAttempts >= 8)
                stop()
        }
    }

    Remote {
        id: remoteController
        client: appClient
    }

    HapticsEffect {
        id: commandFeedback
        intensity: 0.5
        duration: 70
    }

    property int padSize: Math.min(page.width - 2 * Theme.paddingLarge,
                                   page.height * 0.40)
    property int padCell: Math.floor(padSize / 3)

    function feedback() {
        commandFeedback.start()
    }

    function somethingPlaying() {
        return player !== null
    }

    function getMainDisplay(item) {
        if (!item)
            return qsTr("Nothing playing")
        if (item.type === "song")
            return item.artist ? item.artist : qsTr("Unknown artist")
        if (item.type === "movie")
            return item.label
        if (item.type === "episode")
            return item.tvshow
        return item.label
    }

    function getSubDisplay(item) {
        if (!item)
            return ""
        if (item.type === "song")
            return item.label ? item.label : item.file
        if (item.type === "movie")
            return qsTr("Movie")
        if (item.type === "episode")
            return item.label
        return ""
    }

    SilicaFlickable {
        id: upperPanel
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: dpad.top
        anchors.bottomMargin: Theme.paddingSmall
        contentHeight: contentColumn.height
        clip: true

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingSmall

            PageHeader {
                title: qsTr("Remote")
            }

            Item {
                width: parent.width
                height: Theme.iconSizeExtraLarge + 2 * Theme.paddingSmall
                visible: player !== null

                Image {
                    id: thumbnailImg
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.iconSizeExtraLarge
                    height: Theme.iconSizeExtraLarge
                    fillMode: Image.PreserveAspectFit
                    source: player ? player.playingInformation.currentItem.thumbnail : ""
                }

                Column {
                    anchors.left: thumbnailImg.right
                    anchors.leftMargin: Theme.paddingMedium
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: player ? getMainDisplay(player.playingInformation.currentItem) : ""
                        font.pixelSize: Theme.fontSizeLarge
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        width: parent.width
                        text: player ? getSubDisplay(player.playingInformation.currentItem) : ""
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        truncationMode: TruncationMode.Fade
                    }
                }
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                visible: player === null
                text: qsTr("Nothing playing")
                color: Theme.highlightColor
                horizontalAlignment: Text.AlignHCenter
            }

            PlayerControl {
                width: parent.width
                player: page.player
                visible: player !== null
                showLabel: false
            }

            PlayerProperties {
                width: parent.width
                player: page.player
                visible: player !== null
            }

            Row {
                width: parent.width
                height: volumeControl.height
                spacing: Theme.paddingSmall

                BackgroundItem {
                    id: muteButton
                    width: Theme.itemSizeMedium
                    height: volumeControl.height
                    enabled: appClient && appClient.volumePlugin
                    onClicked: {
                        if (appClient && appClient.volumePlugin)
                            appClient.volumePlugin.muted = !appClient.volumePlugin.muted
                    }

                    Label {
                        anchors.centerIn: parent
                        text: appClient && appClient.volumePlugin && appClient.volumePlugin.muted ? "🔇" : "🔊"
                        font.pixelSize: Theme.fontSizeLarge
                        color: muteButton.highlighted ? Theme.highlightColor : Theme.primaryColor
                    }
                }

                VolumeControl {
                    id: volumeControl
                    width: parent.width - muteButton.width - parent.spacing
                    volumePlugin: appClient ? appClient.volumePlugin : null
                }
            }

            Item {
                width: 1
                height: Theme.paddingMedium
            }
        }
    }


    Connections {
        target: appClient.playerService
        onActivePlayerChanged: syncActivePlayer()
    }

    onStatusChanged: {
        if (status === PageStatus.Activating) {
            startInitialPlayerRefresh()
            if (appClient.volumePlugin)
                appClient.volumePlugin.refreshVolume()
        }
    }

    Component.onCompleted: {
        startInitialPlayerRefresh()
        if (appClient.volumePlugin)
            appClient.volumePlugin.refreshVolume()
    }

    // Kore-inspired 3x3 remote layout:
    // Home | Up   | Info
    // Left | OK   | Right
    // Back | Down | Menu
    Item {
        id: dpad
        width: padCell * 3
        height: padCell * 3
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.paddingLarge

        IconButton {
            id: homeButton
            x: 0
            y: 0
            width: padCell
            height: padCell
            icon.source: "image://theme/icon-m-home"
            onClicked: {
                remoteController.home()
                feedback()
            }
        }

        BackgroundItem {
            id: upButton
            x: padCell
            y: 0
            width: padCell
            height: padCell
            onClicked: {
                remoteController.up()
            }
            Label {
                anchors.centerIn: parent
                text: "▲"
                font.pixelSize: Theme.fontSizeHuge
                color: upButton.highlighted ? Theme.highlightColor : Theme.primaryColor
            }
        }

        IconButton {
            id: infoButton
            x: padCell * 2
            y: 0
            width: padCell
            height: padCell
            icon.source: "image://theme/icon-m-question"
            onClicked: {
                remoteController.info()
                feedback()
            }
        }

        BackgroundItem {
            id: leftButton
            x: 0
            y: padCell
            width: padCell
            height: padCell
            onClicked: {
                remoteController.left()
            }
            Label {
                anchors.centerIn: parent
                text: "◀"
                font.pixelSize: Theme.fontSizeHuge
                color: leftButton.highlighted ? Theme.highlightColor : Theme.primaryColor
            }
        }

        BackgroundItem {
            id: selectButton
            x: padCell
            y: padCell
            width: padCell
            height: padCell
            onClicked: {
                remoteController.select()
            }
            Rectangle {
                width: Math.min(parent.width, parent.height) * 0.56
                height: width
                radius: width / 2
                anchors.centerIn: parent
                color: "transparent"
                border.width: Math.max(2, Theme.paddingSmall / 3)
                border.color: selectButton.highlighted ? Theme.highlightColor : Theme.primaryColor

                Label {
                    anchors.centerIn: parent
                    text: "OK"
                    font.pixelSize: Theme.fontSizeMedium
                    color: selectButton.highlighted ? Theme.highlightColor : Theme.primaryColor
                }
            }
        }

        BackgroundItem {
            id: rightButton
            x: padCell * 2
            y: padCell
            width: padCell
            height: padCell
            onClicked: {
                remoteController.right()
            }
            Label {
                anchors.centerIn: parent
                text: "▶"
                font.pixelSize: Theme.fontSizeHuge
                color: rightButton.highlighted ? Theme.highlightColor : Theme.primaryColor
            }
        }

        IconButton {
            id: backButton
            x: 0
            y: padCell * 2
            width: padCell
            height: padCell
            icon.source: "image://theme/icon-m-back"
            onClicked: {
                remoteController.back()
                feedback()
            }
        }

        BackgroundItem {
            id: downButton
            x: padCell
            y: padCell * 2
            width: padCell
            height: padCell
            onClicked: {
                remoteController.down()
            }
            Label {
                anchors.centerIn: parent
                text: "▼"
                font.pixelSize: Theme.fontSizeHuge
                color: downButton.highlighted ? Theme.highlightColor : Theme.primaryColor
            }
        }

        IconButton {
            id: menuButton
            x: padCell * 2
            y: padCell * 2
            width: padCell
            height: padCell
            icon.source: "image://theme/icon-m-menu"
            onClicked: {
                remoteController.contextMenu()
                feedback()
            }
        }
    }
}
