# First playable customer-service loop

This is a historical description of the original Step 4 loop (its Basic Coffee controls and fixed reward have been superseded by [Step 6 preparation](DrinkPreparation.md)), now extended into recurring multi-customer shifts. See [Café shifts](CafeDay.md) for the current play instructions, timing, order selection, results and tests.

1. Tap/click the bunny **Guest** badge at the existing left seat.
2. Choose **Accept Order** for Basic Coffee.
3. Tap/click **Coffee** over the existing coffee machine.
4. Choose **Start brewing**, wait for the progress bar (3 seconds), then choose **Finish coffee**.
5. Back in the café, tap the guest and choose **Serve Basic Coffee**.
6. Coins change from 120 to 130 exactly once and the guest disappears.

Patience starts at 60 seconds when the café opens, including time before accepting. It continues in the order screen, station, and Settings. On expiry the guest disappears, brewing/ready coffee cannot be rewarded, and the active interface explains what happened. Back/Escape returns safely to the café. Leaving the station before finishing discards preparation progress and creates no drink. Finish records the drink but does not serve it automatically.

The original prototype had one guest and one order per scene instance; Step 5 replaces that limitation with repeatable shifts. Its original scope excluded no automatic next guest, saving, daily timer, quality scores, cat movement, abilities, other drinks, or progression is implemented. Bottom navigation remains unchanged placeholders. Settings is available from both gameplay interfaces, with its existing close/focus behavior. Enter activates focused buttons; Escape closes Settings first, or returns from the current gameplay interface.

## Architecture

- `Scenes/Gameplay/CafeSession.tscn` / `Scripts/Gameplay/cafe_session.gd`: scene-owned session state, session clock, customer orders, coins, transition guards, and signals. Step 5 replaces the original single patience Timer with independent deadlines on the shared day clock. Current session defaults: starting Coins 120 and patience 60 seconds; recipes now own Coin values and preparation targets.
- State flow: `WAITING_ORDER → ORDER_ACCEPTED → DRINK_READY → SERVED`. Any active state can transition to `DEPARTED` on expiry. Terminal states cannot earn another reward.
- View flow: café ↔ order, café ↔ station; accepting/finishing/serving return to the café. Expiry keeps an open interface visible with departure feedback and Back enabled.
- `GameplayView.tscn` / `gameplay_view.gd`: input wiring, runtime HUD binding, focus, responsive layout, and presentation. It reads the existing stage transform/seat marker to position stationary customer and equipment interactions.
- `Customer.tscn`: native bunny placeholder button; none of the official cat artwork is altered or deployed as a gameplay actor.
- `OrderScreen.tscn`, `CoffeeStation.tscn`: separate full-screen interfaces with a centered portrait column, 16px minimum essential text and 48px minimum action heights at tested sizes.
- `Main.tscn` owns the session and gameplay view. Its existing Settings panel remains above the gameplay screens. No autoload was added; the responsive base script and environment are unchanged.

## Repeatable checks

Use the sandbox XDG directory overrides described in the main README when necessary.

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://Tools/validate_foundation.gd
godot --headless --path . --script res://Tools/validate_gameplay.gd
```

The gameplay runner uses actual mouse events at 720×1280 and emulated screen-touch events at 320×568 for the complete service loop. Short configurable Timer values exercise expiry in the café, order screen, station, ready-drink state, and Settings. It also checks early/duplicate actions, Back cancellation, zero-time service, keyboard control, focus, readable interface bounds, and the compact status panel. These simulated inputs and native Godot rendering do not establish real browser/device behavior; those checks remain outstanding.
