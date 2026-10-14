import QtQuick 2.0
import harbour.eu.tgcm 1.0
import "."
import Sailfish.Silica 1.0

Item {
    property var player
    property string mode: "all"
    signal selectionMade()
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

    function audioDetail(name) {
        var n = name ? ("" + name).toUpperCase() : ""
        var codec = ""
        if (n.indexOf("TRUEHD") >= 0) codec = "TRUEHD"
        else if (n.indexOf("DTS-HD") >= 0 || n.indexOf("DTS HD") >= 0) codec = "DTS-HD"
        else if (n.indexOf("DTS") >= 0) codec = "DTS"
        else if (n.indexOf("E-AC-3") >= 0 || n.indexOf("EAC3") >= 0 || n.indexOf("DD+") >= 0) codec = "EAC3"
        else if (n.indexOf("AC3") >= 0 || n.indexOf("AC-3") >= 0) codec = "AC3"
        else if (n.indexOf("AAC") >= 0) codec = "AAC"
        else if (n.indexOf("FLAC") >= 0) codec = "FLAC"
        else if (n.indexOf("OPUS") >= 0) codec = "OPUS"
        else if (n.indexOf("MP3") >= 0) codec = "MP3"
        else if (n.indexOf("PCM") >= 0) codec = "PCM"

        var channels = ""
        if (n.indexOf("7.1") >= 0) channels = "7.1"
        else if (n.indexOf("5.1") >= 0) channels = "5.1"
        else if (n.indexOf("2.0") >= 0 || n.indexOf("STEREO") >= 0) channels = "2.0"
        else if (n.indexOf("MONO") >= 0) channels = "1.0"

        if (codec.length && channels.length)
            return codec + " " + channels
        return codec.length ? codec : channels
    }

    function subtitleDetail(name) {
        var n = name ? ("" + name).toUpperCase() : ""
        if (n.indexOf("FORCED") >= 0) return "FORCED"
        if (n.indexOf("SDH") >= 0) return "SDH"
        if (n.indexOf("CLOSED CAPTION") >= 0 || n.indexOf(" CC") >= 0) return "CC"
        return ""
    }

    function audioLabel(language, name) {
        var lang = code(language)
        var detail = audioDetail(name)
        if (lang.length && detail.length)
            return lang + " · " + detail
        if (lang.length)
            return lang
        if (detail.length)
            return detail
        return qsTr("Unknown")
    }

    function subtitleLabel(language, name) {
        var lang = code(language)
        var detail = subtitleDetail(name)
        if (lang.length && detail.length)
            return lang + " · " + detail
        if (lang.length)
            return lang
        if (detail.length)
            return detail
        return qsTr("Unknown")
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
                        if (player) {
                            player.currentAudioStreamIndex = model.modelData.index
                            selectionMade()
                        }
                    }
                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.paddingMedium
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.paddingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        text: audioLabel(model.language, model.name)
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
                        if (player) {
                            player.currentSubtitleIndex = model.modelData.index
                            selectionMade()
                        }
                    }
                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.paddingMedium
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.paddingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        text: model.modelData.index < 0 ?
                                  qsTr("OFF · No subtitles") :
                                  subtitleLabel(model.language, model.name)
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
