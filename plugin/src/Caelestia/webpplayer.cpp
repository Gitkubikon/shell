#include "webpplayer.hpp"

#include <QFile>
#include <QSGSimpleTextureNode>
#include <QSGTexture>
#include <QSGTextureProvider>
#include <QtQuick/qquickwindow.h>
#include <webp/demux.h>
#include <webp/decode.h>

namespace caelestia {

WebpPlayer::WebpPlayer(QQuickItem* parent)
    : QQuickItem(parent) {
    setFlag(ItemHasContents, true);

    m_timer.setSingleShot(true);
    connect(&m_timer, &QTimer::timeout, this, &WebpPlayer::advance);
}

QString WebpPlayer::source() const {
    return m_source;
}

void WebpPlayer::setSource(const QString& src) {
    if (m_source == src) {
        return;
    }
    m_source = src;
    emit sourceChanged();
    load();
}

int WebpPlayer::fillMode() const {
    return m_fillMode;
}

void WebpPlayer::setFillMode(int mode) {
    if (m_fillMode == mode) {
        return;
    }
    m_fillMode = mode;
    emit fillModeChanged();
    update();
}

bool WebpPlayer::isPlaying() const {
    return m_playing;
}

void WebpPlayer::setPlaying(bool p) {
    if (m_playing == p) {
        return;
    }
    m_playing = p;
    emit playingChanged();
    if (m_playing && m_status == Ready && !m_frames.empty()) {
        scheduleNextFrame();
    } else {
        m_timer.stop();
    }
}

WebpPlayer::Status WebpPlayer::status() const {
    return m_status;
}

int WebpPlayer::currentFrame() const {
    return m_currentFrame;
}

void WebpPlayer::setCurrentFrame(int frame) {
    if (frame < 0 || frame >= frameCount()) {
        return;
    }
    if (m_currentFrame == frame) {
        return;
    }
    m_currentFrame = frame;
    emit currentFrameChanged();
    update();
    scheduleNextFrame();
}

void WebpPlayer::clear() {
    m_frames.clear();
    m_durations.clear();
    m_frameSize = QSize();
    m_currentFrame = 0;
    m_timer.stop();
}

void WebpPlayer::load() {
    clear();
    if (m_source.isEmpty()) {
        m_status = Null;
        emit statusChanged();
        update();
        return;
    }

    m_status = Loading;
    emit statusChanged();

    QFile file(m_source);
    if (!file.open(QIODevice::ReadOnly)) {
        m_status = Error;
        emit statusChanged();
        update();
        return;
    }

    const QByteArray data = file.readAll();
    WebPData webpData;
    WebPDataInit(&webpData);
    webpData.bytes = reinterpret_cast<const uint8_t*>(data.constData());
    webpData.size = static_cast<size_t>(data.size());

    std::unique_ptr<WebPDemuxer, decltype(&WebPDemuxDelete)> demux(WebPDemux(&webpData), &WebPDemuxDelete);
    if (!demux) {
        m_status = Error;
        emit statusChanged();
        update();
        return;
    }

    WebPIterator iter;
    if (!WebPDemuxGetFrame(demux.get(), 1, &iter)) {
        m_status = Error;
        emit statusChanged();
        update();
        return;
    }

    const int frameCount = static_cast<int>(WebPDemuxGetI(demux.get(), WEBP_FF_FRAME_COUNT));
    m_frames.reserve(static_cast<size_t>(frameCount));
    m_durations.reserve(static_cast<size_t>(frameCount));

    do {
        WebPDecoderConfig config;
        if (!WebPInitDecoderConfig(&config)) {
            continue;
        }

        if (WebPGetFeatures(iter.fragment.bytes, iter.fragment.size, &config.input) != VP8_STATUS_OK) {
            WebPFreeDecBuffer(&config.output);
            continue;
        }

        config.output.colorspace = MODE_RGBA;

        if (WebPDecode(iter.fragment.bytes, iter.fragment.size, &config) != VP8_STATUS_OK) {
            WebPFreeDecBuffer(&config.output);
            continue;
        }

        QImage image(
            config.output.u.RGBA.rgba, config.output.width, config.output.height, config.output.u.RGBA.stride,
            QImage::Format_RGBA8888);
        m_frames.emplace_back(image.copy());
        m_durations.emplace_back(iter.duration > 0 ? static_cast<int>(iter.duration) : 100);

        WebPFreeDecBuffer(&config.output);
    } while (WebPDemuxNextFrame(&iter));

    WebPDemuxReleaseIterator(&iter);

    if (m_frames.empty()) {
        m_status = Error;
        emit statusChanged();
        update();
        return;
    }

    m_frameSize = m_frames.front().size();
    m_status = Ready;
    emit statusChanged();
    update();

    if (m_playing) {
        scheduleNextFrame();
    }
}

void WebpPlayer::scheduleNextFrame() {
    if (!m_playing || m_frames.empty()) {
        m_timer.stop();
        return;
    }
    const int duration = m_durations.empty() ? 100 : m_durations[static_cast<size_t>(m_currentFrame) % m_durations.size()];
    m_timer.start(qMax(duration, 10));
}

void WebpPlayer::advance() {
    if (!m_playing || m_frames.empty()) {
        return;
    }
    m_currentFrame = static_cast<int>((static_cast<size_t>(m_currentFrame) + 1) % m_frames.size());
    emit currentFrameChanged();
    update();
    scheduleNextFrame();
}

QSGNode* WebpPlayer::updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) {
    if (m_status != Ready || m_frames.empty() || !window()) {
        delete oldNode;
        return nullptr;
    }

    QSGSimpleTextureNode* node = static_cast<QSGSimpleTextureNode*>(oldNode);
    if (!node) {
        node = new QSGSimpleTextureNode();
    }

    QImage frame = m_frames[static_cast<size_t>(m_currentFrame) % m_frames.size()];
    QSGTexture* texture = window()->createTextureFromImage(frame, QQuickWindow::TextureCanUseAtlas);
    node->setTexture(texture);
    node->setOwnsTexture(true);

    const QSizeF itemSize(width(), height());
    const QSizeF frameSize = frame.size();
    QRectF target(0, 0, itemSize.width(), itemSize.height());

    if (m_fillMode == 1) { // PreserveAspectFit
        const qreal sf = qMin(itemSize.width() / frameSize.width(), itemSize.height() / frameSize.height());
        const QSizeF scaled(frameSize.width() * sf, frameSize.height() * sf);
        target = QRectF((itemSize.width() - scaled.width()) / 2.0, (itemSize.height() - scaled.height()) / 2.0, scaled.width(), scaled.height());
    } else if (m_fillMode == 2) { // PreserveAspectCrop
        const qreal sf = qMax(itemSize.width() / frameSize.width(), itemSize.height() / frameSize.height());
        const QSizeF scaled(frameSize.width() * sf, frameSize.height() * sf);
        target = QRectF((itemSize.width() - scaled.width()) / 2.0, (itemSize.height() - scaled.height()) / 2.0, scaled.width(), scaled.height());
    } else {
        target = QRectF(0, 0, itemSize.width(), itemSize.height());
    }

    node->setRect(target);
    node->markDirty(QSGNode::DirtyGeometry | QSGNode::DirtyMaterial);
    return node;
}

} // namespace caelestia
