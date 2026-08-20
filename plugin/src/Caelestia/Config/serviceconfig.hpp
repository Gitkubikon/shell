#pragma once

#include "configobject.hpp"

#include <qstring.h>
#include <qvariant.h>

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;

class ServiceNightLight : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_GLOBAL_PROPERTY(bool, automatic, true)
    CONFIG_GLOBAL_PROPERTY(QString, from, u"20:00"_s)
    CONFIG_GLOBAL_PROPERTY(QString, to, u"08:00"_s)
    CONFIG_GLOBAL_PROPERTY(int, colorTemperature, 4500)

public:
    explicit ServiceNightLight(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class ServiceConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_GLOBAL_PROPERTY(QString, weatherLocation)
    // Guess based on locale
    CONFIG_GLOBAL_PROPERTY(bool, useFahrenheit,
        QLocale().measurementSystem() == QLocale::ImperialUSSystem ||
            QLocale().measurementSystem() == QLocale::ImperialUKSystem)
    // This is always false by default cause apparently even imperial system users don't use it for perf temps?
    CONFIG_GLOBAL_PROPERTY(bool, useFahrenheitPerformance, false)
    // Attempt to guess based on locale
    CONFIG_GLOBAL_PROPERTY(
        bool, useTwelveHourClock, QLocale().timeFormat(QLocale::ShortFormat).toLower().contains(u"a"_s))
    CONFIG_GLOBAL_PROPERTY(QString, gpuType)
    CONFIG_GLOBAL_PROPERTY(int, visualiserBars, 60)
    CONFIG_GLOBAL_PROPERTY(qreal, audioIncrement, 0.1)
    CONFIG_GLOBAL_PROPERTY(qreal, brightnessIncrement, 0.1)
    CONFIG_GLOBAL_PROPERTY(qreal, maxVolume, 1.0)
    CONFIG_GLOBAL_PROPERTY(bool, smartScheme, true)
    CONFIG_GLOBAL_PROPERTY(QString, defaultPlayer, u"Spotify"_s)
    CONFIG_GLOBAL_PROPERTY(QVariantList, playerAliases,
        { vmap({ { u"from"_s, u"com.github.th_ch.youtube_music"_s }, { u"to"_s, u"YT Music"_s } }) })
    CONFIG_GLOBAL_PROPERTY(QString, lyricsBackend, u"Auto"_s)
    // 0 = Monday, 6 = Sunday
    CONFIG_GLOBAL_PROPERTY(int, calendarFirstDayOfWeek, 0)
    // Calendar refresh interval, in ms
    CONFIG_GLOBAL_PROPERTY(int, calendarUpdateInterval, 300000)
    CONFIG_SUBOBJECT(ServiceNightLight, nightLight)

public:
    explicit ServiceConfig(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_nightLight(new ServiceNightLight(this)) {}
};

} // namespace caelestia::config
