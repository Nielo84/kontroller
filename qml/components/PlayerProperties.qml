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
        var base = v.split("-")[0].split("_")[0]
        if (base === "EN") return "ENG"
        if (base === "NL" || base === "DUT") return "NLD"
        if (base === "DE" || base === "GER") return "DEU"
        if (base === "FR" || base === "FRE") return "FRA"
        if (base === "ES") return "SPA"
        if (base === "IT") return "ITA"
        if (base === "PT") return "POR"
        if (base === "JA") return "JPN"
        if (base === "KO") return "KOR"
        if (base === "ZH" || base === "CHI") return "ZHO"
        return base.substring(0, Math.min(3, base.length))
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
                            player.currentAudioStreamIndex = model.modelData.index
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

        // Audio and subtitles are handled only by the dedicated Remote controls.
        // The overflow/submenu intentionally keeps only repeat and shuffle.
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
        player.onShuffledChanged.connect(setPlayerShuffled)
        player.onRepeatChanged.connect(setPlayerRepeat)
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
        setPlayerShuffled()
        setPlayerRepeat()
    }
}
