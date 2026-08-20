#!/usr/bin/env bash
# Rebuild the local Caelestia QML plugins, then symlink them over the
# pacman-installed ones, so the dev source in this repo is always the version
# Quickshell loads.
#
# Run after editing plugin sources, after a pacman update of caelestia-shell,
# or after any dependency soname bump. That last case is what breaks the shell
# silently: the plugin keeps a NEEDED entry for a library that no longer
# exists, and Quickshell reports it as a chain of "Type X unavailable" errors
# ending in "cannot open shared object file: libcava.so.0".
#
# Idempotent. Needs root to write /usr/lib/qt6/qml/Caelestia; the build itself
# is dropped back to the repo owner so no root-owned artifacts land in the tree.
#
# Hooked from /etc/pacman.d/hooks/caelestia-dev-symlinks.hook

set -euo pipefail

SHELL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$SHELL_DIR/build"
B="$BUILD/qml/Caelestia"
D=/usr/lib/qt6/qml/Caelestia
MODULES=(Internal Models Services)

# Canonical configure flags. A from-scratch reconfigure has to reproduce these,
# so they live here rather than being scraped back out of CMakeCache.txt.
CMAKE_FLAGS=(
    -G Ninja
    -DCMAKE_BUILD_TYPE=RelWithDebInfo
    -DINSTALL_LIBDIR=usr/lib/caelestia
    -DINSTALL_QMLDIR=usr/lib/qt6/qml
    -DINSTALL_QSCONFDIR=etc/xdg/quickshell/caelestia
)

OWNER="$(stat -c %U "$SHELL_DIR")"

# Under the pacman hook we are root, but the build must not be.
as_owner() {
    if [[ $EUID -eq 0 && $OWNER != root ]]; then
        runuser -u "$OWNER" -- "$@"
    else
        "$@"
    fi
}

plugins() {
    printf '%s\n' "$B/libcaelestiaplugin.so"
    local m
    for m in "${MODULES[@]}"; do
        printf '%s\n' "$B/$m/libcaelestia-${m,,}plugin.so"
    done
}

# Every plugin present, with every NEEDED entry resolvable.
links_ok() {
    local f
    while read -r f; do
        [[ -f $f ]] || return 1
        if ldd "$f" 2>/dev/null | grep -q 'not found'; then
            return 1
        fi
    done < <(plugins)
}

configure() {
    [[ ${1-} == fresh ]] && as_owner rm -rf "$BUILD"
    as_owner cmake -B "$BUILD" -S "$SHELL_DIR" "${CMAKE_FLAGS[@]}"
}

[[ -f $BUILD/CMakeCache.txt ]] || configure
as_owner cmake --build "$BUILD"

# A soname bump leaves every object file up to date, so ninja relinks nothing
# and the stale NEEDED entry survives an ordinary rebuild. pkg_check_modules
# also short-circuits on its cached __pkg_config_checked_* guard, so a plain
# reconfigure won't re-query pkg-config either. Only a cache wipe fixes it.
if ! links_ok; then
    echo "unresolved libraries after rebuild, reconfiguring from scratch" >&2
    configure fresh
    as_owner cmake --build "$BUILD"

    if ! links_ok; then
        echo "still unresolved after a clean rebuild:" >&2
        while read -r f; do
            ldd "$f" 2>/dev/null | grep 'not found' | sed "s|^|  $(basename "$f"): |" >&2
        done < <(plugins)
        exit 1
    fi
fi

ln -sfn "$B/qmldir"                "$D/qmldir"
ln -sfn "$B/caelestia.qmltypes"    "$D/caelestia.qmltypes"
ln -sfn "$B/libcaelestiaplugin.so" "$D/libcaelestiaplugin.so"

for m in "${MODULES[@]}"; do
    l=${m,,}
    ln -sfn "$B/$m/qmldir"                          "$D/$m/qmldir"
    ln -sfn "$B/$m/caelestia-$l.qmltypes"           "$D/$m/caelestia-$l.qmltypes"
    ln -sfn "$B/$m/libcaelestia-${l}plugin.so"      "$D/$m/libcaelestia-${l}plugin.so"
done

echo "Caelestia dev plugins rebuilt and symlinked -> $B"
