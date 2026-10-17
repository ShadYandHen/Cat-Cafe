# Full gameplay integration and playtesting — Step 11

> Historical Step 11 integration pass evidence. Current Seasonal XP, quality caps, tip settlement
> and schema 5 behavior are documented in [Step 13A corrections](BalanceCorrections13A.md).

## Outcome

The full scripted player journey passed in Godot **4.6.3**, at **720×1280**
(mouse) and **320×568** (simulated touch), in headless and native GL Compatibility
runs. Existing Step 10B work was retained. No gameplay balance, catalog values,
artwork or furniture changed. No commit or push is part of this step.

The test launches Title, activates Play through real input, changes the active
cat to Fade (Mochi and Max support), opens nested menus, and plays a complete
production-length shift using `CafeSession.advance_time` in accelerated slices.
It does not shorten the day, increase patience or bypass preparation controls.
Every order uses its actual requested recipe, station, ingredients, timed
processing, assembly and manual service.

Both portrait runs produced the same first-day result:

| Result | Value |
| --- | ---: |
| Simulated café time | 300 seconds |
| Served / lost | 12 / 0 |
| Coins earned | 155 |
| Reputation XP | 180 |
| Seasonal XP | 100 (50 day + 50 daily challenge) |

These are deterministic scripted outcomes, **not** balance or enjoyment findings.
The script aims for ideal timing; hands-on real-time playtesting remains needed.

After results, input purchases Brewing Equipment and Pink Paw Plaque, equips the
decoration, starts Day 2, and verifies the actual preparation target includes the
upgrade plus the restored team's passive and active bonuses. Back cancels that
preparation without rewards. Settings over nested menus leaves café time and
patience running. Closing that unfinished shift and re-entering through Title
restores permanent values and starts in the pre-day lobby without old customers.

Using an isolated development profile, the same journey then reaches Level 50,
resolves cycles, earns seasonal milestones, claims through both Pass and Inbox,
rolls ten and one lottery rewards, equips a cosmetic, crosses a season boundary,
and claims an old seasonal reward. Separate-process verification reopens both
portrait checkpoints, compares the entire permanent state and opens Title/Play.

## Confirmed defects and minimal fixes

| Defect | Root cause | Correction / regression |
| --- | --- | --- |
| Rewards accepted for released or reloaded unfinished shifts | Service/completion APIs checked the persisted open shift ID but not live scene ownership | New rewards require matching `_active_shift_id`. Already committed completion remains idempotent. Tests reject unseen stale order IDs and abandoned-day completion without changing balances/XP. |
| Team editable while day completion save was pending | Team guard checked phase alone; profile `set_team` lacked the shop's live shift lock | Session uses the common edit gate, and profile rejects active-shift edits. Pending-result saves remain view-only. |
| Automatic calendar polling stayed suspended after recovery | Successful staged-save promotion did not clear `recovery_required` | Clear it only after successful promotion. Regression retains original corrupt bytes/backup, commits a repair and verifies the lock clears. |
| Engine warning during repeated Title/Play input transitions | Immediate scene removal during GUI input dispatch | Play is guarded and scene transition deferred; restore the button on failure. Real-input repeated journey transitions now complete without the baseline `!is_inside_tree()` warning. |

The original regression run failed these lifecycle/recovery checks before the
fixes. All pass afterward. A new test initially clicked an off-screen ingredient
without scrolling; the test was corrected to scroll the existing station. No
production preparation/scoring change was made for that test failure.

No navigation trap was reproduced after the fixes. Repeated routes include:
opening → shop → season → shop, shop → lottery → season → lottery → opening,
café → Map/lottery → season → Settings → season → lottery → café. Static screen
instances remain singletons within the scene. Existing suites verify Escape,
keyboard preparation, Settings focus, cancellation, expiration, order identity,
rush phases, soft closing, cooldowns, quality boundaries and frozen upgrades.

## Isolated development harness

This task adds **no in-game development panel**. Use the editor CLI instead:

```sh
# Start a completely separate first-time profile in the real title/café scenes.
godot --path /workspace/Cat-Cafe --script Tools/development.gd -- \
  --slot=first-run --reset --launch

# Prepare an isolated reward/shop review profile and launch it.
godot --path /workspace/Cat-Cafe --script Tools/development.gd -- \
  --slot=rewards --reset --coins=5000 --reputation=50:0 \
  --tickets=10 --season-xp=25000 --launch

# Inspect state / receipts, or advance calendar boundaries between play sessions.
godot --headless --path /workspace/Cat-Cafe --script Tools/development.gd -- \
  --slot=rewards --boundary=season --show
```

Controls, in argument order:

| Argument | Action |
| --- | --- |
| `--slot=NAME` | Choose a fixed scratch slot; letters/digits/underscore/hyphen only |
| `--reset` | Archive the prior slot directory and create defaults |
| `--coins=N` | Set test Coins |
| `--reputation=LEVEL:XP` | Set Level 1–50 with XP below its next threshold |
| `--season-xp=N` | Raise current Seasonal XP to 0–25,000 |
| `--tickets=N` | Generate tickets through N real Level 50 cycles |
| `--cycles=N` | Simulate N real Level 50 cycles |
| `--advance=SECONDS` | Advance the injected UTC clock, up to 100 seasons per action |
| `--boundary=day/week/season` | Move to the next exact UTC boundary and synchronize |
| `--show` | Print profile, Inbox, claim/service/cycle receipts, lottery history and UTC |
| `--launch` | Launch the real Title with that isolated profile |

Ticket grants intentionally use real cycle accounting: Level 50 is required,
one welcome ticket is still issued once, and cycle prizes accompany the tickets.
Requests are limited to 1–100 cycles at a time. No unbacked ticket balance is
fabricated. Lowering an already reached Level 50 or reducing earned Seasonal XP
requires resetting a scratch slot; historical entitlements are not erased by
stat controls. The injected clock resumes from the saved watermark on relaunch.
Close the launched test session before running more CLI mutation commands; the
underlying local save store assumes one writer.

Safety:

- Fixed storage: `/tmp/paw-pads-development/NAME/profile.json` on this Linux cloud
  environment. There is **no arbitrary save-path option** and no `user://` target.
- Slot traversal/absolute names are rejected. Operations refuse a redirected
  profile destination and active-shift editing before doing file I/O.
- Editor feature, debug engine and explicit `--script`/`-s` execution are required.
  Exported debug builds lack the editor feature; release builds also lack debug.
- `Tools/*` remains excluded from the configured Web export. Production scenes
  do not import or reference the harness. There are no normal navigation entries
  and no runtime development polling.
- Launch prints **DEVELOPMENT ONLY**, the isolated path, and marks the window title.
- Reset archives previous test saves/backups/recovery files instead of deleting
  them. Real player saves are never opened by the harness or validation scripts.

The complete command set, cross-process CLI use and graphical `--launch` were
executed. Production-export exclusion was inspected statically; an actual Web
export/device release was not run in this task.

## Save and calendar findings

Current schema remains **4**. No new permanent fields or migrations are needed
for these fixes. Integration checks load schemas 1–4; existing suites also cover
missing optional fields, invalid item IDs, newer-schema write blocking, malformed
JSON, backup-only recovery, orphan stages, failed writes, repeated purchases,
lottery/inbox round trips and exact cycle accounting. Damaged original files and
validated backups remain recoverable. Successful repair now allows normal
calendar polling to resume. Backup recovery can lose the latest checkpoint;
it is not a transaction-history replay system.

Scene-owned shift liveness is deliberately transient. Reloading an unfinished
shift preserves previously committed rewards but cannot commit new callbacks
against the old shift. A fresh Start Day allocates a new durable ID. A completed
shift can still be acknowledged repeatedly without another day/XP reward.

The unchanged injected calendar suites cover midnight UTC, Monday UTC, 56-day
season end, multiple missed seasons, forward and backward time changes,
seasonal-exclusive eligibility and historical claims. The integration journey
also crosses a boundary and then reloads the resulting state in another process.
The persisted watermark is conservative against regression; local device time
is **not** tamper-proof. There is no server dependency or multi-device clock.

## Validation

```sh
godot --headless --path . --editor --import
godot --headless --path . --script Tools/validate_integration.gd
# Use the artifacts directory printed by that run:
godot --headless --path . --script Tools/validate_integration.gd -- \
  --cold-read=/tmp/paw-integration-PID-TICKS
```

All original validation suites were rerun. Cold verification requires both
portrait checkpoint files; an empty directory cannot pass as a zero-test run.

| Suite | Passed assertions |
| --- | ---: |
| Full player journey / integration — headless | 654 |
| Full player journey — native GL with screenshots | 666 |
| Separate-process whole-profile / UI reload | 17 |
| Persistence | 196 |
| Shop | 495 |
| Lottery / Collections | 587 |
| Seasons / Challenges / Inbox | 628 |
| Cats | 259 |
| Drinks | 1,111 |
| Café shifts | 62 |
| Gameplay UI | 430 |
| Foundation | All 8 viewports |

Native execution uses Xvfb/Mesa GL Compatibility with Dummy audio. The driver
reports unsupported V-Sync; final runs contain no script/scene errors. Screenshots
cover Title, café, drink station, results, nested Settings and Inbox at both
portrait sizes. Reward UI resizing is asserted at 1280×720 and 1920×1080.
Normal isolated startup and the development launch were also exercised.

A before-task hash manifest confirms all original files remain present. Fifty-nine
artwork/reference/data/furniture/recipe/cat-quality resources are byte-identical
to Step 11 entry, including the uncommitted Step 10B catalogs. Only the identified
production lifecycle/storage/title scripts and documentation links changed.
`git diff --check` passed.

## Files for Step 11

Added (plus `.uid` sidecars):

- `Tools/development_profile.gd`
- `Tools/development.gd`
- `Tools/validate_integration.gd`
- `Docs/GameplayIntegration.md`

Modified production code:

- `Scripts/Persistence/cafe_profile.gd` — active shift and team mutation guards
- `Scripts/Persistence/profile_store.gd` — clear recovery flag after promotion
- `Scripts/Gameplay/cafe_session.gd` — common team editing gate
- `Scripts/UI/title.gd` — guarded/deferred Play transition

README and profile/season documentation link this report. All other dirty files
are retained Step 10B work, not rewritten for this task.

## Remaining work / limits

No further confirmed integration blocker remains in the exercised paths. Actual
browser/device persistence, IndexedDB behavior, hardware touch, safe areas,
background-tab behavior, device suspend/resume and export packaging need release
validation. Single-writer local storage and backup rollback limits remain.
The development harness currently uses the Linux cloud's `/tmp` location.

No findings here establish that the game feels fun, cozy or appropriately paced.
Real-time hands-on testing and later balancing remain necessary. Seasonal XP
rates, recipe values, abilities, upgrades and reward probabilities were not
changed. Seasonal Tier 50 pacing and prototype artwork/UI are future work,
not defects silently corrected in this integration pass.
