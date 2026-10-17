# Café upgrades, decorations and unlocks (Step 9)

## Controls

**Upgrade** and **Decorate** on the existing café navigation open the shared full-screen Café Shop. **Café Shop** is also available before Day 1 and on day results. Tabs switch between upgrades and decorations; Back/Escape returns to the originating screen. Settings retains its existing modal/focus behavior. During shifts the shop is view-only, and the authoritative café clock continues. Failed/pending day saves must be resolved before editing.

Scrollable cards show current/max upgrade level, next cost, next Reputation requirement and availability. Buying uses the reviewed current level as a quote. After a purchase the Buy button stays disabled until **Review next level** or explicitly reopening the screen. This prevents double taps from purchasing successive levels. Every backend request also verifies that quote against the persisted level, so replaying it after reload is rejected.

Decoration cards show price, requirement, ownership and compatible slot. Owned items can be displayed/replaced with **Display**, and each slot has **Unequip**. Ownership is retained when replacing or unequipping. A locked shop item granted by a future reward can be displayed once owned; shop Reputation requirements govern buying, not use of an owned item.

## Prototype catalogs

`Data/Cafe/upgrades.json` defines unique IDs, names/descriptions, caps, increasing prices, per-level minimum Reputation, effect type and effect value per level. All values are prototype data, not final balance.

| Upgrade ID | Effect per level | Cap | Costs for levels 1 / 2 / 3 | Café Levels required |
| --- | --- | --- | --- | --- |
| `brewing_equipment` | +3% preparation speed | 3 (+9%) | 60 / 120 / 240 | 1 / 2 / 3 |
| `comfortable_seating` | +3% starting patience | 3 (+9%) | 50 / 100 / 200 | 1 / 2 / 3 |
| `better_ingredients` | +2 final quality points | 3 (+6) | 70 / 140 / 280 | 2 / 3 / 4 |
| `service_training` | +5% ordinary tip amount | 3 (+15%) | 60 / 120 / 240 | 2 / 3 / 4 |

`Data/Cafe/decorations.json` defines original unique items, category, price, minimum Reputation, regular reward classification, optional asset reference, compatible slot and native placeholder symbol/color. No production artwork is added.

| Decoration ID / name | Price | Café Level | Slot |
| --- | --- | --- | --- |
| `pink_paw_plaque` — Pink Paw Plaque | 20 | 1 | Wall |
| `morning_mug_sign` — Morning Mug Sign | 35 | 2 | Wall |
| `mint_leaf_jar` — Mint Leaf Jar | 25 | 1 | Shelf |
| `peach_blossom_vase` — Peach Blossom Vase | 40 | 2 | Shelf |
| `cozy_star_mat` — Cozy Star Mat | 30 | 1 | Floor |
| `strawberry_heart_cushion` — Strawberry Heart Cushion | 45 | 3 | Floor |

`CafeCatalog` validates definitions and provides reusable Reputation/ownership/affordability checks, per-level purchase availability and effect totals. Both JSON files are explicitly included in Web exports. Invalid or unavailable catalogs prevent profile writes rather than silently stripping inventory.

## Transactions and inventory

The existing `CafeProfile` remains authoritative. `purchase_upgrade(id, expected_level)` validates ID, quote, Reputation, funds and cap, then saves Coins and the next level together through the existing staged commit. Persisted levels provide idempotency: an old quote cannot buy another level. A transaction guard prevents reentrant change signals from buying twice. No refund/reallocation system is added.

`purchase_decoration(id)` checks requirements/funds and unique ownership, then saves the deduction and inventory addition together. Repeated purchases reject without a charge. `grant_decoration(id)` is the shared future seasonal/lottery/reward entry point: it grants the same unique inventory ID without Coins or shop Reputation requirements; already owned returns success without a new write, charge or duplicate. This step does not implement reward distribution or redemption. Grants may add ownership during a shift but never equip anything or affect gameplay.

`equip_decoration(slot, id)` accepts only owned compatible items; an empty ID unequips. Repeat assignments are idempotent. The profile also enforces an in-process active-shift lock for purchases/equipment, in addition to the scene's phase guards. A completed shift releases it; leaving the scene abandons the runtime lock. It is not restored on launch because unfinished shifts are not resumed. Starting another day retains existing durable shift/service identity rules.

Every mutation is validated and committed before publishing memory/signals. Failed save writes leave Coins, upgrade levels, inventory and equipment unchanged. The shop shows success or the exact purchase/save rejection. Expected shop errors are consumed by shop feedback so they cannot appear as false customer-service save failures elsewhere.

## Gameplay stacking

Upgrade totals are captured once when Start Day succeeds, before the first arrival. Reopening screens or gaining Reputation cannot apply them again or change the in-flight shift. All cat definitions and recipe base rewards remain unchanged.

- **Patience:** `starting patience = base patience × (1 + cat passive patience + seating bonus)`. This becomes the order's original maximum; Mochi's threshold and restoration use that upgraded value.
- **Preparation:** `target seconds = recipe target / (1 + cat passive speed + equipment bonus + applicable active speed)`. The active snapshot remains specific to that draft. The actual stopping/scoring target and progress display use it. Momo's timing-forgiveness calculation is unchanged.
- **Quality:** compute the existing recipe score, add cat passive points and ingredient-upgrade points, clamp to 0–100, then apply qualifying Blaze conversion only with complete ingredients. Final quality is capped at 74 if any required ingredient is absent; determine tier and XP afterward.
- **Ordinary tip:** `floor(base price × quality tip rate × (1 + cat passive tip bonuses + training bonus))`. The modifier increases the ordinary tip amount, not the base price or tip-rate percentage points. Step 13A carries the unpaid incremental bonus into a persistent fixed-point remainder; see [settlement rules](BalanceCorrections13A.md).
- **Odin premium:** separately `floor(base price × 15%)` when its existing service eligibility/cooldown permits. Training and ordinary-tip passives do not multiply it. Existing exactly-once service commits apply the total Coins and tier XP.

Example: all upgrades at level 1 with Fade active and Max supporting give +28% speed (20% active + 5% passive + 3% equipment), so Basic Coffee targets `3 / 1.28` seconds. With Odin active, Fade support, training level 1 and a 100-Coin Perfect recipe fixture, ordinary tip is floor(15 × 1.15) = 17; premium is 15; service pays 132 and 15 XP.

## Fixed displays

Three stable IDs are used: `wall_display`, `shelf_display`, `floor_display`. `DecorationDisplay` adds non-interactive 48×48 native symbol plaques to the existing Stage coordinates `(335,370)`, `(355,610)`, `(360,684)`. It inherits the café's uniform transform. No environment scene/script, furniture, seat marker, camera or character PNG is changed. It draws only equipped items and redraws on profile changes. There is no freeform editor, dragging or item physics.

## Save schema and migration

Schema **2** extends the existing save with:

```json
{
  "upgrades": {"brewing_equipment": 1},
  "owned_decorations": ["pink_paw_plaque"],
  "equipped_decorations": {
    "wall_display": "pink_paw_plaque",
    "shelf_display": "",
    "floor_display": ""
  }
}
```

Valid schema 0/1 profiles migrate with zero upgrades and empty inventory/displays. Coins, Reputation, day counts, team, Level 50 cycles and pending entitlements are preserved. The existing staged write, recoverable backup and original-file archives are reused. Migration persists on the next meaningful transaction, without charging for new fields.

Loaded upgrade IDs must exist; invalid negative/fractional levels reset to zero (absent entry), and integral levels above a configured cap clamp to that cap with diagnostics. Decoration IDs deduplicate and unknown IDs drop. Unknown slots drop; unowned/incompatible display assignments clear. Missing/wrong container types recover to valid empty structures. Other permanent state is retained by normalization; the existing backup policy still prefers a complete valid checkpoint when the primary requires repair.

JSON numeric conversion from integral floats to integers is normalization, not corruption. Tests specifically protect against incorrectly selecting an older backup after a valid upgrade purchase. Future unknown schema versions remain write-blocked. Test saves stay isolated in unique `/tmp/paw-shop-tests-...` directories; no player save is read or overwritten by script runners.

## Files and scope

Added `Data/Cafe/upgrades.json`, `Data/Cafe/decorations.json`, `Scripts/Gameplay/cafe_catalog.gd`, `cafe_shop_screen.gd`, `decoration_display.gd`, `Scenes/Gameplay/CafeShopScreen.tscn`, `Tools/validate_cafe_shop.gd`, Godot UID sidecars, and this document.

Extended `Scripts/Persistence/cafe_profile.gd`, `Scripts/Gameplay/cafe_session.gd`, `gameplay_view.gd`, `Scenes/Gameplay/GameplayView.tscn`, `DayResults.tscn`, `export_presets.cfg`, the current-schema assertion in `validate_profile.gd`, and documentation links. Other dirty files are existing unfinished Steps 5–8 work.

No cat adoption, cosmetic equipment, seasonal reward system, lottery gameplay, furniture editor or new recipes are implemented. Current balance is deliberately provisional. Decorations use small marker symbols and do not grant gameplay bonuses. Browser exports, real devices and browser storage behavior remain unverified; this step inherits the existing local-save backup and single-writer limitations.

## Validation commands

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://Tools/validate_cafe_shop.gd
godot --headless --path . --script res://Tools/validate_profile.gd
godot --headless --path . --script res://Tools/validate_cats.gd
godot --headless --path . --script res://Tools/validate_drinks.gd
godot --headless --path . --script res://Tools/validate_day.gd
godot --headless --path . --script res://Tools/validate_gameplay.gd
godot --headless --path . --script res://Tools/validate_foundation.gd
```

### Completed checks

Godot 4.6.3 headless import and normal title startup passed. The shop runner passed **451 assertions** both headlessly and with native GL Compatibility, including 720×1280 mouse, 320×568 simulated touch, keyboard purchase/equip, and desktop resize checks. Existing runners passed **196 profile**, **259 cat**, **1,111 drink**, **62 shift**, and **430 gameplay UI** assertions, plus foundation checks across eight viewports. No script/resource errors were reported. Native Xvfb/Mesa reports only its unsupported V-Sync setting warning.

Two separate normal-startup processes under isolated user storage confirmed Coins, upgrade levels, paid/granted ownership and both equipped slots survive exit/relaunch. Native screenshots of upgrade cards, purchase review, inventory, fixed displays, read-only shops and results were inspected at both target portrait sizes. Checksums confirmed all **68 protected** artwork/reference/shared UI/environment/cat/recipe resources unchanged. The original drink scoring script also remains unchanged. Existing uncommitted work is retained; no commits or pushes were made.

The documented prototype choices are additive bonus stacking, quote-based upgrade requests with explicit next-level review, unique (non-stackable) decoration ownership, free reward grants independent of shop unlocks, and fixed marker slots. No requested system was deferred; the only visual assets are intentionally simple native placeholders.
