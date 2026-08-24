#!/bin/bash
#
# prepare-deps.sh — build the minipro dependencies that Visual Minipro bundles.
#
# Everything is built from the git submodules in external/ and dropped at the
# project root, where the Xcode project expects it (all five are git-ignored):
#
#   minipro             CLI binary, embedded into Contents/MacOS
#   libusb-1.0.0.dylib  linked and embedded into Contents/Frameworks
#   infoic.xml          device database, from minipro master
#   infoic_0.7.4.xml    device database, from the minipro 0.7.4 tag
#                       (used when the "legacy infoIC" setting is on)
#   logicic.xml         logic IC test database, from minipro master
#
# The "Prepare minipro dependencies" build phase runs this on every build; it
# exits early unless the submodules moved or an architecture is missing.
#
# Usage: Scripts/prepare-deps.sh [--arch <arch>]... [--force] [--help]
#
# Architectures default to $ARCHS when Xcode runs this, otherwise to a
# universal arm64 + x86_64 build.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)
EXTERNAL_DIR="${PROJECT_ROOT}/external"
MINIPRO_SRC="${EXTERNAL_DIR}/minipro"
LIBUSB_SRC="${EXTERNAL_DIR}/libusb"
WORK_DIR="${PROJECT_ROOT}/.deps"
STAMP_FILE="${WORK_DIR}/stamp"

# infoic.xml from this tag ships alongside the current one for the
# "legacy infoIC" setting. See InfoICUtils.resolveInfoICPath.
LEGACY_TAG="0.7.4"

OUTPUTS=(minipro libusb-1.0.0.dylib infoic.xml infoic_0.7.4.xml logicic.xml)

# Xcode's PATH does not include Homebrew, where autoconf and pkg-config live.
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"

FORCE=0
REQUESTED_ARCHS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --arch)
            [ $# -ge 2 ] || { echo "error: --arch needs an argument" >&2; exit 2; }
            REQUESTED_ARCHS+=("$2")
            shift 2
            ;;
        --force)
            FORCE=1
            shift
            ;;
        --help | -h)
            sed -n '3,22p' "${BASH_SOURCE[0]}" | sed 's|^# \{0,1\}||'
            exit 0
            ;;
        *)
            echo "error: unknown argument '$1'" >&2
            exit 2
            ;;
    esac
done

if [ ${#REQUESTED_ARCHS[@]} -eq 0 ]; then
    # ARCHS is set by Xcode: arm64 for a local Debug build, both for an archive.
    read -r -a REQUESTED_ARCHS <<< "${ARCHS:-arm64 x86_64}"
fi

DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-}"
if [ -z "$DEPLOYMENT_TARGET" ]; then
    DEPLOYMENT_TARGET=$(sed -n 's/.*MACOSX_DEPLOYMENT_TARGET = \([0-9.]*\);.*/\1/p' \
        "${PROJECT_ROOT}/Visual Minipro.xcodeproj/project.pbxproj" | head -1)
fi
: "${DEPLOYMENT_TARGET:=14.6}"

log() {
    echo "prepare-deps: $*"
}

fail() {
    echo "prepare-deps: error: $*" >&2
    exit 1
}

require_tool() {
    command -v "$1" >/dev/null 2>&1 || fail "$1 not found. $2"
}

submodule_sha() {
    git -C "$1" rev-parse HEAD 2>/dev/null || echo "unknown"
}

ensure_submodules() {
    if [ ! -f "${MINIPRO_SRC}/Makefile" ] || [ ! -f "${LIBUSB_SRC}/configure.ac" ]; then
        log "checking out submodules"
        git -C "$PROJECT_ROOT" submodule update --init --recursive \
            || fail "could not check out the submodules in external/"
    fi
    [ -f "${MINIPRO_SRC}/Makefile" ] || fail "external/minipro is empty"
    [ -f "${LIBUSB_SRC}/configure.ac" ] || fail "external/libusb is empty"
}

current_stamp() {
    cat <<EOF
script $(shasum -a 256 "${BASH_SOURCE[0]}" | cut -d' ' -f1)
minipro $(submodule_sha "$MINIPRO_SRC")
libusb $(submodule_sha "$LIBUSB_SRC")
legacy_tag ${LEGACY_TAG}
deployment_target ${DEPLOYMENT_TARGET}
EOF
}

# A universal binary satisfies a request for one of its slices, so builds do
# not thrash between Debug (arm64) and archive (arm64 + x86_64).
has_archs() {
    local file="$1" arch present
    present=$(lipo -archs "$file" 2>/dev/null) || return 1
    for arch in "${REQUESTED_ARCHS[@]}"; do
        [[ " $present " == *" $arch "* ]] || return 1
    done
}

up_to_date() {
    local output
    [ "$FORCE" -eq 0 ] || return 1
    [ -f "$STAMP_FILE" ] || return 1
    [ "$(cat "$STAMP_FILE")" = "$(current_stamp)" ] || return 1
    for output in "${OUTPUTS[@]}"; do
        [ -e "${PROJECT_ROOT}/${output}" ] || return 1
    done
    has_archs "${PROJECT_ROOT}/minipro" || return 1
    has_archs "${PROJECT_ROOT}/libusb-1.0.0.dylib" || return 1
}

copy_tree() {
    (cd "$1" && tar --exclude .git -cf - .) | (cd "$2" && tar -xf -)
}

build_libusb() {
    local src_dir="${WORK_DIR}/build/libusb-src"
    local build_dir="${WORK_DIR}/build/libusb"
    local prefix="${WORK_DIR}/out/libusb"

    require_tool autoreconf "Install it with: brew install autoconf automake libtool"

    log "building libusb (${REQUESTED_ARCHS[*]})"
    rm -rf "$src_dir" "$build_dir" "$prefix"
    mkdir -p "$src_dir" "$build_dir"
    # bootstrap.sh writes into the source tree; copy it to keep the submodule clean.
    copy_tree "$LIBUSB_SRC" "$src_dir"
    (cd "$src_dir" && ./bootstrap.sh >/dev/null 2>&1)
    # --disable-dependency-tracking: gcc-style depfile generation cannot be
    # combined with more than one -arch.
    (
        cd "$build_dir"
        "${src_dir}/configure" \
            --prefix="$prefix" \
            --disable-static \
            --disable-dependency-tracking \
            CC="$CC_BIN" \
            CFLAGS="$ARCH_FLAGS $MIN_VERSION_FLAG" \
            LDFLAGS="$ARCH_FLAGS $MIN_VERSION_FLAG" >/dev/null
        make -j"$(sysctl -n hw.ncpu)" >/dev/null
        make install >/dev/null
    )

    # minipro records this install name when it links, and the app resolves it
    # through its @executable_path/../Frameworks runpath.
    install_name_tool -id @rpath/libusb-1.0.0.dylib "${prefix}/lib/libusb-1.0.0.dylib"
}

build_minipro() {
    local build_dir="${WORK_DIR}/build/minipro"
    local prefix="${WORK_DIR}/out/libusb"
    local git_branch git_hash git_date

    # minipro bakes its git metadata into --version, which the app shows on its
    # info screen. Pass it explicitly: the build tree is a copy without .git.
    git_branch=$(git -C "$MINIPRO_SRC" rev-parse --abbrev-ref HEAD 2>/dev/null || echo master)
    [ "$git_branch" != "HEAD" ] || git_branch=$(git config -f "${PROJECT_ROOT}/.gitmodules" \
        --get submodule.external/minipro.branch 2>/dev/null || echo master)
    git_hash=$(submodule_sha "$MINIPRO_SRC")
    git_date=$(git -C "$MINIPRO_SRC" show -s --format=%ci 2>/dev/null || echo unknown)

    log "building minipro (${REQUESTED_ARCHS[*]})"
    # minipro only builds in-tree; build from a copy to keep the submodule clean.
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    copy_tree "$MINIPRO_SRC" "$build_dir"

    PKG_CONFIG_PATH="${prefix}/lib/pkgconfig" \
        make -C "$build_dir" -j"$(sysctl -n hw.ncpu)" \
        CC="$CC_BIN" \
        CFLAGS="-O2 -Wall $ARCH_FLAGS $MIN_VERSION_FLAG" \
        LDFLAGS="$ARCH_FLAGS $MIN_VERSION_FLAG $RPATH_FLAG" \
        GIT_BRANCH="$git_branch" \
        GIT_HASH="$git_hash" \
        GIT_DATE="$git_date" >/dev/null
}

install_artifacts() {
    local prefix="${WORK_DIR}/out/libusb"

    install -m 755 "${WORK_DIR}/build/minipro/minipro" "${PROJECT_ROOT}/minipro"
    install -m 755 "${prefix}/lib/libusb-1.0.0.dylib" "${PROJECT_ROOT}/libusb-1.0.0.dylib"

    # install_name_tool invalidated libusb's linker signature; Xcode re-signs
    # both with the real identity when it copies them into the bundle.
    codesign --force --sign - "${PROJECT_ROOT}/libusb-1.0.0.dylib" 2>/dev/null

    install -m 644 "${MINIPRO_SRC}/infoic.xml" "${PROJECT_ROOT}/infoic.xml"
    install -m 644 "${MINIPRO_SRC}/logicic.xml" "${PROJECT_ROOT}/logicic.xml"

    if ! git -C "$MINIPRO_SRC" cat-file -e "${LEGACY_TAG}:infoic.xml" 2>/dev/null; then
        git -C "$MINIPRO_SRC" fetch --tags origin >/dev/null 2>&1 || true
    fi
    git -C "$MINIPRO_SRC" show "${LEGACY_TAG}:infoic.xml" > "${PROJECT_ROOT}/infoic_0.7.4.xml" \
        || fail "could not read infoic.xml at tag ${LEGACY_TAG} from external/minipro"
}

ensure_submodules

if up_to_date; then
    exit 0
fi

require_tool make "Install the Xcode command line tools: xcode-select --install"
require_tool pkg-config "Install it with: brew install pkg-config"

CC_BIN=$(xcrun --sdk macosx --find clang)
# The toolchain clang does not pick a default SDK the way /usr/bin/clang does.
SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
ARCH_FLAGS="-isysroot ${SDK_PATH}"
for arch in "${REQUESTED_ARCHS[@]}"; do
    ARCH_FLAGS="${ARCH_FLAGS} -arch ${arch}"
done
MIN_VERSION_FLAG="-mmacosx-version-min=${DEPLOYMENT_TARGET}"
# minipro runs from Contents/MacOS and loads libusb from Contents/Frameworks.
RPATH_FLAG="-Wl,-rpath,@executable_path/../Frameworks"

mkdir -p "$WORK_DIR"
build_libusb
build_minipro
install_artifacts

current_stamp > "$STAMP_FILE"
log "ready: ${OUTPUTS[*]}"
