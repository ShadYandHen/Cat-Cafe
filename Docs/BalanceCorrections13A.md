# Step 13A — Approved reward and quality corrections

This pass changes only Seasonal XP rates, missing-ingredient quality eligibility,
and unpaid ordinary-tip bonus accounting. Existing uncommitted work is preserved;
no commits or pushes are part of this step. Step 12's audit remains a historical
snapshot. Recipes, prices, weights, cat percentages, upgrade values, customer
scheduling, lottery probabilities, art and layouts are unchanged.

## Seasonal XP

`Data/Seasons/pass.json` is authoritative. The catalog validates positive integer
reward values; UI reads the same values instead of duplicating literals.

| Source | Previous XP | Approved XP |
| --- | ---: | ---: |
| Completed café day | 50 | 200 |
| Completed daily challenge | 50 | 150 |
| Completed weekly challenge | 200 | 500 |

The season still lasts 56 days, has 50 tiers at 500 XP/tier and caps at 25,000 XP.
Anchor, UTC boundaries, milestones, Inbox and lottery release rules are unchanged.

The eight-week arithmetic model assumes exactly eight weekly completions:

- Before: `56×50 + 56×50 + 8×200 = 7,200 XP` (Tier 14).
- After: `56×200 + 56×150 + 8×500 = 23,600 XP` (Tier 47).
- Seven additional shifts: `23,600 + 7×200 = 25,000 XP` (Tier 50).

The existing calendar can include clipped partial UTC weeks; this arithmetic is
not a change to scheduling. At cap, further XP does not advance tiers. Results
show the catalog's completed-day award with “up to cap”; completed challenges
remain separate. Failed day saves do not display a granted day award.

Existing XP totals and earned/claimed states stay unchanged. Existing day and
challenge receipts prevent replay; migration never recomputes historical rewards.

## Ingredient completeness and Blaze

Raw scoring remains 50% ingredients, 35% timing, 15% steps, rounded as before.
`DrinkQuality.ingredients_complete` checks membership against every required
ingredient in the order's authoritative recipe. Extra ingredients still incur
the existing raw-score penalty and do not satisfy missing requirements.

Finalization order:

1. Compute raw score with the existing recipe/timing/step rules.
2. Add cat quality and snapshotted ingredient-upgrade bonuses.
3. Clamp to 0–100 for complete ingredients, otherwise 0–74.
4. Blaze may convert an eligible **complete** Excellent result (75–94) to 95.
5. Reapply the completeness guard before deriving tier, XP and reward.

Incomplete drinks neither consume Blaze cooldown nor queue a conversion. A later
complete Excellent drink can use the still-ready ability. Existing cooldown and
complete-drink activation behavior are unchanged. Imperfect timing alone does
not trigger the ingredient cap. Good remains 50–74, Excellent 75–94, Perfect
95–100. UI displays the final capped score/tier.

## Fixed-point ordinary-tip settlement

The existing whole ordinary payout and separate Odin premium are preserved.
All equipped ordinary-tip passives and Service Training stack **additively**.
Preparation records the bonus for that order; reopening screens cannot apply it
again. Only successful service settles it.

Let `B` be recipe base Coins, `p` the quality tip percentage (0, 5, 10, 15),
`b` the sum of bonus percentages (5 per Fade/Odin, 5 per Training level).
Use 10,000 integer units per Coin (one unit is 0.0001 Coin):

```
base_units       = B × p × 100
bonus_units      = B × p × b
ordinary_tip     = (base_units + bonus_units) div 10000
base_whole_tip   = base_units div 10000
bonus_already_paid = ordinary_tip − base_whole_tip
unpaid_bonus     = max(0, bonus_units − bonus_already_paid × 10000)
combined         = saved_remainder + unpaid_bonus
settled_coins    = combined div 10000
new_remainder    = combined mod 10000
service_coins    = B + ordinary_tip + settled_coins + Odin_premium
```

This carries **only unpaid incremental bonus**, never base-tip fractions. If the
old combined rounding already paid a whole extra Coin, its value is deducted
before accumulating a fraction. It cannot double-count that Coin or create a
negative remainder. Existing bonus percentages are exactly representable as
integer percentages; fixed-point operations avoid floating accumulation.

Examples:

- Perfect Basic Coffee: base 10, raw ordinary tip 1.5, one 5% bonus gives
  `.075` unpaid Coins per service. Whole payout stays 11; 40 services add exactly
  three more Coins with zero remainder.
- Perfect base 14 with 5% bonus: raw tip 2.1, bonus `.105`, rather than `.1`
  obtained by prematurely flooring the base tip.
- Perfect base 12 with 15% total bonus: the old whole ordinary tip is already 2
  (base whole tip 1). This covers the `.27` incremental bonus; no additional
  fraction is credited for that service.
- Perfect base 100 with Fade+Odin (10%): ordinary tip 16 with `.5` unpaid;
  the next identical service settles one Coin. Odin's eligible premium remains
  `floor(100×.15)=15`, never entering the ordinary accumulator.

No fractional values appear in the HUD. Order previews include the whole carry
and currently eligible premium; final feedback and day totals use actual payout.

## Profile schema and transaction boundary

Schema **5** adds `ordinary_tip_remainder`, an integer in `[0,9999]`, default 0.
Schema 4 (and earlier supported versions) retain all permanent and seasonal
fields, claims and receipts, initializing only the missing fractional field.
No historical service grants fractions retroactively.

Invalid fractional values (negative, ≥10000, nonintegral, nonnumeric) fail profile
validation and use existing backup recovery. Corrupted originals are retained;
recovery may lose the latest checkpoint as documented for the existing store.
Missing fields default safely. No new files, reward queues or autoloads are used
for tip accounting; the existing `user://player_profile.json` stores the field.

The service API validates active shift/order receipt and fixed-point increment,
then stages **Coins, remainder, Reputation, actual service-Coin challenge progress
and the service receipt together**. Only a successful durable write publishes
memory. Failed writes preserve the entire prior state; retry settles once.
Session reentrancy and stale-callback protections remain. Expired orders, canceled
preparation and historical callbacks cannot settle any bonus. Premium eligibility
and rounding remain separate and unchanged.

## Validation

Godot **4.6.3** headless import and normal startup passed without script or
resource errors. All profiles used isolated `/tmp` or XDG storage, never real
player saves. `git diff --check` passed.

New `Tools/validate_balance_13a.gd` covers approved arithmetic and historical
receipts, all recipe ingredient omissions under maximum bonuses, Blaze eligibility,
quality boundaries, exact fixed-point calculations, threshold settlement, additive
Training, Odin premium separation, repeated callbacks, failed persistence, canceled
and expired orders, schema migration, invalid-state recovery, mouse/touch/keyboard
UI at both portrait sizes, and separate-process remainder continuation.

Existing Persistence, Shop, Lottery, Seasons/Challenges/Inbox, Cats, Drinks,
Day, Gameplay UI, Foundation and Integration suites are retained. Legacy payout
expectations now include actual settled whole Coins.

### Executed results

| Suite | Headless result |
| --- | --- |
| Step 13A corrections | 523 assertions passed |
| Persistence | 196 passed |
| Shop | 496 passed |
| Lottery/Collections | 587 passed |
| Seasons/Challenges/Inbox | 629 passed |
| Cat abilities | 259 passed |
| Drinks | 1,111 passed |
| Café day | 62 passed |
| Gameplay UI | 430 passed |
| Full integration | 656 passed |
| Foundation | All 8 viewports passed |

Native GL Compatibility checks passed: Step 13A **525**, full integration **668**,
and Seasons **629** assertions. Separate-process checks passed **16** fractional
accounting and **17** full-journey reload assertions. Mouse, keyboard and simulated
touch passed at 720×1280 and 320×568. Foundation additionally checks 360×640,
375×667, 390×844, 430×932, 1280×720 and 1920×1080. Native small-phone results
screenshots were inspected: the Seasonal XP line wraps without blocking buttons.
The software graphics driver emitted only its known unsupported VSync warning.

Commands, from the project root (with isolated XDG storage):

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --quit-after 5
godot --headless --path . --script Tools/validate_balance_13a.gd
# Same command for validate_profile, validate_cafe_shop, validate_lottery,
# validate_seasons, validate_cats, validate_drinks, validate_day,
# validate_gameplay, validate_foundation and validate_integration (.gd).
# Native checks use an X display and omit --headless:
godot --path . --audio-driver Dummy --script Tools/validate_balance_13a.gd
# Use the isolated profile path printed by the writer:
godot --headless --path . --script Tools/validate_balance_13a.gd -- --cold-read=/tmp/ISOLATED_PROFILE/profile.json
```

Full logs are in `/tmp/paw-13a/`. Current result screenshots are in
`/tmp/paw-13a-regression-185469/`; native full-journey screenshots are in
`/tmp/paw-integration-184754-9405699/`. These execution artifacts are temporary.
The audit point-scoring script and Python postprocessor passed syntax checks;
the historical 3,880-shift Step 12 simulation was not rerun.

## Files changed in this step

Added:

- `Tools/validate_balance_13a.gd` and its Godot UID.
- `Docs/BalanceCorrections13A.md` (this report).

Modified gameplay/data:

- `Data/Seasons/pass.json`.
- `Scripts/Gameplay/season_catalog.gd`, `season_screen.gd`.
- `Scripts/Gameplay/drink_quality.gd`, `cafe_order.gd`, `cafe_session.gd`.
- `Scripts/Gameplay/gameplay_view.gd`.
- `Scripts/Persistence/cafe_profile.gd`.

Modified validation/audit tools:

- `Tools/validate_cats.gd`, `validate_seasons.gd`, `validate_integration.gd`.
- `Tools/analyze_quality.gd` now applies the production final-quality guard.
- `Tools/summarize_balance.py` reads current Seasonal XP rates from the catalog;
  historical alternative scenarios remain explicitly labeled alternatives.

Updated documentation:

- `README.md`, `Docs/PlayerProfile.md`, `SeasonalPass.md`, `DrinkPreparation.md`,
  `CatTeam.md`, `CafeShop.md`.
- `Docs/GameplayBalance.md` and `GameplayIntegration.md` retain their historical
  findings and gain notices linking to this current correction report.

Compared with the pre-edit snapshot: **21 files modified, 3 added, none removed**.
All **71 protected resources** (art/reference assets, scenes, recipe/cat/shop/reward
catalogs, project settings and export presets) match their initial SHA-256 hashes.
Other dirty/untracked files predate this step and remain intact. Branch `work`,
HEAD `c8c4a4d` unchanged; no commit or push. No scope deviations.

## Remaining concerns

Browser storage, physical touchscreen behavior and app termination during an OS
write are not validated by native/headless tests. Existing staged-write/backup
protections are reused. Balancing outside these three approved corrections stays
for later; this pass does not determine whether the game feels enjoyable.
