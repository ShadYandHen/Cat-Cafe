# Step 14 — Balanced café pacing for playtesting

The developer-approved Model B is now the production **playtesting baseline**, not
permanently finalized difficulty. No economy, cat, quality or progression tuning
is included. No commit or push. Branch `work`, HEAD `898c125` unchanged.

## Approved values and authoritative configuration

| Setting | Previous production | Step 14 |
| --- | --- | --- |
| Normal random arrival interval | 25–35s | **20–26s** |
| Rush random arrival interval | 10–15s | **9–12s** |
| Base patience before bonuses | 60s | **75s** |
| Café day | 300s | unchanged |
| Rush elapsed window | 120–180s | unchanged |
| Customer seats | 2 | unchanged |

The only production source edit is three exported defaults in
`Scripts/Gameplay/cafe_session.gd`. `Scenes/Gameplay/CafeSession.tscn` and Main
have no competing pacing overrides. No new configuration manager, timer or
setting was introduced. Historical audit fixtures deliberately retain the old
intervals to support comparisons; they are excluded from production export.

## Arrival scheduler and Rush boundaries

The existing authoritative `CafeSession.elapsed` clock and seeded RNG are unchanged.
Every scheduled attempt samples the appropriate uniform interval independently.
The first guest still appears immediately. Full-seat attempts are skipped; there
is no queue, stacking, immediate replacement or retry burst. A released seat is
available at the next scheduled attempt. Serving a guest does not reset the clock
or arrival schedule. Order IDs and exactly-once reward protection are unchanged.

At elapsed 120, the phase becomes Rush and `next_arrival = elapsed + random(9,12)`.
At 180, late service begins and `next_arrival = elapsed + random(20,26)`. The prior
phase's pending attempt is replaced, including an attempt exactly on the boundary.
This was existing behavior and is now explicitly tested; it is not a newly missed
or duplicated spawn. At 300, scheduling stops (`next_arrival = INF`), even when an
attempt was scheduled exactly at 300. Existing customers can finish or expire;
results appear after all are resolved. The three phase transition events remain
one-shot. No scheduler correction was needed.

## Patience modifiers and clocks

Starting patience is still:

`75 × (1 + equipped Mochi passive + Comfortable Seating bonus)`

All percentages are unchanged. Seating contributes 3% per purchased level, maximum
9%; Mochi contributes 5% when equipped in any slot. Active Mochi restores 10% of
the customer's modified original patience at the existing below-30% crossing,
subject to the same 30-second cooldown and consumed-crossing rules.

| Setup | Original patience | Eligible Mochi restoration |
| --- | --- | --- |
| No modifiers | 75s | Not active |
| Mochi, no Seating | 78.75s | 7.875s |
| Mochi + Seating 1 | 81s | 8.1s |
| Mochi + Seating 2 | 83.25s | 8.325s |
| Mochi + Seating 3 | 85.5s | 8.55s |

With maximum Seating and Mochi, the first care crossing is just below 25.65s
remaining, at just after 59.85 elapsed for an opening customer; restoration extends
its initial deadline to 94.05s. Remaining patience cannot exceed its modified
maximum or become negative. Rush has no separate patience penalty. Order, station,
team and Settings screens continue to use this same clock, without resetting
customer deadlines. Rapid transitions do not create new timers.

## Step 13A, rewards and persistence preserved

All recipe/cat/shop/season/reward JSON files are unchanged. Profile schema remains
**5**; there is no save migration change. Existing schema 4 migration still
initializes fractional-tip remainder to zero and preserves progression. Existing
profiles and saved teams use the new defaults at the next fresh shift; unfinished
customers/drinks are never restored. Coins/XP and service receipts remain durable.

Verified unchanged: Seasonal XP **200/150/500**, 56-day season, 50×500-XP tiers;
missing-required-ingredient final cap **74**; Blaze requires completeness and
consumes no cooldown for ineligible drinks; persistent fixed-point ordinary-tip
carry; separate Odin premium; recipe bases/ingredients/timing, scoring weights,
quality thresholds, Reputation rewards, upgrade costs/effects/levels, cat values,
lottery probabilities/catalogs, decorations/cosmetics and Inbox behavior.
More service can earn more total Coins/XP per shift; the amount paid per equivalent
service is unchanged. This is a throughput consequence, not an economy rebalance.

## Deterministic before/after comparison

`Tools/compare_pacing_14.gd` reuses the unmodified Step 13B production-session actor.
It first verifies that fresh production defaults exactly equal the approved B
fixture, then runs the previous configuration versus B with identical input
assumptions. It uses actual gameplay/order/scoring/reward methods, not a queue-only
approximation. Neither comparison writes a real profile or changes production to
obtain a desired result.

**960 shifts:** two configurations × upgrades 0/1/2/3 × slow/average/fast × 40 seeds
(417–456), default Mochi/Fade/Max team. All 960 full records match the frozen Step
13B reference, including deadlines, quality counts, activations and fractional
Coins. There is no unexplained divergence from the earlier report.

Actor assumptions are unchanged: FIFO, one drink at a time; tap means 1.8/.85/.45s,
read and notice 6/2.5/1s each, Gaussian timing errors in absolute seconds, per-
ingredient omissions 15/6/1%, distractions 25/10/2%. Automatic cat abilities are
triggered by real session events. Navigation/selection/assembly/service costs are
included; the matching station auto-selects. See the historical Step 13B report
for the exact distributions and limitations.

No-upgrade means (40 seeds per row). Loss percentage is unhappy departures divided
by **admitted** guests; full-seat skips are separate. Idle is forced waiting with
no guest. Rush busy includes reading/reaction/distraction time, not just taps.
Results include soft closing, so final duration can exceed 300 seconds.

| Configuration / actor | Admitted | Skipped | Served | Lost | Loss % | Idle % | Rush busy % | Coins | Rep XP |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Previous / low | 8.93 | 3.30 | 6.92 | 2.00 | 22.41 | 0.63 | 99.98 | 86.28 | 77.75 |
| Previous / average | 11.68 | 0.55 | 11.68 | 0.00 | 0.00 | 28.66 | 89.58 | 149.60 | 156.00 |
| Previous / high | 12.22 | 0.00 | 12.22 | 0.00 | 0.00 | 57.56 | 71.94 | 159.10 | 180.12 |
| Step 14 / low | 9.00 | 6.78 | 7.97 | 1.02 | 11.39 | 0.00 | 100.00 | 99.35 | 88.92 |
| Step 14 / average | 14.55 | 1.23 | 14.55 | 0.00 | 0.00 | 12.62 | 96.63 | 187.03 | 196.20 |
| Step 14 / high | 15.70 | 0.07 | 15.70 | 0.00 | 0.00 | 45.57 | 86.02 | 204.53 | 232.07 |

Average modeled service rises **11.68 -> 14.55**, forced idle falls **28.66% ->
12.62%**, and slow-player loss falls **22.41% -> 11.39%**. No average/fast losses
were observed in these samples; this is not a guarantee for real players. Slower
actors remain continuously occupied, and full seats skip more prospective guests.
These results support playtesting, not a claim that the game is enjoyable.
All four upgrade stages are included in the supporting JSON/CSV.

## Regression coverage and validation

New `Tools/validate_balanced_pacing.gd` covers:

- Exact production defaults, sampled lower/upper bounds and independent intervals
  in opening/Rush/late service, plus endpoint sampler behavior.
- Exact 120/180/300 boundaries with an old scheduled attempt at the boundary;
  no duplicate transition/admission, no post-close arrivals.
- Full seats, expiration/reuse, successful service during scheduled arrivals,
  duplicate callbacks, completion and another day.
- Coarse/fine clock equivalence, comparing timestamps within the existing
  `CafeSession.EPSILON` tolerance rather than bit equality across different tick
  partitioning.
- Base patience 75, all Seating levels with Mochi, threshold/restoration bounds,
  second crossing behavior, rapid screens and expired orders receiving no reward.
- Existing schema 4 migration through actual file load, preparation/service,
  completed day and next day; schema 5 relaunch and stale callbacks.
- Actual Main scenes, two non-overlapping seat controls, mouse at 720×1280,
  simulated touch at 320×568, station opening, live patience in Settings, restored
  focus, keyboard Back and Rush status.

Existing tests expecting old default patience now use the new derived deadlines.
The day suite's explicit 60-second custom fixtures remain intentional timing
isolation cases; its **production interval** assertions use the approved ranges.
No unrelated assertion was removed. Some assertion totals vary with the number
of customers observed in history loops under the new pacing.

| Headless suite | Result |
| --- | --- |
| Balanced pacing (new) | 3,126 assertions passed |
| Step 13A | 523 passed |
| Persistence | 196 passed |
| Shop | 496 passed |
| Lottery/Collections | 587 passed |
| Seasons/Challenges/Inbox | 629 passed |
| Cats | 257 passed |
| Drinks | 1,111 passed |
| Café shifts | 62 passed |
| Gameplay UI | 430 passed |
| Foundation | All 8 viewports passed |
| Full integration | 728 passed |

Godot 4.6.3 headless project import and normal title startup passed without script
or resource errors. All test profiles use isolated `/tmp`/XDG paths.

**Native GL Compatibility (software renderer/Xvfb):**

- Balanced pacing: **3,128** assertions, both portrait sizes, two screenshots.
- Full Title -> Team -> Shift -> preparation/service -> Results -> Shop -> Next Day
  integration: **740** assertions; both portrait sizes, mouse/keyboard/touch,
  Settings focus and screenshots.
- Gameplay UI: **430**, cats: **257** assertions.
- The scripted integration served 14 customers, lost none, earned 182 Coins,
  210 Reputation XP and 350 Seasonal XP (200 day + 150 daily) at each size.
  This ideal-input regression is distinct from the stochastic actor above.

Native two-seat screenshots were inspected, including 320×568: captions/patience
and controls fit and seat hitboxes do not overlap. Existing UI/art was not edited.
Separate processes passed **4** new pacing/save/relaunch checks and **17** full
integration cold-load checks. They reject stale callbacks and restore permanent
inventory/progression. The existing persistence suite also covers failed staged
writes and backup recovery. No real player save was used.

There were no confirmed production bugs and no scheduler fixes. Initial **new
validation-tool** issues were corrected: JSON checkpoint data must be normalized
before comparing with the typed profile; fine/coarse arrival timestamps need the
existing clock epsilon; frozen reference keys need canonical integer formatting.
These were not gameplay regressions and did not require production changes.

The native driver emits its known unsupported VSync warning; no critical errors.
An isolated Xvfb runner was prepared from Debian's signed package metadata, with
package hashes/TLS verification intact. Reusable environment `install_script`
and `start_skill` were saved as a configuration **draft**, not published. No
runtime service or application dependency was added to the Godot project.

## Files changed in Step 14

Production:

- `Scripts/Gameplay/cafe_session.gd`: only the three approved default declarations.

Existing regression expectations:

- `Tools/validate_day.gd`: approved normal/Rush bounds.
- `Tools/validate_cats.gd`: updated default-patience thresholds, deadlines and expiry.
- `Tools/validate_cafe_shop.gd`: patience/Seating/care calculations.
- `Tools/validate_drinks.gd`: expire at the new patience deadline.
- `Tools/validate_gameplay.gd`: expiration scenario advances to the new deadline.

Added:

- `Tools/validate_balanced_pacing.gd` and `.uid`.
- `Tools/compare_pacing_14.gd` and `.uid`.
- `Docs/BalancedCafePacing.md` (this report).

Documentation:

- `Docs/CafeDay.md`, `Docs/CatTeam.md`: current pacing and patience examples.
- `Docs/CafeBalance13B.md`: historical notice linking to the implementation;
  original proposals/results remain intact and other proposals remain unapproved.
- `README.md`: current baseline and report link.

Step 13B's three uncommitted audit tool files and its original report body were
preserved. All official assets, scenes, Data catalogs, profile/storage/scoring/
reward code, project settings and export presets match their starting hashes.
The preservation manifest explicitly checks that the runtime diff consists only
of 60->75, (25,35)->(20,26), and (10,15)->(9,12) default declarations.
No schema change, economy adjustment, cosmetic, decoration, new gameplay or cat
rebalance. No commits or pushes.

## Reproduction and supporting artifacts

From the repository root, use isolated XDG storage:

```sh
export XDG_DATA_HOME=/tmp/paw-14-run/data
export XDG_CONFIG_HOME=/tmp/paw-14-run/config
export XDG_CACHE_HOME=/tmp/paw-14-run/cache
godot --headless --path . --editor --import --quit
godot --headless --path . --script Tools/validate_balanced_pacing.gd
godot --headless --path . --script Tools/compare_pacing_14.gd -- --out=/tmp/paw-14-run/comparison
```

The comparison accepts `--reference=/path/to/Step13B/pacing.json`. If absent, it
still simulates both configurations but explicitly reports unavailable historical
reference checks. In this task all 960 historical records were available/matched.
The fixtures set the same production values after verifying current defaults;
`current` in the historical audit tool means **pre-Step-14**, not a second runtime
configuration. No whole Step 13B economy/team scan is required for this focused
comparison.

Run every existing `Tools/validate_*.gd` using the same headless command. For native
checks start the environment's isolated Xvfb, set `DISPLAY`, omit `--headless`,
and add `--audio-driver Dummy`. `validate_integration.gd -- --capture` captures the
full journey. The new pacing writer prints a scratch folder; pass it to a separate
`validate_balanced_pacing.gd -- --cold-read=/tmp/paw-14-regression-...` process.
Use fresh writer output for each cold read, since starting a new shift writes a
new checkpoint.

Full temporary logs are in `/tmp/paw-14/`, comparisons in
`/tmp/paw-14-comparison/`. Review copies, CSV/JSON, screenshots and a ZIP bundle are
at `/workspace/paw-pads-balance-review/step-14/`, outside production export paths.
All Tools remain covered by the unchanged `Tools/*` export exclusion.

## Remaining limitations and playtesting

Browser storage, real-device touch/safe areas, abrupt OS interruption during a
write, actual reading speed and subjective comfort are not established by these
checks. Xvfb/simulated input is not a physical phone. Simulations omit strategic
batching, extra wrong ingredients, learning and fatigue. Soft closing intentionally
makes some sessions longer than five wall-clock minutes.

Hands-on testing should compare perceived Rush pressure, slow-player recovery,
first-order comprehension, both-seat touch selection, timing clarity and whether
idle periods feel relaxing. The remaining Coin surplus and cat role tradeoffs
from Step 13B are not addressed here. Pacing scaling and other economy/UI
proposals remain unimplemented. Refine further only after developer review.
