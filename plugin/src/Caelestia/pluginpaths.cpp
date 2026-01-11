#include <qcoreapplication.h>
#include <qdir.h>
#include <qfileinfo.h>
#include <qimagereader.h>
#include <qlibraryinfo.h>
#include <qloggingcategory.h>
#include <qpluginloader.h>
#include <qtimer.h>

// Ensure Qt can find GIF/WEBP imageformat plugins even when the launcher
// sanitises library paths. This is executed once at startup when the plugin
// is loaded.
static void ensureImagePlugins() {
    auto addPath = [](const QString& path) {
        if (path.isEmpty()) {
            return;
        }

        const QFileInfo info(path);
        if (!info.exists()) {
            return;
        }

        const QString normalized = info.absoluteFilePath();
        auto paths = QCoreApplication::libraryPaths();
        if (!paths.contains(normalized)) {
            QCoreApplication::addLibraryPath(normalized);
        }
    };

    // Always add the default Qt plugin path.
    addPath(QLibraryInfo::path(QLibraryInfo::PluginsPath));

    // Respect explicit overrides.
    const QString envPaths = QString::fromLocal8Bit(qgetenv("QT_PLUGIN_PATH"));
    const auto splitPaths = envPaths.split(QDir::listSeparator(), Qt::SkipEmptyParts);
    for (const auto& path : splitPaths) {
        addPath(path);
    }

    // User hook for custom plugin locations.
    const QByteArray custom = qgetenv("CAELESTIA_QT_PLUGIN_DIR");
    if (!custom.isEmpty()) {
        addPath(QString::fromLocal8Bit(custom));
    }

    // Common system paths (covers Arch/Debian/Fedora/Flatpak), /usr/local, and common local-prefix installs.
    addPath(QCoreApplication::applicationDirPath() + "/../lib/qt6/plugins");
    addPath(QCoreApplication::applicationDirPath() + "/../lib/qt/plugins");
    addPath(QStringLiteral("/usr/lib/qt6/plugins"));
    addPath(QStringLiteral("/usr/lib64/qt6/plugins"));
    addPath(QStringLiteral("/lib/qt6/plugins"));
    addPath(QStringLiteral("/usr/lib/qt/plugins"));
    addPath(QStringLiteral("/usr/lib64/qt/plugins"));
    addPath(QStringLiteral("/usr/local/lib/qt6/plugins"));
    addPath(QStringLiteral("/usr/local/lib/qt/plugins"));
    addPath(QDir::homePath() + "/.local/lib/qt6/plugins");
    addPath(QDir::homePath() + "/.local/lib/qt/plugins");
    addPath(QStringLiteral("/app/lib/qt6/plugins"));
    addPath(QStringLiteral("/run/current-system/sw/lib/qt6/plugins"));

    auto tryLoadPlugin = [](const QStringList& candidates) {
        for (const QString& file : candidates) {
            QPluginLoader loader(file);
            if (loader.load()) {
                return true;
            }
        }
        return false;
    };

    auto findPlugin = [](const QString& name) {
        QStringList candidates;
        const auto libPaths = QCoreApplication::libraryPaths();
        for (const auto& base : libPaths) {
            const QString dir = base + "/imageformats";
            const QString candidate = dir + "/lib" + name + ".so";
            if (QFileInfo::exists(candidate)) {
                candidates << candidate;
            }
        }
        return candidates;
    };

    // If GIF/WEBP are still missing, log once so users know to install qt6-imageformats.
    QTimer::singleShot(0, qApp, [=]() {
        auto formats = QImageReader::supportedImageFormats();
        auto ensureLoaded = [&](const QByteArray& fmt, const QString& plugin) -> bool {
            if (formats.contains(fmt)) {
                return true;
            }
            if (tryLoadPlugin(findPlugin(plugin))) {
                formats = QImageReader::supportedImageFormats();
                return formats.contains(fmt);
            }
            return false;
        };

        const bool gifLoaded = ensureLoaded("gif", "qgif");

        if (!gifLoaded) {
            qWarning() << "Caelestia: Missing GIF imageformat plugin; install qt6-imageformats or point "
                          "CAELESTIA_QT_PLUGIN_DIR at your Qt plugin dir."
                       << "Current plugin search paths:" << QCoreApplication::libraryPaths();
        }
    });
}

Q_COREAPP_STARTUP_FUNCTION(ensureImagePlugins)
