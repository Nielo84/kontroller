import QtQuick 2.0
import harbour.eu.tgcm 1.0
import "."
import Sailfish.Silica 1.0

Item {
    id: root
    property var player
    property string mode: "all"

    // About five rows remain visible; longer lists scroll internally.
    property int pickerRows: 5
    property int pickerRowHeight: Theme.itemSizeMedium
    property int pickerHeight: pickerRows * pickerRowHeight

    implicitHeight: mode === "audio" ? audioPicker.height :
                    mode === "subtitles" ? subtitlePicker.height :
                    legacyOptions.height

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

    function primaryLabel(language) {
        var c = code(language)
        var full = languageName(language)
        if (c.length && full.length)
            return c + " · " + full
        if (c.length)
            return c
        if (full.length)
            return full
        return qsTr("Unknown")
    }

    function secondaryLabel(language, name) {
        var c = code(language)
        var full = languageName(language)
        var n = name ? ("" + name).trim() : ""
        if (n.length === 0 || n.toUpperCase() === c || n === full)
            return ""
        return n
    }

    // AUDIO PICKER
    SilicaListView {
        id: audioPicker
        visible: mode === "audio"
        width: parent.width
        height: visible ? Math.min(contentHeight, root.pickerHeight) : 0
        clip: true
        model: player ? player.audioStreams : []

        delegate: BackgroundItem {
            width: audioPicker.width
            height: root.pickerRowHeight
            onClicked: {
                if (player)
                    player.currentAudioStreamIndex = model.modelData.index
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.paddingMedium
                anchors.rightMargin: Theme.paddingMedium
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Label {
                    width: parent.width
                    text: primaryLabel(model.language)
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: player && model.modelData.index === player.currentAudioStreamIndex
                    color: player && model.modelData.index === player.currentAudioStreamIndex ?
                               Theme.highlightColor : Theme.primaryColor
                    truncationMode: TruncationMode.Fade
                }

                Label {
                    width: parent.width
                    visible: text.length > 0
                    text: secondaryLabel(model.language, model.name)
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    truncationMode: TruncationMode.Fade
                }
            }
        }

        VerticalScrollDecorator {}
    }

    // SUBTITLE PICKER
    SilicaListView {
        id: subtitlePicker
        visible: mode === "subtitles"
        width: parent.width
        height: visible ? Math.min(contentHeight, root.pickerHeight) : 0
        clip: true
        model: player ? player.subtitles : []

        delegate: BackgroundItem {
            width: subtitlePicker.width
            height: root.pickerRowHeight
            onClicked: {
                if (player)
                    player.currentSubtitleIndex = model.modelData.index
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.paddingMedium
                anchors.rightMargin: Theme.paddingMedium
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Label {
                    width: parent.width
                    text: model.modelData.index < 0 ?
                              qsTr("OFF · No subtitles") :
                              primaryLabel(model.language)
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: player && model.modelData.index === player.currentSubtitleIndex
                    color: player && model.modelData.index === player.currentSubtitleIndex ?
                               Theme.highlightColor : Theme.primaryColor
                    truncationMode: TruncationMode.Fade
                }

                Label {
                    width: parent.width
                    visible: model.modelData.index >= 0 && text.length > 0
                    text: secondaryLabel(model.language, model.name)
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    truncationMode: TruncationMode.Fade
                }
            }
        }

        VerticalScrollDecorator {}
    }

    // Overflow menu now contains only the less frequently used playback options.
    // Audio/Subtitles live exclusively in the fixed rows above the picker.
    Row {
        id: legacyOptions
        visible: mode === "all"
        width: parent.width
        height: visible ? Math.max(repeatSwitch.height, shuffleSwitch.height) : 0

        Switch {
            id: repeatSwitch
            checked: player ? player.repeat > 0 : false
            automaticCheck: false
            icon.source: player && player.repeat === 1 ?
                             "image://theme/icon-m-repeat-single" :
                             "image://theme/icon-m-repeat"
            visible: player ? player.canRepeat : false
            onClicked: if (player) player.repeat = (player.repeat + 1) % 3
        }

        Switch {
            id: shuffleSwitch
            checked: player ? player.shuffled : false
            automaticCheck: false
            icon.source: "image://theme/icon-m-shuffle"
            visible: player ? player.canShuffle : false
            onClicked: if (player) player.shuffled = !player.shuffled
        }
    }
}
