pragma ComponentBehavior: Bound

import Caelestia
import Quickshell.Widgets
import QtQuick

IconImage {
    id: root

    required property color colour

    asynchronous: true

    layer.enabled: true
    layer.effect: Colouriser {
        sourceColor: analyser.dominantColour
        colorizationColor: root.colour
    }

    function requestUpdateSoon(): void {
        Qt.callLater(() => analyser.requestUpdate());
    }

    layer.onEnabledChanged: {
        if (layer.enabled && status === Image.Ready)
            requestUpdateSoon();
    }

    onStatusChanged: {
        if (layer.enabled && status === Image.Ready)
            requestUpdateSoon();
    }

    ImageAnalyser {
        id: analyser

        sourceItem: root
    }
}
