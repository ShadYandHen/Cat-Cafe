# Step 13B — Café pacing, economy and cat balance review

> Historical review: Step 14 implements only Model B arrival and patience defaults.
> Other proposals remain unapproved. See [Balanced café pacing](BalancedCafePacing.md).

**Assessment only. No production values changed. No commits or pushes.**
Baseline: branch `work`, commit `898c1253139e7be5aa3ac2ff8f4e47c9abc1402f`,
Godot 4.6.3. The working tree was clean before this review. Production source,
artwork, scenes, recipes, reward catalogs, prior tools/tests, project settings and
Step 13A corrections remain byte-for-byte unchanged.

## Recommendation and approval boundary

Recommend **Model B: normal 20–26s, Rush 9–12s, base patience 75s** for a hands-on
prototype comparison. Keep 300 seconds, two seats and Rush at 120–180 elapsed.
It cuts modeled average-player forced idle time without the slow-player losses
of Busy Café. Slow players are still continuously occupied; zero pressure for
every player is not established. Model A is the gentler alternative if testing
finds B tiring. No model is implemented.

Recommend **economy Option C**, optional regular non-power collection content,
while preserving today's upgrade costs. Do not inflate costs merely to match
Level 50. Coin surplus is confirmed; whether it harms motivation is untested.
Recommend **holding all cat values**: throughput buffs tested here do not establish
a meaningful benefit, and a premium-tip buff worsens the income leader's advantage.

Approval is required for every proposed pacing, scaling, price, catalog, ability
or UI change. Completing this report does not authorize implementation.

## 1. Verified production baseline

Sources: `Scripts/Gameplay/cafe_session.gd`, `drink_quality.gd`, `cat_team.gd`,
`Scripts/Persistence/cafe_profile.gd`, `Data/Recipes/drinks.json`,
`Data/Cats/roster.json`, `Data/Cafe/*.json`, `Data/Seasons/pass.json`,
`golden_paw_rewards.gd`; historical context in `GameplayBalance.md`,
`BalanceCorrections13A.md`, and `GameplayIntegration.md`.

| System | Current authoritative behavior |
| --- | --- |
| Profile | 120 Coins; Level 1; Mochi active, Fade/Max support; schema 5 |
| Day / seats | 300 active seconds, 2 seats; first customer immediately |
| Normal / Rush arrivals | 25–35s / 10–15s, seeded uniform intervals |
| Phases | Opening 0–120; Rush 120–180; late service 180–300 elapsed |
| Capacity and closing | Full-seat attempts skipped (no outside queue); stop admissions at 300; finish or expire remaining guests |
| Patience | 60s base; individual deadlines; Settings and every station/menu continue time |
| Preparation | 8 recipes, 1–3 ingredients, 3 steps; 3–5s target, manual stop/assembly/service; no movement |
| Speed | Target = recipe target / (1 + cat passive + Equipment + applicable active) |
| Patience stacking | Base × (1 + Mochi passive + Seating); care restoration uses modified original patience |
| Quality | 50 ingredient / 35 timing / 15 step points; cat/upgrade bonuses; final missing-ingredient cap 74 |
| Blaze | Only complete Excellent 75–94 -> 95; incomplete never consumes its cooldown |
| Tier tip / Reputation | Okay 0%/5 XP, Good 5%/8, Excellent 10%/12, Perfect 15%/15 |
| Coins | Recipe base 10/12/14 + ordinary tip + settled unpaid ordinary bonus + eligible separate Odin premium |
| Tip rounding | Combined whole ordinary tip unchanged; 10,000 units/Coin persistent remainder; no premium fractions |
| Active ability | Only active cat; automatic qualifying events; 30s session-time cooldown; reset each day |
| Reputation | 75 + 20×(L−1) to next level; 27,195 XP to Level 50 |
| Season | 56 UTC days, 50×500 XP; 200 day / 150 daily / 500 weekly; claims manual |
| Lottery | Level 50; 50/24/24/2 categories; welcome + each 1,000 XP cycle ticket; no ticket purchases |

Arrivals reset their next scheduled time at phase boundaries. Recipes rotate by
`(order_id−1+schedule_seed) % 8`; they are not independent random draws. Neither
Reputation nor purchases currently increase arrival difficulty. These production
details are retained in the simulations instead of replacing gameplay with a
Poisson queue model.

The historical Step 12 report predates the approved 200/150/500 Seasonal XP,
74-point completeness cap and fractional tips. It reported about 11 shifts for
upgrades and 173 for Level 50. This review finds 10.7 / 168 for its average actor;
that difference is **not solely a Step 13A effect**. Seed counts and the simulated
input policy also changed: the redundant station-category tap is removed, and
expired-screen Back recovery is explicitly modeled. Historical data are not
silently rewritten. Step 11's scripted 155-Coin/100-Seasonal-XP journey is also
historical; the current regression yields 156 Coins / 350 Seasonal XP.

| Upgrade | Effects at levels 1 / 2 / 3 | Costs | Required Reputation levels |
| --- | --- | --- | --- |
| Brewing Equipment | 0.03 per level, speed (max 3) | 60.0/120.0/240.0 | 1.0/2.0/3.0 |
| Comfortable Seating | 0.03 per level, patience (max 3) | 50.0/100.0/200.0 | 1.0/2.0/3.0 |
| Better Ingredients | 2 per level, quality (max 3) | 70.0/140.0/280.0 | 2.0/3.0/4.0 |
| Service Training | 0.05 per level, tip (max 3) | 60.0/120.0/240.0 | 2.0/3.0/4.0 |

Effects are +3/6/9% speed, +3/6/9% starting patience, +2/4/6 quality points,
and +5/10/15% ordinary tip amount. Total upgrades: **1,680 Coins**. Six regular
decorations cost **195 Coins** in total, individual prices 20–45, Reputation 1–3.
Exclusive items' placeholder `price:1` does **not** make them shop-purchasable;
source/rarity eligibility is checked. The complete current Coin shop costs 1,875.

## 2. Method, coverage and player assumptions

`Tools/analyze_cafe_13b.gd` extends the existing audit actor and observes actual
`CafeSession` through `balance_session_probe.gd`. It uses actual recipe scoring,
abilities, purchase validation, profile transactions and soft closing. Candidate
intervals/patience/ability sensitivities exist only on fresh memory-only fixture
objects; no JSON catalogs or production scripts are edited. Every profile has
`store == null`; no real save is read or awarded rewards. Synthetic rewards exist
only in these disposable models. The editor development harness is not used.

Seed matrix:

- **1,920 pacing shifts:** 4 models × 4 upgrade stages × 3 input models × 40 seeds,
  417–456. Stage levels are all 0/1/2/3: new / early / mid / max. Early is four of
  twelve purchases, mid is eight. Fixtures are legal endowments at Reputation
  1/2/3/4, not claims of free or affordable upgrades.
- **12,960 team shifts:** all 60 valid active + unordered-support teams × current/B
  × levels 0/2/3 × slow/average/fast × 12 paired seeds, 417–428.
- **960 ability sensitivity shifts:** four small candidates, control/treatment,
  new/max × 3 input models × 20 paired seeds. Separate private roster objects.
- **480 scaling shifts:** B versus intervals ×0.94, new/max × 3 models × 40 seeds.
- **30 current-economy trajectories:** ten seeds per slow/average/fast actor,
  real sequential purchases and Reputation until Level 50, cap 600 shifts.
  **30 candidate-B trajectories** repeat the same strategy and seeds (results below).
The 60 purchase paths contain 11,731 completed shifts in total. Together with
the four fixed experiment sets, this is **28,051 recorded shifts**, including
repeated control conditions; it is not a count of unique parameter/seed pairs.
- Same-process exact record equality and **24 sampled separate-process replays**.
  Bulk data, per-seed tails and CSV comparisons are outside the project.

| Actor | Tap mean | Read + notice | Timing bias / σ | Omit each ingredient | Distraction |
| --- | --- | --- | --- | --- | --- |
| Slow / unfamiliar | 1.8s | 6 + 6s | +0.65 / 1.0s | 15% | 25%; 15–30s |
| Average | 0.85s | 2.5 + 2.5s | +0.20 / 0.45s | 6% | 10%; 8–18s |
| Fast / practiced | 0.45s | 1 + 1s | +0.10 / 0.15s | 1% | 2%; 8–18s |

These are explicit **assumptions, not measured human distributions**. Timing
errors are Gaussian in absolute seconds, clamped to a minimum 0.05s process.
Taps have uniform ±15% jitter. Each order re-seeds behavioral draws so teams share
errors for the same guest. Shift schedules use the production seed/day logic.
The actor reads, accepts, opens the auto-selected station, selects ingredients,
starts/stops, assembles, returns and manually serves. It processes the oldest
arriving guest first, one drink at a time; Back recovery costs a tap. Cat abilities
are automatic, so there is no fictitious ability-button delay.

Order-switch/navigation costs are represented by these taps and notice/read
budgets. The actor does **not** batch-accept multiple orders or strategically
switch drinks mid-preparation. Maximum accepted orders is therefore one even
though up to two guests overlap. This is a model limitation, not a game limit;
the existing UI suite tests independent orders and switching. Extra wrong
ingredients, scrolling distance, motor disabilities, learning and fatigue are
not represented. Slower play is neither a medical nor a demographic label.

Definitions: loss % = unhappy departures / **admitted** guests; skips are separate
unadmitted attempts. Idle is forced waiting with no guest; "busy" includes reading,
reaction and distractions, not just physical inputs. Rush busy uses 120–180s
exactly; occupancy is sampled at ≤1s, so overlap is an approximate diagnostic.
The session clock resolves deadlines/arrivals exactly. All served metrics include
soft closing; duration can exceed 300s. No-loss findings do not establish spare
attention or enjoyment. P10/P50/P90 are seed percentiles, not player-population
confidence intervals. Per-shift means and pooled service tails are distinguished.

## 3. Three candidate pacing models

| Model | Normal seconds | Rush seconds | Patience | Day / Rush / seats |
| --- | --- | --- | --- | --- |
| Current | 25–35 | 10–15 | 60s | 300s / 120–180 / 2 |
| A — Relaxed | 26–34 | 12–16 | 75s | unchanged |
| B — Balanced | 20–26 | 9–12 | 75s | unchanged |
| C — Busy | 16–22 | 7–10 | 60s | unchanged |

There are no supporting recipe, score, price, ability, seat or day-length changes.
75s patience in A/B deliberately gives slower players recovery time rather than
making them fund faster arrivals through mandatory upgrades. Rush duration is
not extended: the existing minute already occupies nearly all average attention
under B. Keeping 60s makes comparison and teaching straightforward.

Default team Mochi/Fade/Max, no upgrades, 40 seeds per row:

| Model / actor | Admitted / skipped | Served mean [P10–P90] | Lost mean / max | Loss % | Idle % | Rush busy % | Coins / Rep XP |
| --- | --- | --- | --- | --- | --- | --- | --- |
| current / low | 8.93 / 3.30 | 6.92 [5.0–8.1] | 2.00 / 6 | 22.4 | 0.6 | 100.0 | 86.3 / 77.8 |
| current / average | 11.68 / 0.55 | 11.68 [11.0–13.0] | 0.00 / 0 | 0.0 | 28.7 | 89.6 | 149.6 / 156.0 |
| current / high | 12.22 / 0.00 | 12.22 [11.0–13.0] | 0.00 / 0 | 0.0 | 57.6 | 71.9 | 159.1 / 180.1 |
| A / low | 8.88 / 3.10 | 8.15 [7.0–9.0] | 0.72 / 3 | 8.2 | 0.0 | 100.0 | 101.5 / 90.7 |
| A / average | 11.85 / 0.12 | 11.85 [11.0–13.0] | 0.00 / 0 | 0.0 | 28.0 | 88.5 | 151.6 / 158.4 |
| A / high | 11.97 / 0.00 | 11.97 [11.0–13.0] | 0.00 / 0 | 0.0 | 58.5 | 64.6 | 155.9 / 176.4 |
| B / low | 9.00 / 6.78 | 7.97 [6.9–9.1] | 1.02 / 4 | 11.4 | 0.0 | 100.0 | 99.3 / 88.9 |
| B / average | 14.55 / 1.23 | 14.55 [14.0–15.0] | 0.00 / 0 | 0.0 | 12.6 | 96.6 | 187.0 / 196.2 |
| B / high | 15.70 / 0.07 | 15.70 [15.0–16.0] | 0.00 / 0 | 0.0 | 45.6 | 86.0 | 204.5 / 232.1 |
| C / low | 9.72 / 9.65 | 6.10 [4.0–8.0] | 3.62 / 6 | 37.3 | 0.1 | 100.0 | 75.7 / 68.4 |
| C / average | 16.30 / 3.08 | 16.30 [15.0–17.0] | 0.00 / 0 | 0.0 | 3.1 | 98.8 | 209.7 / 219.2 |
| C / high | 18.82 / 0.55 | 18.82 [18.0–19.0] | 0.00 / 0 | 0.0 | 34.8 | 91.8 | 244.9 / 278.2 |

Balanced raises average service from 11.68 to 14.55 (+24.6%) and reduces forced
idle from 28.7% to 12.6%. No average or fast losses occurred in these 40-seed
reference groups, including Busy. That is an observed model outcome, **not** a
zero-loss guarantee for real players. B's slower actor loses 11.4% versus current
22.4%; Relaxed is gentler still at 8.2%. Busy loses 37.3% for that same actor.
Full seats suppress admissions for slower play; quoted lost counts must not hide
its reduced opportunity to earn Coins.

### Tail risk and Rush

| Model / actor | Mean wait | Individual wait P90 | Individual patience P10 / min | Two-guest overlap % | Mean final duration |
| --- | --- | --- | --- | --- | --- |
| current / low | 50.5 | 63.1 | 4.3 / 0.05 | 42.5 | 335.3 |
| current / average | 21.3 | 30.7 | 32.3 / 19.64 | 9.0 | 307.2 |
| A / low | 56.5 | 72.2 | 10.4 / 1.09 | 48.9 | 345.9 |
| A / average | 20.9 | 30.2 | 48.5 / 33.39 | 7.9 | 308.5 |
| B / low | 59.8 | 74.1 | 8.2 / 0.06 | 59.3 | 348.1 |
| B / average | 22.7 | 33.1 | 45.6 / 29.30 | 17.2 | 312.9 |
| C / low | 54.8 | 65.6 | 2.4 / 0.25 | 64.0 | 347.5 |
| C / average | 25.1 | 34.7 | 28.3 / 1.78 | 30.7 | 316.2 |

A new slow player can lose four admitted guests in B's worst sampled shift;
individual successful services can have only 0.06s patience left. More patience
helps but does not make every shift forgiving. Busy reaches six losses and
near-continuous overlap for slow play. These are meaningful sampled extremes,
not mathematical worst cases. A sufficiently long distraction can lose both
waiting customers under any model.

B's average Rush occupancy is 97% of attention versus 86% for fast play and 100%
for slow play. Its average two-guest overlap is 17%, rising to about 59% for slow
play. "Manageable Rush" therefore needs hands-on validation; high busy time can
include a simulated distraction. Empty seats remain available after expiration.
The phase boundary resets can create a lull just before/after Rush: no artificial
burst of queued guests is added here.

The 40-seed new-player means are stable enough to distinguish the large model
changes: first/last 20-seed average-service means differ by at most 0.30 guests
(current 11.55/11.80; B 14.40/14.70). Slow Busy differs 5.8/6.4 served, showing
larger variance; small cat differences should not be treated as settled rankings.

## 4. Experience, upgrades and optional scaling

Balanced, default team, all four stages (40 seeds each):

| Upgrade stage / actor | Served / lost | Idle % | Mean wait / patience left | Timed preparation seconds | Duration |
| --- | --- | --- | --- | --- | --- |
| New (0) / low | 7.97 / 1.02 | 0.0 | 59.8 / 23.4 | 35.6 | 348.1 |
| New (0) / average | 14.55 / 0.00 | 12.6 | 22.7 / 56.1 | 54.4 | 312.9 |
| New (0) / high | 15.70 / 0.00 | 45.6 | 10.9 / 67.9 | 57.6 | 304.1 |
| Early (1) / low | 8.03 / 0.95 | 0.0 | 59.9 / 25.5 | 35.1 | 348.3 |
| Early (1) / average | 14.57 / 0.00 | 12.9 | 22.5 / 58.5 | 53.1 | 312.8 |
| Early (1) / high | 15.72 / 0.00 | 46.0 | 10.8 / 70.2 | 56.1 | 304.0 |
| Mid (2) / low | 8.38 / 0.60 | 0.0 | 60.8 / 26.7 | 34.8 | 348.4 |
| Mid (2) / average | 14.60 / 0.00 | 13.2 | 22.4 / 60.9 | 51.8 | 312.6 |
| Mid (2) / high | 15.72 / 0.00 | 46.5 | 10.7 / 72.6 | 54.7 | 304.0 |
| Max (3) / low | 8.40 / 0.62 | 0.0 | 60.8 / 28.8 | 34.4 | 350.4 |
| Max (3) / average | 14.60 / 0.00 | 13.5 | 22.2 / 63.3 | 50.5 | 312.5 |
| Max (3) / high | 15.72 / 0.00 | 46.9 | 10.5 / 75.0 | 53.3 | 303.9 |

There is no unavoidable five-minute/two-seat problem in these models. Purchasing
upgrades does **not** suddenly eliminate challenge: slow players still wait and
lose customers; average service barely changes. Max upgrades mainly improve
quality, comfort and a few seconds of process time. Under B, average total timed
preparation falls from 54.4 to 50.5s/shift; human/navigation work dominates.
Fast maxed play still has 46.9% forced idle under B (current 58.7%). This may be a
pleasant reward for mastery, not necessarily something to eliminate.

Maximum production speed stack is Fade active + Max passive + Equipment:
`1 + .20 + .05 + .09 = 1.34`, turning a 3s target into 2.24s. Maximum starting
patience is `base×(1+.05+.09)`: current 68.4s, B 85.5s. Mochi restores 10% of that
original when eligible. These are bounded, not unbounded stacking. Faster targets
also make a fixed absolute reaction error a larger fraction of the timing window;
speed is not automatically a quality benefit. Patience does not undo ingredient
mistakes or prevent all long-interruption losses.

**Optional, not recommended for initial implementation:** progression-aware
interval multiplier `f(L)=1` for Level 1–9, `.97` for 10–24, `.94` for 25–50.
Apply `f` once at shift start to B's normal and Rush intervals, with patience
unchanged. Maximum interval reduction 6% (frequency increase 6.38%). At Level 25:
18.80–24.44s normal, 8.46–11.28s Rush. No scaling by current Coins, equipped cats
or recent failures. Existing Reputation is sufficient; no save field/migration
is needed, but returning high-level players would encounter the new rate.

| Fixture upgrade / actor | Δ served | Δ lost | Δ idle points | Δ Coins |
| --- | --- | --- | --- | --- |
| 0 / low | -0.175 | +0.125 | +0.00 | -2.17 |
| 0 / average | +0.325 | +0.000 | -3.01 | +4.45 |
| 0 / high | +0.900 | +0.000 | -3.63 | +11.82 |
| 3 / low | -0.025 | -0.025 | +0.01 | -0.40 |
| 3 / average | +0.350 | +0.000 | -3.07 | +4.95 |
| 3 / high | +0.875 | +0.000 | -3.43 | +11.82 |

These are 40 paired seeds per row at the **maximum** .94 factor, including an
unupgraded sensitivity fixture to assess late-level players who did not buy
upgrades. Expected gain is small for average play; slow cohorts see negligible or
negative benefit. A player could deliberately avoid Reputation gains, but completed
service awards XP automatically; the bigger concern is punishing progress with
hidden pressure. Upgrade-based scaling would encourage delaying purchases, so it
is less suitable. Keep static B until observed play justifies an opt-in or clearly
communicated mastery change. No scaling is implemented.

## 5. Long-term economy — actual purchases

Ten seeds per input model, current pacing, starting Coins 120, default team.
Before every shift the strategy buys the cheapest eligible next upgrade, then all
six regular decorations once upgrades are maxed. Quotes, exact Coins and unlocks
use the real profile purchase API. It continues until Level 50; none of the
600-shift limits were reached. Repeated simulated days preserve fractional tips,
Reputation and purchases. Lottery rolls and manual seasonal claims are excluded
from this **service-only** purchase trajectory; the injected UTC clock is fixed.
Those reward sources are evaluated separately below, not silently added.

| Actor | All upgrades mean [min–max] | All regular decor | Level 50 mean [min–max] | Coins left at Level 50 | Carry Coins paid |
| --- | --- | --- | --- | --- | --- |
| low | 17.8 [16–20] | 19.9 | 321.9 [315–329] | 27,718 | 415.6 |
| average | 10.7 [10–11] | 11.8 | 168.0 [166–170] | 24,368 | 395.1 |
| high | 10.0 [10–10] | 11.1 | 150.4 [149–152] | 23,122 | 389.4 |

| Actor / completed shifts | Coin balance | Reputation level | Cumulative carry Coins |
| --- | --- | --- | --- |
| low / 25 | 501.7 | 11.9 | 26.0 |
| low / 50 | 2,781.3 | 17.8 | 58.4 |
| low / 100 | 7,317.9 | 26.6 | 123.4 |
| average / 25 | 2,136.8 | 17.8 | 53.8 |
| average / 50 | 6,036.6 | 26.0 | 113.1 |
| average / 100 | 13,788.9 | 37.7 | 232.9 |
| high / 25 | 2,389.6 | 18.9 | 59.6 |
| high / 50 | 6,534.3 | 27.8 | 125.6 |
| high / 100 | 14,812.2 | 40.0 | 257.4 |

Coins become unusable for **new current shop purchases** after the six regular
decorations are owned. They retain future spending value, but no repeatable Coin
sink currently exists. Cosmetics are lottery/season rewards, not a Coin shop.
Accumulation alone is not a defect; it can provide a relaxed sense of security.
The 11-versus-168 gap is primarily **content horizon**, not inadequate income.

Step 13A's carry directly pays about 395 Coins over the average trajectory to
Level 50 (roughly 2.35 Coins/shift), alongside unchanged whole tips and Odin
premium rules. It now has measurable value but cannot solve the spending horizon.
This is actual carry payout, **not** a separately replayed old-price purchase
trajectory: removing those Coins could shift purchase timing. Fixed-stage scans
start with zero remainder, so at most one unconverted Coin remains per independent
shift; persistent economy trajectories do not reset that fraction.

### Casual / regular / dedicated schedules

Activity frequency and preparation skill are separate axes. At 3 / 7 / 14 shifts
per week, the same completed-shift trajectory maps to these calendar horizons;
weekly/day challenge outcomes and manual reward claims are not assumed identical.

| Skill | Casual 3/week: upgrades / L50 days | Regular 7/week: upgrades / L50 days | Dedicated 14/week: upgrades / L50 days |
| --- | --- | --- | --- |
| low | 42 / 752 | 18 / 322 | 9 / 161 |
| average | 25 / 392 | 11 / 168 | 6 / 84 |
| high | 24 / 351 | 10 / 151 | 5 / 76 |

These are expected elapsed-day approximations, not login scheduling guarantees.
For example, the lower-quality slow regular actor reaches Level 50 around day
322; the fast actor around day 151. The average dedicated actor is about 84 days,
not eight weeks. Lower quality and fewer services reduce Reputation more than
they reduce base-price Coin earnings. A longer Coin grind would disproportionately
burden that cohort.

### Candidate B economy coupling

| Actor | Current upgrades / L50 shifts | B upgrades / L50 shifts | B Coins left at L50 |
| --- | --- | --- | --- |
| low | 17.8 / 321.9 | 15.4 / 280.7 | 27,775 |
| average | 10.7 / 168.0 | 9.0 / 135.8 | 24,372 |
| high | 10.0 / 150.4 | 8.0 / 116.3 | 23,159 |

These are another **30 actual purchase trajectories**, ten seeds per actor, with
only B's fixture pacing/patience changed. Average Level 50 moves from 168 to
135.8 shifts (−19.2%); upgrades finish after 9 rather than 10.7. Remaining Coins
are nearly the same because the total Reputation target still requires similar
numbers of paid services. Faster arrivals alone do not create new Coin uses.
The recommendation intentionally separates pacing approval from Coin spending.
None of the candidate-B 600-shift caps were reached.


### Lottery and seasonal Coin sources

These are exact reward-policy expectations, not invented prize probabilities:

| Collection state | Expected Coins per lottery roll | Expected Coins per 1,000-XP cycle prize (ticket excluded) |
| --- | --- | --- |
| No regular items owned | 250 | 500 |
| All six regular decorations, no cosmetics | 370 | 625 |
| All regular cosmetics and decorations | 490 | 750 |
| All regular and eligible exclusive items | 510 | 750 |

Lottery regular duplicates fall back to 500; exhausted exclusive draws give
1,000. Cycle rewards choose unowned regular items, falling back to 500 when that
collection is exhausted. Each cycle also grants a ticket. With all pools exhausted,
one cycle prize **plus spending its ticket** averages **1,260 Coins**. In other
states, collection grants alter subsequent roll odds, so the separate columns
should not simply be added as an exact joint expectation. Welcome is one ticket
once at Level 50. No Coins buy tickets in the current design.

Season milestones explicitly grant 250+500+750 = **1,500 Coins** at tiers 5/20/35.
The other seven milestones grant items; owned unique duplicates pay 500 each.
If every milestone item is already owned, claiming a full track yields 5,000 Coins
including fallbacks. The prototype repeats its catalog; this does not promise new
seasonal art. Current 200/150/500 rates give 23,600 XP at 56 days + 56 dailies +
eight weeklies; first 2,500-XP milestone needs about 6–8 completed days with regular
challenge completion, **not** a guaranteed exact login day. The seven extra shifts
for Tier 50 remain unchanged. Manual claims, existing receipts and Inbox behavior
are preserved. More rewards increase surplus rather than creating Coin demand.

## 6. Three economy options

| Option | Exact candidate scope | Motivation / sustainability | Cost and risk |
| --- | --- | --- | --- |
| A — preserve | Current costs, 3 levels, rewards unchanged | Fast early completion and savings; new content could use existing Coins later | Lowest code cost. With no content plan, shop has no long-term purchases after ~12 average shifts |
| B — extend upgrades | Prototype levels 4/5 per category: 600/1,200 Coins, Reputation 10/20; diminishing effects below | Adds 7,200 Coins of purchasing goals, still finite | Medium catalog/UI/save validation work; weak increments may feel poor and more power narrows room for skill |
| C — non-power collections (recommended) | Future 4 regular cosmetics at 300/600/900/1,200; 4 regular decor at 600/900/1,200/1,500; corresponding Reputation gates 5/10/15/20 | 7,200 Coins of optional choice without changing café difficulty; new sets extend duration | Needs a regular-item shop route and ongoing content. Unique purchases are finite; art/content cost is real |

Option B's proposed **additional** per-level effects: +1% preparation speed,
+1% starting patience, +1 quality point, +1% ordinary-tip bonus amount. Thus caps
would become Equipment/Seating 11%, quality +8, Training 17%, instead of 9/9/+6/15.
The existing constant-per-level catalog would need extension to express diminishing
levels; do not silently multiply current values into levels 4/5. Cat percentages,
recipes and the 74 cap stay fixed. With Max support, a 3s process changes from
`3/1.14=2.632s` to `3/1.16=2.586s` (only 0.045s gained). At B patience, two extra
seating levels add 1.5s. This is unlikely to justify 1,800 Coins per category to
every player. The budget buys roughly 46 current-max average shifts' gross income,
or 37 at B; these are price/income estimates, **not simulated purchases of new
levels**. Reputation gates 10/20 occur well before Level 50; simply extending
prices does not bridge the whole horizon.

Option C's eight proposed regular items likewise cost 7,200 in total, without
power or exclusive rewards. They must use the existing ownership inventory;
seasonal/lottery exclusives remain unavailable for Coin purchase. Do not sell
lottery tickets or introduce premium currency. An eight-item set per 56-day
content cycle would absorb about 7,200 Coins **only if** a player wants every
item; casual players can choose a subset. Replenished content, not forced
consumption or balance resets, determines sustainability. The recommendation is
C as a future content/shop scope, keeping existing costs until separately approved.

## 7. Six-cat effectiveness and diversity

All current values are retained:

| Cat | Passive | Active (30s qualifying cooldown) |
| --- | --- | --- |
| Mochi | +5% starting patience | Below 30%, restore 10% original patience, one crossing per guest |
| Fade | +5% ordinary tip amount | +20% preparation speed for this draft |
| Momo | +5 quality points | +15% timing forgiveness for this draft |
| Odin | +5% ordinary tip amount | Separate 15% base-price premium on Excellent/Perfect service |
| Max | +5% preparation speed | +15% preparation speed for this draft |
| Blaze | +5 quality points | Complete Excellent -> Perfect at 95 |

The 60 teams are all 6 active choices × C(5,2) supports. Support order is
irrelevant; cats are unique. Only the active ability can fire. Cooldown is shared
among that active cat's events, not three independent team abilities. Interrupted
preparation can consume a qualifying speed/precision activation without producing
a drink. Mochi's missed threshold crossing during cooldown is not queued. Blaze
cannot convert incomplete drinks after Step 13A.

### Rankings, with identical 12 seeds per team

Selected objective leaders under B; tied teams exist, so these are examples rather
than unique winners. Columns list active first. The CSV contains all 1,080 groups.

| Upgrade / actor | Income leader example | Coins | Reputation leader example | Rep XP |
| --- | --- | --- | --- | --- |
| 0 / low | Odin / Mochi, Momo | 98.08 | Mochi / Momo, Blaze | 95.08 |
| 0 / average | Odin / Fade, Momo | 196.00 | Mochi / Momo, Blaze | 206.92 |
| 0 / high | Odin / Mochi, Fade | 213.67 | Mochi / Fade, Momo | 231.42 |
| 2 / low | Odin / Mochi, Momo | 106.75 | Mochi / Momo, Max | 103.50 |
| 2 / average | Odin / Fade, Momo | 201.58 | Mochi / Momo, Blaze | 206.92 |
| 2 / high | Odin / Fade, Max | 220.42 | Mochi / Fade, Momo | 231.42 |
| 3 / low | Odin / Mochi, Fade | 108.17 | Mochi / Momo, Blaze | 102.58 |
| 3 / average | Odin / Fade, Momo | 202.17 | Mochi / Fade, Momo | 206.92 |
| 3 / high | Odin / Mochi, Fade | 221.25 | Mochi / Fade, Momo | 231.42 |

Current pacing's new average income leader is Odin/Fade/Momo (or Blaze),
153.83 Coins, versus 196.00 in the B team scan. Current new slow Reputation leader
is Mochi/Momo/Blaze, 84.58 XP, versus 95.08 in B. Different objectives have different
leaders; no universal dominant team was established. These 12-seed means should
not be mixed with the 40-seed default-team reference as a precisely paired effect.

### Every active role, controlling the same three passives

For each cat, compare it active against the mean of the other two active choices
for each identical equipped set, then average its ten support sets. This isolates
role opportunity cost better than comparing unrelated top teams. Negative deltas
can mean another active cat (especially Odin) was useful, not a broken ability.

| Active cat | New average Δ Coins / Rep | New slow Δ served / Rep | Activations average / slow |
| --- | --- | --- | --- |
| Mochi | -1.75 / +0.31 | +0.32 / +3.48 | 0.00 / 4.85 |
| Fade | -1.83 / -0.80 | -0.01 / -2.27 | 7.75 / 8.12 |
| Momo | -1.78 / +0.12 | -0.13 / -0.53 | 7.75 / 7.92 |
| Odin | +8.95 / +0.31 | -0.13 / -1.92 | 7.50 / 4.95 |
| Max | -1.81 / -0.53 | +0.09 / -1.04 | 7.75 / 8.13 |
| Blaze | -1.78 / +0.57 | -0.13 / +2.28 | 0.15 / 1.28 |

Mochi is a genuine safety choice for slow play, not an average-player throughput
bonus; normal average service never reaches its threshold in this matrix. Odin
is the clearest income leader even with fractional passives fixed. Fade/Max speed
activations are frequent, but the 3–5s timed step is a small share of human work.
Momo's precision can fire often without moving the final tier. Blaze fires only
about 0.15 times in new average B and 0.02 at max, versus about 1.28 / 0.45 for
slow play. Incomplete drinks now cap at Good, while complete skilled drinks often
already become Perfect through passives/upgrades; both reduce Blaze's valid window.
An emergency or conditional ability need not trigger on every shift to be valid.

### Every passive support, holding active and the other support fixed

Replace each cat with the mean of the three other valid choices, average the
20 active/partner contexts; 12 paired seeds per team. These are marginal
tradeoffs against alternatives, **not** solo-cat rewards or independent effects.

| Support | Average Δ Coins | Average Δ Rep | Slow Δ served | Slow Δ Rep |
| --- | --- | --- | --- | --- |
| Mochi | -0.45 | -1.65 | +0.08 | -0.94 |
| Fade | +0.71 | -1.54 | -0.01 | -1.48 |
| Momo | -0.25 | +3.42 | +0.00 | +3.06 |
| Odin | +0.70 | -1.65 | +0.00 | -1.43 |
| Max | -0.45 | -2.15 | -0.08 | -2.69 |
| Blaze | -0.25 | +3.57 | +0.00 | +3.48 |

Momo and Blaze have identical +5 passives; support ties are expected, not a new
bug. Fade and Odin also share +5% ordinary-tip passives. These now retain fractional
value, but 5% of a small **tip** remains much smaller than 5% of the drink price.
At max upgrades, skilled actors' quality largely saturates, reducing the marginal
value of quality/precision. With absolute-second timing error, shorter targets can
slightly lower raw quality, so a speed cat does not dominate every cohort. Do not
interpret this assumed error model as proof that humans dislike faster equipment.
Patience cannot create extra seats or bypass a missed ingredient; the strongest
teams did not remove all slow-player losses. More overlapping demand alone will
not make every ability equally valuable.

## 8. Cat changes considered, not implemented

Paired B sensitivity: 20 seeds, support team Momo/Blaze (Mochi uses Momo/Max),
new and max upgrades, each input model. The CSV includes every condition.

| Current | Candidate | New average Δ served / Coins / Rep | Max slow Δ served / Coins / Rep |
| --- | --- | --- | --- |
| Fade +20% speed | +25% | +0.00 / +0.00 / -0.15 | +0.00 / +0.00 / +0.00 |
| Max +15% active speed | +20% | +0.00 / +0.00 / -0.15 | +0.00 / +0.00 / +0.00 |
| Mochi restore 10% | 15% | +0.00 / +0.00 / +0.00 | +0.25 / +3.15 / +3.40 |
| Odin premium 15% | 20% | +0.00 / +5.70 / +0.00 | +0.00 / +4.15 / +0.00 |

- **Fade / Max:** roughly one second less timed processing per new average shift,
  zero service gain; −0.15 XP in that fixture. Slow new fixtures lose 0.15 more
  customers on average. No demonstrated gain in team diversity; reject these
  buffs for now. A hands-on check of absolute versus relative timing tolerance is
  needed before any preparation-speed change.
- **Mochi:** 10% -> 15% has no new average benefit; max slow gains 0.25 service and
  3.4 XP in this 20-seed sensitivity. It extends an existing emergency role, but
  may further privilege the safest team and delay soft closing. Hold current
  value until slow-play testing confirms a remaining need after B's 75s patience.
- **Odin:** 15% -> 20% adds 5.7 Coins/new average shift with no throughput or XP
  benefit. It strengthens an already leading income choice and reduces diversity;
  reject. No nerf is justified solely by having an intended income specialist.
- **Momo:** retain +5 quality / 15% forgiveness. Frequent activations but small tier
  changes suggest feedback and saturation questions, not sufficient evidence for
  a numeric buff. Test its feel with correct and imperfect timing first.
- **Blaze:** retain +5 quality and complete Excellent ->95. Its post-13A rarity
  does not justify bypassing ingredient rules or forcing a promotion on every
  drink. Test a naturally Excellent complete recipe with the ability ready before
  considering any separate, explicitly approved tuning.

All six recommendations preserve identity and require no new abilities. Any later
numeric proposal must retain the ingredient cap, cooldown contract, ordinary-tip
carry and premium separation. No fixture-only sensitivity is a recommended
production edit by default.

## 9. Player experience and accessibility

**Confirmed by code and existing regression suites:** order screen lists recipe,
ingredients, numeric patience and final score/tier; timed station shows target,
progress and live stopping time; customer captions identify independent orders;
Rush uses text as well as a color change. Automatic ability availability/cooldown
is shown. Back cancels drafts; expired orders award nothing; team/shop/claims are
view-only during shifts. Settings preserves focus and continues deadlines.
The first-time lobby and "tap a guest" feedback exist. Core input/layout suites
pass at 720×1280 and 320×568, with foundation checks on eight viewport sizes.

**No urgent integration defect was confirmed.** The first audit-actor prototype
omitted Back recovery after an expiration; this produced an invalid auto-station
assertion. That was a bug in new audit tooling, fixed before recorded runs. It is
not evidence that the player UI traps navigation. No production fix was made.

Usability concerns requiring actual players, not declared defects:

1. Rush is announced when the phase changes; no advance warning is implemented.
   Candidate: one text warning at 110s elapsed (10s before Rush), no timing or
   reward change. Could help unfamiliar players, but must not add alarming clutter.
2. Read/choose/stop/assemble/serve may be hard to learn from labels alone.
   Candidate: one first-order checklist or clearer action hint, no extra mandatory
   taps. Test time-to-first-service and incorrect-next-action rate before designing.
3. A correct target is the process meter midpoint, not its far edge. Candidate:
   labeled target marker and clear final Good explanation after a missing
   ingredient; no wider window or scoring change. Verify comprehension first.
4. Settings does not pause the shift. Interruptions can cost customers even while
   reading menus; this is established behavior, not a timer defect. If players
   need a separate relaxed/accessibility mode, it needs its own approval and fair
   reward policy; do not quietly pause this build.
5. Normal/fast small-screen input passes simulated tests, but finger occlusion,
   scroll friction, hand fatigue, reading speed, safe areas and screen readers
   are not established. Existing text sizes/targets are necessary, not sufficient.

Suggested observed-play checklist: first shift without coaching at 320×568;
ask players to locate a pending order, explain the timing target, recover after
an expired drink, notice Rush and identify an ability activation. Compare A/B on
lost customers, perceived pressure and enjoyment. Do not infer those subjective
outcomes from simulated busy percentages.

## 10. Prioritized decision matrix

| Model | Main advantage | Main disadvantage | Recommendation |
| --- | --- | --- | --- |
| A Relaxed | Slow losses 8.2%; comfortable patience; average ~28% idle | Fast players still ~59% idle, little engagement gain over current | Choose if low pressure outranks reducing downtime |
| B Balanced | Average 14.55 served, ~13% idle; slow loss reduced to 11.4% | Slow play remains fully occupied; Rush ~97% average busy; faster progression adds Coin surplus | Recommended hands-on prototype; keep 300s/2 seats/60s Rush |
| C Busy | Fast players ~18.8 served, optimization opportunities | Slow loss 37.3%; average only ~3% idle; poor cozy default | Do not use as default |

Approval decisions, in order:

1. **Pacing:** approve static B (20–26 / 9–12 / 75) or A (26–34 / 12–16 / 75)
   for implementation/playtest. Do not approve a value merely because B is listed
   first; slow-player comfort remains unresolved without human testing.
2. **Economy:** approve future Option C regular-only catalog/shop scope and its
   7,200-Coin prototype budget, or explicitly keep A. Existing upgrade costs and
   rewards stay as shipped. B's extra power levels are not recommended.
3. **Cats:** keep current numbers. The tested four numeric candidates are not
   recommended wholesale; any future Mochi adjustment needs targeted testing.
4. **Scaling:** defer the .97/.94 formula; no automatic difficulty increase now.
5. **Accessibility:** separately approve only the warning/checklist/target-marker
   experiments wanted after observation. No UI implementation is part of this audit.

Seasonal XP, completeness scoring/cap, Blaze eligibility, fractional tips, lottery
probabilities and official artwork are outside the approval choices for this step.

## 11. Validation, safeguards and reproduction

| Suite | Passed |
| --- | --- |
| Step 13A corrections | 523 |
| Persistence | 196 |
| Shop | 496 |
| Lottery / Collections | 587 |
| Seasons / Challenges / Inbox | 629 |
| Cats | 259 |
| Drinks | 1,111 |
| Café day | 62 |
| Gameplay UI | 430 |
| Full integration | 656 |
| Foundation | 8 viewports |

All eleven existing headless suites passed in Godot 4.6.3. Profile paths are
isolated under `/tmp`, with isolated XDG data/config/cache. No production fix or
assertion weakening was used to obtain passes. Tests cover mouse, keyboard,
simulated touch, Settings focus, orders, profile integrity and the eight foundation
viewports (320×568 through 1920×1080). Native graphical/browser/physical-device
playtesting was not run in this task; the current machine has no X display.
Earlier native evidence in Step 13A is historical, not a new result.

Recorded balance runs preserve service accounting and the ingredient cap, bound
occupancy to two seats, require every admitted customer to finish or expire,
assert isolated storage and reproduce seeded outputs. The smoke run covers 48
complete shifts; separate-process replay covers 24 complete records. Three invalid
path/model inputs were deliberately rejected with nonzero exits; these expected
guard failures created no outside output. There are
no test failures remaining or confirmed pre-existing failures. Initial new-tool
failures were corrected and their incomplete runs discarded before saved results.

Reproduce from the project root (set isolated XDG directories first):

```sh
export XDG_DATA_HOME=/tmp/paw-13b-run/data
export XDG_CONFIG_HOME=/tmp/paw-13b-run/config
export XDG_CACHE_HOME=/tmp/paw-13b-run/cache
godot --headless --path . --editor --import --quit
godot --headless --path . --script Tools/analyze_cafe_13b.gd -- --out=/tmp/paw-13b-run --smoke
godot --headless --path . --script Tools/analyze_cafe_13b.gd -- --out=/tmp/paw-13b-run
godot --headless --path . --script Tools/analyze_cafe_13b.gd -- --out=/tmp/paw-13b-run --economy
godot --headless --path . --script Tools/analyze_cafe_13b.gd -- --out=/tmp/paw-13b-run --economy --economy-model=B
godot --headless --path . --script Tools/analyze_cafe_13b.gd -- --out=/tmp/paw-13b-run --scaling
godot --headless --path . --script Tools/analyze_cafe_13b.gd -- --out=/tmp/paw-13b-run --replay
python3 Tools/summarize_cafe_13b.py --input /tmp/paw-13b-run
```

Run each `Tools/validate_*.gd` with the same headless Godot command. The integration
and balance suites also support their documented separate-process cold-read mode.
All tooling is in the existing `Tools/*` Web export exclusion. Production scenes
never reference the new scripts. JSON/CSV bulk output stays outside the checkout
under `/tmp`; a portable evidence bundle is retained at
`/workspace/paw-pads-balance-review/step-13b/`.

## 12. Files and limitations

Added only:

- `Tools/analyze_cafe_13b.gd` and its Godot UID: isolated production-session actor,
  model/team matrices, sensitivity, scaling and real purchase trajectories.
- `Tools/summarize_cafe_13b.py`: stdlib summary statistics, CSV and paired role /
  support contrasts; no production mutation.
- `Docs/CafeBalance13B.md`: this assessment and approval choices.

All **173 original repository files** matched their starting SHA-256 hashes.
The preservation manifest is included in the bundle.
No existing repository file is modified. No gameplay proposal is implemented.
No commits or pushes.

These simulations establish behavior under explicit assumptions, not enjoyment,
empirical player skill, statistical universality or live-service security. They
exclude strategic batching, wrong extra ingredients, multi-device input latency,
learning, fatigue, voluntary breaks, optional reward-claim behavior and infinite
content demand. Independent fixture shifts reset fractional remainder; long-run
purchase trajectories retain it. A fixed UTC clock intentionally isolates service
economy from seasonal claims. Candidate additions to upgrade/content catalogs are
price/effect estimates, not implemented inventory or transaction features. Rare
tails beyond 40 seeds and real interruptions remain possible. Hands-on A/B
playtesting is the next evidence needed before final balance approval.
