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

Remote::Remote(QObject *parent) :
    QObject(parent)
{
}

Client* Remote::client() const
{
	return client_;
}

void Remote::back()
{
	QJsonRpcMessage message = QJsonRpcMessage::createRequest("Input.Back");
	client_->send(message);
}

void Remote::contextMenu()
{
	QJsonRpcMessage message = QJsonRpcMessage::createRequest("Input.ContextMenu");
	client_->send(message);
}

void Remote::downloadSubtitles()
{
	QJsonObject params;
	params.insert("window", "subtitlesearch");
	QJsonRpcMessage message = QJsonRpcMessage::createRequest("GUI.ActivateWindow", params);
	client_->send(message);
}

void Remote::down()
{
	sendRemoteButton(client_, "down");
}

void Remote::home()
{
	QJsonRpcMessage message = QJsonRpcMessage::createRequest("Input.Home");
	client_->send(message);
}

void Remote::info()
{
	QJsonRpcMessage message = QJsonRpcMessage::createRequest("Input.Info");
	client_->send(message);
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

void Remote::showCodec()
{
	QJsonRpcMessage message = QJsonRpcMessage::createRequest("Input.ShowCodec");
	client_->send(message);
}

void Remote::showOSD()
{
	QJsonRpcMessage message = QJsonRpcMessage::createRequest("Input.ShowOSD");
	client_->send(message);
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
