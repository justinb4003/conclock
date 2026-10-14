#!/usr/bin/env python3
"""Fill ConClock's data file with realistic 9am-5pm weekday test entries.

Uses the clients already in the file (adds sample ones if there are none),
keeps existing entries, and backs the file up first. Generated entries have
ids starting with "seed-" so they can be removed again:

    python3 tool/seed_test_data.py            # add 4 weeks of test data
    python3 tool/seed_test_data.py --weeks 6
    python3 tool/seed_test_data.py --remove   # strip seeded entries

Quit ConClock (or hot-restart it right after) so it doesn't overwrite the
file with what it has in memory.
"""
import argparse
import datetime as dt
import json
import os
import random
import shutil
import time

DEFAULT_PATH = os.path.join(
    os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")),
    "com.conclock.conclock",
    "conclock.json",
)

TASKS = [
    "Status call", "Requirements review", "Code review", "Architecture design",
    "Documentation", "Bug triage", "Deployment support", "Data migration",
    "Sprint planning", "Stakeholder demo", "Security review", "Performance tuning",
]
INTERNAL_TASKS = ["Invoicing", "Email / admin", "Proposal writing", "Training"]
SAMPLE_CLIENTS = ["Acme Corp", "Globex", "Initech", "Internal"]
PALETTE = [0xFF1E88E5, 0xFF43A047, 0xFFE53935, 0xFFFB8C00, 0xFF8E24AA, 0xFF00ACC1]


def iso(d):
    return d.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", default=DEFAULT_PATH)
    ap.add_argument("--weeks", type=int, default=4)
    ap.add_argument("--remove", action="store_true")
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()

    data = {"version": 1, "clients": [], "entries": []}
    if os.path.exists(args.file):
        with open(args.file) as f:
            data = json.load(f)
        backup = f"{args.file}.bak-{int(time.time())}"
        shutil.copy2(args.file, backup)
        print(f"Backed up to {backup}")

    entries = [e for e in data.get("entries", []) if not e["id"].startswith("seed-")]
    removed = len(data.get("entries", [])) - len(entries)
    if args.remove:
        data["entries"] = entries
        write(args.file, data)
        print(f"Removed {removed} seeded entries")
        return

    clients = [c for c in data.get("clients", []) if not c.get("archived")]
    if not clients:
        clients = [
            {"id": f"seed-c{i}", "name": n, "color": PALETTE[i], "archived": False}
            for i, n in enumerate(SAMPLE_CLIENTS)
        ]
        data["clients"] = clients

    rng = random.Random(args.seed)
    internal = [c for c in clients if c["name"].lower() == "internal"]
    billable = [c for c in clients if c not in internal] or clients
    # Each client gets its own handful of recurring tasks.
    tasks = {
        c["id"]: INTERNAL_TASKS if c in internal else rng.sample(TASKS, rng.randint(3, 5))
        for c in clients
    }

    today = dt.date.today()
    day = today - dt.timedelta(days=7 * args.weeks)
    added = 0
    while day <= today:
        if day.weekday() < 5:
            # 2-4 clients a day, mostly billable, sometimes an internal block.
            todays = rng.sample(billable, min(len(billable), rng.randint(2, 4)))
            if internal and rng.random() < 0.4:
                todays.append(internal[0])
            t = dt.datetime.combine(day, dt.time(9)).astimezone()
            end_of_day = dt.datetime.combine(day, dt.time(17)).astimezone()
            while t < end_of_day:
                quarters = rng.choice([2, 2, 3, 4, 4, 6, 8, 10])  # 30m - 2.5h
                end = min(t + dt.timedelta(minutes=15 * quarters), end_of_day)
                c = rng.choice(todays)
                entries.append({
                    "id": f"seed-{day.isoformat()}-{added}",
                    "clientId": c["id"],
                    "start": iso(t),
                    "end": iso(end),
                    "note": rng.choice(tasks[c["id"]]),
                })
                added += 1
                t = end
        day += dt.timedelta(days=1)

    entries.sort(key=lambda e: e["start"], reverse=True)
    data["entries"] = entries
    write(args.file, data)
    print(f"Replaced {removed} old seeded entries; added {added} across "
          f"{args.weeks} weeks for {len(clients)} clients -> {args.file}")


def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, path)


if __name__ == "__main__":
    main()
