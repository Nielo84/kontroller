import QtQuick 2.0
import Sailfish.Silica 1.0
import "../utils.js" as Utils


Item {

    property bool showSlider: true
    property bool showLabel: true
    property var player : null
    implicitHeight: row.y + row.height


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
            if(!down && player && player.canSeek) {
                var target = Math.round(sliderValue)
                player.seekToTime(target)

                // Dragging a Silica Slider breaks its value binding. Restore it
                // after sending the seek so later Kodi time updates keep moving it.
                value = Qt.binding(function() { return player ? player.time : 0 })
            }
        }
        visible: showSlider && player && player.type !== "picture"
        valueText: down ? Utils.formatMsecTime(sliderValue) : ""
    }

    Label {
        anchors.left: parent.left
        anchors.leftMargin: Theme.paddingMedium
        anchors.verticalCenter: progressSlider.verticalCenter
        text: getTime(player)
        font.pixelSize: Theme.fontSizeExtraSmall
        id:lblCurrentTime
        color:Theme.highlightColor
    }
    Label {
        anchors.right: parent.right
        anchors.rightMargin: Theme.paddingMedium
        anchors.verticalCenter: progressSlider.verticalCenter
        text: getTotalTime(player)
        font.pixelSize: Theme.fontSizeExtraSmall
        id:lblTotalTime
        color:Theme.highlightColor
    }

    Label {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.paddingSmall
        anchors.rightMargin: Theme.paddingSmall
        anchors.bottom:progressSlider.bottom
        font.pixelSize: Theme.fontSizeExtraSmall
        horizontalAlignment: Text.AlignHCenter
        text: player?getCurrentDisplay(player.playingInformation.currentItem):""
        elide: Text.ElideMiddle
        clip:true
        color:Theme.highlightColor
        visible: showLabel
        id: lblDesc
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: lblDesc.visible?lblDesc.bottom:lblCurrentTime.bottom;
        height:Theme.iconSizeMedium + Theme.paddingMedium
        spacing: Theme.paddingLarge
        id:row
        Repeater {
            model: [
                {"icon":"image://theme/icon-m-previous", "action":"prev"},
    //            {"icon":"image://theme/icon-m-left", "action":"backward"},
                {"icon":"image://assets/icons/icon-m-stop", "action":"stop"},
                {"icon":["image://theme/icon-m-play", "image://theme/icon-m-pause"], "action":"playpause"},
    //            {"icon":"image://theme/icon-m-right", "action":"forward"},
                {"icon":"image://theme/icon-m-next", "action":"next"}
            ]
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Theme.paddingMedium
            height:Theme.iconSizeMedium
            delegate: IconButton {
                width:Theme.iconSizeMedium
                height:Theme.iconSizeMedium
                icon.source: {
                    if(typeof(model.modelData.icon) === "string")
                        return model.modelData.icon;
                    else
                    {
                        if(player && player.speed > 0)
                            return model.modelData.icon[1];
                        else
                            return model.modelData.icon[0];
                    }
                }
                onClicked: executeCommand(model.modelData.action);
            }
        }
    }


    function getTime(player)
    {
        if(player) {
            // Kodi's on-screen time effectively changes near the middle of the
            // second, while flooring here made Kontroller look about one second
            // behind. Round the displayed current time to the nearest second.
            return Utils.formatMsecTime(player.time + 500);
        }
        return "-";
    }

    function getTotalTime(player)
    {
        if(player)
        {
            if(player.type === "picture")
                return "";
            else
                return Utils.formatMsecTime(player.totalTime);
        }
        return "-";
    }

    function executeCommand(command)
    {
        if(player === null)
            return;
        if(command === "stop")
            player.stop();
        if(command === "prev")
            player.previous();
        if(command === "playpause")
            player.playPause();
        if(command === "next")
            player.next();
        if(command === "backward")
            player.seekBackward();
        if(command === "forward")
            player.seekForward();
    }

    function getCurrentDisplay(item)
    {
        if(!item)
            return ""
        else if(item.type === "song")
            return qsTr("<i>%1</i> by <i>%2</i>").arg(item.label).arg(item.artist)
        else if(item.type === "unknown")
            return qsTr("<i>%1</i>").arg(item.label)
        else if(item.type === "movie")
            return qsTr("<i>%1</i>").arg(item.label)
        else if(item.type === "picture")
            return qsTr("<i>%1</i>").arg(item.label)
        else
            return item.type;
    }

    function getNextDisplay(item)
    {
        if(!item)
            return ""
        else if(item.type === "song")
            return qsTr("Next: <i>%1</i> by <i>%2</i>").arg(item.label).arg(item.artist)
        else if(item.type === "unknown")
            return qsTr("Next: <i>%1</i>").arg(item.label)
        else
            return item.type;
    }

}
