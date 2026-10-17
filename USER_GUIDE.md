# ConClock user guide

ConClock tracks time per client and task. One timer runs at a time; starting
something else stops what was running. Everything is saved as you go.

## Track

The main screen: a status card on top, your clients below.

- **Start / stop**: press the round play button on a client (or on one of its
  tasks). Press it on another client or task to switch; press the stop button
  on the running row, or in the status card, to stop. Only the button reacts;
  tapping elsewhere on a row does nothing.
- **Status card**: shows the running client, the elapsed time, when it
  started and today's total. When nothing runs it shows today's total only.
- **Task name**: type in the field in the status card to name what you're
  doing. Earlier tasks for that client are suggested as you type (any case):
  - Click a suggestion, or press Tab (top one) or arrows then Tab/Enter, to
    use it. The entry joins that earlier task.
  - Enter keeps exactly what you typed. Typing an earlier task's name in a
    different case still joins it.
  - Changing the name of a task you resumed renames that task everywhere
    (a toast offers Undo).
- **New task** (the button beside Stop): ends the current task and starts a
  fresh one on the same client. If you've just typed a different
  name over the current one, that name becomes the new task instead.
- **Order**: the client you start moves to the top and stays there after it
  stops; older ones work their way down. Under each client, its recent tasks
  are listed newest first ("N more" shows the rest). The arrow on a client
  hides or shows its tasks; the button in the app bar does it for all.
- **App bar**: **Quick switch** (search icon) to type a client or task name
  and start it with Enter, **Add client**, and show/hide all tasks.
- **Rename a task**: the pencil on the task (or right-click / long-press it).
  Renaming onto an existing name merges the two.

When you stop or switch away from an entry with no name, ConClock asks for
one: pick or type a name, **Leave unnamed**, or **Discard** the entry (a
toast offers Undo).

If a timer has run 9 hours, or the computer slept while it ran, ConClock asks
"Still working on ...?": **Keep running**, **Stop now**, **Stop at** the time
you left, or (after a sleep) remove the gap and keep going.

## Log

Every entry, one week at a time.

- **Week**: the arrows at the top, or **Previous week / Next week** at the end
  of the list, move a week. **This week** jumps back. Tap the dates to pick a
  week from a calendar.
- **Group by Day / Client**: day -> client -> task -> entries, or client ->
  day -> task -> entries. Every level shows its total.
- Tap a day, client or task to open or close it; the unfold button in the
  app bar does them all.
- Open a task to see its entries; tap an entry to edit its client, date,
  start, end and note, or delete it (with Undo). An end time before the
  start means the next day. The pencil on a task renames it.
- **+** adds time by hand.

## Timesheet

A Monday-Sunday grid: clients down the side, days across, totals for each row,
day and the week.

- Move between weeks the same way as the Log.
- Expand a client (or all of them) to see its tasks.
- Hover or tap a cell (or tab to it and press Enter) to see that day's
  tasks for the client.
- **Round up to**: pick the step (6, 10, 15, 20, 30 or 60 minutes; 30 to
  start). **Off** shows exact time. **Per task** rounds each task's day up
  to the next step. **Per day** rounds each client's day total up to the
  next step.
- **Copy week for a spreadsheet** copies the grid as tab-separated decimal
  hours, ready to paste.

## Clients

Add a client with **+**. Tap a client to change its name and color. Drag
the handle to reorder; this order is used by the Log, Timesheet, tray menu
and quick switch (Track orders by recent use). The menu on each client
archives it (hidden from Track but its history stays) or deletes it with all
its entries (after asking, and with Undo; archive instead to keep the
history).

## Settings

- **Display**: **Decimal hours** (1.50 instead of 1:30, everywhere),
  **Monospace times**, and **Dyslexia-friendly font** (all text in
  OpenDyslexic).
- **Data**: **Data location** shows where the data lives; on desktop you can
  move it to another folder (a synced one, to share between computers).
  **Export backup** saves everything as one JSON file; **Import backup**
  replaces all data with one (the current data is kept as a copy first).
- **Appearance**: **Color** (the app's accent), **Background** (Neutral /
  Tinted / Bold use of that color) and **Theme** (System / Light / Dark).
- **Desktop**: **Keep running in tray when closed**. When on, closing the
  window leaves ConClock in the tray; the tray menu shows what's running and
  can stop, start a client, reopen or quit.
- **About**: the version and release date, and a link to ConClock's source
  code on GitHub.

## How do I...

- **Fix a typo in a task name**: on Track, edit the running task's name and
  press Enter; or press the pencil on the task (Track or Log).
- **Log time I forgot to track**: Log -> **+**, pick the client, date, start
  and end.
- **Split my time when I change tasks**: press **New task**, type the next
  task's name.
- **Bill a week**: Timesheet, pick the week, set the rounding, **Copy week for
  a spreadsheet**, paste.
- **Move to a new computer**: Settings -> **Export backup**, then **Import
  backup** on the other one. Or keep the data in a synced folder.
- **Stop billing an old client without losing history**: Clients -> menu ->
  **Archive**.
