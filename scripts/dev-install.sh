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
# Module layout is discovered from the build output: every directory under
# build/qml/Caelestia with a qmldir is a module, and the plugin/typeinfo file
# names come from that qmldir. Nothing here needs updating when upstream adds,
# renames or removes a module.
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

# Module directories in the build: the top-level Caelestia module plus every
# submodule (Caelestia.Config, Caelestia.Services, ...).
module_dirs() {
    local d
    printf '%s\n' "$B"
    for d in "$B"/*/; do
        d=${d%/}
        [[ -f $d/qmldir ]] && printf '%s\n' "$d"
    done
}

# Files Quickshell loads for one module: qmldir, the plugin .so it names, and
# its typeinfo. Names are parsed from qmldir so renames upstream (e.g.
# libcaelestiaplugin.so -> libcaelestia-coreplugin.so) need no script change.
module_files() {
    local dir=$1 q=$1/qmldir plugin typeinfo
    plugin=$(awk '$1 == "plugin" || ($1 == "optional" && $2 == "plugin") { print $NF; exit }' "$q")
    typeinfo=$(awk '$1 == "typeinfo" { print $2; exit }' "$q")

    printf '%s\n' "$q"
    [[ -n $plugin ]]   && printf '%s\n' "$dir/lib$plugin.so"
    [[ -n $typeinfo ]] && printf '%s\n' "$dir/$typeinfo"
    return 0
}

all_files() {
    local d
    while read -r d; do
        module_files "$d"
    done < <(module_dirs)
}

# Every file present, with every NEEDED entry of each plugin resolvable.
links_ok() {
    local f
    while read -r f; do
        if [[ ! -e $f ]]; then
            echo "missing: $f" >&2
            return 1
        fi
        if [[ $f == *.so ]] && ldd "$f" 2>/dev/null | grep -q 'not found'; then
            return 1
        fi
    done < <(all_files)
}

report_unresolved() {
    local f
    while read -r f; do
        [[ $f == *.so ]] || continue
        ldd "$f" 2>/dev/null | grep 'not found' | sed "s|^|  $(basename "$f"): |" >&2
    done < <(all_files)
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
        report_unresolved
        exit 1
    fi
fi

# Drop symlinks into the build dir whose target no longer exists (a module or
# plugin that was renamed/removed upstream), so no dangling links are left
# behind for Quickshell to trip over.
find "$D" -maxdepth 2 -xtype l -lname "$B/*" -print -delete | sed 's|^|removed stale link: |'

while read -r f; do
    rel=${f#"$B"/}
    mkdir -p "$D/$(dirname "$rel")"
    ln -sfn "$f" "$D/$rel"
done < <(all_files)

echo "Caelestia dev plugins rebuilt and symlinked -> $B"
