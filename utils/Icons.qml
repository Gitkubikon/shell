pragma Singleton

import QtQuick
import qs.config
import Quickshell
import Quickshell.Services.Notifications
import Caelestia

QtObject {
    readonly property string battery_0_bar: "battery_0_bar"
    readonly property string battery_1_bar: "battery_1_bar"
    readonly property string battery_2_bar: "battery_2_bar"
    readonly property string battery_3_bar: "battery_3_bar"
    readonly property string battery_4_bar: "battery_4_bar"
    readonly property string battery_5_bar: "battery_5_bar"
    readonly property string battery_6_bar: "battery_6_bar"
    readonly property string battery_full: "battery_full"
    readonly property string battery_charging_full: "battery_charging_full"
    readonly property string battery_unknown: "battery_unknown"
    readonly property string battery_alert: "battery_alert"
    readonly property string battery_saver: "battery_saver"

    readonly property string volume_up: "volume_up"
    readonly property string volume_down: "volume_down"
    readonly property string volume_mute: "volume_mute"
    readonly property string volume_off: "volume_off"

    readonly property string brightness_high: "brightness_high"
    readonly property string brightness_medium: "brightness_medium"
    readonly property string brightness_low: "brightness_low"

    readonly property string wifi: "wifi"
    readonly property string wifi_off: "wifi_off"
    readonly property string signal_wifi_0_bar: "signal_wifi_0_bar"
    readonly property string signal_wifi_1_bar: "signal_wifi_1_bar"
    readonly property string signal_wifi_2_bar: "signal_wifi_2_bar"
    readonly property string signal_wifi_3_bar: "signal_wifi_3_bar"
    readonly property string signal_wifi_4_bar: "signal_wifi_4_bar"
    readonly property string settings_ethernet: "settings_ethernet"

    readonly property string bluetooth: "bluetooth"
    readonly property string bluetooth_disabled: "bluetooth_disabled"
    readonly property string bluetooth_connected: "bluetooth_connected"
    readonly property string bluetooth_searching: "bluetooth_searching"

    readonly property string vpn_lock: "vpn_lock"
    readonly property string vpn_key: "vpn_key"

    readonly property string night_sight_auto: "night_sight_auto"
    readonly property string light_mode: "light_mode"
    readonly property string dark_mode: "dark_mode"

    readonly property string power_settings_new: "power_settings_new"
    readonly property string settings: "settings"
    readonly property string search: "search"
    readonly property string menu: "menu"
    readonly property string more_vert: "more_vert"
    readonly property string more_horiz: "more_horiz"
    readonly property string close: "close"
    readonly property string check: "check"
    readonly property string add: "add"
    readonly property string remove: "remove"
    readonly property string chevron_left: "chevron_left"
    readonly property string chevron_right: "chevron_right"
    readonly property string expand_more: "expand_more"
    readonly property string expand_less: "expand_less"

    readonly property string home: "home"
    readonly property string person: "person"
    readonly property string info: "info"
    readonly property string help: "help"
    readonly property string error: "error"
    readonly property string warning: "warning"
    readonly property string notifications: "notifications"
    readonly property string notifications_active: "notifications_active"
    readonly property string notifications_none: "notifications_none"
    readonly property string notifications_off: "notifications_off"

    readonly property string play_arrow: "play_arrow"
    readonly property string pause: "pause"
    readonly property string skip_next: "skip_next"
    readonly property string skip_prev: "skip_previous"
    readonly property string stop: "stop"
    readonly property string fast_forward: "fast_forward"
    readonly property string fast_rewind: "fast_rewind"
    readonly property string repeat: "repeat"
    readonly property string repeat_one: "repeat_one"
    readonly property string shuffle: "shuffle"

    readonly property string app_registration: "app_registration"
    readonly property string apps: "apps"
    readonly property string calendar_today: "calendar_today"
    readonly property string schedule: "schedule"
    readonly property string language: "language"
    readonly property string palette: "palette"
    readonly property string image: "image"
    readonly property string photo_library: "photo_library"
    readonly property string folder: "folder"
    readonly property string description: "description"
    readonly property string insert_drive_file: "insert_drive_file"
    readonly property string desktop_windows: "desktop_windows"
    readonly property string computer: "computer"
    readonly property string laptop: "laptop"
    readonly property string smartphone: "smartphone"
    readonly property string tablet: "tablet"
    readonly property string watch: "watch"

    readonly property string mic: "mic"
    readonly property string mic_off: "mic_off"
    readonly property string videocam: "videocam"
    readonly property string videocam_off: "videocam_off"
    readonly property string headset: "headset"
    readonly property string headset_mic: "headset_mic"
    readonly property string speaker: "speaker"
    readonly property string cast: "cast"

    readonly property string lock: "lock"
    readonly property string lock_open: "lock_open"
    readonly property string visibility: "visibility"
    readonly property string visibility_off: "visibility_off"

    readonly property string keyboard: "keyboard"
    readonly property string mouse: "mouse"
    readonly property string print: "print"
    readonly property string save: "save"
    readonly property string delete: "delete"
    readonly property string edit: "edit"
    readonly property string share: "share"
    readonly property string content_copy: "content_copy"
    readonly property string content_paste: "content_paste"
    readonly property string undo: "undo"
    readonly property string redo: "redo"

    readonly property string star: "star"
    readonly property string star_border: "star_border"
    readonly property string star_half: "star_half"
    readonly property string favorite: "favorite"
    readonly property string favorite_border: "favorite_border"
    readonly property string thumb_up: "thumb_up"
    readonly property string thumb_down: "thumb_down"

    function forNotification(notif: Notification): string {
        if (notif.appIcon) return notif.appIcon;
        return apps;
    }
}