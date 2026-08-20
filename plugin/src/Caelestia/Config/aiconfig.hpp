#pragma once

#include "configobject.hpp"

#include <qstring.h>
#include <qvariant.h>

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;

class AiPolicies : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    // 0 = allow all, 1 = warn for online, 2 = block online models
    CONFIG_GLOBAL_PROPERTY(int, restrictOnlineModels, 0)

public:
    explicit AiPolicies(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class AiConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_GLOBAL_PROPERTY(QString, model, u"gemini-2.0-flash"_s)
    CONFIG_GLOBAL_PROPERTY(QString, tool, u"search"_s)
    CONFIG_GLOBAL_PROPERTY(qreal, temperature, 0.5)
    CONFIG_GLOBAL_PROPERTY(QString, systemPrompt)
    CONFIG_GLOBAL_PROPERTY(QVariantList, extraModels)
    CONFIG_SUBOBJECT(AiPolicies, policies)

public:
    explicit AiConfig(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_policies(new AiPolicies(this)) {}
};

} // namespace caelestia::config
