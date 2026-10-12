#include "client.h"
#include "remote.h"
#include "server.h"

namespace eu
{
namespace tgcm
{
namespace kontroller
{

namespace
{
void sendRemoteButton(Client* client, const QString& button)
{
    QJsonObject params;
    params.insert("button", button);
    params.insert("keymap", "R1");
    params.insert("holdtime", 0);
    QJsonRpcMessage message = QJsonRpcMessage::createRequest("Input.ButtonEvent", params);
    client->send(message);
}
}

Remote::Remote(QObject *parent) : QObject(parent)
{
}

Client* Remote::client() const
{
    return client_;
}

void Remote::back()
{
    client_->send(QJsonRpcMessage::createRequest("Input.Back"));
}

void Remote::contextMenu()
{
    client_->send(QJsonRpcMessage::createRequest("Input.ContextMenu"));
}

void Remote::downloadSubtitles()
{
    QJsonObject params;
    params.insert("window", "subtitlesearch");
    client_->send(QJsonRpcMessage::createRequest("GUI.ActivateWindow", params));
}

void Remote::down()
{
    sendRemoteButton(client_, "down");
}

void Remote::home()
{
    client_->send(QJsonRpcMessage::createRequest("Input.Home"));
}

void Remote::info()
{
    client_->send(QJsonRpcMessage::createRequest("Input.Info"));
}

void Remote::left()
{
    sendRemoteButton(client_, "left");
}

void Remote::right()
{
    sendRemoteButton(client_, "right");
}

void Remote::select()
{
    sendRemoteButton(client_, "select");
}

void Remote::sendText(const QString& text, bool done)
{
    QJsonObject params;
    params.insert("text", text);
    params.insert("done", done);
    client_->send(QJsonRpcMessage::createRequest("Input.SendText", params));
}

void Remote::showCodec()
{
    client_->send(QJsonRpcMessage::createRequest("Input.ShowCodec"));
}

void Remote::showOSD()
{
    client_->send(QJsonRpcMessage::createRequest("Input.ShowOSD"));
}

void Remote::up()
{
    sendRemoteButton(client_, "up");
}

void Remote::volumeUp()
{
    client_->volumePlugin()->increaseVolume();
}

void Remote::volumeDown()
{
    client_->volumePlugin()->decreaseVolume();
}

void Remote::setClient(Client* client)
{
    if (client_ == client)
        return;
    client_ = client;
    emit clientChanged(client_);
}

}
}
}
