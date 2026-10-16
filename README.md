# ConClock

A lean, local-only time tracker for consultants. No accounts, no network —
one JSON file.

- **Track** — tap a client to start; tap another to switch; tap again (or ■) to stop.
  Type a note for the running entry right in the status panel. The running
  client (and task) slides to the top and stays there after it stops, so
  clients line up most recently used first; the arrow on a client hides its
  tasks.
- **Log** — every entry grouped by day; tap to edit, + to add time manually.
- **Timesheet** — Mon–Sun grid: clients down the side (expand for tasks), days
  across, row/day/week totals. Hover (or tap) a cell for that day's tasks;
  copy the week as tab-separated decimal hours for a spreadsheet. Optional
  rounding up to ½ h, per task or per client-day.
- **Clients** — add, rename, recolor, drag to reorder, archive, delete.
- **Settings** — theme (system / light / dark), app color and background tint, monospace font for times, decimal hours, tray behavior,
  data location, export/import backups.

Desktop: closing the window keeps ConClock running in the system tray (menu
bar on macOS); the tray menu shows what's running and can stop, switch
clients, reopen or quit. Turn it off under Settings → "Keep running in tray
when closed". Launching it again brings back the existing window.

🔍 on Track: type to find a client or task and start it. Right-click
(long-press) a task to rename or merge it. Timers left
running 9h+, or through a computer sleep, prompt "still working?".

Stopping or switching away from an entry with no note asks for a task name
(pick a recent one, type one, leave it unnamed, or discard the entry).

## Data

- Desktop / mobile: `conclock.json` in the app-support directory
  (Linux: `~/.local/share/com.conclock.conclock/`). Shown under Settings → Data location.
  Writes are atomic (temp file + rename); unreadable files are kept as
  `conclock.json.corrupt-<timestamp>`. If the file changes elsewhere (another
  instance, a sync) while you have unsaved edits, those are kept as
  `conclock.json.unsaved-<timestamp>` and a message says so (with an
  Export button). The newest 3 side copies of each kind are kept.
- Web: the browser's IndexedDB (database `conclock`), which holds years of
  entries; data from older versions in `localStorage` moves over on first
  load.
- If a save ever fails (disk or browser storage full), a red banner says so
  and offers Export / Retry; nothing fails silently.
- Desktop: Settings → Data location → *Choose folder…* moves data into any
  folder, e.g. a synced one (Dropbox, OneDrive, Syncthing) to share it
  between computers. Changes from elsewhere are picked up live.

## Build

```sh
flutter run -d linux        # needs: clang cmake ninja-build lld libgtk-3-dev
                            #        libayatana-appindicator3-dev
flutter run -d chrome
flutter build web
flutter test
python3 tool/seed_test_data.py   # 4 weeks of 9-5 test data (--remove to undo)
```

## Releases

GitHub Actions (`.github/workflows/build.yml`) tests and builds on every push:
Linux x64 and arm64 (`.tar.gz` and `.deb`), Windows x64 (setup `.exe`), macOS
universal (`.dmg`) and Android (`.apk`) as workflow artifacts. Pushes to `main` also deploy the web app to GitHub Pages:
https://justinb4003.github.io/conclock/ (data stays in your browser; open
tabs stay in sync). Push a `v*` tag (e.g. `git tag v0.5.0 && git push --tags`) to
publish them as a GitHub release.

```sh
sudo apt install ./conclock_0.5.0_amd64.deb   # installs to /opt/conclock
tool/package_deb.sh                             # build the .deb locally
```

Windows: run `conclock-<version>-windows-x64-setup.exe`. It installs for the
current user (no admin prompt), adds a Start menu entry and optionally a
desktop shortcut and start-at-sign-in; installing a newer version upgrades in
place, and uninstalling keeps your data. The installer isn't code-signed, so
SmartScreen warns on first run: *More info → Run anyway*. The installer script
is `windows/installer/conclock.iss` (Inno Setup).

The macOS build is ad-hoc signed but not notarized (that needs a paid Apple
Developer account), so the first launch is blocked: drag ConClock to
Applications, try to open it, then allow it under System Settings → Privacy &
Security → "Open Anyway". Or: `xattr -dr com.apple.quarantine /Applications/ConClock.app`.

Android: install the `.apk` (allow installs from your browser/files app when
asked). It's signed with a release key held in the repo's Actions secrets
(`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`),
so new versions install over old ones. Keep a backup of that key: without it,
future builds can't update existing installs.
