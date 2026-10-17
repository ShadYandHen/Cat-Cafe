# Permanent profile, Reputation and saves (Step 8)

Step 9 extends this to [schema 2 with café upgrades and decoration inventory](CafeShop.md). The details below also record the original Step 8 behavior.

Step 10A adds [schema 3, spendable tickets, resolved Level 50 rewards and collections](GoldenPawLottery.md). Deferred entitlement behavior described below is historical.

Step 10B adds [schema 4, seasonal progression, challenges and permanent Inbox claims](SeasonalPass.md).

Step 13A adds [schema 5 and persistent fractional ordinary-tip settlement](BalanceCorrections13A.md). Missing fractional state initializes to zero; historical service and seasonal receipts are preserved.

## Player flow

Title → Play now opens **Before opening**, with Coins, Reputation progress, completed days, Start Day, Cat Team and Settings. Team selection works before Day 1 and between shifts; it is locked while a shift runs. No café time or customer arrivals occur before Start Day. A returning player always starts a fresh shift, with their saved economy and team. Unfinished customers, drinks, cooldowns and scene references are never restored.

Coins and Level in the existing HUD read the permanent profile. A readable XP fraction appears above the café. Successful service can display a brief level-up message, and results show the current progress and levels gained during the shift. At Level 50 the fraction shows the repeatable 1,000 XP cycle. Existing pastel controls, portraits, Settings and centered portrait layout are retained.

## Architecture and files

Added:

- `Scripts/Persistence/cafe_profile.gd`: authoritative RefCounted profile, progression, validation, compact entitlement bookkeeping and transactional mutation API.
- `Scripts/Persistence/profile_store.gd`: schema-validated JSON reads, staged writes, backup replacement and recovery archives.
- `Scripts/Persistence/player_profile.gd`: the `PlayerProfile` autoload that loads one profile before Title and retains it across scenes.
- `Tools/validate_profile.gd`: isolated persistence, progression, failure-path and input/UI tests.
- Godot UID sidecars and this document.

Extended `Scripts/Gameplay/cafe_session.gd`, `gameplay_view.gd`, `cat_team_screen.gd`, and `Scenes/Gameplay/GameplayView.tscn`. The pre-day screen reuses the existing DayResults shell as a `DayLobby` instance. `project.godot` adds only the profile autoload; rendering and scaling settings are unchanged. Existing test fixtures now inject fresh in-memory profiles and explicitly start shifts where their older scenarios require it. README and earlier feature documents link here. Other dirty files are prior uncommitted Step 5–7 work.

`CafeSession.coins` is a read-only projection of `profile.coins`, not a second balance. Session earned Coins/XP remain shift statistics, never reapplied to the permanent profile at results. CatTeam is the frozen runtime team during a shift; assignments outside a shift are saved before being accepted, and rolled back on save failure. The scene-owned session clock, recipes, quality calculations and cat ability values are unchanged.

## Save format and storage

Normal game startup loads **`user://player_profile.json`**. `OS.get_user_data_dir()` identifies the platform-specific folder (Godot's app userdata for Paw Pads Café). The schema is JSON version **1**:

- `schema_version`, `coins`, `level`, `xp`, `completed_days`.
- `team`: active, support 1, support 2, with unique valid cat IDs.
- `cycle_xp`, `cycles`, `welcome_granted`, `pending_welcome_ticket`, `pending_cycle_tickets`.
- `next_shift_id`, `open_shift_id`, `shift_completed`, `served_order_ids`: durable transaction identity and current-shift receipts, not an unfinished gameplay snapshot.

Default state is 120 Coins, Level 1, 0 XP/days, Mochi active with Fade/Max support. No file is needed until the first meaningful mutation; then the default or loaded profile is saved together with that change. Temporary nodes, UI state, customer state, drinks and ability state are excluded.

A candidate mutation is validated and written to `.tmp`, flushed, closed, read back and validated. A previously valid primary is copied through `.bak.tmp` to `.bak`. The staged primary is then renamed over `player_profile.json`. Only after promotion succeeds does the profile publish its new in-memory state. This is the commit boundary. A failed write leaves the prior balance, XP and receipt state unchanged.

Load prefers a complete valid primary, then a valid backup. If primary fields require repair and a complete backup exists, the backup is preferred over silently resetting progression. Malformed JSON, negative/fractional/invalid numeric fields and inconsistent receipt/entitlement state are rejected. Schema 0 or missing fields migrate/default into v1, with diagnostics; invalid/duplicate team IDs are repaired to three valid unique cats. A newer unsupported primary or required backup is preserved and write-blocked, rather than downgraded. Missing saves create defaults. Damaged originals remain untouched on load; before replacement they are copied to uniquely named `.corrupt-*` or `.repair-*` archives. An unreadable backup is also archived before replacement. Orphan `.tmp` files are ignored as uncommitted transactions and archived before reuse.

Recovery is reported in the startup log and pre-day interface. Service failures leave the drink ready with a retry message; failed day completion is explicitly pending with **Retry save & continue**. Day start cannot proceed until its checkpoint succeeds. Backup recovery can roll back the latest transaction to the previous valid checkpoint; retained damaged files may allow manual recovery. A backup is not a complete transaction-history archive.

## Reputation and entitlements

Levels 1–49 require `75 + 20 × (current level − 1)` XP. Grants can cross multiple levels and carry the remainder. Reaching Level 50 costs **27,195 total XP** from Level 1. The level never exceeds 50. Negative, fractional, nonnumeric or nonfinite grants are rejected. Numeric saves/rewards are bounded to exactly representable JSON integers.

At Level 50, excess and future XP feed `cycle_xp`. Each 1,000 XP increments `cycles` and `pending_cycle_tickets` once. Reaching Level 50 sets the one-time `welcome_granted` marker and pending welcome ticket in the same transaction. Reload/normalization cannot repeatedly add either reward.

`pending_entitlements()` exposes the stable welcome identity `level50-welcome` and a compact pending cycle serial range. There is exactly one lottery ticket entitlement per cycle; the counts/range avoid creating an enormous array for a large XP grant. There is no claim/redemption API or inventory fabrication in this step.

The reserved future policy is recorded without rolling: 50% 1,000 Coins, 25% regular cosmetic, 25% regular decoration; an exhausted applicable cosmetic/decoration pool falls back to 500 Coins. No such prizes are granted now, and no Coins are issued by simply reaching Level 50 or completing a cycle. Ticket entitlements remain pending for future reward systems.

## Exactly-once shift rules

1. **Start Day** saves a monotonically allocated shift ID before admitting customers. Old service receipts are replaced only when a new shift starts. Old scene callbacks cannot grant rewards to the new shift.
2. **Manual service** computes the existing recipe/cat reward, then commits Coins + Reputation XP + the `(shift ID, order ID)` receipt together. Only success marks the temporary customer served, releases the seat, and consumes any Odin service activation. A reentrant guard and terminal order state protect repeated input; durable receipts protect reload/retry.
3. **Expiration** never calls the permanent reward API. Preparation alone grants nothing.
4. **Soft-close completion** marks that shift completed and increments completed days once. It never adds shift earnings again. Repeated completion is idempotent. If saving fails, results remain pending until retry.
5. **Relaunch/scene replacement** keeps committed economy/team/entitlements, discards unfinished gameplay, and returns to pre-day setup. Starting again allocates a different shift ID. An interrupted shift does not increase completed days; the next day number is completed days + 1.

No save-on-quit dependency is required for completed transactions: every service, team change, level-up and shift completion is committed synchronously at its meaningful change. Shared profile signals update the HUD.

## Validation and limitations

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://Tools/validate_profile.gd
godot --headless --path . --script res://Tools/validate_cats.gd
godot --headless --path . --script res://Tools/validate_drinks.gd
godot --headless --path . --script res://Tools/validate_day.gd
godot --headless --path . --script res://Tools/validate_gameplay.gd
godot --headless --path . --script res://Tools/validate_foundation.gd
```

Command-line `--script` runners intentionally use an in-memory autoload and must inject isolated profiles. The persistence suite opens unique `/tmp/paw-profile-tests-<pid>-<time>/...` paths. Existing suites retain their original gameplay assertions using isolated in-memory profiles and explicit immediate-start fixtures. They never read or overwrite real player saves.

Tests cover real staged writes/reloads, missing/corrupt/backup/legacy/future saves, team repair, XP boundaries/carryover/multiple levels, welcome/repeat entitlement identity, receipts, invalid rewards, failed writes and retry, mid-shift relaunch, day counting, pre-Day 1 team selection, level-up HUD/results, Level 50 UI and touch targets. Mouse and simulated touch run at 720×1280 and 320×568. Separate normal-startup Godot processes under an isolated XDG directory also verify the actual autoload restores committed economy/team after a process exit.

Native GL Compatibility screenshots and automated input are checked. Browser export, real mobile devices and actual IndexedDB synchronization are not verified. A Web runtime check reports unavailable persistent user storage; browser data clearing/private browsing may still prevent retention. Native power-loss/filesystem guarantees beyond staged rename/flush are not established. Saves assume one running game writer; concurrent instances are not coordinated. This is local persistence, with no cloud synchronization.

No adoption, upgrades, cosmetics, decorations, prize redemption, Seasonal Pass or lottery UI is implemented. Official artwork remains unchanged. No commits or pushes are made.

### Completed checks

Godot 4.6.3 import and normal title startup passed. The persistence suite passed **196 assertions** headlessly and with native GL Compatibility, including mouse/touch at both target portrait sizes and storage failure/recovery tests. Regression suites passed **259 cat**, **1,111 drink**, **62 shift**, and **430 gameplay UI** assertions, plus foundation checks across eight viewport sizes. Two separate normal-startup processes verified automatic restore using isolated user storage. Screenshots of pre-Day 1 setup, team editing, level-up HUD, results and Level 50 cycle progress were inspected at 720×1280 and 320×568. The only native graphical warning was unsupported V-Sync configuration under Xvfb/Mesa.

Protected artwork, references, shared UI/environment resources and the existing drink scoring implementation were checksum-verified unchanged. The only project-settings addition is the required profile autoload. Shorter café status messages prevent the new XP header from causing overlap with customer targets. No balance values changed.

Step 11 [integration fixes](GameplayIntegration.md) require live scene ownership for new shift rewards, lock team changes while completion is pending, and resume calendar polling after successful recovery saves. Schema remains 4.
