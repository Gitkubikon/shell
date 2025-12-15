import Quickshell.Io
import QtQuick

JsonObject {
    property string weatherLocation: "" // A lat,long pair or empty for autodetection, e.g. "37.8267,-122.4233"
    property bool useFahrenheit: [Locale.ImperialUSSystem, Locale.ImperialSystem].includes(Qt.locale().measurementSystem)
    property bool useTwelveHourClock: Qt.locale().timeFormat(Locale.ShortFormat).toLowerCase().includes("a")
    // 0 = Monday, 6 = Sunday (matches reference calendar helper)
    property int calendarFirstDayOfWeek: 0
    property int calendarUpdateInterval: 300000 // ms
    property string gpuType: ""
    property int visualiserBars: 45
    property real audioIncrement: 0.1
    property real maxVolume: 1.0
    property bool smartScheme: true
    property string defaultPlayer: "Spotify"
    property list<var> playerAliases: [
        {
            "from": "com.github.th_ch.youtube_music",
            "to": "YT Music"
        }
    ]
    property NightLightConfig nightLight: NightLightConfig {}

    component NightLightConfig: JsonObject {
        property bool automatic: false
        property string from: "19:00"
        property string to: "06:30"
        property int colorTemperature: 4500
    }
}
