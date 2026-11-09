pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components.misc

Singleton {
    id: root

    readonly property list<MprisPlayer> list: Mpris.players.values
    readonly property MprisPlayer active: props.manualActive ?? list.find(p => getIdentity(p) === GlobalConfig.services.defaultPlayer) ?? list[0] ?? null
    property alias manualActive: props.manualActive

    // Dedup key for progressive metadata (e.g. mpv-mpris/yt-dlp player fills title then artist later).
    property string lastNowPlayingKey: ""

    function getIdentity(player: MprisPlayer): string {
        if (!player)
            return "";
        const alias = GlobalConfig.services.playerAliases.values.find(a => a.from === player.identity);
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

    // Quickshell only emits postTrackChanged when trackid/url/title change, so late
    // artist updates (common with mpv-mpris + yt-dlp player) never retrigger it. Watch
    // title/artist too and toast once both are usable.
    function maybeToastNowPlaying(): void {
        if (!GlobalConfig.utilities.toasts.nowPlaying)
            return;

        const player = root.active;
        if (!player)
            return;

        const title = player.trackTitle ?? "";
        const artist = player.trackArtist ?? "";
        if (!title || !artist)
            return;

        const key = `${getIdentity(player)}\0${player.uniqueId}\0${title}\0${artist}`;
        if (key === lastNowPlayingKey)
            return;

        lastNowPlayingKey = key;
        Toaster.toast(Tr.tr("Now playing"), Tr.trCtx("%1 - %2", "track artist and title").arg(artist).arg(title), "music_note");
    }

    onActiveChanged: lastNowPlayingKey = ""

    Connections {
        function onPostTrackChanged(): void {
            root.maybeToastNowPlaying();
        }

        function onTrackTitleChanged(): void {
            root.maybeToastNowPlaying();
        }

        function onTrackArtistChanged(): void {
            root.maybeToastNowPlaying();
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
