#include "cachingimagemanager.hpp"

#include <QtQuick/qquickwindow.h>
#include <qcryptographichash.h>
#include <qdir.h>
#include <qfile.h>
#include <qfileinfo.h>
#include <qfuturewatcher.h>
#include <qimagereader.h>
#include <qpainter.h>
#include <qtconcurrentrun.h>
#include <memory>
#include "../webputils.hpp"
#include <webp/demux.h>

namespace caelestia::internal {

qreal CachingImageManager::effectiveScale() const {
    if (m_item && m_item->window()) {
        return m_item->window()->devicePixelRatio();
    }

    return 1.0;
}

QSize CachingImageManager::effectiveSize() const {
    if (!m_item) {
        return QSize();
    }

    const qreal scale = effectiveScale();
    const QSize size = QSizeF(m_item->width() * scale, m_item->height() * scale).toSize();
    m_item->setProperty("sourceSize", size);
    return size;
}

QQuickItem* CachingImageManager::item() const {
    return m_item;
}

void CachingImageManager::setItem(QQuickItem* item) {
    if (m_item == item) {
        return;
    }

    if (m_widthConn) {
        disconnect(m_widthConn);
    }
    if (m_heightConn) {
        disconnect(m_heightConn);
    }

    m_item = item;
    emit itemChanged();

    if (item) {
        m_widthConn = connect(item, &QQuickItem::widthChanged, this, [this]() {
            updateSource();
        });
        m_heightConn = connect(item, &QQuickItem::heightChanged, this, [this]() {
            updateSource();
        });
        updateSource();
    }
}

QUrl CachingImageManager::cacheDir() const {
    return m_cacheDir;
}

void CachingImageManager::setCacheDir(const QUrl& cacheDir) {
    if (m_cacheDir == cacheDir) {
        return;
    }

    m_cacheDir = cacheDir;
    if (!m_cacheDir.path().endsWith("/")) {
        m_cacheDir.setPath(m_cacheDir.path() + "/");
    }
    emit cacheDirChanged();
}

QString CachingImageManager::path() const {
    return m_path;
}

void CachingImageManager::setPath(const QString& path) {
    if (m_path == path) {
        return;
    }

    m_path = path;
    emit pathChanged();

    // eww but I'll do it again here
    const bool animated = !path.isEmpty() && isAnimated(path);
    if (m_animated != animated) {
        m_animated = animated;
        emit animatedChanged();
    }

    if (!path.isEmpty()) {
        updateSource(path);
    }
}

void CachingImageManager::setPreferAnimated(bool preferAnimated) {
    if (m_preferAnimated == preferAnimated) {
        return;
    }

    m_preferAnimated = preferAnimated;
    emit preferAnimatedChanged();

    if (!m_path.isEmpty()) {
        updateSource(m_path);
    }
}

void CachingImageManager::updateSource() {
    updateSource(m_path);
}

void CachingImageManager::updateSource(const QString& path) {
    if (path.isEmpty()) {
        m_shaPath.clear();
        if (m_animated) {
            m_animated = false;
            emit animatedChanged();
        }
        if (m_cachePath.isValid()) {
            m_cachePath = QUrl();
            emit cachePathChanged();
        }
        if (m_item) {
            m_item->setProperty("source", QUrl());
        }
        return;
    }

    const QFileInfo info(path);
    if (!info.exists() || !info.isFile()) {
        m_shaPath.clear();
        if (m_animated) {
            m_animated = false;
            emit animatedChanged();
        }
        if (m_cachePath.isValid()) {
            m_cachePath = QUrl();
            emit cachePathChanged();
        }
        if (m_item) {
            m_item->setProperty("source", QUrl());
        }
        return;
    }

    const bool animated = isAnimated(path);
    if (m_animated != animated) {
        m_animated = animated;
        emit animatedChanged();
    }

    const bool useAnimation = animated && m_preferAnimated;

    if (useAnimation) {
        const QSize size = effectiveSize();

        if (!m_item || !size.width() || !size.height()) {
            m_shaPath.clear();
            return;
        }

        const QUrl cache;
        if (m_cachePath != cache) {
            m_cachePath = cache;
            emit cachePathChanged();
        }

        m_item->setProperty("source", QUrl::fromLocalFile(path));
        m_shaPath.clear();
        return;
    }

    if (path == m_shaPath) {
        return;
    }

    m_shaPath = path;

    const auto future = QtConcurrent::run(&CachingImageManager::sha256sum, path);

    const auto watcher = new QFutureWatcher<QString>(this);

        connect(watcher, &QFutureWatcher<QString>::finished, this, [watcher, path, this]() {
            if (m_path != path) {
                // Object is destroyed or path has changed, ignore
                watcher->deleteLater();
                return;
            }

            const QSize size = effectiveSize();

            if (!m_item || !size.width() || !size.height()) {
                // Size not ready yet; clear sha so a later updateSource can retry instead of sticking
                if (m_shaPath == path) {
                    m_shaPath.clear();
                }
                watcher->deleteLater();
                return;
            }

        const int mode = m_item->property("fillMode").toInt();
        const QString fillMode = mode == Qt::KeepAspectRatio ? "PreserveAspectFit" : (mode == Qt::KeepAspectRatioByExpanding ? "PreserveAspectCrop" : "Stretch");
        // clang-format off
        const QString filename = QString("%1@%2x%3-%4.png")
            .arg(watcher->result()).arg(size.width()).arg(size.height())
            .arg(fillMode == "PreserveAspectCrop" ? "crop" : fillMode == "PreserveAspectFit" ? "fit" : "stretch");
        // clang-format on

        const QUrl cache = m_cacheDir.resolved(QUrl(filename));
        if (m_cachePath == cache) {
            watcher->deleteLater();
            return;
        }

        m_cachePath = cache;
        emit cachePathChanged();

        if (!cache.isLocalFile()) {
            qWarning() << "CachingImageManager::updateSource: cachePath" << cache << "is not a local file";
            watcher->deleteLater();
            return;
        }

        const QImageReader reader(cache.toLocalFile());
        if (reader.canRead()) {
            m_item->setProperty("source", cache);
        } else {
            bool wroteCache = false;

            // Synchronous WebP fallback: decode first frame and save as PNG
            if (path.endsWith(".webp", Qt::CaseInsensitive)) {
                if (const auto webp = decodeWebpFirstFrame(path); webp.has_value()) {
                    QImage image = *webp;

                    // Mirror the scaling logic from createCache to match target size/fill mode
                    if (size.isValid()) {
                        const Qt::AspectRatioMode mode = fillMode == "PreserveAspectCrop"
                            ? Qt::KeepAspectRatioByExpanding
                            : fillMode == "PreserveAspectFit" ? Qt::KeepAspectRatio : Qt::IgnoreAspectRatio;
                        image = image.scaled(size, mode, Qt::SmoothTransformation);

                        if (fillMode == "PreserveAspectCrop" || fillMode == "PreserveAspectFit") {
                            QImage canvas(size, QImage::Format_ARGB32);
                            canvas.fill(Qt::transparent);

                            QPainter painter(&canvas);
                            painter.drawImage((size.width() - image.width()) / 2, (size.height() - image.height()) / 2, image);
                            painter.end();
                            image = canvas;
                        }
                    }

                    const QString parent = QFileInfo(cache.toLocalFile()).absolutePath();
                    if (QDir().mkpath(parent) && image.save(cache.toLocalFile())) {
                        wroteCache = true;
                        m_item->setProperty("source", cache);
                    }
                }
            }

            if (!wroteCache) {
                m_item->setProperty("source", QUrl::fromLocalFile(path));
                createCache(path, cache.toLocalFile(), fillMode, size);
            }
        }

        // Clear current running sha if same
        if (m_shaPath == path) {
            m_shaPath = QString();
        }

        watcher->deleteLater();
    });

    watcher->setFuture(future);
}

QUrl CachingImageManager::cachePath() const {
    return m_cachePath;
}

void CachingImageManager::createCache(
    const QString& path, const QString& cache, const QString& fillMode, const QSize& size) const {
    QThreadPool::globalInstance()->start([path, cache, fillMode, size] {
        QImageReader reader(path);
        reader.setAutoTransform(true);

        // Decode as close to target as possible to save time/memory for huge wallpapers
        if (size.isValid()) {
            const QSize native = reader.size();
            if (native.isValid()) {
                const Qt::AspectRatioMode mode = fillMode == "PreserveAspectCrop"
                    ? Qt::KeepAspectRatioByExpanding
                    : fillMode == "PreserveAspectFit" ? Qt::KeepAspectRatio : Qt::IgnoreAspectRatio;
                reader.setScaledSize(native.scaled(size, mode));
            }
        }

        QImage image = reader.read();
        if (image.isNull()) {
            // Fallback: decode WebP without Qt plugin support
            if (path.endsWith(".webp", Qt::CaseInsensitive)) {
                if (const auto webp = decodeWebpFirstFrame(path); webp.has_value()) {
                    image = *webp;
                }
            }

            if (image.isNull()) {
                qWarning() << "CachingImageManager::createCache: failed to read" << path << reader.errorString();
                return;
            }
        }

        image.convertTo(QImage::Format_ARGB32);

        if (fillMode == "PreserveAspectCrop") {
            image = image.scaled(size, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation);
        } else if (fillMode == "PreserveAspectFit") {
            image = image.scaled(size, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        } else {
            image = image.scaled(size, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
        }

        if (fillMode == "PreserveAspectCrop" || fillMode == "PreserveAspectFit") {
            QImage canvas(size, QImage::Format_ARGB32);
            canvas.fill(Qt::transparent);

            QPainter painter(&canvas);
            painter.drawImage((size.width() - image.width()) / 2, (size.height() - image.height()) / 2, image);
            painter.end();

            image = canvas;
        }

        const QString parent = QFileInfo(cache).absolutePath();
        if (!QDir().mkpath(parent) || !image.save(cache)) {
            qWarning() << "CachingImageManager::createCache: failed to save to" << cache;
        }
    });
}

QString CachingImageManager::sha256sum(const QString& path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "CachingImageManager::sha256sum: failed to open" << path;
        return "";
    }

    QCryptographicHash hash(QCryptographicHash::Sha256);
    hash.addData(&file);
    file.close();

    return hash.result().toHex();
}

bool CachingImageManager::isAnimated(const QString& path) {
    QImageReader reader(path);
    if (reader.canRead() && reader.supportsAnimation()) {
        return reader.imageCount() > 1;
    }

    const auto supportedFormats = QImageReader::supportedImageFormats();
    const bool supportsWebp = supportedFormats.contains("webp");

    // Fallback: detect animated WebP only when the plugin exists
    if (supportsWebp && path.endsWith(".webp", Qt::CaseInsensitive)) {
        QFile file(path);
        if (file.open(QIODevice::ReadOnly)) {
            const QByteArray data = file.readAll();
            WebPData webpData;
            WebPDataInit(&webpData);
            webpData.bytes = reinterpret_cast<const uint8_t*>(data.constData());
            webpData.size = static_cast<size_t>(data.size());

            std::unique_ptr<WebPDemuxer, decltype(&WebPDemuxDelete)> demux(
                WebPDemux(&webpData), &WebPDemuxDelete);
            if (demux) {
                const uint32_t frames = WebPDemuxGetI(demux.get(), WEBP_FF_FRAME_COUNT);
                return frames > 1;
            }
        }
    }

    return false;
}

} // namespace caelestia::internal
