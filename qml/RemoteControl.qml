import QtQuick 2.6
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
    property bool drawerVisible: false
    property bool kodiInputVisible: false
    property string kodiInputTitle: ""
    property string kodiInputType: ""
    property string kodiInputValue: ""
    property var shutdownRemorse: null

    // Kore-like compact pad, lifted from the very bottom for easier thumb use.
    property int padSize: Math.floor(page.width * 0.68)
    property int padCell: Math.floor(padSize / 3)
    property string repeatDirection: ""

    function syncActivePlayer() {
        if (!appClient || !appClient.playerService)
            return
        player = appClient.playerService.activePlayer
        if (player)
            player.refreshPlayerStatus()
    }

    function startInitialPlayerRefresh() {
        if (!appClient || !appClient.playerService)
            return
        initialRefreshAttempts = 0
        syncActivePlayer()
        appClient.playerService.refreshPlayerInfo()
        initialPlayerRefresh.restart()
    }

    function sendDirection(direction) {
        if (direction === "up")
            remoteController.up()
        else if (direction === "down")
            remoteController.down()
        else if (direction === "left")
            remoteController.left()
        else if (direction === "right")
            remoteController.right()
    }

    function startDirection(direction) {
        sendDirection(direction)
        repeatDirection = direction
        navigationRepeat.restart()
    }

    function stopDirection() {
        navigationRepeat.stop()
        repeatDirection = ""
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
            return qsTr("Unknown")
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
        return qsTr("Unknown")
    }

    function activeSubtitleText() {
        if (!player || player.currentSubtitleIndex < 0)
            return qsTr("OFF")
        if (!player.subtitles)
            return qsTr("Unknown")
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
        return qsTr("Unknown")
    }

    function togglePropertyPanel(mode) {
        propertiesExpanded = false
        propertyPanelMode = propertyPanelMode === mode ? "" : mode
    }

    function createInfoComponents() {
        internal.informationPageComponents = {}
        var components = [
            {"type":"album", "component":"AlbumInformationPage"},
            {"type":"artist", "component":"ArtistInformationPage"},
            {"type":"episode", "component":"EpisodeInformationPage"},
            {"type":"movie", "component":"MovieInformationPage"},
            {"type":"season", "component":"SeasonInformationPage"},
            {"type":"tvshow", "component":"TvShowInformationPage"}
        ]
        for (var i = 0; i < components.length; ++i) {
            var comp = Qt.createComponent(components[i].component + ".qml")
            internal.informationPageComponents[components[i].type] = comp
        }
    }

    function closeDrawer() {
        drawerVisible = false
    }

    function pushRelevantPage(target) {
        closeDrawer()
        if (target === "music")
            internal.createMusicPage({"file":"", "filetype":"", "label":qsTr("Sources")})
        else if (target === "videos")
            internal.createVideoPage({"file":"", "filetype":"", "label":qsTr("Sources")})
        else if (target === "images")
            internal.createImagePage({"file":"", "filetype":"", "label":qsTr("Sources")})
        else if (target === "playlist")
            pageStack.push(Qt.resolvedUrl("PlaylistPage.qml"))
        else if (target === "server")
            pageStack.push(Qt.resolvedUrl("ServerPage.qml"))
        else if (target === "settings")
            pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
        else if (target === "switch")
            pageStack.push(Qt.resolvedUrl("ServerSelectionPage.qml"))
    }

    // PageFactory callbacks.
    function pushRemotePage() {}
    function pushCurrentPage() {}
    function toMenu() {
        drawerVisible = true
    }

    Timer {
        id: initialPlayerRefresh
        interval: 500
        repeat: true
        onTriggered: {
            initialRefreshAttempts++
            syncActivePlayer()
            if (appClient && appClient.playerService)
                appClient.playerService.refreshPlayerInfo()
            if ((player && player.type !== "") || initialRefreshAttempts >= 8)
                stop()
        }
    }

    Timer {
        id: navigationRepeat
        interval: 115
        repeat: true
        onTriggered: {
            if (repeatDirection !== "")
                sendDirection(repeatDirection)
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

    PageFactory {
        id: internal
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

            // Kore-like toolbar: hamburger left, title compact, power right.
            Item {
                width: parent.width
                height: Theme.itemSizeMedium

                IconButton {
                    id: hamburgerButton
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.paddingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    icon.source: "image://theme/icon-m-menu"
                    onClicked: {
                        powerMenuVisible = false
                        drawerVisible = !drawerVisible
                    }
                }

                Label {
                    anchors.left: hamburgerButton.right
                    anchors.leftMargin: Theme.paddingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Remote")
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.primaryColor
                }

                BackgroundItem {
                    id: powerButton
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.paddingMedium
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.itemSizeSmall
                    height: Theme.itemSizeSmall
                    enabled: appClient && appClient.server
                    onClicked: {
                        drawerVisible = false
                        powerMenuVisible = !powerMenuVisible
                    }

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

                    // Plain, aligned text instead of the two boxed selectors from build 20.
                    Row {
                        width: parent.width
                        height: player && player.type === "video" ? Theme.itemSizeSmall : 0
                        visible: player && player.type === "video"
                        spacing: Theme.paddingMedium

                        BackgroundItem {
                            width: (parent.width - parent.spacing) / 2
                            height: Theme.itemSizeSmall
                            onClicked: togglePropertyPanel("audio")
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                spacing: Theme.paddingSmall
                                Label {
                                    text: qsTr("Audio:")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.secondaryColor
                                }
                                Label {
                                    width: parent.width - x
                                    text: activeAudioText()
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                    color: propertyPanelMode === "audio" ? Theme.highlightColor : Theme.primaryColor
                                    truncationMode: TruncationMode.Fade
                                }
                            }
                        }

                        BackgroundItem {
                            width: (parent.width - parent.spacing) / 2
                            height: Theme.itemSizeSmall
                            onClicked: togglePropertyPanel("subtitles")
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                spacing: Theme.paddingSmall
                                Label {
                                    text: qsTr("Subs:")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.secondaryColor
                                }
                                Label {
                                    width: parent.width - x
                                    text: activeSubtitleText()
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                    color: propertyPanelMode === "subtitles" ? Theme.highlightColor : Theme.primaryColor
                                    truncationMode: TruncationMode.Fade
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
                text: appClient && appClient.connectionStatus === 2 ?
                          qsTr("Nothing playing") : qsTr("Connecting to Kodi…")
                color: Theme.secondaryColor
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Connections {
        target: appClient && appClient.playerService ? appClient.playerService : null
        onActivePlayerChanged: syncActivePlayer()
    }

    Connections {
        target: appClient
        onConnectionStatusChanged: {
            if (appClient.connectionStatus === 2)
                startInitialPlayerRefresh()
        }
        onInputRequested: {
            kodiInputTitle = title
            kodiInputType = type
            kodiInputValue = value
            kodiInputField.text = value
            kodiInputVisible = true
            kodiInputField.forceActiveFocus()
        }
        onInputFinished: {
            kodiInputVisible = false
            kodiInputField.focus = false
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Activating) {
            startInitialPlayerRefresh()
            if (appClient && appClient.volumePlugin)
                appClient.volumePlugin.refreshVolume()
        }
    }

    Component.onCompleted: {
        createInfoComponents()
        startInitialPlayerRefresh()
        if (appClient && appClient.volumePlugin)
            appClient.volumePlugin.refreshVolume()
    }

    // Power actions.
    Rectangle {
        id: powerMenu
        z: 220
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
                    text: qsTr("Shutdown")
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
                    text: qsTr("Restart")
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
                    text: qsTr("Suspend")
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
                    text: qsTr("Hibernate")
                }
            }
        }
    }

    // Main hamburger drawer: this replaces the old directory landing page.
    Item {
        id: drawerLayer
        z: 300
        anchors.fill: parent
        visible: drawerVisible

        Rectangle {
            anchors.fill: parent
            color: "#80000000"
            MouseArea {
                anchors.fill: parent
                onClicked: drawerVisible = false
            }
        }

        Rectangle {
            width: page.width * 0.76
            height: parent.height
            anchors.left: parent.left
            color: Theme.rgba(Theme.highlightBackgroundColor, 0.99)

            Column {
                width: parent.width
                anchors.top: parent.top
                anchors.topMargin: Theme.paddingLarge

                Label {
                    text: appClient && appClient.server ? appClient.server.name : qsTr("Kontroller")
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                    leftPadding: Theme.horizontalPageMargin
                    height: Theme.itemSizeMedium
                    verticalAlignment: Text.AlignVCenter
                }

                Repeater {
                    model: [
                        {"label": qsTr("Remote"), "target": "remote"},
                        {"label": qsTr("Music"), "target": "music"},
                        {"label": qsTr("Videos"), "target": "videos"},
                        {"label": qsTr("Images"), "target": "images"},
                        {"label": qsTr("Playlist"), "target": "playlist"},
                        {"label": qsTr("Server management"), "target": "server"},
                        {"label": qsTr("Settings"), "target": "settings"}
                    ]
                    delegate: BackgroundItem {
                        width: parent.width
                        height: Theme.itemSizeMedium
                        onClicked: {
                            if (modelData.target === "remote")
                                closeDrawer()
                            else
                                pushRelevantPage(modelData.target)
                        }
                        Label {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.horizontalPageMargin
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: modelData.target === "remote" ? Theme.highlightColor : Theme.primaryColor
                        }
                    }
                }

                BackgroundItem {
                    width: parent.width
                    height: Theme.itemSizeMedium
                    visible: appSettings.servers.length > 1
                    onClicked: pushRelevantPage("switch")
                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Switch server")
                    }
                }
            }
        }
    }

    // Kodi asks for text via Input.OnInputRequested when search/path dialogs are active.
    Rectangle {
        id: kodiInputPanel
        z: 400
        visible: kodiInputVisible
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.paddingMedium
        anchors.rightMargin: Theme.paddingMedium
        anchors.bottomMargin: Theme.paddingMedium
        height: inputColumn.height + 2 * Theme.paddingMedium
        radius: Theme.paddingMedium
        color: Theme.rgba(Theme.highlightBackgroundColor, 0.99)
        border.width: 1
        border.color: Theme.highlightColor

        Column {
            id: inputColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: Theme.paddingMedium
            anchors.leftMargin: Theme.paddingMedium
            anchors.rightMargin: Theme.paddingMedium
            spacing: Theme.paddingSmall

            Label {
                width: parent.width
                text: kodiInputTitle.length > 0 ? kodiInputTitle : qsTr("Kodi input")
                font.pixelSize: Theme.fontSizeMedium
                font.bold: true
                wrapMode: Text.Wrap
            }

            TextField {
                id: kodiInputField
                width: parent.width
                text: kodiInputValue
                placeholderText: qsTr("Enter text for Kodi")
                inputMethodHints: kodiInputType === "password" ? Qt.ImhHiddenText : Qt.ImhNone
            }

            Row {
                anchors.right: parent.right
                spacing: Theme.paddingMedium
                Button {
                    text: qsTr("Cancel")
                    onClicked: {
                        kodiInputVisible = false
                        kodiInputField.focus = false
                    }
                }
                Button {
                    text: qsTr("Send")
                    onClicked: {
                        remoteController.sendText(kodiInputField.text, true)
                        kodiInputVisible = false
                        kodiInputField.focus = false
                    }
                }
            }
        }
    }

    // Compact D-pad, about one centimetre higher than build 20.
    Item {
        id: dpad
        width: padCell * 3
        height: padCell * 3
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.itemSizeSmall + Theme.paddingLarge

        IconButton {
            id: homeButton
            x: 0
            y: 0
            width: padCell
            height: padCell
            icon.source: "image://theme/icon-m-home"
            onClicked: remoteController.home()
        }

        Item {
            id: upButton
            x: padCell
            y: 0
            width: padCell
            height: padCell
            Rectangle {
                anchors.fill: parent
                radius: Theme.paddingSmall
                color: upTouch.pressed ? Theme.rgba(Theme.highlightColor, 0.28)
                                       : Theme.rgba(Theme.primaryColor, 0.12)
            }
            Label { anchors.centerIn: parent; text: "▲"; font.pixelSize: Theme.fontSizeHuge }
            MouseArea {
                id: upTouch
                anchors.fill: parent
                onPressed: startDirection("up")
                onReleased: stopDirection()
                onCanceled: stopDirection()
            }
        }

        IconButton {
            id: infoButton
            x: padCell * 2
            y: 0
            width: padCell
            height: padCell
            icon.source: "image://theme/icon-m-question"
            onClicked: remoteController.info()
        }

        Item {
            id: leftButton
            x: 0
            y: padCell
            width: padCell
            height: padCell
            Rectangle {
                anchors.fill: parent
                radius: Theme.paddingSmall
                color: leftTouch.pressed ? Theme.rgba(Theme.highlightColor, 0.28)
                                         : Theme.rgba(Theme.primaryColor, 0.12)
            }
            Label { anchors.centerIn: parent; text: "◀"; font.pixelSize: Theme.fontSizeHuge }
            MouseArea {
                id: leftTouch
                anchors.fill: parent
                onPressed: startDirection("left")
                onReleased: stopDirection()
                onCanceled: stopDirection()
            }
        }

        Item {
            id: selectButton
            x: padCell
            y: padCell
            width: padCell
            height: padCell
            Rectangle {
                width: Math.min(parent.width, parent.height) * 0.78
                height: width
                radius: width / 2
                anchors.centerIn: parent
                color: selectTouch.pressed ? Theme.rgba(Theme.highlightColor, 0.28)
                                           : Theme.rgba(Theme.primaryColor, 0.12)
                border.width: Math.max(2, Theme.paddingSmall / 3)
                border.color: selectTouch.pressed ? Theme.highlightColor : Theme.primaryColor
                Label {
                    anchors.centerIn: parent
                    text: "OK"
                    font.pixelSize: Theme.fontSizeMedium
                }
            }
            MouseArea {
                id: selectTouch
                anchors.fill: parent
                onPressed: remoteController.select()
            }
        }

        Item {
            id: rightButton
            x: padCell * 2
            y: padCell
            width: padCell
            height: padCell
            Rectangle {
                anchors.fill: parent
                radius: Theme.paddingSmall
                color: rightTouch.pressed ? Theme.rgba(Theme.highlightColor, 0.28)
                                          : Theme.rgba(Theme.primaryColor, 0.12)
            }
            Label { anchors.centerIn: parent; text: "▶"; font.pixelSize: Theme.fontSizeHuge }
            MouseArea {
                id: rightTouch
                anchors.fill: parent
                onPressed: startDirection("right")
                onReleased: stopDirection()
                onCanceled: stopDirection()
            }
        }

        IconButton {
            id: backButton
            x: 0
            y: padCell * 2
            width: padCell
            height: padCell
            icon.source: "image://theme/icon-m-back"
            onClicked: remoteController.back()
        }

        Item {
            id: downButton
            x: padCell
            y: padCell * 2
            width: padCell
            height: padCell
            Rectangle {
                anchors.fill: parent
                radius: Theme.paddingSmall
                color: downTouch.pressed ? Theme.rgba(Theme.highlightColor, 0.28)
                                         : Theme.rgba(Theme.primaryColor, 0.12)
            }
            Label { anchors.centerIn: parent; text: "▼"; font.pixelSize: Theme.fontSizeHuge }
            MouseArea {
                id: downTouch
                anchors.fill: parent
                onPressed: startDirection("down")
                onReleased: stopDirection()
                onCanceled: stopDirection()
            }
        }

        IconButton {
            id: menuButton
            x: padCell * 2
            y: padCell * 2
            width: padCell
            height: padCell
            icon.source: "image://theme/icon-m-menu"
            onClicked: remoteController.contextMenu()
        }
    }
}
