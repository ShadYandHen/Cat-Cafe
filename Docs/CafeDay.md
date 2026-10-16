# Café shifts (Step 5)

Step 8 adds [persistent progression, saves, and pre-day team setup](PlayerProfile.md); the details below also record the earlier step’s implementation.

Step 6 extends preparation and rewards; see [Drink preparation](DrinkPreparation.md) for current recipes, controls and scoring.

Run `project.godot` in Godot 4.6.3 and press F5 → Play. Day 1 starts at 120 Coins with a guest immediately seated. Further guests arrive on a seeded schedule: 25–35 seconds normally, 10–15 during Rush. A full café skips an arrival; nothing queues or stacks. There are two existing seat markers and no new furniture or moving characters.

## Play a shift

- Tap a numbered guest to accept their requested drink. Pink means waiting to order, gold means pending drink, mint means ready to serve. Each badge shows its order number and remaining patience.
- Tap **Prepare**. When multiple accepted/ready orders exist, the station shows numbered order-selection buttons. Select the intended order, select ingredients, manually stop the recipe process at its target, then Assemble drink.
- Return and tap the matching guest to Serve drink for its recipe base value plus quality tip and daily XP. Other customers cannot receive that drink. You can have a ready drink for each order; there is no general inventory system.
- Back/Escape or switching selected orders discards unfinished brewing, including a stopped process that has not been assembled. Already-finished drinks remain bound to their customers until served or expired.
- Each guest has 60 seconds from arrival, including time before acceptance. Time continues in order, station and Settings interfaces. Expiry releases only that guest's seat and invalidates their order/drink. If a selected guest leaves, choose another available order or return to the café.

## Five-minute day

| Elapsed | Remaining | Phase | Arrivals |
| --- | --- | --- | --- |
| 0:00–2:00 | 5:00–3:00 | Opening | Normal |
| 2:00–3:00 | 3:00–2:00 | Rush Hour | Faster |
| 3:00–5:00 | 2:00–0:00 | Late service | Normal |
| 5:00 onward | 0:00 | Soft closing | None |

The café status HUD displays countdown, phase, active guest count and feedback. Rush uses a gold status panel. All order/station screens also show the day clock and selected customer's patience. Soft closing keeps existing guests serviceable until every guest is served or loses patience; overtime patience/brewing still advance.

Results show day number, served/lost guests, earned Coins and total Coins. **Start Day N** starts a new shift without reloading scenes. It preserves accumulated Coins, resets counters/clock/temporary state, increments the day number and resumes normal arrivals. Day number and Coins are runtime HUD values; Level remains 1. Nothing is saved across application restarts.

## Architecture

`CafeSession` remains owned by `Main.tscn`; no autoloads were added. `CafeOrder` is a small RefCounted record with customer/order IDs, seat, requested drink, status and patience deadline. IDs are never reused within a session, including across days. Terminal orders remain available for the current day's reporting and are cleared on the next day.

One authoritative `elapsed` clock advances in `CafeSession._process`. It drives phase boundaries, seeded arrival scheduling, each customer's independent deadline, and the selected preparation's elapsed time. The old single-customer Timer was removed; there is no second patience/day clock. `advance_time` resolves events chronologically so large/accelerated ticks and normal frame ticks produce the same schedule. Expiry is resolved before new arrivals at the same timestamp; closing is applied before an arrival scheduled at exactly 300 seconds. Phases reset the arrival cadence to the corresponding interval. The clock continues past 300 only to finish the soft close, then freezes on results.

`GameplayView` binds the model to two reusable Customer buttons at the existing left/right seat markers, equipment interaction, OrderScreen, CoffeeStation and DayResults. Its responsive positioning keeps the 720×1280 canvas, centered desktop portrait, 16px essential interface text, 14px order captions and at least 44px touch targets at tested sizes. The shared title, theme, Settings, bottom navigation and official artwork are unchanged.

## Validation

From the repository, using the README's sandbox XDG overrides when necessary:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://Tools/validate_day.gd
godot --headless --path . --script res://Tools/validate_gameplay.gd
godot --headless --path . --script res://Tools/validate_foundation.gd
```

`validate_day.gd` accelerates the same production clock to exercise a full shift, independent orders, selection cancellation, expiry, soft-close service, exact rewards, result counters, next-day reset, stale actions, and coarse/fine timestep equivalence. `validate_gameplay.gd` uses mouse events at 720×1280 and simulated touch at 320×568 for two orders, selection, service, results and next day. It also tests live runtime clock advancement inside station/Settings, keyboard control, focus, and interface bounds/overlap. Foundation checks cover the existing eight viewport sizes.

Balance values are prototype exports on `CafeSession`; the default seed is 417 (offset by day). Native Godot screenshots were inspected. Browser/device, high-DPI safe areas, and long real-time playtesting remain unverified. Step 6 adds recipes, quality scoring and daily XP; cat abilities/movement, permanent reputation levels, upgrades, cosmetics and persistence remain unimplemented.
