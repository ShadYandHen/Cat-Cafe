# Step 16L — Official landscape conversion

## Decision and scope

Paw Pads Café is now a mobile-first, landscape-only game. Reference: 1280×720;
supported phone shapes: 16:9 and wider. Windows remains a windowed playtest target.
The front-facing café, stationary barista and two customer positions remain.
This conversion adapts the existing uncommitted Step 16B visual preparation rather
than discarding it. No Step 16C work, gameplay systems or balance changes were added.
No commit or push was made.

## Configuration

| Setting | Before | Now |
| --- | --- | --- |
| Reference viewport | 720×1280 | 1280×720 |
| Default desktop window | 432×768 | 1152×648 |
| Android orientation | Portrait (1) | Landscape (0) |
| Rendering | GL Compatibility | Preserved |
| Stretch | canvas_items / expand | Preserved |
| Main scene | Scenes/Title.tscn | Preserved |
| Save schema | 5 | Preserved |

`expand` uniformly scales the reference canvas and adds horizontal logical room
on wider phones. Content fills the usable landscape canvas instead of a centered
720-unit column. Artwork is aspect-fitted; no original images were edited.
The Windows playtest helper now fits a 16:9 window up to 1280×720 within 90% of the
usable display. Android, editor, Linux and explicit CLI sizes are not overridden.

Android's existing export preset inherits the project orientation: no duplicate
preset orientation setting was introduced. The generated manifest was inspected:
`screenOrientation=0`, debug application ID `org.shadyandhen.pawpadscafe.playtest`.

## Shared layout and safe areas

`Scripts/UI/portrait_layout.gd` retains its existing resource path for compatibility,
but now owns the landscape safe canvas. It converts native screen/window pixel
insets into logical units. Android intersects the app window rectangle with
`DisplayServer.get_display_safe_area()` so an already inset window is not inset
a second time. Missing platform data yields zero insets. The existing Web CSS
`env(safe-area-inset-*)` fallback remains; Web is not a validated release target here.

Tests inject asymmetric left/top/right/bottom window-pixel insets of 60/18/36/12.
Café controls, dialogs, menu content, stations and Settings all follow the same
usable rectangle. This proves layout geometry, not physical cutout behavior.
Root and window resize events reflow the canvas; reopening hidden content triggers
another layout pass. A short settling pass accommodates wrapped-label minimum sizes.

Fonts and targets adapt using window-pixel scale. Primary preparation actions are
64 pixels high, Back 48, station tabs 48, ingredient targets 64, and Settings at
least 44. These are rendered-window measurements, not physical-device DPI claims.

## Café composition

The scene-owned stage changes from 680×760 to 1280×520 presentation coordinates.
It is uniformly fitted within the space below the HUD and above secondary navigation.
The room includes a central window, warm counter, shelves, lamps and native plants.
The active approved cat is centered behind the counter. Coffee/Milk equipment sit
to the left; Tea/Cold to the right. Two seated customer positions occupy the foreground.
Existing decoration slots are repositioned without changing their stable IDs,
ownership, compatibility or saved assignments.

The compact HUD places the café name and Settings alongside Day, Coins and Level.
The second line separates shift/phase/ability status from Reputation progress.
Four secondary navigation entries remain: Upgrade, Decorate, Cat Team and Map.
There is no redundant Prepare control. Map retains Golden Paw/Collections access,
including the existing Seasonal Pass and Inbox route.

Customer tickets remain automatically visible above occupied seats. Their actual
recipe, selection outline, Prepare/Serve cue, patience bar and non-color waiting/
low-patience text reflect CafeSession. Body taps retain optional order inspection.
Press-down IDs, departed-order checks and manual service transactions are unchanged.

## Preparation stations

All four categories retain the shared CoffeeStation scene and Step 16B renderer:

| Region | Content |
| --- | --- |
| Left | Four station tabs, requirements, two-column scrollable ingredient palette |
| Center | Prominent live cup, recipe name, authoritative timing guide and completion state |
| Right | Order/patience context, independent order selection, Start/Stop/Assemble, Back |

Settings stays at the top right. The cup remains pinned while ingredients scroll.
Coffee, Milk, Tea and Cold retain their existing ingredient colors, layers, ice,
foam, steeping/pouring/mixing feedback and completed-ticket previews. The timing
guide remains tied to the session's actual elapsed/target values; no second timer,
automatic stop or new preparation step was introduced. Assembly still returns
immediately to the café, and serving still requires the Ready → Serve ticket.

At 960×540 (an additional stress-test size), the palette may require a short vertical
scroll. Ingredient minimum heights are rounded to whole logical units so the last
row can be fully revealed instead of remaining fractionally clipped.

## Menus and title

| Screen | Landscape adaptation |
| --- | --- |
| Title | Logo/tagline and Play/Settings left; aspect-fitted official Mochi right |
| Before opening | Profile summary left; Start Day, Team, Shop and Settings right |
| Guest details | Recipe/order context left; existing actions and Back right |
| Results | Detailed earned values left; next-day and supporting actions right |
| Cat Team/roster | Status/navigation sidebar; slots/summary and two-column roster right |
| Shop/upgrades | Status/sidebar, existing tabs, two-column upgrade cards |
| Decorations | Existing slots and two-column inventory cards; same purchase/equip handlers |
| Lottery | Status/sidebar, tabs, full-height reward/roll/history content |
| Collections | Existing ownership/equipment content in the right scroll region |
| Seasonal Pass | Status/sidebar, Pass/Inbox tabs, full-height milestones and challenges |
| Challenges | Existing daily/weekly progress stays inside the Pass content |
| Reward Inbox | Existing non-expiring claim list in the right scroll region |
| Reputation | Existing HUD, before-opening/results progress and Level 50 bookkeeping retained |
| Settings | Centered shared modal inside the safe rectangle; focus restoration retained |

`landscape_menu.gd` shares sidebar/dialog geometry; domain screen scripts retain
existing callbacks and profile transactions. Long catalogs still scroll vertically;
Back and Settings remain pinned. Roster and shop cards expand to use both columns.
Shared pastel styles keep their colors, rounded corners and interaction states;
vertical button padding is reduced to fit landscape targets without oversized panels.

## Input and gameplay preservation

Mouse, keyboard/focus, Escape, simulated touch and existing Settings behavior remain.
There is no hover-only requirement, joystick, cat movement or automated support service.
No platform-specific gameplay branch was added.

The preservation audit compares all pre-existing files against the task-start hashes.
All original illustrations, runtime catalogs, session/scoring/cat models, persistence
code and export presets remain byte-identical. The Step 16B cup renderer and artwork
mapping are also byte-identical; their presentation container was adapted.

Production behavior remains: 300-second shifts, two seats, normal 20–26s and Rush
9–12s arrivals, Rush 120–180s, base patience 75s, eight recipes, the incomplete-drink
cap of 74, Blaze restrictions, fractional ordinary tips, unchanged cat/upgrades,
Coins/Reputation, Seasonal XP 200/150/500 and schema 5. No migration is required.

## Validation

Godot 4.6.3 import succeeds. All 17 headless suites pass: Foundation, Day, Drinks,
Cats, Profile, Shop, Lottery, Seasons, Gameplay, Integration, Step 13A, Model B pacing,
Export configuration, Café Visuals, Order Tickets, Visual Preparation and Landscape.

Orientation-dependent tests now use 1280×720 and 960×540 with mouse/simulated touch;
Foundation also tests all four requested landscape sizes. Gameplay assertions are
retained. The Step 13A results assertion now verifies containment and non-overlap
instead of requiring the description to sit vertically above its action.

The new Landscape suite checks all four requested sizes, asymmetric cutout insets,
two independent tickets, correct station/order association, manual Serve, equipment,
menu/settings navigation, safe bounds and full day results. The graphical run includes
976 assertions and 36 screenshots. Headless includes 940 assertions.

Native graphical Foundation passes five sizes. Native graphical Visual Preparation
passes 2,512 assertions for all eight recipes at reference and small landscape sizes.
Full native integration passes 740 assertions; separate-process save reload passes
17 assertions. Results are recorded in the external validation logs. All profiles use isolated temporary paths or memory.

Both Windows and Android debug exports complete. Windows PCK integrity checks pass
for all 146 entries; the Android archive contains 148 game assets. Runtime JSON
catalogs match the source; development Tools, reference art, documentation and signing
keys are excluded. APK v2/v3 signatures verify. An isolated Linux run of the exported
PCK completes Title → Play → Café → station → preparation → service with landscape
settings. This is packaged-resource validation, not native Windows execution.

Known environment warnings: Mesa does not support VSync switching; the Android host
adb cannot create its default home directory; the prebuilt template retains an unused
themed-icon reference. These do not prevent completed exports. Physical Android
installation/launcher/cutout behavior remains unverified.

## Evidence and running builds

Artifacts are outside the repository and production export inputs:
`/workspace/paw-pads-playtest-builds/step-16l/`.

- `windows/PawPadsCafe.exe`, `.console.exe`, `.pck`: keep together when running.
- `android/PawPadsCafe-debug.apk`: install as a development APK on a test device.
- `screenshots/`: title/café at all four requested sizes, plus safe-area two-customer,
  station, Ready/Serve, team, shop, rewards, season and results captures per size.
- `preparation/`: eight-recipe selected/completed states, brewing, missing ingredients,
  and Ready tickets at 1280×720 and 960×540.
- `Landscape-Review.png`: representative café, station, roster and results overview.
- `PawPadsCafe-Step16L-Screenshots.zip`: screenshot bundle.
- `validation/`: suite results, native checks, cold reload, exports, manifest,
  signatures, packaged-resource smoke test and preservation audit.
- `SHA256SUMS`: build and screenshot-bundle checksums.

Reproduce source checks with isolated XDG paths, `godot --headless --editor --path .
--import`, then `godot --headless --path . --script res://Tools/validate_<suite>.gd`.
For native captures use `--script res://Tools/validate_landscape.gd --
--capture-dir=<external-directory>`. Export with the existing Windows Playtest and
Android Playtest presets; prerequisites remain in PlaytestBuildGuide.md.

## Remaining work

No physical Android or native Windows playtest was performed. Real touch hardware,
cutouts, suspension, device DPI and performance need hands-on validation. Portrait
windows are outside the supported presentation. Temporary native room/customer/drink
visuals remain; approved character transparency imperfections are untouched.

Long catalogs use vertical scrolling. Existing Settings functionality remains a
placeholder. Step 16B visuals already exist and were retained; further illustrated
station polish can follow review of this landscape foundation. No new preparation
mechanics are pending from this conversion. No Step 16C work was done.

## Suite results

| Headless suite | Result |
| --- | --- |
| foundation | PASS: 5 landscape viewports, real stretch, readable labels, touch targets, navigation, settings and theme states |
| day | PASS: 62 accelerated day/order assertions |
| drinks | PASS: 1031 drink system assertions |
| cats | PASS: 257 cat team/ability assertions |
| profile | PASS: 196 persistent profile assertions (isolated paths: /tmp/paw-profile-tests-244553-387233) |
| cafe_shop | PASS: 496 café shop assertions (isolated saves: /tmp/paw-shop-tests-244564-423955) |
| lottery | PASS: 587 lottery and collection assertions (isolated: /tmp/paw-lottery-244574-391236) |
| seasons | PASS: 629 seasonal/challenge/Inbox assertions (isolated: /tmp/paw-seasons-244585-372367) |
| gameplay | PASS: 466 gameplay UI assertions |
| integration | PASS: 728 full integration assertions (artifacts: /tmp/paw-integration-244699-215207) |
| balance_13a | PASS: 523 Step 13A assertions; isolated files: /tmp/paw-13a-regression-244710 |
| balanced_pacing | PASS: 3126 balanced pacing assertions; isolated /tmp/paw-14-regression-244720 |
| playtest_exports | PASS: 26 playtest export assertions |
| cafe_visuals | PASS: 940 café visual assertions |
| order_tickets | PASS: 758 order-ticket assertions; isolated /tmp/paw-16a1-tests-244748 |
| visual_preparation | PASS: 2472 visual preparation assertions |
| landscape | PASS: 940 landscape assertions |

## Files

Compared with the task-start snapshot (which already included Step 16B):

- `Assets/UI/cozy_theme.tres`
- `Docs/LandscapeConversion16L.md`
- `Docs/PlaytestBuildGuide.md`
- `README.md`
- `Scenes/Environment/Cafe.tscn`
- `Scenes/Gameplay/CafeShopScreen.tscn`
- `Scenes/Gameplay/CatTeamScreen.tscn`
- `Scenes/Gameplay/CoffeeStation.tscn`
- `Scenes/Gameplay/DayResults.tscn`
- `Scenes/Gameplay/OrderScreen.tscn`
- `Scenes/Gameplay/RewardsScreen.tscn`
- `Scenes/Gameplay/SeasonScreen.tscn`
- `Scenes/Main.tscn`
- `Scenes/Title.tscn`
- `Scenes/UI/TopHUD.tscn`
- `Scripts/Environment/cafe.gd`
- `Scripts/Gameplay/cafe_shop_screen.gd`
- `Scripts/Gameplay/cat_team_screen.gd`
- `Scripts/Gameplay/decoration_display.gd`
- `Scripts/Gameplay/gameplay_view.gd`
- `Scripts/Gameplay/rewards_screen.gd`
- `Scripts/Gameplay/season_screen.gd`
- `Scripts/UI/bottom_navigation.gd`
- `Scripts/UI/ingredient_button.gd`
- `Scripts/UI/landscape_menu.gd`
- `Scripts/UI/landscape_menu.gd.uid`
- `Scripts/UI/playtest_window.gd`
- `Scripts/UI/portrait_layout.gd`
- `Scripts/UI/preparation_layout.gd`
- `Tools/record_preparation_demo.gd`
- `Tools/validate_balance_13a.gd`
- `Tools/validate_balanced_pacing.gd`
- `Tools/validate_cafe_shop.gd`
- `Tools/validate_cafe_visuals.gd`
- `Tools/validate_cats.gd`
- `Tools/validate_drinks.gd`
- `Tools/validate_foundation.gd`
- `Tools/validate_gameplay.gd`
- `Tools/validate_integration.gd`
- `Tools/validate_landscape.gd`
- `Tools/validate_landscape.gd.uid`
- `Tools/validate_lottery.gd`
- `Tools/validate_order_tickets.gd`
- `Tools/validate_playtest_exports.gd`
- `Tools/validate_profile.gd`
- `Tools/validate_seasons.gd`
- `Tools/validate_visual_preparation.gd`
- `project.godot`
