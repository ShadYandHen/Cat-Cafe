# Seasonal Pass, Challenges and Permanent Reward Inbox — Step 10B

Step 13A adds schema 5 fractional ordinary tips; schema 4 migration details and
original validation evidence below describe the Step 10B implementation.

## Access and scope

Use **Map → Season Pass & Reward Inbox**, or **Shop & Golden Paw → Season Pass &
Reward Inbox** before opening or after results. Map retains the Lottery and
Collections screens. The pass and Inbox share a scrollable portrait screen with
fixed tabs, Settings and Back. Claims are available before Day 1 and between
shifts, view-only during active shifts. The café clock and customer patience
continue while viewing these interfaces or Settings. Artwork, recipes, cat
bonuses, base rewards, and café geometry are unchanged.

The pass is free: no premium track, purchases, advertising or premium currency.

## Calendar and injected clock

`Data/Seasons/pass.json` anchors season 1 at **2026-10-17 00:00:00 UTC**, ending
**2026-12-12 00:00:00 UTC**. This is the task's current date, not an expired
historical season. Seasons are consecutive 56-day intervals `[start, end)` with
stable IDs `paw-season-0001`, `paw-season-0002`, etc. The anchor is configurable
before release; changing a shipped calendar requires a deliberate migration.

`CafeProfile.clock` is an injectable Callable returning Unix UTC seconds. The
normal runtime uses system UTC. `SeasonCatalog` and `SeasonalProgress` are pure
calendar/state helpers and never read the system clock themselves. A persisted
`seasonal.last_time` watermark prevents returning to an already visited period
when a local clock moves backwards. This is a local prototype, not a trusted
server clock: moving the device clock forward can advance periods. Tests inject
fixed times instead of depending on real-time waits.

- Daily boundaries: **00:00 UTC**.
- Weekly boundaries: **Monday 00:00 UTC**.
- Challenge intervals are clipped to the current season's start and end. The
  season ID is part of every challenge period identity, so an intersecting week
  cannot carry progress into the next season.
- One existing PlayerProfile autoload polls calendar changes once per second.
  It saves only when the season, challenge period or eligibility changes, not on
  every countdown update. Transactions synchronize again at their own timestamp.
- Recovery loads do not automatically write; the next explicit permanent action
  retains existing recovery archives through ProfileStore.
- Before a future configured anchor, season 1 is scheduled but events earn no XP.

## Separate Seasonal XP

Each tier requires **500 Seasonal XP**, starting at tier 0 and capped at tier 50
(**25,000 XP**). Excess XP at the cap is discarded; no additional tiers or rewards
are fabricated. Tier and within-tier progress are derived from the saved XP,
not maintained as competing balances.

| Source | Seasonal XP |
| --- | ---: |
| Finalized café day | 200 |
| Completed daily challenge | 150 |
| Completed weekly challenge | 500 |

Permanent Reputation continues to use the existing drink-quality XP and Level 50
cycle system. Seasonal XP never overwrites, converts to, or changes Reputation.
Step 13A approves these rates. Over 56 days, one completed café day per day,
all 56 dailies and eight weekly rewards give **23,600 XP (Tier 47)**. Seven extra
shifts supply the remaining 1,400 XP to Tier 50. Actual UTC partial-week scheduling
is unchanged. Existing XP and completed reward receipts are never recalculated.
See [Step 13A corrections](BalanceCorrections13A.md) for current accounting.

## Challenge definitions and selection

One daily and one weekly challenge are active, drawn from JSON definitions:

| Cadence | Objective | Target | Event metric |
| --- | --- | ---: | --- |
| Daily | Serve drinks | 5 | served |
| Daily | Serve Good-or-better drinks | 3 | good |
| Daily | Earn service Coins | 100 | coins |
| Weekly | Complete café days | 5 | days |
| Weekly | Serve drinks | 30 | served |
| Weekly | Serve Excellent-or-better drinks | 10 | excellent |

Selection uses explicitly implemented FNV-1a over
`season_id:cadence:UTC_period_start`, followed by modulo pool size. It is stable
across platforms and relaunches. Saved state records period ID, definition ID,
clipped interval, progress and completion. Progress is clamped to the target.
Completion grants XP automatically once, in the same transaction that reaches
the target; challenge XP itself does not generate more gameplay events.

Quality objectives deliberately use **served drinks**, not cancelled/unfinished
preparations. `CafeSession.serve` supplies the actual final quality tier and actual
service Coins (including existing tips/premium bonuses) to `apply_service`.
The existing shift/order receipt gates the service, money, Reputation and
challenge event together. Customers who expire, duplicate taps, failed saves,
reopened screens and historical receipts cannot generate extra progress.

`complete_shift` adds the 50 day XP and the eligible day-challenge event alongside
the existing completed-day receipt. Abandoned shifts get no day XP. Successfully
committed services remain valid even if a player later abandons the shift.
There is no retroactive XP for days or drinks from older saves.

## Explicit reward milestones

The prototype track repeats for subsequent seasons until new tracks are authored.
Item ownership remains unique, so repeat item claims use the fallback below.

| Tier | Reward | Classification |
| --- | --- | --- |
| 5 | 250 Coins | Coins |
| 10 | Strawberry Badge | Regular cosmetic |
| 15 | Mint Leaf Jar | Existing regular decoration |
| 20 | 500 Coins | Coins |
| 25 | Mint Ribbon | Regular cosmetic |
| 30 | Peach Blossom Vase | Existing regular decoration |
| 35 | 750 Coins | Coins |
| 40 | Spring Blossom Badge | Seasonal exclusive cosmetic |
| 45 | Spring Heart Mat | Seasonal exclusive decoration |
| 50 | Little Dreams Badge | Seasonal exclusive cosmetic |

The tier 40 and 45 items reuse Step 10A's unreleased previews. Tier 50 adds only a
catalog definition using the existing café-badge placeholder, not new artwork.

Milestones become earned at their required XP, but rewards are **manual claims**.
A unique item already owned at claim time substitutes **500 Coins**, including
seasonal exclusives. The stored outcome records this fallback. This fixed reward
policy is separate from the lottery's exhausted-exclusive **1,000 Coin** rule,
which remains unchanged.

## Permanent Inbox and atomic claims

At the moment a milestone is earned, its entitlement is placed in the permanent
Inbox, with ID `season_id:tier:N`. Both the pass's Claim button and Inbox's Claim
button reference that **same entitlement**. It records type, payload snapshot,
source (`season_pass`), source season, tier, creation UTC timestamp, claim status,
claim receipt, claimed timestamp and actual awarded outcome.

Pending rewards never expire. Claimed entries remain as durable receipts.
Rollover does not copy entries or create a second claim surface. It simply
archives the participated season and starts the next one; all earned unclaimed
Inbox entries already remain available permanently. Unreached milestones create
nothing. Returning after multiple missed seasons jumps directly to the current
calendar interval and does not generate rewards or empty history for missed
seasons. Archived XP/earned/claimed sets and the Inbox are validated together.

Claims use `GoldenPawRewards.fixed_outcome` and the same `apply` candidate-state
ownership/Coins path used by the existing lottery. There is one decoration
inventory and one cosmetic inventory. Ownership and equipment remain separate.
A claim candidate contains the outcome, Coin/inventory changes,
`claim:<entitlement_id>` receipt, claimed timestamp, and current/archived claimed
milestone set. Only a successful staged-write validation and promotion publishes
it in memory. Duplicate claims fail; failed writes retain the pending entitlement
and grant nothing. Invalid or unavailable payloads remain unclaimed for recovery.

The service, completed-day, challenge-XP and earned-milestone transaction is one
commit. Claiming is a separate deliberate transaction. No reward is replayed on
load, and interrupted `.tmp` files never become claimable receipts.

## Rollover and existing lottery

The two preview items and Little Dreams Badge have
`origin_season = paw-season-0001` and `eligibility_start = season_released`.
Before that season ends they cannot enter a lottery pool. Calendar synchronization
adds ended catalog-origin season IDs to the existing `released_seasons` list,
even if the player missed that season. It does not create ownership or tickets.

The lottery synchronizes its candidate calendar **before** sampling rewards, so a
roll exactly at season end uses the released pool without needing an earlier UI
poll. The existing weights **50/24/24/2**, uniform item selection, exclusive
non-duplication and **1,000 Coin** exhausted-exclusive fallback are unchanged.
Already owned seasonal items are excluded from exclusive draws as usual.

## Save schema and migration

Schema **4** adds one `seasonal` object:

```text
seasonal:
  current: id, start, end, xp, earned[], claimed[], daily{}, weekly{}
  history[]: id, start, end, xp, earned[], claimed[]
  inbox[]: id, type, payload, source, season, tier, created_at,
           claimed, claim_receipt, claimed_at, outcome
  last_time: UTC watermark
```

Existing schema 0–3 saves preserve Coins, Reputation, days, cats, upgrades,
decorations/equipment, cosmetics/equipment, lottery tickets/history and Level 50
entitlements. New seasonal state starts with no retroactive XP or prizes.
Calendar creation occurs on the next runtime synchronization/transaction.
Normal startup synchronizes automatically; tests never touch real player saves.

Seasonal validation checks calendar identity/intervals, deterministic challenge
schedules, progress limits, earned/claimed sets, unique Inbox IDs, timestamp and
payload types, receipt consistency and linkage to historical seasons. Corrupt
seasonal ledgers are rejected for existing backup recovery rather than silently
resetting earned rewards. Unknown newer schemas remain write-blocked. Existing
staged writes, validated backups and damaged-file archives are retained.

## Files

Added (plus Godot UID sidecars):

- `Data/Seasons/pass.json`
- `Scripts/Gameplay/season_catalog.gd`
- `Scripts/Gameplay/seasonal_progress.gd`
- `Scripts/Gameplay/season_screen.gd`
- `Scenes/Gameplay/SeasonScreen.tscn`
- `Tools/validate_seasons.gd`
- `Docs/SeasonalPass.md`

Modified:

- `Scripts/Persistence/cafe_profile.gd`, `player_profile.gd`
- `Scripts/Gameplay/cafe_session.gd`, `gameplay_view.gd`
- `Scripts/Gameplay/golden_paw_rewards.gd` (shared fixed-outcome grant helper)
- `Scripts/Gameplay/cafe_shop_screen.gd`, `rewards_screen.gd` (entry buttons)
- `Scenes/Gameplay/GameplayView.tscn`
- `Data/Rewards/cosmetics.json`, `Data/Cafe/decorations.json` (season metadata)
- `export_presets.cfg` (include season JSON in Web export)
- `Tools/validate_lottery.gd` (current schema expectation)
- README, profile and lottery documentation links

## Validation and limitations

Godot 4.6.3 headless import and ordinary title/autoload startup passed. Startup
created schema 4 / season 1 at zero XP using isolated user storage. A separate
write/read process pair verified XP, pending/claimed Inbox entries, missed-season
rollover and old-season claims after a cold load.

| Suite | Passed assertions |
| --- | ---: |
| Seasons / Challenges / Inbox — headless | 628 |
| Seasons / Challenges / Inbox — native GL Compatibility | 628 |
| Lottery | 587 |
| Shop | 495 |
| Persistence | 196 |
| Cats | 259 |
| Drinks | 1,111 |
| Café shifts | 62 |
| Gameplay UI | 430 |
| Foundation | All 8 viewport configurations |

New tests cover exact tier boundaries, all challenge definitions via real service
and completed-day transactions, injected UTC clocks, Monday/midnight boundaries,
clock rollback, challenge completion duplication, milestones, claims, failures,
multiple missed seasons, old entitlements, seasonal lottery release and schema 3
migration. UI tests use mouse at 720×1280, simulated touch at 320×568, keyboard,
Settings focus (including rollover behind the modal), in-shift locks and desktop
resize checks at 1280×720 / 1920×1080. Native screenshots were inspected at both
portrait sizes. Mesa reports unsupported V-Sync; Dummy audio avoids unavailable
host audio. All save tests use isolated temporary paths.

Sixty-five protected artwork/reference/shared UI/recipe/cat-quality files were
compared to HEAD and were unchanged. `git diff --check` passed.

Browser/physical-device storage, touch hardware, safe areas and IndexedDB remain
unverified. The clock is local and not tamper-resistant. Backup recovery can
restore an older valid checkpoint; there is no cross-device/server ledger or
multi-writer coordination. Reward track values and badge/decoration markers are
prototypes. Season pacing remains deliberately unchanged. Inbox/history records
are retained without expiry. No premium passes, ads, adoption, new artwork,
recipe rebalance or cat-ability changes were introduced. No commit or push.

Step 11: [cross-system journey, recovery findings and isolated progression harness](GameplayIntegration.md). Calendar and XP rules remain unchanged.
