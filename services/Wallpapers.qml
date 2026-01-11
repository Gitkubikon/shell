pragma Singleton

import qs.config
import qs.utils
import Caelestia.Models
import Quickshell
import Quickshell.Io
import QtQuick

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property list<string> smartArg: Config.services.smartScheme ? [] : ["--no-smart"]

    readonly property string currentThumbPath: `${Paths.state}/wallpaper/thumbnail.jpg`

    property bool showPreview: false
    readonly property string current: showPreview ? previewPath : actualCurrent
    readonly property string currentThumbnail: showPreview ? previewThumbnail : actualThumbnail

    property string previewPath
    property string previewThumbnail
    property string actualCurrent
    property string actualThumbnail
    property bool previewColourLock

    function setWallpaper(path, thumb) {
        actualCurrent = path;
        actualThumbnail = thumb || currentThumbPath;
        Quickshell.execDetached(["caelestia", "wallpaper", "-f", path, ...smartArg]);
    }

    function preview(path, thumb) {
        previewPath = path;
        previewThumbnail = thumb || "";
        showPreview = true;

        if (Colours.scheme === "dynamic")
            getPreviewColoursProc.running = true;
    }

    function stopPreview() {
        showPreview = false;
        if (!previewColourLock)
            Colours.showPreview = false;
    }

    list: wallpapers.entries
    key: "relativePath"
    useFuzzy: Config.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })

    IpcHandler {
        target: "wallpaper"

        function get() {
            return root.actualCurrent;
        }

        function set(path: string) {
            root.setWallpaper(path);
        }

        function list() {
            return root.list.map(w => w.path).join("\n");
        }
    }

    FileView {
        path: root.currentNamePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.actualCurrent = text().trim();
            root.actualThumbnail = root.currentThumbPath;
            root.previewColourLock = false;
        }
    }

    FileSystemModel {
        id: wallpapers

        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Images
    }

    Process {
        id: getPreviewColoursProc

        command: ["caelestia", "wallpaper", "-p", root.previewPath, ...root.smartArg]
        stdout: StdioCollector {
            onStreamFinished: {
                Colours.load(text, true);
                Colours.showPreview = true;
            }
        }
    }
}
