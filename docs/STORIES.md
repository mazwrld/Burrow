# Burrow stories

Burrow runs `mo` and reads its output. Snapshot pages are named
`<nn>-<page>.png` and come from snapshot mode with fixture JSON, so no
snapshot ever runs a real `mo clean`.

Test fixtures live in `Tests/Fixtures/`: `status.json`, `analyze-home.json`,
`uninstall-list.json`, `history.json`, `clean-list.txt`, `clean-dry-run.txt`
(captured from Mole 1.64.0 on 2026-10-30).

## M1 Core loop: preview a clean, run it, see what it did

### S-001 Find `mo` on launch
As the user, I open Burrow and it finds my `mo` without setup.
Screens: 00-setup.png
Acceptance:
- [unit] It looks in the Settings path, then `/opt/homebrew/bin/mo`, `/usr/local/bin/mo`, `~/.local/bin/mo`, and takes the first that runs `mo --version`.
- [unit] It reads the version from the first line, `Mole version 1.64.0`.
- [snap] With no `mo`, a setup page shows "Burrow needs the Mole command line tool", the line `brew install mole`, a Copy button and a Check Again button.
- [unit] A version older than 1.62.0 shows the setup page with "Update Mole to 1.62.0 or later" and `brew upgrade mole`.
UX:
- Flow: launch -> Burrow finds Mole in under a second -> last page opens. No Mole -> setup page -> Copy Command -> install in Terminal -> Check Again -> last page opens
- Surface: full-window setup page instead of the sidebar (a problem people must fix before anything works, but not an alert: it needs reading and copying)
- States: checking (no UI under half a second); missing "Burrow needs Mole" with `brew install mole`; too old "Update Mole to 1.62.0 or later" with `brew upgrade mole`; found shows the version in Settings
- Words: title "Burrow Needs Mole", body "Burrow shows and runs the Mole command line tool. Install it with Homebrew, then check again.", buttons "Copy Command", "Check Again"
- Access: Check Again is the default button (Return); VoiceOver reads the command text
Status: todo

### S-002 See my Mac's health at a glance
As the user, I open the Health page and see disk free, memory pressure, CPU and battery.
Screens: 01-health.png
Depends: S-001
Acceptance:
- [unit] `status.json` decodes into `StatusSnapshot` with no field lost that the page shows.
- [snap] The page shows the health score and its message, one row each for disk, memory, CPU and battery, and the top five processes.
- [snap] A Mac with no battery shows no battery row, not "0%".
- [self] Command-R refreshes it; a refresh that takes longer than 10 seconds shows an error with the command that failed.
UX:
- Flow: Command-1 or sidebar Health -> cached snapshot shows at once -> fresh snapshot replaces it -> Command-R or toolbar Refresh to read again
- Surface: sidebar page (a place people come back to)
- States: loading shows the last snapshot with "Updated 2 min ago", first run shows a spinner "Reading health…"; error inline "Unable to read health. `mo status --json` exited with 1." with Copy Command and Refresh; no battery hides the row
- Words: header "Health", score "82 Good" plus Mole's message, rows "Disk", "Memory", "CPU", "Battery", table "Top Processes"; toolbar tooltip "Read health from Mole again (⌘R)"
- Access: meters carry the value as text ("Memory pressure: normal"), never color alone; each row is one VoiceOver element
Status: todo

### S-003 Preview a clean
As the user, I press Preview on the Clean page and see what `mo clean` would remove, grouped, with sizes.
Screens: 02-clean-preview.png, 03-clean-scanning.png
Depends: S-001
Acceptance:
- [unit] `clean-list.txt` parses into groups (`=== User essentials ===`) of paths with sizes (`/path  # 63.1MB`); the header comments are skipped.
- [unit] The total comes from the `Potential space: 4.14GB | Items: 359 | Categories: 6` line of the dry-run output, with ANSI color codes removed.
- [snap] While scanning, the page shows a progress spinner, the current section name from the output, and a Stop button.
- [snap] After the scan, each group is a disclosure row with its total; paths inside show size and a Reveal in Finder button.
- [snap] A note under the total says "Cleaning also empties the Trash" when `~/.Trash` is in the list.
- [snap] Items Mole lists only as advice (the `Large files` and `Project artifacts` sections) show in a separate "Not cleaned by this run" box with their hint (`mo purge`).
UX:
- Flow: Command-3 or sidebar Clean -> Preview button (or Clean > Preview, Command-Shift-P) -> live section name while scanning -> groups appear, biggest first -> expand a group -> Reveal in Finder on an item. Stop ends the preview; nothing changed either way
- Surface: sidebar page with an outline list (a place people come back to); the total and buttons sit in a header above the list
- States: empty before first preview "Preview shows what Mole can clean. Nothing is removed." with Preview; scanning "Previewing… User essentials" with Stop; nothing found "Nothing to clean right now"; error inline with exit code and Copy Command; long paths truncate in the middle with the full path as tooltip; 400+ items scroll in a lazy outline
- Words: "Preview", "Stop", header "4.14 GB in 359 items", note "Cleaning also empties the Trash.", box title "Not cleaned by this run" with "Run `mo purge` to remove build folders."; Reveal tooltip "Show this item in Finder"
- Access: groups expand with Right and Left arrows; sizes in monospaced digits; VoiceOver reads "User essentials, 1.2 GB, 87 items"
Status: todo

### S-004 Confirm and run the clean
As the user, I press Clean, read a confirmation dialog that says what will happen, confirm, and watch it run.
Screens: 04-clean-confirm.png, 05-clean-running.png, 06-clean-done.png
Depends: S-003
Acceptance:
- [snap] The Clean button is disabled until a preview finished in this session, and the button title names the size: "Clean 4.14 GB".
- [snap] The confirmation dialog says the size, "Files are deleted for good. They do not go to the Trash.", the Trash note from S-003, and has Cancel (default) and Clean (destructive) buttons.
- [unit] Confirming runs exactly `mo clean` with no other flags and no `sudo`.
- [snap] While running, the output streams into a log view with colors removed; a Stop button sends SIGINT.
- [snap] When done, the page shows the freed size from the output and a "See in History" button.
- [unit] The output line saying system caches were skipped shows an "Admin cleanup skipped" row with an Open in Terminal button (S-006).
UX:
- Flow: after a preview, Clean 4.14 GB button -> confirmation dialog -> Clean -> log streams -> done summary -> See in History. Escape or Cancel closes the dialog with nothing changed; Stop interrupts a run (what was already deleted stays deleted, and the done summary says "Stopped")
- Surface: confirmation dialog (a rare action that deletes data and cannot be undone)
- States: button disabled with tooltip "Preview first to see what will be cleaned"; running log with Stop; done "Freed 4.02 GB"; stopped "Stopped. Some items were already deleted."; admin skipped row "Admin cleanup skipped. It needs your password." with Open in Terminal
- Words: dialog title "Clean 4.14 GB?", message "Files are deleted for good. They do not go to the Trash. Cleaning also empties the Trash.", buttons "Clean" (destructive) and "Cancel" (default, Return)
- Access: Return picks Cancel, so a stray Return deletes nothing; the log view is a text area VoiceOver can read; done state announces "Clean finished, freed 4.02 GB"
Status: todo

### S-005 See what the last clean removed
As the user, I open History and see each Mole run with its date, command and size.
Screens: 07-history.png
Depends: S-001
Acceptance:
- [unit] `history.json` decodes `sessions[]` and `deletions[]`.
- [snap] Each session row shows the command, start time, size freed and counts of removed, trashed, skipped and failed.
- [snap] Dry-run sessions (`clean-dry-run`) show in gray with a "Preview" badge.
- [snap] Selecting a session lists its deletions with path, size, and "Deleted" or "Trash".
UX:
- Flow: Command-5 or sidebar History or "See in History" -> runs list, newest first -> select a run -> its items show below
- Surface: sidebar page, list plus detail split (a place people come back to)
- States: empty "No Mole runs yet. Runs from Burrow and from Terminal show here."; preview runs gray with a "Preview" badge; error inline with Copy Command
- Words: columns "Command", "Started", "Freed", "Deleted", "Moved to Trash", "Skipped", "Failed"; item status "Deleted" or "Moved to Trash"
- Access: arrow keys move through runs; the Preview badge is a word, not only gray
Status: todo

### S-006 Hand a step to Terminal
As the user, I press Open in Terminal on a step Burrow cannot do, and Terminal opens with the command typed in.
Screens: 06-clean-done.png
Acceptance:
- [unit] The command is built from a fixed list (`mo clean`, `mo clean --whitelist`, `mo uninstall <name>`), never from free text; names are shell-quoted.
- [manual] Terminal opens a new window that runs the command, and Mole asks for the password there.
- [snap] Next to the button, the command shows in monospace with a Copy button.
UX:
- Flow: Open in Terminal button -> Terminal opens a new window and runs the command -> Mole asks for the password there. Copy Command is the fallback when Terminal automation is denied
- Surface: inline button next to the command it runs (one action on something already on screen)
- States: Terminal automation denied -> inline "Burrow can't control Terminal. Copy the command and paste it into Terminal." with Copy Command
- Words: "Open in Terminal", "Copy Command"; tooltip "Run this command in a new Terminal window"; after copy the button reads "Copied" for two seconds
- Access: the command is selectable text; both buttons reachable by Tab
Status: todo

### S-007 See the pages in a sidebar
As the user, I switch between Health, Clean and History in a sidebar, with the selection kept after a restart.
Screens: 01-health.png, 02-clean-preview.png, 07-history.png
Acceptance:
- [snap] The sidebar lists Health, Space, Clean, Apps, History with SF Symbols; Space and Apps show "Coming soon" until M2.
- [self] Command-1 to Command-5 select the pages.
- [self] Quitting and reopening shows the last page.
UX:
- Flow: click a sidebar row or Command-1…5 -> page shows; quit and reopen -> same page
- Surface: sidebar window (the app's main shape)
- States: Space and Apps show "Coming soon" with one sentence on what they will do
- Words: "Health", "Space", "Clean", "Apps", "History"; symbols heart.text.square, chart.pie, sparkles, square.grid.2x2, clock.arrow.circlepath
- Access: Up and Down move the selection; each row has its label for VoiceOver
Status: todo

## M2 Explore: Space and Apps

### S-008 Browse disk use from the top
As the user, I open Space and see the largest locations, biggest first.
Screens: 08-space.png
Depends: S-001
Acceptance:
- [unit] `analyze-home.json` decodes `entries[]` and `large_files[]`.
- [snap] Each row shows name, size bar, size, and a "Cache" badge when `cleanable` is true.
- [snap] A `partial` size reads "at least 3.2 GB"; `unavailable` reads "Unknown", never "0 bytes".
Status: todo

### S-009 Drill into a folder
As the user, I double-click a folder row and see what is inside it, with a path bar to go back.
Screens: 09-space-folder.png
Depends: S-008
Acceptance:
- [unit] It runs `mo analyze --json <path>` with `--json` before the path.
- [self] Command-Up goes to the parent; Return opens the selected folder.
- [snap] The path bar shows each level and each one is clickable.
Status: todo

### S-010 Reveal an item in Finder
As the user, I right-click a row in Space and choose Reveal in Finder.
Screens: 09-space-folder.png
Depends: S-008
Acceptance:
- [manual] Finder opens with the item selected.
- [self] No context menu item deletes anything.
Status: todo

### S-011 List my apps by size
As the user, I open Apps and see every installed app with its size and source.
Screens: 10-apps.png
Depends: S-001
Acceptance:
- [unit] `uninstall-list.json` decodes; `size` strings like `968.3MB` sort as bytes.
- [snap] Rows show icon, name, size, and a "Homebrew" badge for cask apps.
- [self] Typing in the search field filters by name.
Status: todo

### S-012 Preview an app uninstall
As the user, I select an app and press Preview Uninstall to see every file that would go.
Screens: 11-apps-preview.png
Depends: S-011, S-006
Acceptance:
- [unit] It runs `mo uninstall --dry-run <uninstall_name>`.
- [snap] The preview lists files to remove and the "Personal data kept" list separately.
- [snap] A running app shows "Quit <App> first".
- [snap] The Uninstall button opens Terminal with `mo uninstall <name>` (S-006); the app never uninstalls by itself.
Status: todo

## M3 Answers: History search

### S-013 Ask "did Mole delete this file?"
As the user, I type a path in History's search field and see every deletion at or under it.
Screens: 12-history-search.png
Depends: S-005
Acceptance:
- [unit] Matching is a path prefix match on whole path components (`/a/b` matches `/a/b/c`, not `/a/bc`).
- [snap] No match shows "Mole has no record of this path in the last 200 entries", not "Not deleted".
Status: todo

### S-014 Protect a path from cleaning
As the user, I right-click a path in the clean preview and choose Protect, which opens the whitelist in Terminal.
Screens: 02-clean-preview.png
Depends: S-003, S-006
Acceptance:
- [unit] It opens `mo clean --whitelist`; Burrow never writes `~/.config/mole/whitelist` itself.
- [manual] After saving there, a new preview no longer lists the path.
Status: todo

## M4 Speed

### S-015 Run everything from the menu bar menus
As the user, I find Preview Clean, Refresh and every page under the app's menus with shortcuts.
Screens: none (menus)
Acceptance:
- [self] Clean > Preview (Command-Shift-P), View > Refresh (Command-R), Go > pages (Command-1…5).
Status: todo

### S-016 Keep the health page live
As the user, I turn on Live on the Health page and it updates every 2 seconds while the window is visible.
Screens: 01-health.png
Depends: S-002
Acceptance:
- [unit] It reads `mo status --watch --interval 2s` line by line and stops the process when the page hides or the window closes.
- [self] No `mo` process is left running after quit.
Status: todo

## M5 System

### S-017 See disk free in the menu bar
As the user, I turn on a menu bar item that shows free disk space and opens Burrow.
Screens: 13-menubar.png
Depends: S-002
Acceptance:
- [snap] The item shows free GB; its menu has Open Burrow and Preview Clean.
- [self] It refreshes at most once a minute and only while visible.
Status: todo

## M6 Polish

### S-018 App icon
As the user, I see Burrow's own icon in the Dock and every snapshot. Not the Mole logo.
Screens: all
Status: todo

### S-019 Choose where `mo` lives
As the user, I set the `mo` path in Settings when it is somewhere unusual.
Screens: 14-settings.png
Depends: S-001
Acceptance:
- [self] A path that does not run `mo --version` shows "This is not the Mole command".
Status: todo

### S-020 Empty and error states on every page
As the user, I see a plain sentence, not a blank page, when a scan fails or finds nothing.
Screens: 15-empty.png
Acceptance:
- [snap] Clean with nothing to remove: "Nothing to clean right now".
- [snap] A failed command shows its exit code and a Copy Command button.
Status: todo

## Later
- `mo optimize` preview and run.
- `mo purge` preview and run with `--yes`.
- `mo installer` preview (the removal itself needs Terminal).
- `mo slim` preview.
- Clean external volumes (`mo clean --external`).

## Dropped
- Accounts, sync, sharing: one user, one Mac.
- Scheduled or automatic cleans: Mole is against background agents and schedulers.
- Notifications and alerts: same reason.
- Deleting files directly from Space: only `mo` removes files.
- Editing the whitelist in-app: Mole owns that file; Terminal does it.
- Running admin steps with a password prompt in the app: Burrow never runs `sudo`.
- `mo update`, `mo remove`, `mo touchid`, `mo completion`: Mole setup, not daily jobs.
