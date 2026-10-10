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
    property bool hidePanel: true
    property int initialRefreshAttempts: 0
    property bool propertiesExpanded: false
    property string propertyPanelMode: ""
    property bool powerMenuVisible: false
    property var shutdownRemorse: null

    // Keep the remote compact like Kore: the navigation pad occupies about
    // two thirds of the screen width, with the corner actions close to it.
    property int padSize: Math.floor(page.width * 0.68)
    property int padCell: Math.floor(padSize / 3)

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

    SystemService {
        id: systemService
        client: appClient
    }

    HapticsEffect {
        id: commandFeedback
        intensity: 0.5
        duration: 70
    }

    function feedback() {
        commandFeedback.start()
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

    function languageCode(value) {
        if (!value)
            return ""
        var clean = ("" + value).trim()
        if (clean.length === 0)
            return ""
        return clean.substring(0, Math.min(3, clean.length)).toUpperCase()
    }

    function activeAudioText() {
        if (!player || !player.audioStreams)
            return qsTr("AUDIO")
        for (var i = 0; i < player.audioStreams.length; ++i) {
            var stream = player.audioStreams[i]
            if (stream && stream.index === player.currentAudioStreamIndex) {
                var lang = languageCode(stream.language)
                var name = stream.name ? ("" + stream.name).trim() : ""
                if (lang.length > 0 && name.length > 0 && name.toUpperCase() !== lang)
                    return lang + " · " + name
                if (lang.length > 0)
                    return lang
                if (name.length > 0)
                    return name
            }
        }
        return qsTr("AUDIO")
    }

    function activeSubtitleText() {
        if (!player || player.currentSubtitleIndex < 0)
            return qsTr("OFF")
        if (!player.subtitles)
            return qsTr("SUBS")
        for (var i = 0; i < player.subtitles.length; ++i) {
            var sub = player.subtitles[i]
            if (sub && sub.index === player.currentSubtitleIndex) {
                var lang = languageCode(sub.language)
                var name = sub.name ? ("" + sub.name).trim() : ""
                if (lang.length > 0 && name.length > 0 && name.toUpperCase() !== lang)
                    return lang + " · " + name
                if (lang.length > 0)
                    return lang
                if (name.length > 0)
                    return name
            }
        }
        return qsTr("SUBS")
    }

    function togglePropertyPanel(mode) {
        if (propertyPanelMode === mode)
            propertyPanelMode = ""
        else
            propertyPanelMode = mode
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

            // Compact Kore-like top bar.
            Item {
                width: parent.width
                height: Theme.itemSizeMedium

                Label {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Remote")
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.primaryColor
                }

                IconButton {
                    id: serverMenuButton
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.paddingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    icon.source: "image://theme/icon-m-menu"
                    onClicked: pageStack.push(Qt.resolvedUrl("ServerPage.qml"))
                }

                BackgroundItem {
                    id: powerButton
                    anchors.right: serverMenuButton.left
                    anchors.rightMargin: Theme.paddingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.itemSizeSmall
                    height: Theme.itemSizeSmall
                    enabled: appClient && appClient.server
                    onClicked: powerMenuVisible = !powerMenuVisible

                    // Draw a proper power symbol instead of relying on a font glyph.
                    Item {
                        anchors.centerIn: parent
                        width: Theme.iconSizeMedium
                        height: Theme.iconSizeMedium

                        Rectangle {
                            width: parent.width * 0.72
                            height: width
                            radius: width / 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            color: "transparent"
                            border.width: Math.max(2, Theme.paddingSmall / 3)
                            border.color: powerButton.highlighted ? Theme.highlightColor : Theme.primaryColor
                        }
                        Rectangle {
                            width: Math.max(3, Theme.paddingSmall / 2)
                            height: parent.height * 0.56
                            radius: width / 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            color: powerButton.highlighted ? Theme.highlightColor : Theme.primaryColor
                        }
                    }
                }
            }

            // Compact now-playing card. Extra player properties stay available,
            // but are collapsed by default to keep the remote clean.
            Rectangle {
                id: playerCard
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                height: playerCardColumn.height + 2 * Theme.paddingMedium
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.16)
                visible: player !== null

                Column {
                    id: playerCardColumn
                    anchors.top: parent.top
                    anchors.topMargin: Theme.paddingMedium
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.paddingMedium
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Item {
                        width: parent.width
                        height: Math.max(Theme.itemSizeLarge, mediaText.height)

                        Image {
                            id: thumbnailImg
                            anchors.left: parent.left
                            anchors.top: parent.top
                            width: Theme.itemSizeLarge
                            height: Theme.itemSizeLarge
                            fillMode: Image.PreserveAspectCrop
                            source: player ? player.playingInformation.currentItem.thumbnail : ""
                        }

                        Column {
                            id: mediaText
                            anchors.left: thumbnailImg.right
                            anchors.leftMargin: Theme.paddingMedium
                            anchors.right: parent.right
                            anchors.verticalCenter: thumbnailImg.verticalCenter
                            spacing: Theme.paddingSmall

                            Label {
                                width: parent.width
                                text: player ? getMainDisplay(player.playingInformation.currentItem) : ""
                                font.pixelSize: Theme.fontSizeMedium
                                font.bold: true
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                text: player ? getSubDisplay(player.playingInformation.currentItem) : ""
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                truncationMode: TruncationMode.Fade
                            }
                        }
                    }

                    PlayerControl {
                        width: parent.width
                        player: page.player
                        showLabel: false
                    }

                    Row {
                        id: streamSelectors
                        width: parent.width
                        height: player && player.type === "video" ? Theme.itemSizeSmall : 0
                        visible: player && player.type === "video"
                        spacing: Theme.paddingSmall

                        BackgroundItem {
                            id: audioField
                            width: (parent.width - parent.spacing) / 2
                            height: Theme.itemSizeSmall
                            onClicked: togglePropertyPanel("audio")

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.paddingSmall
                                color: propertyPanelMode === "audio" ?
                                           Theme.rgba(Theme.highlightColor, 0.20) :
                                           Theme.rgba(Theme.primaryColor, 0.08)
                                border.width: 1
                                border.color: propertyPanelMode === "audio" ?
                                                  Theme.highlightColor : Theme.secondaryColor
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.paddingSmall
                                anchors.rightMargin: Theme.paddingSmall
                                spacing: Theme.paddingSmall

                                Rectangle {
                                    width: Theme.iconSizeSmall
                                    height: Theme.iconSizeSmall
                                    radius: width / 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: "transparent"
                                    border.width: 2
                                    border.color: Theme.primaryColor

                                    Label {
                                        anchors.centerIn: parent
                                        text: "A"
                                        font.bold: true
                                        font.pixelSize: Theme.fontSizeSmall
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - Theme.iconSizeSmall - parent.spacing
                                    spacing: 0
                                    Label {
                                        width: parent.width
                                        text: qsTr("Audio")
                                        font.pixelSize: Theme.fontSizeExtraSmall
                                        color: Theme.secondaryColor
                                    }
                                    Label {
                                        width: parent.width
                                        text: activeAudioText()
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.bold: true
                                        truncationMode: TruncationMode.Fade
                                    }
                                }
                            }
                        }

                        BackgroundItem {
                            id: subtitleField
                            width: (parent.width - parent.spacing) / 2
                            height: Theme.itemSizeSmall
                            onClicked: togglePropertyPanel("subtitles")

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.paddingSmall
                                color: propertyPanelMode === "subtitles" ?
                                           Theme.rgba(Theme.highlightColor, 0.20) :
                                           Theme.rgba(Theme.primaryColor, 0.08)
                                border.width: 1
                                border.color: propertyPanelMode === "subtitles" ?
                                                  Theme.highlightColor : Theme.secondaryColor
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.paddingSmall
                                anchors.rightMargin: Theme.paddingSmall
                                spacing: Theme.paddingSmall

                                Rectangle {
                                    width: Theme.iconSizeSmall * 1.25
                                    height: Theme.iconSizeSmall
                                    radius: Theme.paddingSmall / 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: "transparent"
                                    border.width: 2
                                    border.color: Theme.primaryColor

                                    Label {
                                        anchors.centerIn: parent
                                        text: "CC"
                                        font.bold: true
                                        font.pixelSize: Theme.fontSizeExtraSmall
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - Theme.iconSizeSmall * 1.25 - parent.spacing
                                    spacing: 0
                                    Label {
                                        width: parent.width
                                        text: qsTr("Subtitles")
                                        font.pixelSize: Theme.fontSizeExtraSmall
                                        color: Theme.secondaryColor
                                    }
                                    Label {
                                        width: parent.width
                                        text: activeSubtitleText()
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.bold: true
                                        truncationMode: TruncationMode.Fade
                                    }
                                }
                            }
                        }
                    }

                    PlayerProperties {
                        width: parent.width
                        player: page.player
                        mode: propertyPanelMode
                        visible: propertyPanelMode !== ""
                    }

                    Row {
                        width: parent.width
                        height: volumeControl.height
                        spacing: Theme.paddingSmall

                        BackgroundItem {
                            id: muteButton
                            width: Theme.itemSizeSmall
                            height: volumeControl.height
                            enabled: appClient && appClient.volumePlugin
                            onClicked: {
                                if (appClient && appClient.volumePlugin)
                                    appClient.volumePlugin.muted = !appClient.volumePlugin.muted
                            }

                            Label {
                                anchors.centerIn: parent
                                text: appClient && appClient.volumePlugin && appClient.volumePlugin.muted ? "🔇" : "🔊"
                                font.pixelSize: Theme.fontSizeMedium
                                color: muteButton.highlighted ? Theme.highlightColor : Theme.primaryColor
                            }
                        }

                        VolumeControl {
                            id: volumeControl
                            width: parent.width - muteButton.width - propertiesButton.width - 2 * parent.spacing
                            volumePlugin: appClient ? appClient.volumePlugin : null
                        }

                        IconButton {
                            id: propertiesButton
                            width: Theme.itemSizeSmall
                            height: volumeControl.height
                            icon.source: "image://theme/icon-m-menu"
                            onClicked: {
                                propertiesExpanded = !propertiesExpanded
                                if (propertiesExpanded)
                                    propertyPanelMode = ""
                            }
                        }
                    }

                    PlayerProperties {
                        width: parent.width
                        player: page.player
                        mode: "all"
                        visible: propertiesExpanded
                    }
                }
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                visible: player === null
                text: qsTr("Nothing playing")
                color: Theme.secondaryColor
                horizontalAlignment: Text.AlignHCenter
            }

            Item {
                width: 1
                height: Theme.paddingSmall
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

    Rectangle {
        id: powerMenu
        z: 100
        visible: powerMenuVisible
        anchors.top: parent.top
        anchors.topMargin: Theme.itemSizeMedium
        anchors.right: parent.right
        anchors.rightMargin: Theme.paddingMedium
        width: Math.min(page.width * 0.66, Theme.itemSizeHuge * 3.2)
        height: powerMenuColumn.height
        radius: Theme.paddingMedium
        color: Theme.rgba(Theme.highlightBackgroundColor, 0.98)
        border.width: 1
        border.color: Theme.highlightColor

        Column {
            id: powerMenuColumn
            width: parent.width

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeMedium
                visible: appClient && appClient.server && appClient.server.poweroffEnabled
                onClicked: {
                    powerMenuVisible = false
                    shutdownRemorse = Remorse.popupAction(page, qsTr("Shutdown Kodi"),
                                                          function() { systemService.shutdownServer() })
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.paddingMedium
                    text: qsTr("⏻  Shutdown")
                }
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeMedium
                visible: appClient && appClient.server && appClient.server.rebootEnabled
                onClicked: {
                    powerMenuVisible = false
                    shutdownRemorse = Remorse.popupAction(page, qsTr("Restart Kodi"),
                                                          function() { systemService.rebootServer() })
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.paddingMedium
                    text: qsTr("↻  Restart")
                }
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeMedium
                visible: appClient && appClient.server && appClient.server.suspendEnabled
                onClicked: {
                    powerMenuVisible = false
                    shutdownRemorse = Remorse.popupAction(page, qsTr("Suspend Kodi"),
                                                          function() { systemService.suspendServer() })
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.paddingMedium
                    text: qsTr("Ⅱ  Suspend")
                }
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeMedium
                visible: appClient && appClient.server && appClient.server.hibernateEnabled
                onClicked: {
                    powerMenuVisible = false
                    shutdownRemorse = Remorse.popupAction(page, qsTr("Hibernate Kodi"),
                                                          function() { systemService.hibernateServer() })
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.paddingMedium
                    text: qsTr("◐  Hibernate")
                }
            }
        }
    }

    // Compact Kore-inspired 3x3 pad:
    // Home | Up   | Info
    // Left | OK   | Right
    // Back | Down | Menu
    Item {
        id: dpad
        width: padCell * 3
        height: padCell * 3
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.paddingMedium

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
            onClicked: remoteController.up()

            Rectangle {
                anchors.fill: parent
                radius: Theme.paddingSmall
                color: upButton.highlighted ?
                           Theme.rgba(Theme.highlightColor, 0.28) :
                           Theme.rgba(Theme.primaryColor, 0.12)
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
            onClicked: remoteController.left()

            Rectangle {
                anchors.fill: parent
                radius: Theme.paddingSmall
                color: leftButton.highlighted ?
                           Theme.rgba(Theme.highlightColor, 0.28) :
                           Theme.rgba(Theme.primaryColor, 0.12)
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
            onClicked: remoteController.select()

            Rectangle {
                width: Math.min(parent.width, parent.height) * 0.78
                height: width
                radius: width / 2
                anchors.centerIn: parent
                color: selectButton.highlighted ?
                           Theme.rgba(Theme.highlightColor, 0.28) :
                           Theme.rgba(Theme.primaryColor, 0.12)
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
            onClicked: remoteController.right()

            Rectangle {
                anchors.fill: parent
                radius: Theme.paddingSmall
                color: rightButton.highlighted ?
                           Theme.rgba(Theme.highlightColor, 0.28) :
                           Theme.rgba(Theme.primaryColor, 0.12)
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
            onClicked: remoteController.down()

            Rectangle {
                anchors.fill: parent
                radius: Theme.paddingSmall
                color: downButton.highlighted ?
                           Theme.rgba(Theme.highlightColor, 0.28) :
                           Theme.rgba(Theme.primaryColor, 0.12)
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
