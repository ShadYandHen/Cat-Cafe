# Step 16A — Front-facing café

## Result and scope

The main service view now has one layered room: warm panelled walls, a daylight
window, cup shelves, lamps and plants, a central approved cat illustration behind
one timber counter, four visible preparation appliances, and two front-facing seats.
This replaces the previous side-view prep counter/customer nook with a large text
status panel. The title screen, full-screen preparation screens, Settings, bottom
navigation styling and all gameplay systems are retained.

The production session, recipes, cat roster/abilities, profile/schema 5, transactions,
upgrade values, rewards, Model B scheduling and Step 13A scoring are unchanged.
No artwork was generated or edited. No commit or push was made.

## Files

Modified:

- `Scenes/Environment/Cafe.tscn`: barista TextureRect, foreground counter and repositioned stable markers.
- `Scripts/Environment/cafe.gd`: native front-facing room drawing, aspect-preserving stage layout, approved cat texture selection.
- `Scenes/Gameplay/Customer.tscn`: order bubble, independent patience bar and action-state label.
- `Scripts/Gameplay/customer_placeholder.gd`: original native rabbit/bear placeholder variants.
- `Scenes/Gameplay/GameplayView.tscn`: four reusable equipment instances.
- `Scripts/Gameplay/gameplay_view.gd`: presentation/input routing, compact status, state-driven barista/guest rendering and responsive placement.
- `Scripts/Gameplay/decoration_display.gd`: display locations outside interactive regions; narrow floor marker in central aisle.
- `Scenes/UI/TopHUD.tscn`, `Scripts/UI/portrait_layout.gd`: single-line stat chips with readable minimum sizes; original safe-area calculations retained.
- `Tools/validate_gameplay.gd`, `Tools/validate_profile.gd`: exact display expectations updated from two-line to single-line Day/Level labels; reward/data assertions retained.
- `Tools/validate_integration.gd`: next-day preparation chooses the appliance matching the recipe rather than treating Coffee as a generic entrance.

Added:

- `Scenes/Environment/StationEquipment.tscn`, `Scripts/Environment/station_equipment.gd` and UID: reusable native appliance presentation.
- `Tools/validate_cafe_visuals.gd` and UID: isolated scene/input/geometry tests and optional screenshots.
- `Tools/validate_playtest_exports.gd.uid`: Godot-generated stable script identity from importing the existing Step 15 tool.
- `Docs/.gdignore`: prevents documentation CSVs from being imported as translation resources.
- This report.

Import exposed a pre-existing Step 15 issue: `PlaytestFeedback.csv` was interpreted
as localization and produced `bucket_table_size == 0` errors. Ignoring Docs fixes
that import error without altering the feedback file. Newly generated CSV import
sidecars from that failed import were removed; no pre-existing files were deleted.

## Scene hierarchy

```text
Main
├── Content/Layout
│   ├── TopHUD (name, Settings; Day / Coins / Level chips)
│   ├── Welcome (Reputation progress)
│   ├── Cafe                         # fixed 680 × 760 presentation coordinates
│   │   └── Stage                    # uniform fit, centered; no gameplay clock
│   │       ├── PrepStation / CustomerSeatLeft / CustomerSeatRight / CatRest
│   │       ├── Barista              # approved TextureRect, KEEP_ASPECT_CENTERED
│   │       ├── Counter              # foreground native wooden counter
│   │       └── DecorationDisplay    # passive, saved ownership/slot assignments
│   └── BottomNavigation             # unchanged five controls
├── CafeSession                      # unchanged authoritative gameplay
├── GameplayView
│   ├── Customer / CustomerRight
│   │   ├── Bunny                    # native rabbit / bear placeholder
│   │   ├── Caption                  # complete recipe name, max two lines
│   │   ├── Patience                 # remaining / original patience
│   │   └── State                    # Take order / Preparing / Serve drink; low !
│   ├── CoffeeEquipment / MilkEquipment / TeaEquipment / ColdEquipment
│   ├── Status                       # countdown, phase, active ability status
│   └── existing order, station, lobby, results, team, shop and reward interfaces
└── SettingsPanel                    # unchanged behavior and focus restoration
```

The room wall/floor are drawn behind the Stage; its barista precedes the counter.
The gameplay interaction controls sit above the room. Foreground counter/appliances
naturally obscure the lower body, with faces and recognizable upper-body details
kept visible. Textures use the complete source image without region cropping,
recoloring, resizing the source file, or changing its proportions.

## Approved character references

The active cat's existing roster `artwork` path is authoritative:

- `Assets/Characters/mochi_official.png`
- `Assets/Characters/fade_official.png`
- `Assets/Characters/momo_official.png`
- `Assets/Characters/odin_official.png`
- `Assets/Characters/max_official.png`
- `Assets/Characters/blaze_official.png`

The TextureRect changes after a valid team selection before a shift. All six are
checked against their roster paths. Cat controls remain stationary; no movement,
manual ability button or support automation was added. The main HUD displays the
active cat name and Ready/countdown; the existing session still activates abilities
automatically. Full ability descriptions remain in Cat Team.

## Customer, patience and order presentation

Empty seats remain native furniture; no inactive button intercepts input. Occupied
seats show a cream rabbit or brown bear, a full recipe bubble, a patience track and
an explicit action. These woodland figures are temporary originals, not official
cat illustrations or final customer art. The invisible native Button text supplies
a detailed accessible name; tooltip text includes order ID and remaining seconds.

Selection uses a thicker bubble outline, keyboard focus its visible outline, and
ready drinks a green outline plus **Serve drink**. Low patience uses a darker bar
and a visible **!** prefix, not color alone. Bars read `order.remaining(session.elapsed)
/ order.original_patience`; no visual timer is introduced. Served/expired customers
are hidden when the authoritative seat is released; the existing order interface
continues to show quality and reward previews, and the Coins HUD reflects settlement.

Order bubbles preserve all eight complete recipe names. Two-line wrapping is tested;
no ellipsis or category-only substitution makes similar orders indistinguishable.
Detailed ingredients/preparation remain in the existing station UI.

## Equipment and HUD

Four simple native appliance controls represent a coffee machine, milk bottle,
teapot and iced glass. Each retains a text caption, mouse/keyboard focus and 48px+
height. The shorter visible Cold caption has a full Cold Drinks accessible name.
Tapping an appliance calls the existing `open_station` then `select_station`;
the bottom Prepare control retains the original recipe-aware generic entry.

There are **no existing production station unlock requirements**: all four categories
are currently available. No new locks or progression rules were invented. Disabled
appliances reject activation; the existing session still rejects opening outside a
valid café view. Existing preparation/cancel/order-switching logic is unchanged.

Day/Coins/Level are now single-line chips. Reputation remains visible; the café
status is a concise countdown/phase/active-cat line. Only the main HUD shortens
“30s cooldown” to “30s”; detailed station/ability descriptions remain unchanged.
The bottom five navigation entries and their responsive styling are retained.

## Responsive decisions and fixes

- Keep 720×1280 reference resolution, centered portrait desktop column and the
  existing browser/Android safe-area code.
- Uniformly fit the café's 680×760 coordinate system without distorting art.
- Give guest targets at least 112 screen pixels height and appliances at least
  48 pixels height; all tested targets exceed 44×44 pixels.
- Keep important HUD/progress text 16px+; order/action/appliance captions 14px+
  on the smallest phone, with larger native sizes on the reference viewport.
- Scale customer faces with available seat space rather than fixing them at 40px
  on the reference viewport. Both faces remain at least 35px high on small screens.
- Reflow when session view/occupancy changes. This fixes a discovered inherited
  three-line caption minimum that initially shrank the second customer's face.
- Reserve separate non-overlapping appliance and guest hit regions. Fixes from
  screenshot/testing include the initial phone row overlap, desktop caption heights,
  and a floor-decoration marker intruding on the left guest's target.
- Single-line phase/ability status avoids hiding the top of the barista, including
  Late service with a running cooldown. No scrolling is needed for café service.

## Validation

All 14 headless suites pass: Foundation; Day; Drinks; Cats; Profile; Shop; Lottery;
Seasons/Challenges/Inbox; Gameplay UI; Integration; Step 13A; Step 14; Export checks;
and the new Café Visuals suite. Existing numerical suites total 8,171 assertions,
plus 26 export assertions and the final 916 visual assertions (9,113 combined,
with the separate eight-viewport Foundation checks).

The new suite covers all six approved textures, uniform/aspect-preserving placement,
barista prominence, both customer regions/faces, all eight full recipe labels,
independent patience, low-patience text, prepared-drink feedback, expiration,
all four appliance routes, disabled appliance protection, Rush/late-service cooldown
HUD, Settings focus/clock continuity, and pre-shift team changes. It uses isolated
profiles and injected session advancement, never real player saves.

Graphical checks use Godot 4.6.3 with Xvfb/Mesa software rendering, mouse and simulated
touch, at 720×1280 and 320×568. The full graphical integration journey passes **740
assertions**, including full accelerated shifts, service, team, shops, upgrades,
collections, seasonal claims/Inbox, Settings and wider desktop resizing. A second
process cold-loads the saved journey checkpoints: **17 assertions**. Native visual checks pass **942 assertions**, and their
captures verify empty/one/two guests, low patience, ready drink, Rush, equipment and
all six baristas. Screenshots were inspected, and the layout issues above corrected.

Both Windows and Android debug exports complete with the existing Step 15 presets.
The exported Windows PCK contains 134 checked entries; Android 136 game assets.
The payload verifier checks all runtime catalogs, PCK checksums, both Android ABIs,
and exclusion of development tools, documentation, references and signing keys.
APK v2/v3 signing verification succeeds. No export configuration changes were needed.

Reproduce the visual tests:

```sh
# Set isolated XDG_DATA_HOME / XDG_CONFIG_HOME / XDG_CACHE_HOME first.
godot --headless --path . --script res://Tools/validate_cafe_visuals.gd
# Under an available native display, omit --headless:
godot --path . --audio-driver Dummy --script res://Tools/validate_cafe_visuals.gd -- --capture-dir=/tmp/paw-16a-screenshots
```

Review evidence is outside production exports and Git:
`/workspace/paw-pads-playtest-builds/step-16a/`.

- `screenshots/`: full-resolution PNGs; `review-contact-sheet.png` offers a quick comparison.
- `validation/`: suite results, native checks, cold reload, import/export and preservation logs.
- `windows/`, `android/`: actual debug re-exports used for payload checks; platform execution remains unverified.

## Limitations and Step 16B

Some approved PNGs retain white/red edge residue or floor ovals. These are visibly
inherited transparency imperfections and were deliberately not edited. Counter
occlusion is a display layer, not a destructive crop. Background/furniture,
customers, appliances and decoration markers remain simple temporary native artwork;
this is not a finished painted environment. The rabbit/bear are placeholders, not
approved final character designs. The title and full-screen station art are outside
this step; Step 16B can polish dedicated preparation screens later.

No physical Android or native Windows gameplay was tested. Native safe-area geometry
and export configuration remain checked, but device cutouts, actual touch hardware,
platform performance and OS suspend/resume still require hands-on testing. Xvfb's
unsupported VSync warning is a host limitation. Android's existing host adb failure
(read-only `/home/agent/.android`) does not block APK export; the previously documented
unused themed-icon resource warning remains. Automated checks and screenshots do
not establish whether the café feels cozy or fun to a human playtester.
