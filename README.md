# ConClock

A lean, local-only time tracker for consultants. No accounts, no network —
one JSON file.

- **Track** — tap a client to start; tap another to switch; tap again (or ■) to stop.
  Type a note for the running entry right in the status panel.
- **Log** — every entry grouped by day; tap to edit, + to add time manually.
- **Timesheet** — Mon–Sun grid: clients down the side (expand for tasks), days
  across, row/day/week totals. Hover (or tap) a cell for that day's tasks;
  copy the week as tab-separated decimal hours for a spreadsheet. Optional
  rounding up to ½ h, per task or per client-day.
- **Clients** — add, rename, recolor, drag to reorder, archive, delete.

Stopping or switching away from an entry with no note asks for a task name
(pick a recent one, type one, leave it unnamed, or discard the entry).

## Data

- Desktop / mobile: `conclock.json` in the app-support directory
  (Linux: `~/.local/share/com.conclock.conclock/`). Shown under Clients → ⓘ.
  Writes are atomic (temp file + rename); unreadable files are kept as
  `conclock.json.corrupt-<timestamp>`.
- Web: browser `localStorage` (key `conclock.data`).

## Build

```sh
flutter run -d linux        # needs: clang cmake ninja-build libgtk-3-dev
flutter run -d chrome
flutter build web
flutter test
python3 tool/seed_test_data.py   # 4 weeks of 9-5 test data (--remove to undo)
```

## Releases

GitHub Actions (`.github/workflows/build.yml`) tests and builds on every push:
Linux x64 (`.tar.gz` and `.deb`) and Windows x64 (`.zip`) as workflow
artifacts. Pushes to `main` also deploy the web app to GitHub Pages:
https://justinb4003.github.io/conclock/ (data stays in your browser; open
tabs stay in sync). Push a `v*` tag (e.g. `git tag v0.1.1 && git push --tags`) to
publish them as a GitHub release.

```sh
sudo apt install ./conclock_0.1.1_amd64.deb   # installs to /opt/conclock
tool/package_deb.sh                             # build the .deb locally
```
