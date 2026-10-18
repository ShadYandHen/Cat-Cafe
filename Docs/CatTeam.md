# Cat team and automatic abilities (Step 7)

Step 8 adds [persistent progression, saves, and pre-day team setup](PlayerProfile.md); the details below also record the earlier step’s implementation.

## Controls and team lifetime

The existing **Cat Team** navigation entry opens a full-screen roster. During a shift it is view-only; customer patience, preparation and ability cooldown continue. The **Cat Team** action on day results allows editing. Choose Active, Support 1 or Support 2, scroll to a cat, and use its assignment button. Assigning an already equipped cat swaps slots, preserving exactly three unique cats. All six cats are available without ownership/adoption logic.

The default team is **Mochi active, Fade and Max supporting**. Changes persist within the running session and take effect on the next day. Day 1 still starts immediately on Play, so the first edit opportunity is after its results. Back/Escape returns to the originating café/results screen. Settings retains its modal and focus behavior. The roster uses existing PNGs with aspect-preserving TextureRects; no artwork is modified. Cards and controls scroll, while Settings and Back remain fixed.

## Data and state ownership

- `Data/Cats/roster.json`: validated IDs, names, passive/active kinds, descriptions, numeric parameters, 30-second cooldowns, and official artwork resource paths. Explicitly included in Web exports.
- `Scripts/Gameplay/cat_team.gd`: session-owned RefCounted roster, unique slots, slot swapping and freshly calculated passive totals. No cumulative modifiers or autoload.
- `CafeSession`: guards assignments at results, owns the shared ability deadline and activation log, snapshots preparation modifiers, applies patience/quality/reward effects, and drives all timing from its existing `elapsed` clock.
- `CafeOrder`: retains original starting patience and a consumed threshold-crossing flag, plus separate ordinary and premium tip amounts.
- `CatTeamScreen.tscn` / `cat_team_screen.gd`: presentation and assignment requests only. `GameplayView` connects existing navigation, results, HUD status, and preparation target display.

The model rejects in-shift assignments even if stale UI input calls it. All three slots contribute their passives once; only slot zero's active kind is evaluated. Reopening screens does not apply any modifier again. No support cat prepares or serves anything automatically.

## Passive effects

| Cat | Passive |
| --- | --- |
| Mochi | Starting patience × 1.05 |
| Fade | Ordinary tip amount +5% |
| Momo | Final quality +5 points |
| Odin | Ordinary tip amount +5% |
| Max | Preparation speed +5% |
| Blaze | Final quality +5 points |

Bonuses of the same type add. Momo + Blaze give +10 quality, applied to the existing rounded recipe score and clamped to 0–100 before tier selection or Blaze conversion. Fade + Odin give +10% to the ordinary tip amount, **not** ten additional percentage points of base price.

Monetary calculations use whole Coins:

`ordinary_tip = floor(base × quality_tip_rate × (1 + equipped_tip_bonus))`

`premium_tip = floor(base × Odin_active_tip_rate)` (calculated separately, only when Odin activates on service)

`service_coins = base + ordinary_tip + settled_bonus_coins + premium_tip`

Round once for the ordinary tip and once for the premium; never round the quality tip before applying passives. Premium is not amplified by passive tip bonuses. Step 13A persists the unpaid incremental ordinary-tip bonus in fixed-point units,
settling whole Coins on later successful services. It never carries base-tip or
premium-tip fractions; see [the exact formula and transaction rules](BalanceCorrections13A.md). For base 100, Perfect, Fade + Odin equipped: ordinary tip is floor(15 × 1.10) = 16; active Odin can add 15 more, giving 131 total Coins. Service previews include the currently eligible premium and fractional settlement; service feedback and results use the amount actually paid. XP remains 5/8/12/15 by final quality tier.

## Active abilities and cooldown

Only a qualifying event consumes an activation. A shared absolute `ability_ready_at = elapsed + 30` deadline uses café-session time, including station, order, Team and Settings screens and soft closing. There is no additional Timer. Cooldown and activation history reset at the start of each day. Nothing triggers on results or on opening a UI. The HUD and gameplay screens show active cat and Ready/countdown status.

| Active cat | Qualifying event | Effect |
| --- | --- | --- |
| Mochi | An active customer's patience first crosses below 30% of its original starting patience | Add 10% of that original patience, capped at original maximum remaining patience |
| Fade | Starting a valid accepted-order preparation | +20% speed for that draft |
| Momo | Starting a valid timing preparation | +15% width of the timing scoring window for that draft |
| Odin | Manually serving Excellent or Perfect while ready | Separate extra tip of 15% of base price |
| Max | Starting a valid accepted-order preparation | +15% speed for that draft |
| Blaze | All required ingredients present and completed quality, after passives, is Excellent (75–94) | Convert to 95 before determining rewards |

Mochi uses explicit threshold events in the existing chronological clock loop. Strictly below 30% is checked with a small floating-point tolerance. A crossing is consumed once even if cooldown is unavailable; it is not queued for later and restoration does not create another activation on that customer's next crossing. Simultaneous crossings use order creation order as a stable tie-break. Expired customers are resolved first and never revived. With Mochi equipped, the Step 14 default original patience is 78.75s and restoration is 7.875s (75 base seconds before the existing +5% passive).

Preparation effects are fixed when the player starts processing:

`effective_target = recipe_target / (1 + passive_speed + activated_speed)`

Max active contributes its own 5% passive plus 15% active, giving 20% total speed (3s → 2.5s). Fade active with Max support gives 25% total (3s → 2.4s). The actual stop-time scoring and UI use that target. Cooldown finishing midway does not change the target of an in-flight draft.

Momo widens the timing error normalization window to `effective_target × 1.15`. Timing points remain `35 × clamp(1 − abs(actual − effective_target) / window, 0, 1)`. It does not alter ingredients, create a drink, or guarantee Perfect. The scoring function's default parameter preserves pre-cat behavior.

Duplicate start/stop/finish signals cannot stack modifiers on a draft. Cancel, switching orders/stations, or selected-customer departure discards its modifiers without refunding a consumed cooldown. A later qualifying draft can activate after cooldown, but modifiers never accumulate across attempts. A stopped draft retains its snapshot until assembly/cancellation. Blaze consumes no cooldown on Okay, Good or already Perfect drinks. Odin consumes none on low tiers, expired customers, or a zero-valued premium; serving remains exactly once. Customers and drinks stay associated with their existing unique order IDs.

## Validation and limits

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://Tools/validate_cats.gd
godot --headless --path . --script res://Tools/validate_drinks.gd
godot --headless --path . --script res://Tools/validate_day.gd
godot --headless --path . --script res://Tools/validate_gameplay.gd
godot --headless --path . --script res://Tools/validate_foundation.gd
```

The existing suites retain their baseline assertions. Their fixtures explicitly disable cat effects to isolate the pre-cat recipe/day rules; the new cat suite runs with effects enabled and checks real session preparation, final quality, Coin/XP ledgers, all six passives/actives, eligibility/cooldown, threshold events, expiration, two orders, next day, and coarse/fine clock equivalence. It also exercises mouse at 720×1280, simulated touch at 320×568, keyboard assignment/Escape, scroll accessibility, Settings focus, live runtime cooldown, and resizing through desktop portrait layouts.

Art cutout issues from the supplied PNGs remain. The screen intentionally uses a simple scrollable card list. Team editing is after results only; no separate pre-day lobby is added. There is no adoption, persistence, walking, cat animation, permanent leveling, or unrelated progression. Native headless/GL Compatibility checks do not establish browser, physical-touch-device, Web export, or safe-area correctness.

## Completed validation in this workspace

Godot 4.6.3 headless import and title launch passed without script/resource errors. The final cat suite passed **259 assertions** in both headless and native GL Compatibility runs, including 720×1280 mouse, 320×568 simulated touch, keyboard, and desktop resize checks. Existing suites passed **1,111 drink**, **62 accelerated shift**, and **430 gameplay UI** assertions, plus foundation checks across eight viewports. Native screenshots of café ability status, locked/editable team, roster, preparation and results were inspected at both target portrait sizes. The native environment reports only an unsupported V-Sync setting warning under Xvfb/Mesa.

Checksums confirm the existing artwork, references, shared UI/environment resources, title and project configuration remain unchanged. Existing unfinished Step 5/6 work is retained. No commits or pushes were made.

## Step 7 file changes

Added `Data/Cats/roster.json`, `Scripts/Gameplay/cat_team.gd`, `Scripts/Gameplay/cat_team_screen.gd`, `Scenes/Gameplay/CatTeamScreen.tscn`, `Tools/validate_cats.gd`, their Godot UID sidecars, and this document.

Extended `Scripts/Gameplay/cafe_session.gd`, `cafe_order.gd`, `drink_quality.gd`, `gameplay_view.gd`, `Scenes/Gameplay/GameplayView.tscn`, and `DayResults.tscn`. Updated `export_presets.cfg` to package cat JSON, the three existing gameplay/day/drink test fixtures to isolate baseline mechanics, and README/drink documentation links. Other dirty files shown by Git belong to the preceding uncommitted steps.

The implementation stays within the requested scope. The documented prototype choices are slot swapping, editing after results only, additive speed modifiers with reciprocal target durations, one consumed Mochi crossing per guest, and whole-Coin tip rounding.
