#!/usr/bin/env bash
set -euo pipefail

APP_NAME="RequestLab"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$DIST_DIR/release"

cd "$ROOT_DIR"

APP_VERSION="${APP_VERSION:-0.1.0}"
APP_BUILD="${APP_BUILD:-$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}"
ARCHIVE_BASENAME="$APP_NAME-$APP_VERSION-$APP_BUILD-macOS"
ARCHIVE_PATH="$RELEASE_DIR/$ARCHIVE_BASENAME.zip"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/requestlab-release.XXXXXX")"
PACKAGE_DIST_DIR="$WORK_DIR/dist"
STAGING_DIR="$WORK_DIR/staging"
APP_BUNDLE="$PACKAGE_DIST_DIR/$APP_NAME.app"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$RELEASE_DIR"

DIST_DIR="$PACKAGE_DIST_DIR" \
BUILD_CONFIGURATION=release \
APP_VERSION="$APP_VERSION" \
APP_BUILD="$APP_BUILD" \
"$ROOT_DIR/script/build_and_run.sh" --bundle-only

xattr -cr "$APP_BUNDLE"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
else
  codesign --force --deep --sign - "$APP_BUNDLE"
fi

codesign --verify --deep --strict "$APP_BUNDLE"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
COPYFILE_DISABLE=1 cp -R "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
xattr -cr "$STAGING_DIR/$APP_NAME.app"
rm -f "$ARCHIVE_PATH" "$CHECKSUM_PATH"

COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent "$STAGING_DIR/$APP_NAME.app" "$ARCHIVE_PATH"
shasum -a 256 "$ARCHIVE_PATH" > "$CHECKSUM_PATH"

echo "Release archive: $ARCHIVE_PATH"
echo "Checksum: $CHECKSUM_PATH"
