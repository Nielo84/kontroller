import QtQuick 2.0
import Sailfish.Silica 1.0
import "../utils.js" as Utils

Item {
    property bool showSlider: true
    property bool showLabel: true
    property var player: null
    implicitHeight: controlsRow.y + controlsRow.height

    Slider {
        id: progressSlider
        anchors.left: parent.left
        anchors.right: parent.right
        minimumValue: 0
        maximumValue: player && player.totalTime > 0 ? player.totalTime : 1
        stepSize: 1000
        animateValue: false
        value: player ? player.time : 0
        onDownChanged: {
            if (!down && player && player.canSeek) {
                var target = Math.round(sliderValue)
                player.seekToTime(target)
                value = Qt.binding(function() { return player ? player.time : 0 })
            }
        }
        visible: showSlider && player && player.type !== "picture"
        valueText: down ? Utils.formatMsecTime(sliderValue) : ""
    }

    Label {
        id: lblCurrentTime
        anchors.left: parent.left
        anchors.leftMargin: Theme.paddingMedium
        anchors.verticalCenter: progressSlider.verticalCenter
        text: getTime(player)
        font.pixelSize: Theme.fontSizeExtraSmall
        color: Theme.highlightColor
    }

    Label {
        id: lblTotalTime
        anchors.right: parent.right
        anchors.rightMargin: Theme.paddingMedium
        anchors.verticalCenter: progressSlider.verticalCenter
        text: getTotalTime(player)
        font.pixelSize: Theme.fontSizeExtraSmall
        color: Theme.highlightColor
    }

    Label {
        id: lblDesc
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.paddingSmall
        anchors.rightMargin: Theme.paddingSmall
        anchors.bottom: progressSlider.bottom
        font.pixelSize: Theme.fontSizeExtraSmall
        horizontalAlignment: Text.AlignHCenter
        text: player ? getCurrentDisplay(player.playingInformation.currentItem) : ""
        elide: Text.ElideMiddle
        clip: true
        color: Theme.highlightColor
        visible: showLabel
    }

    // Larger transport controls with more breathing room below the seek bar.
    Row {
        id: controlsRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: progressSlider.bottom
        anchors.topMargin: Theme.paddingMedium
        spacing: Theme.paddingSmall
        height: Theme.itemSizeSmall

        IconButton {
            width: Theme.itemSizeSmall
            height: Theme.itemSizeSmall
            icon.source: "image://theme/icon-m-previous"
            onClicked: executeCommand("prev")
        }

        BackgroundItem {
            width: Theme.itemSizeSmall
            height: Theme.itemSizeSmall
            onClicked: executeCommand("backward")
            Label {
                anchors.centerIn: parent
                text: "«"
                font.pixelSize: Theme.fontSizeHuge
                color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
            }
        }

        IconButton {
            width: Theme.itemSizeSmall
            height: Theme.itemSizeSmall
            icon.source: player && player.speed > 0 ?
                         "image://theme/icon-m-pause" : "image://theme/icon-m-play"
            onClicked: executeCommand("playpause")
        }

        IconButton {
            width: Theme.itemSizeSmall
            height: Theme.itemSizeSmall
            icon.source: "image://assets/icons/icon-m-stop"
            onClicked: executeCommand("stop")
        }

        BackgroundItem {
            width: Theme.itemSizeSmall
            height: Theme.itemSizeSmall
            onClicked: executeCommand("forward")
            Label {
                anchors.centerIn: parent
                text: "»"
                font.pixelSize: Theme.fontSizeHuge
                color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
            }
        }

        IconButton {
            width: Theme.itemSizeSmall
            height: Theme.itemSizeSmall
            icon.source: "image://theme/icon-m-next"
            onClicked: executeCommand("next")
        }
    }

    function getTime(p) {
        return p ? Utils.formatMsecTime(p.time) : "-"
    }

    function getTotalTime(p) {
        if (!p)
            return "-"
        return p.type === "picture" ? "" : Utils.formatMsecTime(p.totalTime)
    }

    function executeCommand(command) {
        if (player === null)
            return
        if (command === "stop")
            player.stop()
        else if (command === "prev")
            player.previous()
        else if (command === "playpause")
            player.playPause()
        else if (command === "next")
            player.next()
        else if (command === "backward")
            player.seekBackward()
        else if (command === "forward")
            player.seekForward()
    }

    function getCurrentDisplay(item) {
        if (!item)
            return ""
        if (item.type === "song")
            return qsTr("<i>%1</i> by <i>%2</i>").arg(item.label).arg(item.artist)
        if (item.type === "unknown" || item.type === "movie" || item.type === "picture")
            return qsTr("<i>%1</i>").arg(item.label)
        return item.type
    }
}
