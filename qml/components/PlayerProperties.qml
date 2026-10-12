import QtQuick 2.0
import harbour.eu.tgcm 1.0
import "."
import Sailfish.Silica 1.0

Item {
    property var player
    property string mode: "all"
    implicitHeight: contents.height

    Remote {
        id: remoteController
        client: appClient
    }

    function code(value) {
        if (!value)
            return ""
        var v = ("" + value).trim().toUpperCase()
        return v.substring(0, Math.min(3, v.length))
    }

    function languageName(value) {
        var c = code(value)
        if (c === "ENG") return qsTr("English")
        if (c === "NLD" || c === "DUT") return qsTr("Dutch")
        if (c === "DEU" || c === "GER") return qsTr("German")
        if (c === "FRA" || c === "FRE") return qsTr("French")
        if (c === "SPA") return qsTr("Spanish")
        if (c === "ITA") return qsTr("Italian")
        if (c === "POR") return qsTr("Portuguese")
        if (c === "JPN") return qsTr("Japanese")
        if (c === "KOR") return qsTr("Korean")
        if (c === "ZHO" || c === "CHI") return qsTr("Chinese")
        if (c === "UND") return qsTr("Unknown")
        return ""
    }

    function streamLabel(language, name) {
        var c = code(language)
        var full = languageName(language)
        var n = name ? ("" + name).trim() : ""
        var label = c
        if (full.length > 0)
            label += (label.length ? " · " : "") + full
        if (n.length > 0 && n.toUpperCase() !== c && n !== full)
            label += (label.length ? " — " : "") + n
        return label.length ? label : qsTr("Unknown")
    }

    Column {
        id: contents
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.paddingSmall

        // Clear direct audio list used by the Remote page.
        Column {
            width: parent.width
            visible: mode === "audio"

            Repeater {
                model: player ? player.audioStreams : []
                delegate: BackgroundItem {
                    width: contents.width
                    height: Theme.itemSizeSmall
                    onClicked: {
                        if (player)
                            player.currentAudioStream = model.modelData.index
                    }
                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.paddingMedium
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.paddingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        text: streamLabel(model.language, model.name)
                        font.bold: player && model.modelData.index === player.currentAudioStreamIndex
                        color: player && model.modelData.index === player.currentAudioStreamIndex ?
                                   Theme.highlightColor : Theme.primaryColor
                        truncationMode: TruncationMode.Fade
                    }
                }
            }
        }

        // Clear direct subtitle list used by the Remote page.
        Column {
            width: parent.width
            visible: mode === "subtitles"

            Repeater {
                model: player ? player.subtitles : []
                delegate: BackgroundItem {
                    width: contents.width
                    height: Theme.itemSizeSmall
                    onClicked: {
                        if (player)
                            player.currentSubtitleIndex = model.modelData.index
                    }
                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.paddingMedium
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.paddingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        text: model.modelData.index < 0 ?
                                  qsTr("OFF · No subtitles") :
                                  streamLabel(model.language, model.name)
                        font.bold: player && model.modelData.index === player.currentSubtitleIndex
                        color: player && model.modelData.index === player.currentSubtitleIndex ?
                                   Theme.highlightColor : Theme.primaryColor
                        truncationMode: TruncationMode.Fade
                    }
                }
            }

            BackgroundItem {
                width: contents.width
                height: Theme.itemSizeSmall
                onClicked: remoteController.downloadSubtitles()
                Label {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.paddingMedium
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Download subtitles…")
                    color: Theme.highlightColor
                }
            }
        }

        // Keep the legacy controls available from the overflow menu and old CurrentlyPlaying page.
        ComboBox {
            id: cbxSubs
            visible: mode === "all" && player && player.type === "video"
            label: qsTr("Subtitles")
            clip: true
            menu: ContextMenu {
                Repeater {
                    id: subsRptr
                    model: player ? player.subtitles : []
                    delegate: MenuItem {
                        text: model.modelData.index < 0 ?
                                  qsTr("OFF · No subtitles") :
                                  streamLabel(model.language, model.name)
                        onClicked: if (player) player.currentSubtitleIndex = model.modelData.index
                    }
                }
                MenuItem {
                    text: qsTr("Download subtitles…")
                    onClicked: remoteController.downloadSubtitles()
                }
            }
            currentIndex: -1
            value: player && player.subtitles.length === 0 ? qsTr("No subtitles available") : ""
        }

        ComboBox {
            id: cbxStreams
            visible: mode === "all" && player && player.type === "video"
            label: qsTr("Audio")
            clip: true
            menu: ContextMenu {
                Repeater {
                    id: streamsRptr
                    model: player ? player.audioStreams : []
                    delegate: MenuItem {
                        text: streamLabel(model.language, model.name)
                        onClicked: if (player) player.currentAudioStream = model.modelData.index
                    }
                }
            }
            value: ""
        }

        Row {
            visible: mode === "all"
            width: parent.width
            height: repeatSwitch.height
            Switch {
                id: repeatSwitch
                checked: false
                automaticCheck: false
                icon.source: "image://theme/icon-m-repeat"
                visible: player ? player.canRepeat : false
                onClicked: player.repeat = (player.repeat + 1) % 3
            }
            Switch {
                id: shuffleSwitch
                checked: false
                automaticCheck: false
                icon.source: "image://theme/icon-m-shuffle"
                visible: player ? player.canShuffle : false
                onClicked: player.shuffled = !player.shuffled
            }
        }
    }

    onPlayerChanged: {
        if (player) {
            connectPlayerEvents()
            updatePlayerProperties()
        }
    }

    function connectPlayerEvents() {
        player.onCurrentSubtitleIndexChanged.connect(setSubsIndex)
        player.onCurrentAudioStreamIndexChanged.connect(setAudioIndex)
        player.onShuffledChanged.connect(setPlayerShuffled)
        player.onRepeatChanged.connect(setPlayerRepeat)
    }

    function getCurrentSubsIndex() {
        if (player) {
            var idx = player.currentSubtitleIndex
            for (var i = 0; i < player.subtitles.length; ++i)
                if (player.subtitles[i].index === idx)
                    return i
        }
        return -1
    }

    function setSubsIndex() {
        var idx = getCurrentSubsIndex()
        if (idx !== -1 && mode === "all") {
            cbxSubs.currentIndex = idx
            cbxSubs.value = player.subtitles[idx].name
        }
    }

    function getCurrentAudioIndex() {
        if (player) {
            var idx = player.currentAudioStreamIndex
            for (var i = 0; i < player.audioStreams.length; ++i)
                if (player.audioStreams[i].index === idx)
                    return i
        }
        return -1
    }

    function setAudioIndex() {
        var i = getCurrentAudioIndex()
        if (i !== -1 && mode === "all") {
            cbxStreams.currentIndex = i
            cbxStreams.value = streamLabel(player.audioStreams[i].language, player.audioStreams[i].name)
        }
    }

    function setPlayerShuffled() {
        shuffleSwitch.checked = player ? player.shuffled : false
    }

    function setPlayerRepeat() {
        if (player) {
            repeatSwitch.checked = player.repeat > 0
            repeatSwitch.icon.source = player.repeat === 1 ?
                        "image://theme/icon-m-repeat-single" : "image://theme/icon-m-repeat"
        } else {
            repeatSwitch.checked = false
            repeatSwitch.icon.source = "image://theme/icon-m-repeat"
        }
    }

    Component.onCompleted: {
        if (player)
            connectPlayerEvents()
        updatePlayerProperties()
    }

    function updatePlayerProperties() {
        setSubsIndex()
        setAudioIndex()
        setPlayerShuffled()
        setPlayerRepeat()
    }
}
