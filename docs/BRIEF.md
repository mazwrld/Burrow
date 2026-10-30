# Burrow

A native Mac window for the Mole CLI (`mo`): see what fills your disk, preview a
cleanup, run it, and check what was removed, without opening Terminal. For one
person: the owner of this Mac.

Name and bundle id: **Burrow**, `com.maz.burrow` (decided by the agent). Not
"Mole": the Mole name and logo are trademarks, and "Mole for Mac" is a separate
paid product (see `mole/TRADEMARK.md`). Burrow uses its own name and icon and
does not claim to be part of Mole.

## Replaces
Typing `mo status`, `mo analyze`, `mo clean --dry-run` and `mo history` in
Terminal and reading the output by eye.

## Main jobs
1. **Health**: a glance at disk free, memory pressure, CPU, battery and the
   top processes (`mo status --json`).
2. **Space**: browse what uses the disk, drill into folders, see which items
   Mole knows are caches (`mo analyze --json [path]`).
3. **Clean**: preview (`mo clean --dry-run`, read `~/.config/mole/clean-list.txt`),
   confirm in a dialog, then run `mo clean` and stream its output.
4. **Apps**: list installed apps by size (`mo uninstall --list`) and preview an
   uninstall (`mo uninstall --dry-run <name>`). The real uninstall opens in
   Terminal, because Mole needs a terminal for it.
5. **History**: what Mole removed and when (`mo history --json --limit 200`).

## Data
Burrow owns almost no data. Every screen reads `mo` live and decodes its JSON.
- `StatusSnapshot`: health score, cpu, memory, disks, batteries, top processes.
- `DiskEntry`: name, path, size, isDir, cleanable, insight, scanStatus.
- `InstalledApp`: name, bundleId, source, uninstallName, path, size.
- `HistorySession`: command, startedAt, endedAt, size, actions, deletions.
- Settings (UserDefaults): path to `mo`, last-run time.

## Shape
Sidebar window with the five pages, macOS 26 or later. Local only. Works
offline. No accounts. Not sandboxed: it must run `/opt/homebrew/bin/mo`
(or the path set in Settings).

## Safety rules (from Mole's own contract)
- Burrow never deletes a file itself. Only `mo` removes things.
- Every removal shows a preview first and needs a click in a confirmation dialog
  that names the size and says "deleted for good" or "goes to the Trash".
- The clean confirmation dialog says that `mo clean` also empties the Trash.
- Never runs `sudo`, never asks for a password. Steps that need admin access,
  uninstall, installer and whitelist editing open in Terminal with the exact
  command.
- `partial` sizes show as "at least", `unavailable` as "unknown", never zero.

## System hooks
"Open in Terminal" for the steps only Terminal can do. Later: a menu bar
extra with disk free.

## Reference
`mo` itself (the TUIs of `mo status` and `mo analyze`), plus the layout of
System Settings > General > Storage.

## Look
Native, with the Mac's own accent color (decided by the agent). Sizes in a
monospaced digit font so columns line up.

## Not in version one
- `mo optimize`, `mo purge`, `mo installer`, `mo slim`, `mo touchid`.
- Editing the whitelist inside the app (opens Terminal instead).
- Menu bar extra, notifications, scheduled cleans, background monitoring.
