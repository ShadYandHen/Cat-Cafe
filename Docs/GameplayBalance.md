# Gameplay balance and player experience audit — Step 12

> Historical Step 12 balance audit evidence. Current Seasonal XP, quality caps, tip settlement
> and schema 5 behavior are documented in [Step 13A corrections](BalanceCorrections13A.md).

**Audit only. No production values, scenes, artwork or player saves were changed.**
All existing uncommitted Steps 10B–11 work is preserved. Recommendations below
require design approval; no commits or pushes were made.

## Evidence and reproducibility

The audit uses the actual Godot 4.6.3 `CafeSession`, order state transitions,
`DrinkQuality`, profile transactions, cat roster and shop catalogs. Temporary
profiles are in-memory only (`store == null`), with an injected UTC clock.
`balance_session_probe.gd` observes arrival attempts/admissions without changing
`super` behavior. Audit tools live in the already export-excluded `Tools/` folder.
Raw output and CSVs stay outside the checkout under `/tmp/paw-balance-step12`;
review copies are retained at `/workspace/paw-pads-balance-review/step-12`.

- **3,880** recorded seeded shifts: 1,440 reference trials, 2,400 team-scan trials,
  and 40 level-1 upgrade trials. There are **3,640 unique** condition/seed pairs;
  overlapping reference/scanning trials are de-duplicated for statistics.
- Reference matrix: six teams × upgrade levels 0/2/3 × four input models ×
  20 seeds (417–436). Team scan: all **60** active + unordered-support combinations,
  average/low models, upgrades 0/3, ten paired seeds (417–426). Rankings use only
  those common ten seeds, including for reference teams.
- Two full-record replays match exactly. Twenty sampled trials also reproduce
  exactly in a **separate process**.
- **512,000** paired point-scoring evaluations: eight recipes × four skill models ×
  eight bonus/ability variants × 2,000 error samples. **144** exact integer-tip
  cases and 56 actual UTC challenge-day definitions are exported.
- **60** multi-day economy trajectories purchase through real Coin/unlock APIs,
  with independent day seeds and a 60-day cap. None was censored.
- P10/P50/P90 are descriptive seed percentiles, not confidence intervals or player
  population estimates. Cat/upgrade effects are model-dependent, not measured
  human preferences.

Reproduce from the repository root:

```sh
godot --headless --path . --script Tools/analyze_balance.gd -- --out=/tmp/paw-balance-step12
godot --headless --path . --script Tools/analyze_quality.gd
godot --headless --path . --script Tools/analyze_balance.gd -- --out=/tmp/paw-balance-step12 --economy
godot --headless --path . --script Tools/analyze_balance.gd -- --out=/tmp/paw-balance-step12 --replay
python Tools/summarize_balance.py --input /tmp/paw-balance-step12
```

The main sampler restricts output to `/tmp`; quality output is fixed there.
No real save is opened, no rewards go to real profiles, no gameplay runtime or
export setting is changed. The previously implemented development harness is
not needed for this audit.

## 1. Current baseline, checked against code/data

Sources: `Scripts/Gameplay/cafe_session.gd`, `drink_quality.gd`, `cat_team.gd`,
`Scripts/Persistence/cafe_profile.gd`, `Data/Recipes/drinks.json`,
`Data/Cats/roster.json`, `Data/Cafe/*.json`, `Data/Seasons/pass.json`,
`golden_paw_rewards.gd` and `season_catalog.gd`. Earlier documents are historical
context, not assumed authoritative.

| System | Current value |
|---|---|
| Starting profile | 120 Coins; Level 1; 0 XP; Mochi active, Fade/Max support |
| Shift | 300.0 seconds; opening 0–120, Rush 120–180, late service 180–300 elapsed |
| Arrivals | Normal 25–35s; Rush 10–15s |
| Capacity | 2 seats; first guest immediately; full-seat arrival attempts are skipped, not queued |
| Patience | 60.0s base, modified at arrival; continues across all screens |
| Closing | No admissions at 300s; finish/expire remaining guests before results |
| Recipes | 8; 3 steps each: select ingredients, timed process, assemble; manual service |
| Quality | 0–49 Okay; 50–74 Good; 75–94 Excellent; 95–100 Perfect |
| Scoring | 50 ingredient points + 35 timing points + 15 completion points; round, add bonuses, clamp, then Blaze |
| Quality tips / XP | 0/5/10/15% of base price; 5/8/12/15 Reputation XP |
| Money | floor(base × quality_tip_rate × (1 + ordinary_tip_bonus)); Odin separately floors 15% of base |
| Cats | Active + 2 unique supports; all passives; only active ability; 30s cooldown; fresh each day |
| Reputation | 75 + 20×(L−1), Levels 1–50; 27,195 total XP to Level 50 |
| Level 50 | Welcome ticket once; each 1,000 XP gives one ticket plus one separate cycle reward |
| Season | 56 UTC days; 50 tiers × 500 XP = 25,000; day/daily/weekly awards 50/50/200 |
| Season rewards | Milestones 5,10,…50; exclusives 40/45/50; manual claims; Inbox never expires |
| Calendar | Anchor 2026-10-17 UTC; daily midnight; weekly Monday UTC; clipped at season bounds |
| Lottery | Level 50 unlock; 50% 500 Coins / 24% cosmetic / 24% decoration / 2% exclusive; no pity |
| Cycle prize | 50% 1,000 Coins / 25% unowned regular cosmetic / 25% unowned regular decoration; exhaustion 500 Coins |

Recipe selection is **not independent random sampling**: the implementation rotates
through `(order_id - 1 + schedule_seed) % 8`. Arrival intervals are seeded random.
Phase changes reset the next-arrival timer, rather than keeping the previous
phase's scheduled arrival. These details explain a roughly 11–13-guest ceiling
under fast play; an interval-only Poisson model would overestimate demand.

The current catalogs agree with the latest Step 9–11 descriptions. Step 8's
reserved/deferred reward language and older schema numbers in historical sections
are not current runtime behavior. Other easily misunderstood details are the
multiplicative **ordinary tip amount** bonus (not percentage points of base),
Mochi's missed crossings not retrying after cooldown, and the nine clipped weekly
periods in the first season. The all-at-one-level upgrade fixtures below are
endowments for effect isolation, not claims that a Level-1 player can buy them.

## 2. Input models and café pacing

These assumptions are **not empirical human measurements**. They describe a FIFO,
one-drink-at-a-time policy; it does not pre-accept a second order or optimize taps.
A real player can behave differently. Input/reading/scrolling costs are approximated,
not replayed UI events. The Step 11 real-input regression is rerun separately.

| Model | Tap mean (s) | Read / notice (s) | Timing bias / σ (s) | Per-ingredient omission | Distraction chance |
|---|---|---|---|---|---|
| average | 0.85 | 2.5 / 2.5 | 0.2 / 0.45 | 6% | 10% |
| high | 0.45 | 1.0 / 1.0 | 0.1 / 0.15 | 1% | 2% |
| ideal | 0.15 | 0.15 / 0.15 | 0.0 / 0.0 | 0% | 0% |
| low | 1.8 | 6.0 / 6.0 | 0.65 / 1.0 | 15% | 25% |

Tap jitter is uniform ±15%; timing error is Gaussian in **absolute seconds**;
negative process durations clamp to 0.05s. Distractions cost 8–18s, or 15–30s in
the low model. Ideal is a near-instant automated lower bound, not human play.
Per-order random draws and arrival seeds are paired across teams. Wrong extra
ingredients and device-specific scrolling are not modeled, so mistake estimates
are not a comprehensive error model.

Default team (Mochi/Fade/Max), no upgrades; 20 seeds:

| Model | Admitted | Served mean [P10–P90] | Lost | Coins | Rep XP | Idle s | Rush occupied |
|---|---|---|---|---|---|---|---|
| ideal | 12.15 | 12.15 [11.0–13.0] | 0.0 | 157.6 | 182.2 | 232.7 | 39% |
| high | 12.15 | 12.15 [11.0–13.0] | 0.0 | 157.3 | 179.8 | 168.2 | 74% |
| average | 11.55 | 11.55 [10.9–12.1] | 0.0 | 148.3 | 157.3 | 76.9 | 91% |
| low | 8.50 | 5.70 [3.9–8.0] | 2.8 | 71.4 | 67.0 | 2.2 | 100% |

| All upgrades level | Model | Served | Skipped attempts | Serve wait s | Patience left s | Timed process s | Total shift s | Perfect share |
|---|---|---|---|---|---|---|---|---|
| 0 | average | 11.6 | 0.6 | 22.8 | 40.2 | 3.8 | 306.2 | 63.2% |
| 0 | low | 5.7 | 3.6 | 53.4 | 14.1 | 4.2 | 333.1 | 29.8% |
| 2 | average | 11.6 | 0.6 | 22.6 | 44.0 | 3.6 | 306.1 | 79.2% |
| 2 | low | 6.5 | 3.5 | 55.4 | 15.6 | 4.0 | 338.3 | 38.5% |
| 3 | average | 11.6 | 0.6 | 22.4 | 46.0 | 3.5 | 306.1 | 81.0% |
| 3 | low | 6.7 | 3.5 | 54.8 | 17.8 | 3.9 | 339.5 | 44.8% |

Waiting is arrival-to-service **for served customers**, including processing;
these survivor averages exclude customers who expire. Timed process excludes
reading, selection and navigation. Idle means no guest being handled under this
policy; “Rush occupied” includes modeled input/distraction delays and is not a
measure of mental workload. Occupancy integration uses ≤0.25s observation steps;
production event resolution remains authoritative. Up to two guests coexist;
this policy accepts only one order at a time, despite the game supporting two.

Key findings:

- Ideal default play is idle about **233s / 301s (77%)**. Fast preparation upgrades
  mostly add idle time; demand, not brewing, is the fast-player bottleneck.
- Average play is comfortable outside Rush but spends about **90%** of Rush
  handling/waiting on work. It also skips about 0.6 full-seat admission attempts
  per shift. “No lost customers” therefore does not mean every offered guest entered.
- Low play admits fewer guests and loses about one third of those admitted.
  Its near-zero idle time and 333–339s total shift show soft-closing tail pressure.
  Added patience can lengthen that tail while improving successful service.
- Raising global arrivals to fill ideal idle time would likely worsen the low
  model's losses. Tutorial/interaction-speed playtests should precede any global
  arrival change. No arrival values are changed here.

`pacing.csv` contains all configurations and descriptive distributions; raw JSON
also retains offered/admitted/skipped, waiting/patience samples, occupancy, Rush
admissions/service, ability activations and quality counts. Waiting/Coins/XP
P10/P50/P90 can be inspected without reducing the analysis to averages.

## 3. All recipes and quality

| Recipe | Ingredients | Target s | Base Coins | Selection + process + assemble steps | Perfect Coins (no bonuses) |
|---|---|---|---|---|---|
| Basic Coffee | Coffee, Water | 3.0 | 10.0 | 2 ingredients / 3 steps | 11.0 |
| Vanilla Cloud Coffee | Coffee, Milk, Vanilla | 4.0 | 14.0 | 3 ingredients / 3 steps | 16.0 |
| Warm Milk | Milk | 3.0 | 10.0 | 1 ingredients / 3 steps | 11.0 |
| Honey Hug Milk | Milk, Honey | 4.0 | 12.0 | 2 ingredients / 3 steps | 13.0 |
| Garden Tea | Tea, Water | 4.0 | 10.0 | 2 ingredients / 3 steps | 11.0 |
| Honey Blossom Tea | Tea, Water, Honey | 5.0 | 12.0 | 3 ingredients / 3 steps | 13.0 |
| Berry Breeze | Berries, Water, Ice | 3.0 | 12.0 | 3 ingredients / 3 steps | 13.0 |
| Iced Cocoa Cloud | Cocoa, Milk, Ice | 4.0 | 14.0 | 3 ingredients / 3 steps | 16.0 |

All stations present the same nine ingredient choices. Warm Milk requires one
selection; three-ingredient drinks add two taps and more omission opportunities.
Warm Milk and Basic Coffee both pay 10 with 3s processing, although Coffee needs
two ingredients. Garden Tea pays 10 with 4s; Honey Tea pays 12 with three
ingredients/5s versus Berry Breeze's three ingredients/3s. Longer targets also
make a fixed absolute timing error less costly, so shorter time is not a strict
accuracy advantage. Orders are assigned, not player-chosen profit exploits.
Vanilla Coffee and Iced Cocoa have identical numeric complexity/rewards.

The score before bonuses is:

`round(50 × clamp((hits − extras)/required,0,1) + 35 × clamp(1 − |error|/[target×(1+forgiveness)],0,1) + 15 × completed_steps/3)`.

A nonempty ingredient selection earns the full three-step completion component
when assembled, even if ingredients are missing. With correct ingredients and
all steps, the approximate Perfect absolute-error window is
`target × (5.5 + quality_bonus)/35 × (1+forgiveness)` (rounding boundary included).
At a 3s target it expands from **±0.47s** to **±1.84s** at +16 quality. Speed
shrinks targets and therefore shrinks absolute timing tolerance; it does not
widen forgiveness. Momo widens the scoring denominator by 15%, not by 15 quality
points or 15 percentage points of success probability.

| Model | Point-scoring variant | Perfect | Wrong-ingredient Perfect / all attempts | XP per attempt |
|---|---|---|---|---|
| average | plain | 65.1% | 0.0% | 13.70 |
| average | ingredients_max | 84.7% | 0.0% | 14.43 |
| average | two_quality_cats | 86.2% | 0.0% | 14.52 |
| average | quality_and_upgrades | 92.1% | 5.7% | 14.73 |
| average | momo_ready | 86.3% | 0.0% | 14.53 |
| average | blaze_ready | 98.6% | 12.2% | 14.90 |
| low | plain | 24.8% | 0.0% | 11.69 |
| low | ingredients_max | 46.2% | 0.0% | 12.71 |
| low | two_quality_cats | 55.6% | 0.0% | 13.19 |
| low | quality_and_upgrades | 69.4% | 5.7% | 13.80 |
| low | momo_ready | 59.6% | 0.0% | 13.37 |
| low | blaze_ready | 89.8% | 21.2% | 14.22 |

This point study keeps the base target fixed and weights recipes equally. “Ready”
assumes that active ability is available for **that draft**; it is not a claim of
100% cooldown uptime. Full-shift simulations use the actual 30s cooldown and
real speed-adjusted targets instead.

Confirmed scoring consequences, requiring a design decision rather than an
unapproved fix:

- A three-ingredient recipe with one omitted ingredient scores 83 at exact timing.
  Two quality passives (+10) plus Ingredients level 3 (+6) make that **99/Perfect**.
- Blaze can promote that incomplete Excellent drink to Perfect when ready.
  With Blaze+Momo's +10, even correct-ingredient drinks with zero timing points
  score 75 and can become Perfect; max Ingredients raises this floor to 81.
- The low point model's ready-Blaze case yields about 90% Perfect attempts,
  including about 21% of all attempts with omitted ingredients. Cooldown and
  patience make full-shift results less generous, but do not remove the rule.

Suggested experiment: require exact ingredient correctness for Perfect and for
Blaze conversion, while separately testing quality caps around +8–10 instead of
+16. These are proposals only. Changes would also change Reputation and tips.

## 4. Coins, prices and upgrade affordability

| Quality | XP | Base 10 payout | Base 12 payout | Base 14 payout |
|---|---|---|---|---|
| Okay | 5 | 10 | 12 | 14 |
| Good | 8 | 10 | 12 | 14 |
| Excellent | 12 | 11 | 13 | 15 |
| Perfect | 15 | 11 | 13 | 16 |

Integer flooring makes Good's nominal 5% tip **zero on every recipe**. Fade or
Odin's +5% ordinary-tip passive, separately **or together (+10%)**, changes none
of those 12 base/tier payouts without Service Training. This is verified through
the actual reward function, not an approximation. Odin's separate active premium
still pays +1 on bases 10/12 or +2 on base 14, subject to quality/cooldown.

Service Training's threshold interactions:

- No tip cats: levels 1 and 2 add no Coins; level 3 adds +1 only on base-12 Perfect.
- Default Fade support (+5%): level 1 adds no Coins; level 2 adds +1 on base-12
  Perfect; level 3 adds nothing further for any current recipe/quality tier.
- Both tip cats: level 1 crosses that same base-12 threshold; later levels do
  not improve current payouts. Good remains zero and Excellent unchanged.

This is a high-confidence reward-resolution problem. Fractional tip carry is a
candidate way to retain intended percentages; redefining bonuses as percentage
points would be a much larger buff and should not be slipped in as a rounding fix.

| Upgrade | Incremental costs 1/2/3 | Total | Unlock levels | Earliest days 1/2/3, buying that chain alone |
|---|---|---|---|---|
| Brewing Equipment | 60.0 / 120.0 / 240.0 | 420.0 | 1.0 / 2.0 / 3.0 | 0 / 1 / 3 |
| Comfortable Seating | 50.0 / 100.0 / 200.0 | 350.0 | 1.0 / 2.0 / 3.0 | 0 / 1 / 2 |
| Better Ingredients | 70.0 / 140.0 / 280.0 | 490.0 | 2.0 / 3.0 / 4.0 | 1 / 2 / 3 |
| Service Training | 60.0 / 120.0 / 240.0 | 420.0 | 2.0 / 3.0 / 4.0 | 1 / 2 / 3 |

Affordability columns assume the no-upgrade average rate of 148.3 Coins and
157.35 XP per shift, starting with 120 Coins; they include Reputation unlocks but
reserve all Coins for that one chain. They are not simultaneous purchase promises.
All upgrades cost **1,680 Coins** in total. Six purchasable decorations cost
**20, 35, 25, 40, 30, 45 = 195 Coins**, unlock at Levels 1/2/1/2/1/3, and have no
stat bonuses. Reward-only exclusive entries' reserved `price=1` is **not** a shop
price; those entries are excluded from affordability totals.

The persistent economy simulation instead buys the cheapest eligible next
upgrade after each day, starting at day 0, then buys all regular decorations after
maxing upgrades. It uses actual transaction/unlock checks and independent day
seeds. No lottery or seasonal prizes are claimed, and no new Coins are injected.

| Model | Max upgrades mean days | Observed range | Upgrades + decorations mean | Observed range |
|---|---|---|---|---|
| low | 20.25 | 18–23 | 22.60 | 20–25 |
| average | 10.95 | 10–11 | 12.10 | 11–13 |
| high | 10.10 | 10–11 | 11.20 | 11–12 |

At the average model's 10.95-shift upgrade mean, 3/7/14/28 shifts per week imply
about **25.6 / 11.0 / 5.5 / 2.7 calendar days** respectively. Low-model upgrade
completion is about 20.25 shifts (47.3 days at 3/week). Decorations alone have a
Coin shortfall of only 75 from the starting balance; Reputation Level 3 for the
last item, rather than raw price, can be the binding early limit.

Snowballing is modest for average play: granting every upgrade raises default
income from 148.3 to 152.9 (+3.1%) without increasing served customers. It helps
low play more (71.4→85.7, +20.0%). Once the small shop is complete, there is no
recurring Coin sink in current scope, long before the Level 50 lottery unlocks.
This is a content/economy-horizon concern, not evidence that early prices should
all be raised. Raising prices alone risks making slow play tedious.

## 5. Reputation and Level 50 horizon

The exact cumulative threshold is `75×(L−1) + 10×(L−1)×(L−2)`.

| Level | Total XP | Low shifts | Average shifts | High shifts | Ideal shifts |
|---|---|---|---|---|---|
| 5 | 420 | 7 | 3 | 3 | 3 |
| 10 | 1395 | 21 | 9 | 8 | 8 |
| 20 | 4845 | 73 | 31 | 27 | 27 |
| 30 | 10295 | 154 | 66 | 58 | 57 |
| 40 | 17745 | 265 | 113 | 99 | 98 |
| 50 | 27195 | 406 | 173 | 152 | 150 |

These are `ceil(total XP / mean shift XP)` steady-rate projections, not simulated
multi-month learning trajectories. Average upgrades reduce the Level 50 estimate
from 173 shifts to 165; low upgrades from 406 to 322. Quality-focused teams improve
XP but do not change per-tier XP constants. Recipes of equal quality award equal
XP regardless of duration, complexity or base price.

Sensitivity independent of this policy: at 12 served guests, all Okay/Good/
Excellent/Perfect yields **60/96/144/180 XP per shift**, or **454/284/189/152 shifts**
to Level 50. Losing 25% of otherwise identical services multiplies required shifts
by about 1.33; losing half doubles them. Cat effects enter through quality,
survival and successful service, never a direct XP multiplier.

At the default average rate, Level 50 is about **404 calendar days at 3 shifts/week,
173 at 7/week, 86.5 at 14/week, or 43.3 at 28/week**. Thus one or two shifts a day
normally do not unlock the lottery in the first season. Whether that is too slow
depends on the intended endgame horizon; it needs an explicit design target.

At Level 50, one 1,000 XP cycle averages **6.36 average-model shifts**, or 14.91 low
and 5.49 ideal shifts. An exclusive-category lottery result averages **50 tickets**;
Roll 10 has only `1−0.98^10 = 18.3%` chance of at least one exclusive-category hit,
not a guarantee. At this XP rate, 50 repeat tickets represent roughly 318 further
shifts after Level 50, before counting the welcome ticket or future reward sources.

When all eligible regular collections are owned, the separate cycle prize is
worth 750 expected Coins. When all currently eligible lottery items are owned,
a ticket returns `0.98×500 + 0.02×1000 = 510` expected Coins. Together that is
**1,260 expected Coins per repeat cycle**, besides service earnings. With empty
collections, immediate Coin components are 500 per cycle and 250 per ticket;
item ownership and duplicate fallbacks change that value over time. No real-money
value is assigned to items. Mature rewards dwarf the already finished shop.

## 6. Seasonal feasibility and alternative models

The standard eight-week planning calculation assumes 56 daily and eight weekly
challenge completions. “Casual/some” below explicitly means 24 shifts, 16 daily
and four weekly completions; this is an assumption, not measured attendance.

| Profile | Shifts / season | Daily / weekly completions | Current XP | Tier | Milestones reached |
|---|---|---|---|---|---|
| Casual | 24 | 16 / 4 | 2800 | 5 | 5 |
| Regular | 56 | 56 / 8 | 7200 | 14 | 5, 10 |
| Engaged | 112 | 56 / 8 | 10000 | 20 | 5, 10, 15, 20 |
| Dedicated | 224 | 56 / 8 | 15600 | 31 | 5, 10, 15, 20, 25, 30 |

Using the **actual first-season schedule**, there are nine clipped Monday-based
weekly periods, not eight. A separate cached-shift calendar model applies the
real deterministic objective definitions and progress thresholds. Casual plays
Monday/Wednesday/Saturday; others play 1/2/4 shifts daily. These use average
skill at upgrades 0/0/2, then high at upgrades 3 respectively, and twenty seeded
seasons. This is a conditional model, not real challenge-completion data.

| Profile | Actual daily / weekly wins mean | XP [P10–P90] | Tier range |
|---|---|---|---|
| Casual | 24 / 2 | 2800 [2800–2800] | 5–5 |
| Regular | 56 / 8 | 7200 [7200–7200] | 14–14 |
| Engaged | 56 / 9 | 10200 [10200–10200] | 20–20 |
| Dedicated | 56 / 9 | 15800 [15800–15800] | 31–31 |

The casual model completes 24 dailies but only two weekly objectives; this
happens to total the same 2,800 as the different arithmetic assumptions above.
Regular completes eight weekly periods; engaged/dedicated complete nine and gain
200 XP over the simplified planning table. The upper result is still only Tier 31.
A three-shift week cannot complete the five-café-day weekly objective. Slow
players also struggle with the 100-service-Coin daily when mean income is 71.

With all 56 daily and eight weekly awards, non-day XP is 4,400:

| Goal | XP required | Café shifts required | Shifts/day across 56 days | Minimum café minutes/day |
|---|---|---|---|---|
| Tier 40 | 20000 | 312 | 5.6 | 27.9 |
| Tier 45 | 22500 | 362 | 6.5 | 32.3 |
| Tier 50 | 25000 | 412 | 7.4 | 36.8 |

For nine weekly wins, those shift counts fall by only four. Times exclude menus,
soft closing and pauses. Tier 50's 412 shifts is **34.3 hours** of five-minute café
time, or 36.8 minutes every day. The regular routine offers about 4.7 hours over
the season and reaches only **28.8%** of required XP. First Tier-5 reward arrives
around 19–20 regular calendar days; the first seasonal cosmetic (Tier 10) around
39. Casual three-shift weeks generally never reach that cosmetic milestone.

Comparison models are proposals, not applied configuration:

| Candidate | XP day/daily/weekly | XP/tier | Casual tier | Regular | Engaged | Dedicated |
|---|---|---|---|---|---|---|
| Current | 50/50/200 | 500 | 5 | 14 | 20 | 31 |
| Higher day XP | 375/50/200 | 500 | 21 | 50 | 50 | 50 |
| Lower tier XP | 50/50/200 | 140 | 20 | 50 | 50 | 50 |
| Weekly-heavy | 50/50/2500 | 500 | 24 | 50 | 50 | 50 |
| Hybrid | 250/100/300 | 300 | 29 | 50 | 50 | 50 |

A player-friendly **target for approval** is completion around **40 café shifts,
32 daily challenges and six weekly challenges** over eight weeks: about five
short shifts/week, with missed objectives allowed. The illustrative Hybrid gives
`40×250 + 32×100 + 6×300 = 15,000`, exactly 50 tiers at 300 XP. It is one candidate,
not a chosen permanent solution. At three shifts/week its assumed casual profile
still reaches about Tier 29, so a target of completion for three/week would need
a more generous model or a different reward cadence. Decide that target first.

Day-only 375 and tier-only 140 barely cover perfect regular attendance; they leave
little missed-day margin. Weekly-heavy 2,500 makes one missed weekly cost five
whole tiers, creating disproportionate pressure. Hybrid needs playtesting for
frequent-player early completion, Coin reward inflation and fair treatment of
an in-progress season; any approved rollout must preserve earned Inbox rewards.

## 7. Cat comparisons

| Cat | Passive | Active | Cooldown |
|---|---|---|---|
| Mochi | +5% starting patience | Restore 10% original patience below 30%, once per guest crossing. | 30.0 |
| Fade | +5% ordinary tip amount | +20% preparation speed for one draft. | 30.0 |
| Momo | +5 quality points | 15% wider timing scoring window for one draft. | 30.0 |
| Odin | +5% ordinary tip amount | Extra 15% of base price when serving Excellent or Perfect. | 30.0 |
| Max | +5% preparation speed | +15% preparation speed for one draft. | 30.0 |
| Blaze | +5 quality points | Convert an Excellent completed drink to Perfect (95). | 30.0 |

| Active / supports (reference teams) | Model | Served | Coins | Rep XP | Activations / shift |
|---|---|---|---|---|---|
| mochi/fade/max | average | 11.6 | 148.3 | 157.3 | 0.1 |
| mochi/fade/max | low | 5.7 | 71.4 | 67.0 | 4.9 |
| fade/max/mochi | average | 11.6 | 148.2 | 156.6 | 7.1 |
| fade/max/mochi | low | 5.0 | 63.1 | 57.8 | 7.2 |
| max/fade/mochi | average | 11.6 | 148.2 | 156.8 | 7.1 |
| max/fade/mochi | low | 5.2 | 64.9 | 60.5 | 7.2 |
| momo/blaze/max | average | 11.6 | 149.6 | 167.6 | 7.1 |
| momo/blaze/max | low | 4.5 | 56.9 | 59.1 | 7.0 |
| blaze/max/momo | average | 11.6 | 150.0 | 172.1 | 1.6 |
| blaze/max/momo | low | 4.5 | 57.4 | 63.5 | 1.9 |
| odin/fade/max | average | 11.6 | 156.9 | 157.3 | 6.7 |
| odin/fade/max | low | 4.5 | 60.5 | 52.9 | 3.5 |

Reference support rosters differ, so the table is not an isolated causal active
comparison except where the same three cats swap roles. The full 60-team scan
uses paired ten-seed rankings:

| Upgrade level_model | Top Coin team (active first) | Coins | Rep XP | Coin P10–P90 |
|---|---|---|---|---|
| 0_average | odin/blaze/momo | 157.5 | 165.4 | 145–171 |
| 0_low | mochi/max/momo | 76.0 | 76.2 | 53–101 |
| 3_average | odin/blaze/momo | 161.8 | 167.7 | 150–176 |
| 3_low | mochi/blaze/momo | 94.4 | 100.3 | 76–118 |

These rankings are conditional on the modeled policy and ten seeds, with
overlapping outcome distributions. They do not establish a universally best team.

- **Mochi** is situational rather than weak: virtually unused in average play,
  about five activations in low play, and valuable survival/throughput there.
  A threshold missed during cooldown is not retried. Seats and Mochi stack
  additively on original patience: 60×1.14 = 68.4s maximum starting patience;
  a qualifying restoration adds up to 6.84s.
- **Fade/Max** shorten real targets, but the arrival ceiling makes their speed
  largely idle-time gains for fast players. Same-team active Fade is mechanically
  faster than active Max (20% vs 15%); neither increases average served counts
  in those reference cases. Absolute-error assumptions can slightly hurt quality
  as targets shrink. Max's passive remains useful from support.
- **Momo/Blaze** have identical +5 passives. Together their +10 already masks much
  timing error; Momo's active adds little in the average point model. Blaze's
  conversion is more powerful, but can erase ingredient/timing mistakes as above.
  Ready-state point-study power should not be mistaken for every-drink uptime.
- **Odin** contributes tangible +1/+2 premiums on qualifying services, and is a
  strong income choice in average/fast models. His ordinary-tip passive, like
  Fade's, is invisible without a rounding threshold crossing from upgrades.
- Only one active ability exists, not six simultaneously competing triggers.
  Equipping support cats never consumes cooldown or automates service. The
  “shared” 30s rule is per current active cat; the active's opportunity cost and
  situational trigger rate matter more than stacking multiple cooldowns.

## 8. Upgrade benefits and marginal value

| Upgrade | Level 0/1/2/3 effects | Marginal / cost finding |
|---|---|---|
| Brewing | 0/3/6/9% speed; target = base/(1+speed) | Base 4s with no cats: 4.000/3.883/3.774/3.670s; each step saves less despite doubling cost |
| Seating | 0/3/6/9% patience | +1.8s per level on 60s base; most valuable for slow input, can lengthen closing tail |
| Ingredients | 0/+2/+4/+6 quality | Applies before tier; major effect near thresholds; stacks to +16 with Momo+Blaze |
| Training | 0/5/10/15% ordinary-tip amount | Most marginal purchases pay zero under current integer prices; thresholds depend on tip cats |

Speed and patience modifiers add with cat passives; the current preparation
active adds to speed for its one draft. Quality adds/clamps before tier and Blaze.
Ordinary tips multiply their amount; Odin's premium is separate and unaffected
by Training. Effects freeze for the shift. Low model benefits from bought
patience/quality more than fast play; broad price cuts/buffs are not supported
by a single uniform upgrade test. The cheapest-next purchase strategy is one
possible choice, not an optimized ROI solution.

## 9. Player-experience findings (no redesign)

The actual scene flow, UI scripts and unchanged Step 11 screenshots were reviewed;
the real-input integration and viewport suites were rerun. This is not a fresh
human usability study.

| Observation | Evidence / classification | Potential friction |
|---|---|---|
| Order identity, drink name and ingredients are shown | Confirmed UI fields in OrderScreen / station; independent IDs | Good baseline clarity; two guests and station switching still need first-time-user observation |
| Patience/countdown remains visible; Rush uses text/color | Confirmed live labels and Gold status style | Countdown pressure is objective; whether it feels cozy is subjective |
| Quality/result score and Coin/XP preview appear | Confirmed serving UI | No explicit explanation identifies which ingredient/timing mistake lowered quality |
| Ingredients need not be correct to assemble | Confirmed scoring and preparation APIs | High scores can teach incorrect recipes; approval needed for any correctness gate |
| Ability readiness/cooldown is visible | Confirmed status display; ability_feedback is set but not consumed by gameplay_view | Exact automatic effect is easy to miss; perceived usefulness may differ from measured utility |
| Results show Coins/Reputation, not Seasonal XP/challenge award breakdown | Confirmed results text construction | Earned seasonal rewards may feel unacknowledged until a separate menu is opened |
| Map opens Lottery/Collections; Pass/Inbox is another button inside | Confirmed navigation routes | Labels do not predict destination; discoverability concern, not a reproduced navigation trap |
| Season reward list shows locked/earned/claimed and total/within-tier XP | Confirmed Seasonal UI | Long wait to first milestone may feel like no progress even though XP increases |
| Scrolls and ≥44px targets pass | Automated real-input tests, not a hands-on accessibility study | Nine ingredient buttons can require scrolling on 320px phones; modeled tap delay is not measured scroll effort |

No objectively broken navigation path or new UI regression was found in this
audit. Confirmed information omissions and scoring/rounding behavior are distinct
from subjective concerns about fun, relaxation, tutorial needs or cosmetic appeal.
No screen, artwork or control was changed.

## 10. Prioritized recommendations — approval required

| Priority / system | Current → candidate | Evidence | Expected impact / side effects | Confidence / playtest |
|---|---|---|---|---|
| High / Seasonal pacing | 50/50/200 XP, 500/tier → evaluate Hybrid 250/100/300, 300/tier | Regular Tier 14; dedicated Tier 31; target example 40 shifts +32 daily +6 weekly | Attainable pass with missed objectives; earlier completion and more Coin/item rewards; preserve old entitlements | Math high; target medium; hands-on required |
| High / Quality correctness | Perfect can omit ingredients → require exact ingredients for Perfect/Blaze, test max bonus +8–10 vs +16 | 99/100 missing one ingredient; ready Blaze masks zero timing points | Keeps recipe learning meaningful; lowers tips/Rep XP and may disadvantage casuals | Behavior high; proposed cap medium; playtest required |
| High / Tip resolution | Integer floor per service → retain fractional tip carry, compare percentage-point alternative separately | All +5%/+10% ordinary-tip passives inert without Training | Makes purchased/passive bonuses measurable; save/money representation and total payout impact need design review | High on current floor; medium on remedy; playtest required |
| Medium / Casual challenges | Daily 100 Coins → test 75–80; weekly 5 days → test 3; served 30 → test 20–30 | Low income ~71; three-shift budget cannot complete five-day objective | More attainable challenges; extra Seasonal XP and easier frequent-player clears | Medium; completion telemetry/playtest required |
| Medium / Early reward cadence | First reward 2,500 XP (~20 regular days) → target first 1–3 shifts within an approved season model | Shop can max by ~11 shifts before first seasonal milestone | Earlier acknowledgement; changes reward density and economic value | High timing math, medium target; playtest required |
| Medium / Cat differentiation | Fade +20% vs Max +15%; duplicate +5 quality passives → measure alternatives before changing values | Same-team speed active gains no throughput in average model; Momo active largely masked | Preserve useful support roles; any buff can alter error tolerance or survival | Medium; real-input tests required |
| Medium / Long-term unlock horizon | Lottery Level 50 → decide intended horizon; compare Levels 25–30 only if an earlier booth is wanted | 173 average shifts; 404 calendar days at 3/week | Earlier access vs loss of endgame goal and more early Coin rewards | Math high; design choice open; playtest required |
| Medium / Feedback/navigation | Hidden effect/season award details → show existing awarded amounts and label destinations explicitly | Confirmed absent breakdown; Map destination mismatch | Better comprehension without stat changes; small-screen clutter/focus risk | Code high, usefulness medium; usability test required |
| Low / Global arrivals | 25–35s / 10–15s → retain for now; only test normal 22–30s after input timing data | Ideal 77% idle but low already loses guests | May fill high-skill idle; likely harms casuals and increases earnings | Model medium; human data required |
| Low / Shop prices | 1,680 upgrades /195 decorations → hold prices until desired spend horizon agreed | ~11 average shifts vs173 to lottery; low20 shifts | Avoid arbitrary grind inflation; permanent Coin surplus remains unsolved by prices alone | High totals; horizon subjective; playtest required |

These are alternatives and priorities, not a bundled implementation proposal.
In particular do not apply a quality nerf, a lower arrival interval and slower
Seasonal XP simultaneously without observing casual losses. If desired, first
approve a season completion target, a recipe-correctness rule, and how fractional
Coins should be represented. No question or approval is needed to finish this
read-only audit; all decisions remain for a later implementation task.

## 11. Validation, preservation and remaining unknowns

Godot 4.6.3 existing baseline suites were run unchanged:

| Suite | Result |
|---|---|
| Persistence | 196 |
| Shop | 495 |
| Lottery | 587 |
| Seasons / challenges / Inbox | 628 |
| Cats | 259 |
| Drinks | 1111 |
| Café shifts | 62 |
| Gameplay UI | 430 |
| Foundation | 8 viewport configurations |
| Full integration | 654 |

The analysis adds only three audit GDScripts (observer, sampler, point-score/
calendar study), one stdlib Python summarizer and this report, plus generated
Godot UID sidecars. Production source, balance/data catalogs, prior tests, prior
documentation, official artwork and all pre-existing uncommitted work are checked
byte-for-byte against the audit-start hash manifest: **all 162 pre-existing files are unchanged and none were removed**. No save files are written
by simulated profiles. Existing integration suites use isolated scratch saves.
`Tools/*` stays excluded by the existing export configuration.

Reproducibility includes exact in-process and separate-process replays, seeded
calendar planning, and source-derived prices/XP thresholds. An early economy
trial reused the same player-error seed every day and produced a persistent
bad-draw outlier; the final sixty trajectories use independent day seeds. No
production change was made to address that modeling issue. Sampler process
outputs are outside production exports.

Unknowns requiring hands-on data: actual reading/scroll/tap times on phones,
timing-error distributions, first-time ingredient mistakes, mental load during
Rush, batch-order strategies, learning and fatigue, notification comprehension,
long-term attendance/challenge completion, and whether waiting feels cozy or
boring. Browser/device storage and rendering, background tabs, suspend/resume
and real hardware touch remain release-readiness work. Simulations cannot
establish enjoyment, retention, statistical dominance across players or final
balance. No recommendations have been implemented.
