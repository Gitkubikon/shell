#include "webputils.hpp"

#include <QFile>
#include <webp/decode.h>

namespace caelestia {

std::optional<QImage> decodeWebpFirstFrame(const QString& path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return std::nullopt;
    }

    const QByteArray data = file.readAll();
    if (data.isEmpty()) {
        return std::nullopt;
    }

    WebPDecoderConfig config;
    if (!WebPInitDecoderConfig(&config)) {
        return std::nullopt;
    }

    const VP8StatusCode status = WebPGetFeatures(
        reinterpret_cast<const uint8_t*>(data.constData()), static_cast<size_t>(data.size()), &config.input);
    if (status != VP8_STATUS_OK) {
        WebPFreeDecBuffer(&config.output);
        return std::nullopt;
    }

    config.output.colorspace = MODE_RGBA;

    const VP8StatusCode decStatus = WebPDecode(
        reinterpret_cast<const uint8_t*>(data.constData()), static_cast<size_t>(data.size()), &config);
    if (decStatus != VP8_STATUS_OK) {
        WebPFreeDecBuffer(&config.output);
        return std::nullopt;
    }

    QImage image(
        config.output.u.RGBA.rgba, config.output.width, config.output.height, config.output.u.RGBA.stride,
        QImage::Format_RGBA8888);

    const QImage copy = image.copy(); // detach from WebP buffer
    WebPFreeDecBuffer(&config.output);
    return copy;
}

} // namespace caelestia
