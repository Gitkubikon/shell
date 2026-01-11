#pragma once

#include <QImage>
#include <QQuickItem>
#include <QTimer>
#include <vector>
#include <qqml.h>

namespace caelestia {

class WebpPlayer : public QQuickItem {
    Q_OBJECT
    QML_NAMED_ELEMENT(WebpPlayer)
    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(int fillMode READ fillMode WRITE setFillMode NOTIFY fillModeChanged)
    Q_PROPERTY(bool playing READ isPlaying WRITE setPlaying NOTIFY playingChanged)
    Q_PROPERTY(Status status READ status NOTIFY statusChanged)
    Q_PROPERTY(int currentFrame READ currentFrame WRITE setCurrentFrame NOTIFY currentFrameChanged)
    Q_PROPERTY(int frameCount READ frameCount NOTIFY statusChanged)

public:
    enum Status { Null, Loading, Ready, Error };
    Q_ENUM(Status)

    explicit WebpPlayer(QQuickItem* parent = nullptr);

    QString source() const;
    void setSource(const QString& src);

    int fillMode() const;
    void setFillMode(int mode);

    bool isPlaying() const;
    void setPlaying(bool p);

    Status status() const;

    int currentFrame() const;
    void setCurrentFrame(int frame);

    int frameCount() const { return static_cast<int>(m_frames.size()); }

signals:
    void sourceChanged();
    void fillModeChanged();
    void playingChanged();
    void statusChanged();
    void currentFrameChanged();

protected:
    QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) override;

private:
    void load();
    void clear();
    void scheduleNextFrame();
    void advance();

    QString m_source;
    int m_fillMode = 0; // mirrors Image.FillMode
    bool m_playing = false;
    Status m_status = Null;
    int m_currentFrame = 0;

    std::vector<QImage> m_frames;
    std::vector<int> m_durations; // ms
    QSize m_frameSize;
    QTimer m_timer;
};

} // namespace caelestia
