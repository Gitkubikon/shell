//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_NO_XDG_DESKTOP_PORTAL=1

import "modules"
import "modules/drawers"
import "modules/background"
import "modules/areapicker"
import "modules/lock"
import "modules/configeditor"
import Quickshell

ShellRoot {
    Lock {
        id: lock
    }
    Background {
        lock: lock
    }
    Drawers {}
    AreaPicker {}
    WindowFactory {}

    Shortcuts {}
    BatteryMonitor {}
    IdleMonitors {
        lock: lock
    }
}
