# Golden Paw Lottery and Collections (Step 10A)

The existing **Map** navigation opens Golden Paw Lottery & Collections. Before
opening and after results, use **Shop & Golden Paw**, then the visible Golden Paw
entry. The booth is visible at Level 1 and rolls unlock at Level 50. Collections
can be viewed at any level. Spending and equipment changes are blocked during a
shift by both the UI/session and the authoritative profile. The café clock keeps
running while viewing rewards and Settings.

## Catalogs

`Data/Rewards/cosmetics.json` defines:

| Item | Classification | Availability |
| --- | --- | --- |
| Strawberry Badge | Regular cosmetic | Lottery / future grants |
| Mint Ribbon | Regular cosmetic | Lottery / future grants |
| Coffee Pin | Regular cosmetic | Lottery / future grants |
| Golden Paw Badge | Exclusive cosmetic | Lottery |
| Dream Star Ribbon | Exclusive cosmetic | Lottery |
| Spring Blossom Badge | Exclusive cosmetic | Unreleased seasonal preview |

`Data/Cafe/decorations.json` retains the six regular shop decorations and adds
Golden Paw Lantern (wall), Dream Star Planter (shelf), and Spring Heart Mat
(floor, unreleased seasonal preview). Exclusive decorations are reward-only,
never purchasable for their reserved price field. Ownership and equipment use the
existing decoration inventory, slots, and native marker renderer.

Cosmetics use one `cafe_badge` slot, represented by a small non-interactive paw
badge in the café and an equipment indicator in Collections. They never alter
character artwork or grant stats. Ownership remains after unequipping. Future
reward systems can call `grant_cosmetic` / `grant_decoration` idempotently.

All reward definitions include classification, source, optional asset, slot,
exclusive flag, originating season, lottery eligibility, and start condition.
A `season_released` item is excluded until its season ID appears in the profile's
`released_seasons`. This build has no season-release action or pass progression.
Unreleased items appear as locked collection previews and are excluded from the
completion denominator. Newly added eligible catalog entries automatically
appear in counts and the UI without a save migration.

## Exact reward rules

`GoldenPawRewards` is independent of UI and saves. It accepts an injected Godot
`RandomNumberGenerator`. Category selection uses uniform integer buckets 0–99:

| Buckets | Lottery | Separate Level 50 cycle |
| --- | --- | --- |
| 0–49 | 500 Coins | 1,000 Coins |
| 50–73 | Regular cosmetic | Regular cosmetic |
| 74 | Regular decoration | Regular cosmetic |
| 75–97 | Regular decoration | Regular decoration |
| 98–99 | Exclusive | Regular decoration |

Lottery regular draws choose uniformly from the entire eligible regular
category, including owned entries. An owned selection pays **500 Coins** and
records the duplicate item ID. An empty regular pool also pays 500 Coins.
Exclusive draws choose uniformly from currently eligible **unowned** cosmetics
and decorations together; exhaustion pays **1,000 Coins**. No pity or rarity
guarantee exists. Roll 10 performs ten independent selections against the
candidate inventory, so earlier outcomes affect duplicate eligibility.

Cycle item rewards instead select uniformly among eligible **unowned** regular
items. An exhausted regular category pays **500 Coins**. Every cycle gives one
lottery ticket **in addition** to this separate reward. The welcome entitlement
gives one ticket without a cycle prize.

## Transactions and entitlement resolution

The persistent `CafeProfile` owns all Coins, items, equipment, tickets, and
receipts. Reward helpers only operate on a deep candidate snapshot. Staged save
validation and promotion must succeed before that state is published.

- One saved welcome flag identifies `level50-welcome` permanently.
- Cycle serials 1 through `resolved_cycles` identify processed entitlements.
  Each newly processed cycle stores its selected outcome and cycle ID.
- The issued/spent invariant is:
  `tickets = resolved_cycles + int(welcome_processed) - (next_roll_sequence - 1)`.
- Resolving pending rewards commits tickets, prizes, inventory, and receipts
  together. Resolution runs after successful service/XP grants and on ordinary
  profile load. Failed resolution leaves the durable entitlement pending.
- Resolution handles up to 128 cycles per transaction to bound work on oversized
  legacy saves. A visible Resolve Pending action processes any remainder.
- Recovery loads do not write automatically. Explicit reward resolution or the
  next successful permanent transaction retains damaged originals through the
  existing archive/backup mechanism.
- A roll requires Level 50, 1 or 10 tickets, an inactive shift, and the expected
  persisted next sequence. The UI requires Review before another roll, so repeat
  input cannot turn one displayed quote into multiple spends.
- Roll 10 is one transaction: all ten ticket deductions and prizes persist
  together, or none do. Failed writes also restore the in-memory RNG state.
- History retains the last 50 rolls, with category, item ID / Coins, sequence,
  duplicate flag and fallback reason. It is an already-awarded read-only ledger,
  never a claim surface. All ten latest outcomes are shown in a scrollable list.

A completed service and its XP are saved first. If Level 50 reward resolution
then fails, that service remains committed and the entitlement remains pending;
retrying resolution cannot duplicate service Coins or XP. No unfinished shift is
restored. As before, local backup recovery may roll back to the last valid
checkpoint; there is no server ledger or multi-process writer coordination.

## Save schema

Schema **3**, still at `user://player_profile.json`, adds:

- `lottery_tickets`, `welcome_processed`, `resolved_cycles`
- `cycle_rewards` (durable outcomes keyed by cycle serial)
- `owned_cosmetics`, `equipped_cosmetics`
- `lottery_history`, `next_roll_sequence`
- `released_seasons` (future release bookkeeping only)

Schemas 0–2 retain Coins, Reputation, cycle XP, days, cat team, upgrades, and all
existing decoration ownership/equipment. Pending welcome/cycle fields migrate
into spendable tickets and resolved receipts. Ticket/sequence inconsistencies or
invalid reward ledgers reject the save and use existing recovery behavior;
invalid cosmetic ownership/equipment fields are repaired with diagnostics.
Unknown future schemas remain write-blocked. JSON receipt numbers normalize to
integers before staged validation. Interrupted `.tmp` files are retained/ignored,
never replayed. Real saves are never opened by test scripts.

## Files

New: reward cosmetic JSON, `reward_catalog.gd`, `golden_paw_rewards.gd`,
`rewards_screen.gd`, `RewardsScreen.tscn`, `validate_lottery.gd`, this document.
Modified: `cafe_profile.gd`, `profile_store.gd`, `cafe_catalog.gd`, decoration JSON,
`decoration_display.gd`, `cafe_session.gd`, `gameplay_view.gd`,
`GameplayView.tscn`, `cafe_shop_screen.gd`, Web export JSON include filter,
profile/shop regression expectations, profile documentation and README.

## Validation

Run using Godot 4.6.3, for example:

```sh
godot --headless --path . --editor --import
godot --headless --path . --script Tools/validate_lottery.gd
```

All tests use unique temporary profiles under `/tmp`, never the player save.
The lottery suite checks exact probability buckets, deterministic seeds, unlocks,
ticket accounting, Roll 1/10, stale inputs, history truncation, duplicate fallbacks,
exclusive exhaustion, cycle rewards, old entitlements, equipment, shared
inventory, failed writes, bounded backlogs, orphan saves, mouse, simulated touch,
keyboard, Settings focus, shift locks, portrait sizes and desktop resizing.

Existing shop, profile, cat, drink, day, gameplay UI and eight-viewport foundation
suites are retained. Old entitlement tests now assert spendable tickets and
resolved receipts instead of deferred Step 8 placeholders; reward-only
exclusives are asserted unpurchasable in the shop suite.

Native graphical checks use GL Compatibility with Xvfb/Mesa and the Dummy audio
driver; portrait screenshots are inspected separately. Browser export, actual
phones, CSS safe areas and IndexedDB durability are not verified in this task.

No commits or pushes are part of this step. No Seasonal Pass, challenges, Inbox,
real-money purchases, new recipes or cat abilities are implemented.

Final results on Godot 4.6.3:

| Suite | Result |
| --- | --- |
| Lottery and Collections (headless and native GL) | 575 assertions each |
| Café Shop | 486 assertions |
| Profile / save recovery | 196 assertions |
| Cats | 259 assertions |
| Drinks | 1,111 assertions |
| Café day | 62 assertions |
| Gameplay UI | 430 assertions |
| Foundation | All 8 viewport configurations passed |

Import and ordinary title startup passed. Separate write/read processes verified
tickets, cycle receipts, history, ownership and cosmetic equipment survive a cold
load. Sixty-five tracked artwork/reference/shared UI/recipe/cat-quality files were
compared byte-for-byte to HEAD and were unchanged. `git diff --check` passed.
Native Mesa reports unsupported V-Sync; Dummy audio avoids unavailable host audio.
Screenshots at both portrait sizes were inspected; results/history/items scroll,
while Settings and Back remain accessible. New rewards UI also passed centered
layout assertions at 1280×720 and 1920×1080 and after resizing back to portrait.
