pragma ComponentBehavior: Bound

import qs.components
import qs.components.images
import qs.components.filedialog
import qs.services
import qs.config
import qs.utils
import Caelestia.Internal as CaelestiaInternal
import QtQuick

Item {
    id: root

    // Current wallpaper path (managed by Caelestia)
    property string source: Wallpapers.current

    // Cached thumbnails for ultra-fast initial paint
    property string thumbSource: Wallpapers.currentThumbnail

    // Expose the currently visible image item (for visualiser/shaders)
    readonly property Item current: activeSlot?.activeChild

    // Track which slot is currently active
    property Item activeSlot: one
    // Serial to discard stale loads during rapid preview scrubbing
    property int loadSerial: 0

    property var sessionLock: null
    readonly property bool sessionLocked: sessionLock ? sessionLock.secure : false

    anchors.fill: parent

    // When the source changes, update the "other" slot to enable a crossfade.
    onSourceChanged: {
        if (!source) {
            activeSlot = null;
        } else {
            loadSerial++;
            // Update the inactive slot
            const nextSlot = (activeSlot === one) ? two : one;
            nextSlot.loadAndBecomeActive(source, thumbSource, loadSerial);
        }
    }

    // Empty-state UI (unchanged)
    Loader {
        anchors.fill: parent
        active: !root.source

        sourceComponent: StyledRect {
            color: Colours.palette.m3surfaceContainer

            Row {
                anchors.centerIn: parent
                spacing: Appearance.spacing.large

                MaterialIcon {
                    text: "sentiment_stressed"
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.extraLarge * 5
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.spacing.small

                    StyledText {
                        text: qsTr("Wallpaper missing?")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Appearance.font.size.extraLarge * 2
                        font.bold: true
                    }

                    StyledRect {
                        implicitWidth: selectWallText.implicitWidth + Appearance.padding.large * 2
                        implicitHeight: selectWallText.implicitHeight + Appearance.padding.small * 2

                        radius: Appearance.rounding.full
                        color: Colours.palette.m3primary

                        FileDialog {
                            id: dialog
                            title: qsTr("Select a wallpaper")
                            filterLabel: qsTr("Image files")
                            filters: Images.validImageExtensions
                            onAccepted: path => Wallpapers.setWallpaper(path)
                        }

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onPrimary
                            function onClicked() { dialog.open(); }
                        }

                        StyledText {
                            id: selectWallText
                            anchors.centerIn: parent
                            text: qsTr("Set it now!")
                            color: Colours.palette.m3onPrimary
                            font.pointSize: Appearance.font.size.large
                        }
                    }
                }
            }
        }
    }

    // Two slots that we crossfade between
    Img { id: one }
    Img { id: two }

    // ----------------------------------------------------------------------
    // Img: persistent dual-renderer (static + gif), no Loader, no reparenting
    // ----------------------------------------------------------------------
    component Img: Item {
        id: img
        anchors.fill: parent

        // Path we want this slot to display
        property string path: ""
        // Optional thumbnail for faster first paint
        property string thumb: ""

        // Determine renderer (animated renderer for GIF or WebP)
        readonly property bool isAnimatedFormat: path && (path.toLowerCase().endsWith(".gif") || path.toLowerCase().endsWith(".webp"))
        readonly property bool isWebp: path && path.toLowerCase().endsWith(".webp")

        // The child that is currently visible (either staticImg or gifImg)
        readonly property Item activeChild: isAnimatedFormat ? gifImg : staticImg

        // Track which root load this slot represents
        property int serial: -1

        // Load new wallpaper and become active when ready
        function loadAndBecomeActive(newPath, newThumb, newSerial) {
            serial = newSerial;
            path = newPath;
            thumb = newThumb;
            activationTimeout.restart();

            // Clear everything first to force a reload
            staticImg.visible = false;
            staticImg.thumb = "";
            staticImg.source = "";
            staticImg.fullReady = false;
            staticImg.path = "";

            gifImg.visible = false;
            gifImg.playing = false;
            gifImg.source = "";

            webpImg.visible = false;
            webpImg.source = "";

            // Defer loading to next tick to ensure QML clears the old image
            reloadTimer.restart();
        }

        Timer {
            id: reloadTimer
            interval: 1
            repeat: false
            onTriggered: {
                if (isAnimatedFormat) {
                    if (isWebp) {
                        webpImg.source = img.path;
                        webpImg.visible = true;
                    } else {
                        gifImg.source = img.path;
                        gifImg.visible = true;
                    }
                } else {
                    staticImg.thumb = img.thumb;
                    staticImg.thumbUrl = img.thumb ? Qt.resolvedUrl(img.thumb) : "";
                    staticImg.fullSource = Qt.resolvedUrl(img.path);
                    staticImg.fullReady = false;
                    staticImg.source = staticImg.thumbUrl ? staticImg.thumbUrl : staticImg.fullSource;
                    staticImg.path = img.path;
                    staticImg.visible = true;
                }

                // Check if already ready (sync/cached load)
                checkAndActivate();
            }
        }

        // Force activation if decode stalls; avoids “stuck” previews
        Timer {
            id: activationTimeout
            interval: 180
            repeat: false
            onTriggered: img.checkAndActivate(true)
        }

        // Check if ready and activate this slot
        function checkAndActivate(force = false) {
            if (serial !== root.loadSerial)
                return;

            if (!force) {
                if (isAnimatedFormat) {
                    if (isWebp) {
                        if (webpImg.status !== CaelestiaInternal.WebpPlayer.Ready)
                            return;
                    } else {
                        if (gifImg.status !== Image.Ready)
                            return;
                    }
                } else if (staticImg.status !== Image.Ready) {
                    return;
                }
            }

            // Start GIF playback (playing is bound, just set frame)
            if (isAnimatedFormat) {
                if (!isWebp)
                    gifImg.currentFrame = 0;
                else
                    webpImg.currentFrame = 0;
            }

            // Make this slot active
            root.activeSlot = img;
        }

        // Crossfade/scale state lives on the slot wrapper
        opacity: 0
        scale: Wallpapers.showPreview ? 1 : 0.8

        // --- Static renderer (persistent) ---
        CachingImage {
            id: staticImg
            anchors.fill: parent
            visible: false
            property string thumb: ""
            property url fullSource: ""
            property url thumbUrl: ""
            property bool fullReady: false
            // Try fast thumbnail first; fall back to full-res
            source: thumb ? Qt.resolvedUrl(thumb) : ""

            onStatusChanged: {
                if (!visible)
                    return;

                if (status === Image.Ready) {
                    const isThumbSource = thumb && source.toString() === thumbUrl.toString();
                    if (!isThumbSource) {
                        fullReady = true;
                        img.checkAndActivate();
                    } else {
                        // Thumb loaded; now request full-res
                        source = fullSource;
                    }
                } else if (status === Image.Error) {
                    // Fall back to full-res if thumb fails
                    if (thumb && source.toString() === thumbUrl.toString()) {
                        source = fullSource;
                    }
                }
                // If decode drags, the timer will flip us to the new slot anyway
            }

            onVisibleChanged: {
                if (visible)
                    img.checkAndActivate();
            }
        }

        // --- GIF renderer (persistent AnimatedImage) ---
        AnimatedImage {
            id: gifImg
            anchors.fill: parent
            visible: false
            cache: true
            asynchronous: true
            playing: visible && (root.activeSlot === img) && !root.sessionLocked
            fillMode: Image.PreserveAspectCrop

            onStatusChanged: {
                if (status === Image.Ready && visible) {
                    img.checkAndActivate();
                }
            }

            onVisibleChanged: {
                if (visible)
                    img.checkAndActivate();
                else
                    playing = false;
            }
        }

        // --- WebP renderer (fallback, independent of Qt imageformat plugin) ---
        CaelestiaInternal.WebpPlayer {
            id: webpImg
            anchors.fill: parent
            visible: false
            playing: visible && (root.activeSlot === img) && !root.sessionLocked
            fillMode: Image.PreserveAspectCrop

            onStatusChanged: {
                if (status === CaelestiaInternal.WebpPlayer.Ready && visible) {
                    img.checkAndActivate();
                }
            }

            onVisibleChanged: {
                if (visible)
                    img.checkAndActivate();
                else
                    playing = false;
            }
        }

        // Animate *this slot* (not the child), to avoid touching decoder items
        states: State {
            name: "visible"
            when: root.activeSlot === img
            PropertyChanges { target: img; opacity: 1; scale: 1 }
        }

        transitions: [
            Transition {
                to: "visible"
                ParallelAnimation {
                    NumberAnimation {
                        target: img
                        property: "opacity"
                        duration: Appearance.anim.durations.large
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                    NumberAnimation {
                        target: img
                        property: "scale"
                        duration: Appearance.anim.durations.large
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }
            },
            Transition {
                from: "visible"; to: ""
                ParallelAnimation {
                    NumberAnimation {
                        target: img
                        property: "opacity"
                        duration: Appearance.anim.durations.large
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                    NumberAnimation {
                        target: img
                        property: "scale"
                        duration: Appearance.anim.durations.large
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }
            }
        ]

        // Initialize once at creation
        Component.onCompleted: {
            if (root.source && root.activeSlot === img) {
                loadAndBecomeActive(root.source, root.thumbSource, root.loadSerial);
            }
        }
    }
}
