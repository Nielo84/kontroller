import QtQuick 2.6
import Sailfish.Silica 1.0
import harbour.eu.tgcm 1.0
import Nemo.Notifications 1.0
import "./components"

ApplicationWindow {
    allowedOrientations: Orientation.All
    _defaultPageOrientations: Orientation.All
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    id: appWindow

    // Remote is now the real root page, not a page pushed after the menu.
    initialPage: Component {
        RemoteControl {}
    }

    function openRemote() {
        pageStack.push(Qt.resolvedUrl("RemoteControl.qml"))
    }

    Component.onCompleted: {
        // Establish the last/only Kodi connection without needing KontrollerMain.
        if (appSettings.lastServer.length > 0) {
            appClient.switchToServer(appSettings.lastServer)
        } else if (appSettings.servers.length === 1) {
            appClient.switchToServer(appSettings.servers[0].uuid)
            appSettings.lastServer = appSettings.servers[0].uuid
        }
    }

    bottomMargin: controllerPanel.visibleSize

    DockedPanel {
        id: controllerPanel
        width: parent.width
        dock: Dock.Bottom
        visible: true
        height: col.height
        open: {
            if (pageStack.currentPage && !!pageStack.currentPage.hidePanel)
                return false
            return !!playerControl.player
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: Theme.paddingSmall

            Row {
                visible: !pageStack.currentPage || !pageStack.currentPage.overridePanelImg
                anchors.left: parent.left
                anchors.right: parent.right
                bottomPadding: Theme.paddingSmall

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Image {
                        source: playerControl.player ? playerControl.player.playingInformation.currentItem.thumbnail : ""
                        height: Theme.iconSizeLarge
                        width: Theme.iconSizeLarge
                        id: thumbnailImg
                        fillMode: Image.PreserveAspectFit
                        MouseArea {
                            anchors.fill: parent
                            onClicked: appWindow.openRemote()
                        }
                    }
                    Text {
                        text: (appClient && appClient.volumePlugin) ?
                                  "🔈 " + appClient.volumePlugin.formatVolume(appClient.volumePlugin.currentVolume) : ""
                        width: parent.width
                        font.pixelSize: Theme.fontSizeExtraSmall
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.primaryColor
                        MouseArea {
                            anchors.fill: parent
                            onClicked: appWindow.openRemote()
                        }
                    }
                }

                PlayerControl {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - thumbnailImg.width
                    player: appClient.playerService.activePlayer
                    id: playerControl
                }
            }
        }
    }

    Notification {
        id: theNotif
        appName: "kontroller"
        appIcon: "/usr/share/icons/hicolor/86x86/apps/kontroller.png"
        category: "kontroller"
    }

    Connections {
        target: appClient.downloadService
        onDownloadStarted: {
            var message = qsTr("Download of %1 started").arg(file)
            theNotif.body = message
            theNotif.previewBody = message
            theNotif.summary = qsTr("Download started")
            theNotif.previewSummary = qsTr("Download started")
            theNotif.publish()
        }
        onDownloadCompleted: {
            var message = qsTr("Download of %1 complete").arg(file)
            theNotif.body = message
            theNotif.previewBody = message
            theNotif.summary = qsTr("Download complete")
            theNotif.previewSummary = qsTr("Download complete")
            theNotif.publish()
        }
        onDownloadError: {
            var message = qsTr("Download of %1 failed with error %2").arg(file).arg(error)
            theNotif.body = message
            theNotif.previewBody = message
            theNotif.summary = qsTr("Download error")
            theNotif.previewSummary = qsTr("Download error")
            theNotif.publish()
        }
    }
}
