#pragma once

#include <optional>
#include <qimage.h>

namespace caelestia {

// Decode the first frame of a WebP image. Returns nullopt on failure.
std::optional<QImage> decodeWebpFirstFrame(const QString& path);

} // namespace caelestia
