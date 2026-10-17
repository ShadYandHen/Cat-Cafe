# Core drinks and preparation (Step 6)

Step 8 adds [persistent progression, saves, and pre-day team setup](PlayerProfile.md); the details below also record the earlier step’s implementation.

Step 7 adds [cat team bonuses and automatic abilities](CatTeam.md) to these base preparation/reward rules.

Run the project, Play, tap a customer, and accept their named recipe. Tap the **Prepare** equipment control or bottom navigation button. Select the intended order when two are pending. Its matching full-screen station opens automatically; station tabs also allow Coffee, Milk, Tea, and Cold Drinks to be selected explicitly. A mismatched station cannot process the order.

The scrollable workspace holds station tabs, the requested ingredients, ingredient buttons and a process meter. Action, Settings and Back remain outside the scroll area. Select ingredients (tap again to remove), start the named process, and stop it at the displayed target time. The timer remains on the action button even when the workspace is scrolled. The meter's midpoint represents the target; it fills at twice the target time. Choose **Assemble drink**, return, then tap the matching guest and **Serve drink**. Quality is displayed on completion and on the service screen. Preparation never automatically serves or grants rewards.

All categories share the accessible full-screen shell and deterministic timing component. Coffee brews, milk heats/mixes, tea steeps, and cold drinks chill/mix. These are intentionally simple prototype interactions. No ingredient stock, complex recipes, multi-station routing, or minigame artwork is introduced.

## Prototype recipe data

`Data/Recipes/drinks.json` is included explicitly in Web exports. Each record specifies ID, name, category, ingredients, three preparation steps, base Coins, station, action and target seconds. `DrinkCatalog` validates the catalog before the session begins. The seeded sequence cycles through all recipes without consuming arrival-scheduler random numbers, preserving the existing arrival schedule.

| Recipe | Station | Ingredients | Process / target | Base Coins |
| --- | --- | --- | --- | --- |
| Basic Coffee | Coffee | Coffee, Water | Brew / 3s | 10 |
| Vanilla Cloud Coffee | Coffee | Coffee, Milk, Vanilla | Brew / 4s | 14 |
| Warm Milk | Milk | Milk | Heat / 3s | 10 |
| Honey Hug Milk | Milk | Milk, Honey | Mix / 4s | 12 |
| Garden Tea | Tea | Tea, Water | Steep / 4s | 10 |
| Honey Blossom Tea | Tea | Tea, Water, Honey | Steep / 5s | 12 |
| Berry Breeze | Cold Drinks | Berries, Water, Ice | Chill / 3s | 12 |
| Iced Cocoa Cloud | Cold Drinks | Cocoa, Milk, Ice | Mix / 4s | 14 |

## Scoring and service

Step 13A applies an ingredient-completeness guard **after** raw scoring, quality
bonuses and eligible Blaze conversion. Missing any required ingredient caps the
final score at 74 (Good); Blaze cannot activate on an incomplete drink. Correct
ingredients with imperfect timing remain eligible for higher tiers. Raw weights
below are unchanged. See [current reward accounting](BalanceCorrections13A.md).

`DrinkQuality.score` rounds the weighted sum to an integer from 0 to 100:

- Ingredients (50 points): `(correct selections − extra selections) / required count`, clamped to 0–1. Missing ingredients and incorrect extras reduce quality. Duplicate inputs do not inflate scores.
- Timing (35 points): `1 − abs(actual − target) / target`, clamped to 0–1. Stopping immediately or at twice the target earns no timing points. Timing uses the session clock, including time inside Settings.
- Steps (15 points): 5 per completed selection/process/assembly step. Empty ingredient selection skips the selection step; completing a drink still requires manually stopping the process and assembling it.

| Score | Tier | Tip | Daily Reputation XP |
| --- | --- | --- | --- |
| 0–49 | Okay | 0% | 5 |
| 50–74 | Good | 5% | 8 |
| 75–94 | Excellent | 10% | 12 |
| 95–100 | Perfect | 15% | 15 |

Coins are integers: `tip = floor(base Coins × tip percentage)` and `reward = base + tip`. For example, Perfect Iced Cocoa gives 14 + 2 = 16 Coins and 15 XP. Small Good tips can round to zero; all values and this rounding policy are prototypes. Reputation XP is applied to the permanent profile and tracked in day results. Results count quality tiers of **served** drinks; expired/prepared-only drinks earn nothing.

## State ownership and safety

`CafeSession` remains scene-owned and authoritative. `CafeOrder` carries its recipe snapshot, quality and precomputed reward. Existing WAITING_ORDER → ORDER_ACCEPTED → DRINK_READY → SERVED states remain; any active order may expire. The selected draft tracks ingredients, start time and manually stopped duration. There are no new timers or autoloads.

Switching orders, switching to another station, Back/Escape, departure of the selected guest, and day reset clear the unfinished draft. Ingredients lock after processing starts. A completed assembled drink remains attached to its order; it cannot be assigned to another guest. Ingredients/process cannot be changed for a ready drink. Serving durably commits Coins, XP, fractional ordinary-tip settlement and its receipt before marking the temporary order terminal, preventing duplicate rewards. Expiration invalidates ready drinks as well as unfinished preparation. Other customers' orders are unaffected.

Five-minute days, phases, arrivals, independent patience, soft closing and next-day Coin carryover are preserved. Results add daily XP and served-quality counts, which reset on the next day. Settings never pauses the clock. Cancellation allows a fresh attempt while patience remains; assembled drinks cannot be remade in this prototype.

## Validation

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://Tools/validate_drinks.gd
godot --headless --path . --script res://Tools/validate_day.gd
godot --headless --path . --script res://Tools/validate_gameplay.gd
godot --headless --path . --script res://Tools/validate_foundation.gd
```

The old day/UI scenarios remain, using Basic Coffee fixtures and explicit Stop/Assemble actions to match the new controls. The new drink runner covers catalog validation, generation across all recipes, scoring boundaries/weights, all reward tiers, all recipes end-to-end, cancel/switch/expiry, daily resets, and actual mouse/touch selection and preparation at 720×1280 and 320×568. Keyboard preparation is also exercised. Native GL Compatibility rendering is checked with Xvfb/Mesa. Browser/device usability, real touch hardware, high-DPI safe areas, and exported Web builds remain unverified.

No cat abilities, persistent Reputation levels, saves, upgrades, decorations or long-term rewards are implemented. Character assets, title artwork, environment, theme, shared Settings and responsive layout scripts remain unchanged.

Verified in this cloud workspace with Godot 4.6.3: headless import and title launch passed; 1,111 drink-system assertions, 430 gameplay UI assertions, 62 accelerated shift assertions, and foundation checks at all eight documented viewports passed. The native GL Compatibility drink runner also passed its 1,110 assertions before adding the final pre-process expiration regression check. Native screenshots of order, station, timing, quality and results were inspected at both target portrait sizes. The only graphical warning was unsupported V-Sync configuration under Xvfb/Mesa. Checksums confirmed all 68 protected artwork/title/environment/shared-UI resources unchanged.
