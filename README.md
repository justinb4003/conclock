# ConClock

A lean, local-only time tracker for consultants. No accounts, no network:
one JSON file. Runs on Linux, Windows, macOS, Android and the web.

See [USER_GUIDE.md](USER_GUIDE.md) for how to use it.

- **Track**: start, stop and switch clients and tasks with the play button.
  Name the running task in the status card (it autocompletes from earlier
  tasks). Clients line up most recently started first.
- **Log**: one week at a time, grouped by day or by client; edit any entry,
  add time by hand.
- **Timesheet**: a Mon-Sun grid of clients (and their tasks) by day, with
  optional rounding up to the half hour and a copy-for-spreadsheet button.
- **Clients**: add, rename, recolor, reorder, archive, delete.
- **Settings**: theme and colors, time display, tray behavior, data
  location, backups, and the version and release date.

Desktop builds keep running in the system tray (menu bar on macOS) when the
window closes, and the window title shows the version.

## Data

- Desktop / mobile: `conclock.json` in the app-support directory (Linux:
  `~/.local/share/com.conclock.conclock/`), shown under Settings -> Data
  location. On the web: the browser's IndexedDB (database `conclock`); data
  from older versions in `localStorage` moves over on first load.
- The file is versioned (currently `"version": 2`). Client and entry ids are
  UUIDv7s (RFC 9562), so they sort by creation time; ids from older versions
  are converted on load, keeping their creation time, and the original file
  is kept as `conclock.json.pre-uuid-<timestamp>`.
- Writes are atomic (temp file + rename). Side copies are kept, newest 3 of
  each kind: `.corrupt-` for unreadable files, `.unsaved-` for edits that lost
  to a change made elsewhere (with a message and an Export button),
  `.pre-import-` before an import, `.before-switch-` / `.replaced-` when
  changing the data folder.
- If a save fails (disk or browser storage full), a red banner says so and
  offers Export / Retry; nothing fails silently.
- Desktop: Settings -> Data location -> *Choose folder...* moves the data into
  any folder, e.g. a synced one (Dropbox, OneDrive, Syncthing) to share it
  between computers. Changes made elsewhere are picked up live.

## Build

```sh
flutter run -d linux        # needs: clang cmake ninja-build lld libgtk-3-dev
                            #        libayatana-appindicator3-dev
flutter run -d chrome
flutter build web
flutter test
flutter test --platform chrome test/web   # storage and UUID tests in a browser
python3 tool/seed_test_data.py   # 4 weeks of 9-5 test data (--remove to undo)
```

Local builds show "Development build" under Settings -> About; CI passes the
commit's date in with `--dart-define=RELEASE_DATE=YYYY-MM-DD`.

## Releases

GitHub Actions (`.github/workflows/build.yml`) tests and builds on every push:
Linux x64 and arm64 (`.tar.gz` and `.deb`), Windows x64 (setup `.exe`), macOS
universal (`.dmg`) and Android (`.apk`) as workflow artifacts. Pushes to
`main` also deploy the web app to GitHub Pages:
https://justinb4003.github.io/conclock/ (data stays in your browser; open
tabs stay in sync). To release, bump `version:` in `pubspec.yaml`, then push
a `v*` tag (e.g. `git tag v0.7.0 && git push origin v0.7.0`) to publish the
builds as a GitHub release.

```sh
sudo apt install ./conclock_0.7.0_amd64.deb   # installs to /opt/conclock
tool/package_deb.sh                             # build the .deb locally
```

**Windows**: run `conclock-<version>-windows-x64-setup.exe`. It installs for
the current user (no admin prompt), adds a Start menu entry and optionally a
desktop shortcut and start-at-sign-in; installing a newer version upgrades in
place, and uninstalling keeps your data. The app and installer are signed
with Azure Artifact Signing (publisher "Justin Buist"), done in CI over OIDC
through the `signing` environment; pull requests build unsigned. SmartScreen
may still warn on a new release until it has built up download reputation.
The installer script is `windows/installer/conclock.iss` (Inno Setup).

**macOS**: the build is ad-hoc signed but not notarized (that needs a paid
Apple Developer account), so the first launch is blocked: drag ConClock to
Applications, try to open it, then allow it under System Settings -> Privacy &
Security -> "Open Anyway". Or:
`xattr -dr com.apple.quarantine /Applications/ConClock.app`.

**Android**: install the `.apk` (allow installs from your browser or files app
when asked). It's signed with a release key held in the repo's Actions
secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_ALIAS`), so new versions install over old ones. Keep a backup of
that key: without it, future builds can't update existing installs.
