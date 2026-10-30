# Spec: Polish the look, add the icon, then Space and Apps (M2)

Status: ready-for-agent, published as https://github.com/mazwrld/Burrow/issues/1
Date: 2026-10-30
Reads: `docs/BRIEF.md`, `docs/STORIES.md` (S-008 to S-012), `docs/GLOSSARY.md`

## Problem Statement

Burrow's milestone 1 works: Health, Clean and History read Mole and the Clean
flow previews, confirms and runs `mo clean`. But it still looks like a template.
It has the template's blue placeholder icon, no app-specific design rules, and
two sidebar pages (Space and Apps) that only say "Coming soon". To find out
what fills the disk, the user still has to open Terminal and run
`mo analyze`. To see which apps are big and what an uninstall would remove,
they still have to run `mo uninstall --list` and `mo uninstall --dry-run`.
The confirmation dialog before Clean, the most important screen for safety,
also has no working snapshot, so nobody can check it without clicking.

## Solution

Two passes, in order.

1. **Polish.** Bring every existing page in line with the Mac design rules,
   write down Burrow's design tokens (accent, size column width, meter width,
   badge style) so new pages match, and give Burrow its own icon. The icon
   must not use the Mole name or logo. Fix the snapshot of the Clean
   confirmation dialog so it can be reviewed like every other screen.
2. **Space and Apps (M2).**
   - Space shows the largest locations on the disk, biggest first. The user
     can drill into folders with a path bar to go back, and Reveal in Finder
     on any row. Items Mole knows are caches carry a "Cache" badge.
   - Apps lists every installed app by size. The user can search by name,
     and Preview Uninstall shows which files would be removed and which
     personal data is kept. The Uninstall button hands the real command to
     Terminal, because Mole needs a terminal for it.
   - Neither page ever removes a file itself.

## User Stories

### Polish

1. As the user, I want Burrow to have its own icon in the Dock, Finder and every snapshot, so that I can tell it apart from the template and from Mole.
2. As the user, I want the icon to suggest digging or a burrow, not a mole animal or Mole's logo, so that Burrow does not claim to be part of Mole.
3. As the user, I want the icon to look right in light, dark, tinted and clear icon styles, so that it fits any Dock.
4. As the user, I want every size column in Burrow to line up at the same width with monospaced digits, so that I can compare sizes at a glance.
5. As the user, I want the meters on Health, the size bars on Space, and the badges on History and Space to share one style, so that the app feels like one product.
6. As the user, I want Burrow to follow my Mac's accent color by default, so that it looks like a built-in app.
7. As the user, I want toolbar buttons to look and behave like other Mac apps (Preview, Refresh, Stop), so that I already know how to use them.
8. As the user, I want every icon-only button to show a tooltip with what it does and its shortcut, so that I never have to guess.
9. As the user, I want empty, loading and error states on every page to use the system's empty-state look with one clear next action, so that I never face a blank page.
10. As the user, I want the "Not cleaned by this run" box on Clean to name the command that handles each row (`mo purge`), so that I know where to go next.
11. As a reviewer, I want a light and a dark snapshot of the Clean confirmation dialog, so that I can check its words ("Clean 4.14 GB?", "deleted for good", Trash note, Cancel as default) without clicking.
12. As a reviewer, I want every page to pass the grid lint and layout checks, so that spacing stays on the 4 pt grid as pages are added.
13. As a developer, I want a short design system document that says which token to use when, so that M2 pages match M1 without guessing.

### Space

14. As the user, I want to open Space and see the largest locations on my disk, biggest first, so that I know what is filling it.
15. As the user, I want each row to show its name, a size bar, and its size, so that I can compare at a glance.
16. As the user, I want a "Cache" badge on rows Mole recognizes as caches, so that I know which ones Clean can handle.
17. As the user, I want known heavy locations (such as device backups) marked, so that I notice them.
18. As the user, I want a partly measured size to read "at least 3.2 GB", so that I don't trust a lower bound as exact.
19. As the user, I want a size Mole could not measure to read "Unknown", not "0 bytes", so that I'm not misled into thinking it's empty.
20. As the user, I want to double-click a folder (or select it and press Return) to see what is inside, so that I can drill down to the real culprit.
21. As the user, I want a path bar that shows every level and lets me click any level, so that I can jump back up quickly.
22. As the user, I want Command-Up to go to the parent folder, so that I can browse with the keyboard.
23. As the user, I want a loading state while Mole measures a folder, and a Stop button, so that a slow scan never looks frozen.
24. As the user, I want the largest files listed for the folder I'm in, so that one huge file doesn't hide inside a folder total.
25. As the user, I want to right-click any row and choose Reveal in Finder, so that I can deal with it myself.
26. As the user, I want no row in Space to offer delete, so that I can't remove my own files by accident.
27. As the user, I want a short hint on each row that Mole can handle (caches go to Clean, build folders to `mo purge`, apps to Apps), so that I know which page or command fits.
28. As the user, I want Refresh (Command-R) to measure the current folder again, so that I see the effect of a clean.
29. As the user, I want Space to remember the folder I'm in while I switch pages, so that I don't lose my place.

### Apps

30. As the user, I want to open Apps and see every installed app with its size, biggest first, so that I know which apps take the most space.
31. As the user, I want each row to show the app's icon, name and size, so that I recognize it quickly.
32. As the user, I want a "Homebrew" badge on apps installed as Homebrew casks, so that I know they're managed differently.
33. As the user, I want sizes like `968.3MB` sorted as real sizes, not as text, so that the order is right.
34. As the user, I want to type in a search field to filter apps by name, so that I can find one app fast.
35. As the user, I want to select an app and press Preview Uninstall, so that I can see every file an uninstall would remove before deciding.
36. As the user, I want the preview to list the files to remove, with sizes, so that I know what goes.
37. As the user, I want the preview to list "Personal data kept" separately, so that I know my settings and documents stay by default.
38. As the user, I want the preview to say the app goes to the Trash, so that I know I can get it back.
39. As the user, I want a running app to show "Quit <App> first", so that the uninstall doesn't fail halfway.
40. As the user, I want the Uninstall button to open Terminal with `mo uninstall <name>` already typed and running, so that Mole can ask for confirmation and my password there.
41. As the user, I want Copy Command next to it, so that I can paste it myself if Terminal can't be opened.
42. As the user, I want app names with spaces or quotes to be quoted safely in that command, so that the wrong app is never targeted.
43. As the user, I want Apps to refresh after I come back from Terminal, so that an uninstalled app disappears from the list.
44. As the user, I want an error state with the failed command and Try Again when Mole can't list apps, so that I know what went wrong.

### Keyboard and access

45. As a keyboard user, I want to move through Space and Apps rows with the arrow keys and open with Return, so that I never need the mouse.
46. As a VoiceOver user, I want each row read as name, size, and badge words, so that meaning never depends on color.
47. As the user, I want Command-2 and Command-4 to open Space and Apps, so that the M1 shortcuts keep working.

## Implementation Decisions

### Polish

- The design pass follows the template's rules: system controls and styles, only the accent is custom, Liquid Glass only on floating controls. The default accent stays "system".
- New shared tokens: one size column width, one meter or size-bar width, and one badge style (the existing History "Preview" badge becomes the shared badge). They live next to the template's spacing scale and theme. Pages stop using their own numbers for these.
- A design system document records each token and when to use it. M2 pages use only those tokens.
- The icon is a new Icon Composer file with Burrow's own artwork (a tunnel or burrow opening, not an animal or Mole's mark). It is checked with the template's icon review render in every look.
- The confirmation dialog snapshot changes how it captures: it captures the dialog the window presents, or the window together with its attached dialog. Every other snapshot stays as it is. The dialog's words do not change.

### Space

- Space reads `mo analyze --json` for the overview and `mo analyze --json <path>` for a folder. `--json` always comes before the path, because Mole's flag parser stops at the first path.
- A new decoder in the logic library reads one analyze result: `scan_status`, `path`, `overview`, `total_size`, `total_files`, `large_files[]` and `entries[]`. On entries, `insight`, `cleanable` and `last_access` are optional: Mole leaves them out when false or unknown. Sizes are bytes.
- A scan status type maps `complete`, `partial` and `unavailable` to the words "exact", "at least" and "Unknown". It reuses the lower-bound idea from the existing Mole size type, so every page says "at least" the same way.
- A new Space page model keeps a stack of visited paths (the path bar), the current result, loading, failure and the running process. It follows the shape of the existing Health and History page models. Stop uses the existing process stop. Results stay in memory while the user is on other pages and are not saved between launches.
- A row hint maps an entry to the page or command that handles it: `cleanable` goes to Clean, known build or dependency folder names go to `mo purge`, `.app` bundles go to Apps, and everything else gets no hint. The hint is words only, never an action that removes anything.
- Reveal in Finder uses the same call as the Clean page. Space has no delete, Move to Trash, or Clean action. This is a product decision from the brief: only `mo` removes files.

### Apps

- Apps reads `mo uninstall --list` (JSON when stdout is not a terminal): `{name, bundle_id, source, uninstall_name, path, size}`. `size` is Mole's display string; it is parsed with the existing Mole size parser for sorting.
- App icons come from the system, using the app's path. They are loaded lazily, so 50+ rows still scroll smoothly.
- Preview Uninstall runs `mo uninstall --dry-run <uninstall_name>`. A new parser in the logic library reads its text output, after the existing color and screen-code stripping. Mole prints clear-screen codes here too. The parser reads:
  - the "Files to be removed:" list (path and size per line),
  - the "Personal data to remove:" and "Personal data kept:" lists,
  - the app-running notice,
  - the "Dry run complete" line, as proof that nothing was removed.
- The Mole client gains two command cases (app list and uninstall preview) with fixture files, the same way M1 added status, history and clean. Fixture mode still never runs `mo`.
- Uninstall uses the existing Terminal handoff (`TerminalCommand.uninstall(name:)`), which already shell-quotes names. Burrow never runs `mo uninstall` without `--dry-run` itself, never passes `--permanent`, and never passes `--with-data`.
- Apps reloads its list when the app becomes active again after a Terminal handoff.
- Preview Uninstall opens in an inspector beside the list (it shows details of the selection while the user keeps browsing). It is not a sheet, because no input is needed and the user may compare several apps.

### Shared

- The two "Coming soon" placeholders and their page flag are removed once both pages ship.
- New words go into the glossary before they appear on screen: "Cache" (badge), "Preview Uninstall", "Uninstall", "Personal data kept", "Files to remove", "at least", "Unknown".

## Testing Decisions

- **One seam: the Mole boundary.** Every page reads Mole through the Mole client. In fixture mode it reads captured output from the fixtures folder and never runs `mo`. All page behavior is tested through that seam, by the in-app self-test driving the real page models. No new seam is added.
- **Parsers at the logic library's public interface.** The new analyze decoder, scan-status words, row hint, app list decoder and uninstall-preview parser get unit tests that feed captured fixture text and check the public result. They do not test private helpers. Prior art: the existing parser tests for the clean list, dry-run totals, run summary, status and history.
- **Fixtures are synthetic.** M2 fixtures use made-up paths and app names (for example `/Users/test/Projects/...`, "Example Editor"), not a capture of this Mac's personal folders. They do follow Mole 1.64's exact field names and text layout. Each needs:
  - an overview,
  - a drill-down folder with `partial` and `unavailable` entries,
  - an app list with an App and a Homebrew row,
  - an uninstall preview with kept personal data,
  - an uninstall preview with an app that is running.
- **Self-test checks**, one per behavior:
  - Space opens to the overview, biggest first.
  - Drilling in pushes the path bar and Command-Up pops it.
  - A partial size reads "at least" and an unavailable one reads "Unknown".
  - Apps sorts by real size and search filters it.
  - Preview Uninstall splits files to remove from personal data kept.
  - A running app shows the quit notice.
  - Uninstall hands exactly `mo uninstall '<name>'` to Terminal.
  - No Space or Apps action ever starts a removing command. This one is checked by recording every command the client is asked to run.
- **Snapshots** for every new page and state in light and dark: Space overview, Space folder, Apps list, Apps preview, plus the fixed confirmation dialog. Each must pass the grid lint and layout check. A good snapshot test is one a person reads: words, alignment, both modes.
- **Icon** is checked with the icon review render in every look, not by a test.

## Out of Scope

- History search ("did Mole delete this file?", S-013) and Protect from cleaning (S-014): milestone 3.
- Live Health updates, menu commands beyond today's, and the menu bar item: milestones 4 and 5.
- Choosing where `mo` lives in Settings (S-019) and the full empty and error state sweep (S-020): milestone 6. The polish pass only touches states that already exist.
- Running `mo uninstall` for real inside Burrow, `--with-data`, `--permanent`, or picking which leftovers to keep. That stays in Terminal.
- Any delete, Move to Trash, or clean action on Space.
- `mo optimize`, `mo purge`, `mo installer`, `mo slim`: listed under Later in the stories.
- A custom look ("own parts" design kit). Burrow stays native with the system accent.
- Publishing this spec to an issue tracker: none is configured.

## Further Notes

- Mole's terms forbid the Mole name and logo on other apps (`TRADEMARK.md` in the Mole repo). The icon and any copy must not use them.
- `mo analyze --json` on a large folder can take seconds. Space must show the loading state and allow Stop. The M1 "read the output to the end, then wait for the exit code" fix in the process runner already covers long output.
- The exact wording of Mole's app-running notice in the uninstall preview is not pinned yet. Confirm it from Mole's `lib/uninstall/batch.sh` when writing the parser, and record it in the fixture.
- During M1, the self-test sometimes timed out on this Mac while it was under heavy load (load average around 20). Waits are now 30 seconds. Treat a new flaky check as a bug to diagnose, not a reason to raise the limit again.
- Suggested build order:
  1. design tokens and the dialog snapshot fix,
  2. the icon,
  3. Space (S-008, S-009, S-010),
  4. Apps (S-011, S-012).

  Commit after each, with snapshots reviewed.
