pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Caelestia
import qs.components.misc
import qs.config

Singleton {
    id: root

    readonly property list<MprisPlayer> list: Mpris.players.values
    readonly property MprisPlayer active: props.manualActive ?? list.find(p => getIdentity(p) === Config.services.defaultPlayer) ?? list[0] ?? null
    property alias manualActive: props.manualActive

    function getIdentity(player: MprisPlayer): string {
        const alias = Config.services.playerAliases.find(a => a.from === player.identity);
        return alias?.to ?? player.identity;
    }

    // Cache art URL per track — some players (e.g. YouTube Music via browser)
    // briefly provide mpris:artUrl then clear it in a later metadata update.
    property string _cachedArtUrl: ""
    property string _cachedTrackId: ""

    function getArtUrl(player: MprisPlayer): string {
        if (!player)
            return "";

        const trackId = player.trackTitle + "\0" + player.trackArtist;
        if (trackId !== _cachedTrackId) {
            _cachedTrackId = trackId;
            _cachedArtUrl = "";
        }

        if (player.trackArtUrl) {
            _cachedArtUrl = player.trackArtUrl;
            return player.trackArtUrl;
        }

        if (_cachedArtUrl)
            return _cachedArtUrl;

        const url = player.metadata["xesam:url"] ?? "";
        if (url.startsWith("https://www.youtube.com/watch") || url.startsWith("https://music.youtube.com/watch")) {
            const id = url.match(/[?&]v=([\w-]{11})/)?.[1];
            if (id) {
                _cachedArtUrl = `https://img.youtube.com/vi/${id}/hqdefault.jpg`;
                return _cachedArtUrl;
            }
        }
        return "";
    }

    Connections {
        function onPostTrackChanged() {
            if (!Config.utilities.toasts.nowPlaying) {
                return;
            }
            if (root.active.trackArtist != "" && root.active.trackTitle != "") {
                Toaster.toast(qsTr("Now Playing"), qsTr("%1 - %2").arg(root.active.trackArtist).arg(root.active.trackTitle), "music_note");
            }
        }

        target: root.active
    }

    PersistentProperties {
        id: props

        property MprisPlayer manualActive

        reloadableId: "players"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaToggle"
        description: "Toggle media playback"
        onPressed: {
            const active = root.active;
            if (active && active.canTogglePlaying)
                active.togglePlaying();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaPrev"
        description: "Previous track"
        onPressed: {
            const active = root.active;
            if (active && active.canGoPrevious)
                active.previous();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaNext"
        description: "Next track"
        onPressed: {
            const active = root.active;
            if (active && active.canGoNext)
                active.next();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaStop"
        description: "Stop media playback"
        onPressed: root.active?.stop()
    }

    IpcHandler {
        function getActive(prop: string): string {
            const active = root.active;
            return active ? active[prop] ?? "Invalid property" : "No active player";
        }

        function list(): string {
            return root.list.map(p => root.getIdentity(p)).join("\n");
        }

        function play(): void {
            const active = root.active;
            if (active?.canPlay)
                active.play();
        }

        function pause(): void {
            const active = root.active;
            if (active?.canPause)
                active.pause();
        }

        function playPause(): void {
            const active = root.active;
            if (active?.canTogglePlaying)
                active.togglePlaying();
        }

        function previous(): void {
            const active = root.active;
            if (active?.canGoPrevious)
                active.previous();
        }

        function next(): void {
            const active = root.active;
            if (active?.canGoNext)
                active.next();
        }

        function stop(): void {
            root.active?.stop();
        }

        target: "mpris"
    }
}
