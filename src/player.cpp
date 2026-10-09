#include "player.h"

#include "client.h"
#include "utils.h"

namespace eu
{
namespace tgcm
{
namespace kontroller
{

namespace
{ // helper functions to parse query results

int getTime_(QJsonObject time)
{
	auto hours = time.value("hours").toDouble();
	auto minutes = time.value("minutes").toDouble();
	auto seconds = time.value("seconds").toDouble();
	auto milliseconds = time.value("milliseconds").toDouble();
	return hours * 3600 * 1000 + minutes * 60 * 1000 + seconds * 1000 + milliseconds;
}

int repeatToInt_(QString repeat)
{
	if (repeat == "off")
		return 0;
	if (repeat == "one")
		return 1;
	if (repeat == "all")
		return 2;
	return -1;
}

bool sameSubtitles_(QVector<Subtitle*> const& actuals, QJsonArray const& newSubs)
{
	if (newSubs.size() != actuals.size() - 1)
	{
		qDebug() << "Not same subtitles, not same size";
		return false;
	}
	for (int i = 1; i < actuals.size(); ++i)
	{
		if (!newSubs[i - 1].isObject())
		{
			qDebug() << "Not same subtitles, invalid object";
			return false;
		}
		auto sub = newSubs[i - 1].toObject();
		auto index = sub.value("index").toInt();
		auto language = sub.value("language").toString();
		auto name = sub.value("name").toString();
		if (name.size() == 0)
			name = language;
		if (actuals[i]->index() != index || actuals[i]->name() != name || actuals[i]->language() != language)
		{
			qDebug() << "Not same subtitles, properties differ";
			qDebug() << actuals[i]->index() << index << actuals[i]->name() << name << actuals[i]->language()
			         << language;
			return false;
		}
	}
	return true;
}

bool sameAudio_(QVector<AudioStream*> const& actuals, QJsonArray const& newSubs)
{
	if (newSubs.size() != actuals.size())
		return false;
	for (int i = 0; i < actuals.size(); ++i)
	{
		if (!newSubs[i].isObject())
			return false;
		auto sub = newSubs[i].toObject();
		auto index = sub.value("index").toInt();
		auto language = sub.value("language").toString();
		auto name = sub.value("name").toString();
		if (name.size() == 0)
			name = language;
		if (actuals[i]->index() != index || actuals[i]->name() != name || actuals[i]->language() != language)
			return false;
	}
	return true;
}


} // namespace

int Player::playerId() const
{
	return playerId_;
}

void Player::setPlayerId(int playerId)
{
	if (playerId == playerId_)
		return;
	playerId_ = playerId;
	emit playerIdChanged();
}

QString Player::type() const
{
	return type_;
}

void Player::setType(const QString& type)
{
	setType_(type);
}

void Player::setType_(QString type)
{
	if (type_ == type)
		return;
	type_ = type;
	emit typeChanged();
}

QString Player::current() const
{
	return current_;
}

void Player::setCurrent(const QString& current)
{
	if (current == current_)
		return;
	current_ = current;
	emit currentChanged();
}

int Player::speed() const
{
	return speed_;
}

void Player::setSpeed(int speed)
{
	setSpeed_(speed);
}

void Player::setSpeed_(int speed)
{
	const bool changed = (speed != speed_);
	speed_ = speed;
	if (changed)
		emit speedChanged();

	// Keep the local progress clock strictly tied to Kodi's playback speed.
	// Use a monotonic elapsed clock so QTimer scheduling jitter cannot make
	// Kontroller slowly drift behind the TV.
	if (speed_ == 0 || totalTime_ == 0)
	{
		timer_.stop();
		playbackElapsed_.invalidate();
	}
	else
	{
		playbackElapsed_.start();
		timer_.start();
	}
}

int Player::playlistPosition() const
{
	return playlistPosition_;
}

void Player::setPlaylistPosition(int /*playlistPosition*/)
{
	// TODO: implement
}

void Player::setPlaylistPosition_(int playlistPosition)
{
	if (playlistPosition == playlistPosition_)
		return;
	playlistPosition_ = playlistPosition;
	emit playlistPositionChanged();
}

double Player::percentage() const
{
	return percentage_;
}

int Player::time() const
{
	return time_;
}

void Player::setTime(int time)
{
	setTime_(time);
}

int Player::totalTime() const
{
	return totalTime_;
}

bool Player::shuffled() const
{
	return shuffled_;
}

bool Player::canMove() const
{
	return canMove_;
}

bool Player::canRepeat() const
{
	return canRepeat_;
}

bool Player::canShuffle() const
{
	return canShuffle_;
}

int Player::repeat() const
{
	return repeat_;
}

bool Player::live() const
{
	return live_;
}

bool Player::partyMode() const
{
	return partyMode_;
}

bool Player::canSeek() const
{
	return canSeek_;
}

int Player::playlistId() const
{
	return playlistId_;
}

int Player::currentSubtitleIndex() const
{
	return currentSubtitleIndex_;
}

bool Player::active() const
{
	return active_;
}

void Player::setActive(bool active)
{
	if (active == active_)
		return;
	active_ = active;
	emit activeChanged(active);
}

namespace
{
int propSubtitlesCount(QQmlListProperty<Subtitle>* list)
{
	return static_cast<QVector<Subtitle*>*>(list->data)->size();
}

Subtitle* propSubtitlesAt(QQmlListProperty<Subtitle>* list, int index)
{
	auto l = static_cast<QVector<Subtitle*>*>(list->data);
	if (index < (int)l->size())
		return (*l)[index];
	return nullptr;
}
} // namespace

QQmlListProperty<Subtitle> Player::subtitles()
{
	return QQmlListProperty<Subtitle>(this, &subtitles_, &propSubtitlesCount, &propSubtitlesAt);
}

void Player::setPercentage_(double percentage)
{
	if (percentage_ == percentage)
		return;

	percentage_ = percentage;
	emit percentageChanged(percentage);
}

void Player::setTime_(int time)
{
	// Re-anchor the local clock whenever we receive or calculate a new
	// playback position. This also keeps the displayed time tightly synced.
	if (speed_ != 0 && totalTime_ > 0)
		playbackElapsed_.start();
	else
		playbackElapsed_.invalidate();

	if (time_ == time)
		return;

	time_ = time;
	emit timeChanged(time);

	if (totalTime_ > 0)
		setPercentage_(100.0 * (double)time_ / (double)totalTime_);
}

void Player::setTotalTime_(int totalTime)
{
	if (totalTime_ == totalTime)
		return;

	totalTime_ = totalTime;
	emit totalTimeChanged(totalTime);

	if (totalTime_ > 0)
		setPercentage_(100.0 * (double)time_ / (double)totalTime_);

	if (totalTime_ != 0 && speed_ != 0)
	{
		playbackElapsed_.start();
		timer_.start();
	}
	else
	{
		timer_.stop();
		playbackElapsed_.invalidate();
	}
}

void Player::setShuffled_(bool shuffled)
{
	if (shuffled_ == shuffled)
		return;

	shuffled_ = shuffled;
	emit shuffledChanged(shuffled);
}

void Player::setCanMove_(bool canMove)
{
	if (canMove_ == canMove)
		return;

	canMove_ = canMove;
	emit canMoveChanged(canMove);
}

void Player::setCanRepeat_(bool canRepeat)
{
	if (canRepeat_ == canRepeat)
		return;

	canRepeat_ = canRepeat;
	emit canRepeatChanged(canRepeat);
}

void Player::setCanShuffle_(bool canShuffle)
{
	if (canShuffle_ == canShuffle)
		return;

	canShuffle_ = canShuffle;
	emit canShuffleChanged(canShuffle);
}

void Player::setRepeat_(int repeat)
{
	if (repeat_ == repeat)
		return;

	repeat_ = repeat;
	emit repeatChanged(repeat);
}

void Player::setLive_(bool live)
{
	if (live_ == live)
		return;

	live_ = live;
	emit liveChanged(live);
}

void Player::setPartyMode_(bool partyMode)
{
	if (partyMode_ == partyMode)
		return;

	partyMode_ = partyMode;
	emit partyModeChanged(partyMode);
}

void Player::setCanSeek_(bool canSeek)
{
	if (canSeek_ == canSeek)
		return;

	canSeek_ = canSeek;
	emit canSeekChanged(canSeek);
}

void Player::setPlaylistId_(int playlistId)
{
	if (playlistId_ == playlistId)
		return;

	playlistId_ = playlistId;
	emit playlistIdChanged(playlistId);
}

void Player::setCurrentSubtitleIndex_(int index)
{
	if (currentSubtitleIndex_ != index)
	{
		currentSubtitleIndex_ = index;
		emit currentSubtitleIndexChanged();
	}
}

void Player::setCurrentAudioStreamIndex_(int index)
{
	if (currentAudioStreamIndex_ != index)
	{
		currentAudioStreamIndex_ = index;
		emit currentAudioStreamIndexChanged();
	}
}

void Player::setPlayingInformation(PlayingInformation* playingInformation)
{
	if (playingInformation_ == playingInformation)
		return;

	playingInformation_ = playingInformation;
	emit playingInformationChanged(playingInformation_);
}

void Player::handleShuffleResult_(QJsonRpcServiceReply* reply, bool shuffle)
{
	if (reply && reply->response().result().isString())
	{
		if (reply->response().result().toString() == "OK")
			setShuffled_(shuffle);
	}
}

void Player::handleSetAudioStreamResult_(QJsonRpcServiceReply* reply, int index)
{
	if (!reply)
		return;
	if (reply->response().result().isString())
	{
		if (reply->response().result().toString() == "OK")
			setCurrentAudioStreamIndex_(index);
	}
}

void Player::handleSetSubtitleResult_(QJsonRpcServiceReply* reply, int index)
{
	if (reply && reply->response().result().isString())
	{
		if (reply->response().result().toString() == "OK")
		{
			setCurrentSubtitleIndex_(index);
		}
	}
}

void Player::handlePlayPause_()
{
	QJsonRpcServiceReply* reply = dynamic_cast<QJsonRpcServiceReply*>(sender());
	if (reply)
	{
		QJsonRpcMessage message = reply->response();
		if (message.errorCode() == 0)
		{
			QJsonValue val = message.result();
			if (val.isObject())
			{
				QJsonObject obj = val.toObject();
				QJsonValue typeVal = obj.value("speed");
				if (typeVal.isDouble())
				{
					setSpeed_((int)typeVal.toDouble());
				}
			}
		}
	}
}

void Player::handleSetRepeatResult_(QJsonRpcServiceReply* reply, QString repeat)
{
	if (reply && reply->response().result().isString())
	{
		QString rep = reply->response().result().toString();
		if (rep == "OK")
		{
			setRepeat_(repeatToInt_(repeat));
		}
		else
		{
			int res = repeatToInt_(repeat);
			if (res != -1)
				setRepeat_(res);
		}
	}
}

void Player::refreshPlayerStatus()
{
	QJsonObject parameters;
	parameters["playerid"] = playerId_;
	QJsonArray properties;
	properties.append(QString("speed"));
	properties.append(QString("position"));
	properties.append(QString("type"));
	properties.append(QString("percentage"));
	properties.append(QString("time"));
	properties.append(QString("totaltime"));
	properties.append(QString("playlistid"));
	properties.append(QString("canseek"));
	properties.append(QString("canshuffle"));
	properties.append(QString("canrepeat"));
	properties.append(QString("live"));
	properties.append(QString("repeat"));
	properties.append(QString("shuffled"));

	properties.append(QString("canmove"));
	properties.append(QString("canzoom"));
	properties.append(QString("canrotate"));
	properties.append(QString("canchangespeed"));
	properties.append(QString("subtitles"));
	properties.append(QString("currentsubtitle"));
	properties.append(QString("subtitleenabled"));
	properties.append(QString("audiostreams"));
	properties.append(QString("currentaudiostream"));
	parameters["properties"] = properties;
	QJsonRpcMessage message = QJsonRpcMessage::createRequest("Player.GetProperties", parameters);
	auto reply = client_->send(message);
	if (reply)
		connect(reply, &QJsonRpcServiceReply::finished, this, &Player::handlePlayerStatus_);
}

void Player::updateTimer_()
{
	if (speed_ == 0 || totalTime_ <= 0)
		return;

	if (!playbackElapsed_.isValid())
	{
		playbackElapsed_.start();
		return;
	}

	// Add the real elapsed time instead of assuming every QTimer callback
	// happened exactly on schedule.
	const qint64 elapsed = playbackElapsed_.elapsed();
	if (elapsed <= 0)
		return;

	int newTime = time_ + static_cast<int>(elapsed * speed_);
	newTime = qBound(0, newTime, totalTime_);
	setTime_(newTime);
}

void Player::handlePlayerStatus_()
{
	QJsonRpcServiceReply* reply = dynamic_cast<QJsonRpcServiceReply*>(sender());
	if (reply)
	{
		QJsonRpcMessage message = reply->response();
		if (message.errorCode() == 0)
		{
			QJsonValue val = message.result();
			if (val.isObject())
			{
				QJsonObject obj = val.toObject();
				QJsonValue typeVal = obj.value("type");
				if (!typeVal.isString())
					return;
				QString typ = typeVal.toString();
				if (typ != type())
					setType_(typ);
				// During a seek an older GetProperties reply can arrive after the
				// user moved the slider. Do not let that stale value pull the
				// seek bar back; Player.Seek/OnSeek will supply the authoritative time.
				if (!seekInFlight_)
				{
					if (obj.value("time").isObject())
						setTime_(getTime_(obj.value("time").toObject()));
					else if (obj.value("percentage").isDouble()) // read if time not available
						setPercentage_(obj.value("percentage").toDouble());
				}
				if (obj.value("totaltime").isObject())
					setTotalTime_(getTime_(obj.value("totaltime").toObject()));
				if (obj.value("speed").isDouble())
					setSpeed_(obj.value("speed").toInt());
				if (obj.value("position").isDouble())
					setPlaylistPosition_(obj.value("position").toInt());
				if (obj.value("playlistid").isDouble())
					setPlaylistId_(obj.value("playlistid").toInt());
				if (obj.value("canseek").isBool())
					setCanSeek_(obj.value("canseek").toBool());
				if (obj.value("canshuffle").isBool())
					setCanShuffle_(obj.value("canshuffle").toBool());
				if (obj.value("canrepeat").isBool())
					setCanRepeat_(obj.value("canrepeat").toBool());
				if (obj.value("live").isBool())
					setLive_(obj.value("live").toBool());
				if (obj.value("repeat").isString())
					setRepeat_(repeatToInt_(obj.value("repeat").toString()));
				if (obj.value("shuffled").isBool())
					setShuffled_(obj.value("shuffled").toBool());
				if (obj.value("canmove").isBool())
					setCanMove_(obj.value("canmove").toBool());
				auto subtitles = obj.value("subtitles").toArray();
				if (!subtitles.isEmpty())
				{
					if (!sameSubtitles_(subtitles_, subtitles))
					{
						subtitles_.clear();
						auto nosub = new Subtitle(this);
						nosub->setIndex(-1);
						nosub->setLanguage("");
						nosub->setName(tr("No subtitles"));
						subtitles_.push_back(nosub);
						for (auto sub_ : subtitles)
						{
							auto sub = sub_.toObject();
							auto index = sub.value("index").toInt();
							auto language = sub.value("language").toString();
							auto name = sub.value("name").toString();
							auto s = new Subtitle(this);
							s->setIndex(index);
							s->setLanguage(language);
							if (name.size() > 0)
								s->setName(name);
							else
								s->setName(language);
							subtitles_.push_back(s);
						}
						auto currentSub = obj.value("currentsubtitle").toObject();
						auto enabled = obj.value("subtitleenabled").toBool();
						emit subtitlesChanged();
						if (enabled)
						{
							if (!currentSub.isEmpty())
							{
								auto index = currentSub.value("index");
								setCurrentSubtitleIndex_(index.toInt());
							}
						}
						else
							setCurrentSubtitleIndex_(-1);
					}
				}
				auto audiostreams = obj.value("audiostreams").toArray();
				if(!sameAudio_(audioStreams_, audiostreams))
				{
					audioStreams_.clear();
					if (!audiostreams.isEmpty())
					{
						for (auto stream_ : audiostreams)
						{
							auto stream = stream_.toObject();
							auto index = stream.value("index").toInt();
							auto language = stream.value("language").toString();
							auto name = stream.value("name").toString();
							auto s = new AudioStream(this);
							s->setIndex(index);
							s->setLanguage(language);
							if (name.size() > 0)
								s->setName(name);
							else
								s->setName(language);
							audioStreams_.push_back(s);
						}
						auto currentStream = obj.value("currentaudiostream");
						auto index = currentStream.toObject().value("index").toInt();
						emit audioStreamsChanged();
						setCurrentAudioStreamIndex_(index);
					}
					else
					{
						emit audioStreamsChanged();
						setCurrentAudioStreamIndex_(-1);
					}
				}
				// setBoolValue(obj.value("canzoom"), *player, &Player::setCanZoom);
				// setBoolValue(obj.value("canrotate"), *player, &Player::setCanRotate);
				// setBoolValue(obj.value("canchangespeed"), *player, &Player::setCanChangeSpeed);
			}
		}
		refreshCurrentlyPlaying_();
	}
}

Player::Player(Client* client, int playerId, QObject* parent) :
    QObject(parent), playerId_{playerId}, client_{client}, playingInformation_{new PlayingInformation{this}},
    playlistService_{new PlaylistService{client_, this}}
{
	// Update four times a second. The old 1 Hz clock could visibly trail Kodi
	// by almost a second even when the underlying position was correct.
	timer_.setInterval(250);
	connect(&timer_, &QTimer::timeout, this, &Player::updateTimer_);

	seekRefreshTimer_.setInterval(350);
	seekRefreshTimer_.setSingleShot(true);
	connect(&seekRefreshTimer_, &QTimer::timeout, this, &Player::finishSeekRefresh_);
}

namespace
{
int propAudioStreamsCount(QQmlListProperty<AudioStream>* list)
{
	return static_cast<QVector<AudioStream*>*>(list->data)->size();
}

AudioStream* propAudioStreamsAt(QQmlListProperty<AudioStream>* list, int index)
{
	auto l = static_cast<QVector<AudioStream*>*>(list->data);
	if (index < (int)l->size())
		return (*l)[index];
	return nullptr;
}
} // namespace

QQmlListProperty<eu::tgcm::kontroller::AudioStream> eu::tgcm::kontroller::Player::audioStreams()
{
	return QQmlListProperty<AudioStream>(this, &audioStreams_, &propAudioStreamsCount, &propAudioStreamsAt);
}

void Player::setAudioStreams(QVector<AudioStream*> audioStreams, int currentAudioStreamIndex)
{
	audioStreams_ = std::move(audioStreams);
	currentAudioStreamIndex_ = currentAudioStreamIndex;
	emit audioStreamsChanged();
	emit currentAudioStreamIndexChanged();
}

int Player::currentAudioStreamIndex() const
{
	return currentAudioStreamIndex_;
}

PlayingInformation* Player::playingInformation()
{
	return playingInformation_;
}

PlaylistService* Player::playlistService()
{
	return playlistService_;
}

void Player::stop()
{
	QJsonObject parameters;
	parameters["playerid"] = playerId_;
	QJsonRpcMessage message = QJsonRpcMessage::createRequest("Player.Stop", parameters);
	client_->send(message);
	// no manage of reply, will be handled by a notification and/or polling
}

void Player::previous()
{
	QJsonObject parameters;
	parameters["playerid"] = playerId_;
	parameters["to"] = QLatin1String("previous");
	QJsonRpcMessage message = QJsonRpcMessage::createRequest("Player.GoTo", parameters);
	client_->send(message);
	// no manage of reply, will be handled by a notification and/or polling
}

void Player::next()
{
	QJsonObject parameters;
	parameters["playerid"] = playerId_;
	parameters["to"] = QLatin1String("next");
	QJsonRpcMessage message = QJsonRpcMessage::createRequest("Player.GoTo", parameters);
	client_->send(message);
	// no manage of reply, will be handled by a notification and/or polling
}

void Player::moveToFirst()
{
	QJsonObject parameters;
	parameters["playerid"] = playerId_;
	parameters["to"] = 0;
	QJsonRpcMessage message = QJsonRpcMessage::createRequest("Player.GoTo", parameters);
	client_->send(message);
	// no manage of reply, will be handled by a notification and/or polling
}

void Player::updateProperty(QJsonObject const property)
{
	for (auto it = property.begin(); it != property.end(); ++it)
	{
		auto prop = it.key();
		auto v = it.value();
		if (prop == "shuffled")
		{
			setShuffled_(v.toBool());
		}
		else if (prop == "repeat")
		{
			setRepeat_(repeatToInt_(v.toString()));
		}
		else
		{
			qDebug() << "Unhandled property : " << property;
		}
	}
}

void Player::refreshCurrentlyPlaying_()
{
	QJsonObject parameters;
	parameters["playerid"] = playerId_;
	QJsonArray properties;
	properties.append("thumbnail");
	properties.append("fanart");
	properties.append("art");
	properties.append("title");
	properties.append("file");
	properties.append("artistid");
	properties.append("albumid");
	properties.append("displayartist");
	properties.append("artist");
	properties.append("album");
	properties.append("tvshowid");
	properties.append("showtitle");
	properties.append("episode");
	parameters["properties"] = properties;
	auto mess = QJsonRpcMessage::createRequest("Player.GetItem", parameters);
	auto reply = client_->send(mess);
	connect(reply, &QJsonRpcServiceReply::finished, this, &Player::handleGetItemResponse_);
}

void Player::setPercentage(double percentage)
{
	const double target = qBound(0.0, percentage, 100.0);
	if (totalTime_ > 0)
		seekToTime((int)(totalTime_ * target / 100.0));
}

void Player::seekToTime(int timeMs)
{
	if (totalTime_ <= 0)
		return;

	const int target = qBound(0, timeMs, totalTime_);
	const int serial = ++seekRequestSerial_;
	seekInFlight_ = true;

	// Reflect the user's chosen position immediately. The Player.Seek reply
	// contains Kodi's exact time and will correct this if necessary.
	setTime_(target);

	int remaining = target;
	QJsonObject timeValue;
	timeValue.insert("hours", remaining / 3600000);
	remaining %= 3600000;
	timeValue.insert("minutes", remaining / 60000);
	remaining %= 60000;
	timeValue.insert("seconds", remaining / 1000);
	timeValue.insert("milliseconds", remaining % 1000);

	QJsonObject valueArg;
	valueArg.insert("time", timeValue);

	QJsonObject parameters;
	parameters.insert("playerid", playerId_);
	parameters.insert("value", valueArg);

	QJsonRpcMessage message = QJsonRpcMessage::createRequest("Player.Seek", parameters);
	auto reply = client_->send(message);
	if (reply)
	{
		reply->setProperty("seekSerial", serial);
		connect(reply, &QJsonRpcServiceReply::finished, this, &Player::handleSeekResult_);
	}
	else
	{
		seekInFlight_ = false;
	}
}

void Player::handleSeekResult_()
{
	auto reply = dynamic_cast<QJsonRpcServiceReply*>(sender());
	if (!reply)
		return;

	const int serial = reply->property("seekSerial").toInt();
	if (serial != seekRequestSerial_)
		return; // an older seek finished after a newer one

	const auto response = reply->response();
	if (response.errorCode() == 0 && response.result().isObject())
	{
		const auto result = response.result().toObject();
		if (result.value("totaltime").isObject())
			setTotalTime_(getTime_(result.value("totaltime").toObject()));
		if (result.value("time").isObject())
			setTime_(getTime_(result.value("time").toObject()));
		else if (result.value("percentage").isDouble())
			setPercentage_(result.value("percentage").toDouble());
	}

	// Kodi can emit OnSeek and older GetProperties replies around the same
	// time. Debounce them, then fetch one fresh authoritative state. This is
	// equivalent to the refresh that previously only happened after Pause/Play.
	scheduleStatusRefresh();
}

void Player::scheduleStatusRefresh()
{
	seekInFlight_ = true;
	seekRefreshTimer_.start();
}

void Player::finishSeekRefresh_()
{
	seekInFlight_ = false;
	refreshPlayerStatus();
}

void Player::seekBackward()
{
	QJsonObject parameters;
	parameters.insert("playerid", playerId_);
	QJsonObject valueArg;
	valueArg.insert("step", QLatin1String("smallbackward"));
	parameters.insert("value", valueArg);
	QJsonRpcMessage message = QJsonRpcMessage::createRequest("Player.Seek", parameters);
	client_->send(message);
}

void Player::seekForward()
{
	QJsonObject parameters;
	parameters.insert("playerid", playerId_);
	QJsonObject valueArg;
	valueArg.insert("step", QLatin1String("smallforward"));
	parameters.insert("value", valueArg);
	QJsonRpcMessage message = QJsonRpcMessage::createRequest("Player.Seek", parameters);
	client_->send(message);
}

void Player::playPause()
{
	QJsonObject parameters;
	parameters["playerid"] = playerId_;
	QJsonRpcMessage message = QJsonRpcMessage::createRequest("Player.PlayPause", parameters);
	QJsonRpcServiceReply* reply = client_->send(message);
	if (reply)
		connect(reply, &QJsonRpcServiceReply::finished, this, &Player::handlePlayPause_);
}

void Player::setShuffled(bool shuffled)
{
	QJsonObject parameters;
	parameters.insert("playerid", playerId_);
	parameters.insert("shuffle", shuffled);
	QJsonRpcMessage message = QJsonRpcMessage::createRequest("Player.SetShuffle", parameters);
	auto reply = client_->send(message);
	connect(reply, &QJsonRpcServiceReply::finished, this, [this, reply, shuffled]() {
		handleShuffleResult_(reply, shuffled);
	});
}

void Player::setRepeat(int repeat)
{
	QJsonObject parameters;
	parameters.insert("playerid", playerId_);
	QString val;
	if (repeat == 0)
		val = "off";
	else if (repeat == 1)
		val = "one";
	else if (repeat == 2)
		val = "all";
	else
		return;
	parameters.insert("repeat", val);
	QJsonRpcMessage message = QJsonRpcMessage::createRequest("Player.SetRepeat", parameters);
	auto reply = client_->send(message);
	connect(reply, &QJsonRpcServiceReply::finished, this, [this, reply, val]() { handleSetRepeatResult_(reply, val); });
}

void Player::setCurrentSubtitleIndex(int index)
{
	QJsonObject parameters;
	parameters.insert("playerid", playerId_);
	if (index == -1)
	{
		parameters.insert("enable", false);
		parameters.insert("subtitle", QString("off"));
	}
	else
	{
		parameters.insert("enable", true);
		parameters.insert("subtitle", index);
	}
	QJsonRpcMessage message = QJsonRpcMessage::createRequest("Player.SetSubtitle", parameters);
	auto reply = client_->send(message);
	connect(reply, &QJsonRpcServiceReply::finished, this, [this, reply, index]() {
		handleSetSubtitleResult_(reply, index);
	});
}

void Player::setCurrentAudioStreamIndex(int index)
{
	QJsonObject parameters;
	parameters.insert("playerid", playerId_);
	parameters.insert("stream", index);
	QJsonRpcMessage message = QJsonRpcMessage::createRequest("Player.SetAudioStream", parameters);
	auto reply = client_->send(message);
	connect(reply, &QJsonRpcServiceReply::finished, this, [this, reply, index]() {
		Player::handleSetAudioStreamResult_(reply, index);
	});
}

void Player::handleGetItemResponse_()
{
	auto reply = dynamic_cast<QJsonRpcServiceReply*>(sender());
	if (reply != nullptr)
	{
		PlaylistItem item_;
		auto resp = reply->response().toObject().value("result").toObject();
		auto itemTmp = resp.value("item");
		if (itemTmp.isObject())
		{
			auto item = itemTmp.toObject();
			item_.setFile(item.value("file").toString());
			item_.setType(item.value("type").toString());

			// Kodi often leaves the legacy "thumbnail" field empty for movies/episodes.
			// Kore uses artwork.poster for those media types, so prefer the same source here.
			QString thumbnail = item.value("thumbnail").toString();
			auto art = item.value("art").toObject();
			if (item_.type() == "movie" || item_.type() == "episode")
			{
				QString poster = art.value("poster").toString();
				if (poster.isEmpty())
					poster = art.value("tvshow.poster").toString();
				if (poster.isEmpty())
					poster = art.value("season.poster").toString();
				if (!poster.isEmpty())
					thumbnail = poster;
			}
			if (thumbnail.isEmpty())
				thumbnail = art.value("thumb").toString();
			if (thumbnail.isEmpty())
				thumbnail = item.value("fanart").toString();

			item_.setThumbnail(getImageUrl(client_, thumbnail).toString());
			item_.setFanart(getImageUrl(client_, item.value("fanart").toString()).toString());
			item_.setLabel(item.value("title").toString());
			if (item_.type() == "song")
			{
				item_.setSongId(item.value("id").toInt());
				auto artistIds = item.value("artistid");
				if (artistIds.isArray() && artistIds.toArray().size() > 0)
				{
					item_.setArtistId(artistIds.toArray()[0].toInt());
				}
				item_.setArtist(item.value("displayartist").toString());
				item_.setAlbumId(item.value("albumid").toInt());
				item_.setAlbum(item.value("album").toString());
			}
			else if (item_.type() == "movie")
			{
				item_.setMovieId(item.value("id").toInt());
			}
			else if (item_.type() == "episode")
			{
				item_.setTvshowId(item.value("tvshowid").toInt());
				item_.setTvshow(item.value("showtitle").toString());
			}
			playingInformation_->setItem(item_);
		}
	}
}

} // namespace kontroller
} // namespace tgcm
} // namespace eu
