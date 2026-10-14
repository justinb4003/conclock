#!/usr/bin/env bash
# Package a Linux release bundle as a .deb.
#   tool/package_deb.sh [version] [out_dir] [arch]
# Run after `flutter build linux --release`. Version defaults to pubspec's,
# arch (amd64 or arm64) to this machine's.
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="${1:-$(sed -n 's/^version: *\([^+]*\).*/\1/p' pubspec.yaml)}"
OUT="${2:-build/deb}"
ARCH="${3:-$(dpkg --print-architecture)}"
case "$ARCH" in
  amd64) FLUTTER_ARCH=x64 ;;
  arm64) FLUTTER_ARCH=arm64 ;;
  *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;;
esac
APP_ID=com.conclock.conclock
BUNDLE=build/linux/$FLUTTER_ARCH/release/bundle
[ -x "$BUNDLE/conclock" ] || { echo "No release bundle; run flutter build linux --release" >&2; exit 1; }

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

install -d "$ROOT/opt/conclock" "$ROOT/usr/bin" "$ROOT/DEBIAN" \
  "$ROOT/usr/share/applications" "$ROOT/usr/share/icons/hicolor/512x512/apps" \
  "$ROOT/usr/share/icons/hicolor/256x256/apps" \
  "$ROOT/usr/share/icons/hicolor/scalable/apps"
cp -r "$BUNDLE"/. "$ROOT/opt/conclock/"
ln -s /opt/conclock/conclock "$ROOT/usr/bin/conclock"
install -m 644 web/icons/Icon-512.png \
  "$ROOT/usr/share/icons/hicolor/512x512/apps/$APP_ID.png"
install -m 644 assets/icon/conclock-256.png \
  "$ROOT/usr/share/icons/hicolor/256x256/apps/$APP_ID.png"
install -m 644 assets/icon/conclock.svg \
  "$ROOT/usr/share/icons/hicolor/scalable/apps/$APP_ID.svg"

cat > "$ROOT/usr/share/applications/$APP_ID.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=ConClock
Comment=Lean time tracking for consultants
Exec=/opt/conclock/conclock
Icon=$APP_ID
Categories=Office;ProjectManagement;
StartupWMClass=$APP_ID
Terminal=false
DESKTOP

cat > "$ROOT/DEBIAN/control" <<CONTROL
Package: conclock
Version: $VERSION
Architecture: $ARCH
Maintainer: Justin Buist <justin.buist@gmail.com>
Depends: libgtk-3-0 | libgtk-3-0t64, libayatana-appindicator3-1, libc6
Section: utils
Priority: optional
Installed-Size: $(du -sk "$ROOT/opt" | cut -f1)
Homepage: https://github.com/justinb4003/conclock
Description: Lean, local-only time tracker for consultants
 Tap a client to start tracking, add task notes, and review hours in a
 daily log or weekly timesheet. All data stays in a local JSON file.
CONTROL

find "$ROOT" -type d -exec chmod 755 {} +
chmod -R go-w "$ROOT"
mkdir -p "$OUT"
dpkg-deb --root-owner-group --build "$ROOT" "$OUT/conclock_${VERSION}_${ARCH}.deb"
