import QtQuick 2.0
import QtFeedback 5.0
import harbour.eu.tgcm 1.0
import Sailfish.Silica 1.0
import "."

Page {
    id: page
    allowedOrientations: Orientation.Portrait

    Remote {
        id: remoteController
        client: appClient
    }

    HapticsEffect {
        id: commandFeedback
        intensity: 0.5
        duration: 70
    }

    // Keep the control pad thumb-friendly and clear of the screen edges.
    property int padSize: Math.min(page.width - 2 * Theme.paddingLarge,
                                   page.height * 0.43)
    property int padCell: Math.floor(padSize / 3)
    function feedback() {
        commandFeedback.start()
    }

    // Kore-inspired 3x3 remote layout:
    // Home | Up   | Info
    // Left | OK   | Right
    // Back | Down | Menu
    //
    // The complete pad sits near the bottom for one-handed use.
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
                feedback()
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
                feedback()
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
                feedback()
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
                feedback()
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
                feedback()
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
