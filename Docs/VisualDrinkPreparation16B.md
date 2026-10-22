# Step 16B — Visual drink preparation

## Result

All four preparation stations now use a pinned, visual cup workspace, illustrated
ingredient controls and a timing guide. The cup changes as actual ingredients are
selected, fills/pours/stirs during the existing timed interaction, and retains a
finished appearance after assembly. Station tabs, customer identity, ingredients,
Start/Stop/Assemble and Back remain functional with mouse, keyboard and touch.

No recipe, preparation step, timer, score, reward, ability, progression, save schema,
character source art or main café composition was changed. Nothing was committed
or pushed. Step 16C is not implemented.

## Files added or modified

Modified:

- `Scenes/Gameplay/CoffeeStation.tscn`: shared station composition and reusable visual controls.
- `Scripts/Gameplay/gameplay_view.gd`: read-only visual snapshots, pinned station connections, compact descriptions and actual timing/finished-drink feedback.
- `Scenes/Gameplay/Customer.tscn`: a small completed-drink preview inside the existing Ready ticket icon, without changing ticket layout.
- `Scripts/UI/title.gd`: call the Windows-playtest-only window-fit helper on startup; branding/layout/navigation unchanged.
- `Tools/validate_drinks.gd`, `Tools/validate_integration.gd`: updated station-tab paths and scroll helpers for tabs now pinned outside the ingredient scroll area.

Added (with Godot-generated script UIDs):

- `Scripts/UI/drink_art.gd`: shared native ingredient symbols and palette.
- `Scripts/UI/drink_canvas.gd`: shared cup, liquids, ingredient details, animation and timing guide.
- `Scripts/UI/ingredient_button.gd`: icon, readable ingredient name and Needed/Added/Extra feedback.
- `Scripts/UI/preparation_layout.gd`: responsive station layout, pinned workspace and controls.
- `Scripts/UI/playtest_window.gd`: safe initial sizing for Windows playtest exports only.
- `Tools/validate_visual_preparation.gd`: isolated visual/state/input/geometry regression suite and screenshots.
- `Tools/record_preparation_demo.gd`: excluded-from-export, scripted native recording driver.
- This report.

## Shared visual architecture

```text
CoffeeStation                         # shared by all four categories
└── Content/Layout (preparation_layout.gd)
    ├── Heading / Patience / Settings
    ├── OrderChoices                   # existing independent accepted-order selector
    ├── Stations                       # four pinned category tabs
    ├── DrinkWorkspace (drink_canvas.gd)
    │   ├── RecipeName
    │   └── TimingHint
    ├── Description                    # compact, authoritative ingredient requirements
    ├── Workspace (ScrollContainer)    # ingredient palette only; no horizontal scrolling
    │   └── Body
    │       ├── Ingredients            # nine shared ingredient_button.gd controls
    │       └── Progress               # legacy read-only node, hidden; guide replaces it
    ├── Action                         # existing Start / Stop / Assemble handler
    └── Back
```

`CafeSession` is still the sole authority. GameplayView supplies presentation data:
category, recipe/order identity, selected ingredients, elapsed preparation, target,
and authoritative final quality tier. Neither renderer nor layout writes session
state. Ingredient controls call the existing `toggle_ingredient`; the action calls
the original start/stop/finish methods. The core session, quality, abilities,
transactions and save code are byte-identical to the task baseline.

The visual snapshot cache exists only because the existing assembly method clears
its temporary ingredient selection immediately. It retains a copy of the actual
selected ingredients and timing for that order's finished rendering. It is not an
inventory, order manager, timer or save field. Served/departed orders are removed;
new occupants never inherit the previous cup. It never assumes missing ingredients
were added. Mid-shift reload continues the established fresh-shift recovery policy.

## Cup and ingredient rendering

The renderer uses simple original Godot vector shapes, not generated illustrations,
third-party art or edits to official cats. One uniform drawing transform preserves
cup proportions. Native Labels retain legible text at the actual screen scale.

| Existing ingredient | Visual |
| --- | --- |
| Coffee | Brown layer; brown brew and coffee pour |
| Water | Pale blue liquid layer |
| Milk | Cream layer/lightened mixture and illustrative foam |
| Vanilla | Golden flavor layer/stripe |
| Honey | Amber syrup layer/stripe |
| Tea | Amber liquid and teabag/leaf symbol |
| Berries | Pink liquid and berry pieces |
| Ice | Visible pale cubes only when selected |
| Cocoa | Brown liquid/powder details |

Before processing, the cup shows selected layers; during processing they share an
illustrative mixture color. Layer heights/fill amounts are presentation, not recipe
quantities or new scoring inputs. Milk foam is illustrative milk presentation, not
an added topping ingredient. Required, selected, missing and extra states use the
existing public recipe requirements, without revealing scoring weights or new
hidden information.

Ingredient controls retain their names and existing validation. Needed is shown
for an unselected required ingredient; ✓ Added for selected required ingredients;
+ Extra for selected non-required ingredients. Buttons remain disabled when the
existing session forbids selection. Selecting/deselecting changes both the control
and cup; no decorative ingredient is added independently of session state.

## Four station identities

- **Coffee:** warm wooden/cream workspace, ceramic cup, brown layers and an actual
  elapsed-time-driven pour during Brew.
- **Milk:** peach/cream workspace, milk layers/foam and a gentle stirring motion
  during the recipe's existing Heat or Mix action.
- **Tea:** mint/cream workspace, amber tea and teabag when selected; gentle movement
  during existing Steep.
- **Cold Drinks:** pale blue workspace, taller handle-free glass, berry/cocoa colors
  and ice only when selected; existing Chill/Mix timing.

All eight existing recipes share these components. There are no new ingredients,
steps, recipes, unlocks, drag mechanics, fill quantities or automatic preparation.

## Timing and completion

The cup and timeline read `brew_elapsed` and `preparation_target()` from the session.
The marker is exactly the existing ideal stopping time on a display range of twice
the target. It is not a new quality zone: the continuous quality formula and Momo's
forgiveness remain unchanged. The guide shows actual elapsed/target seconds.

Start and Stop retain their original behavior. Stop has a distinct peach action
state and readable action/timer text. Reaching/passing the marker never automatically
stops or assembles. Animation uses the authoritative elapsed value and does not
advance, pause or reset clocks. Patience and the café shift continue normally.

Assembly still returns immediately to the café. There is **no mandatory completion
screen, extra confirmation, forced delay or automatic service reward**. The Ready
ticket shows the actual completed cup and brief sparkles; its existing Serve action
is unchanged. Opening the matching station again shows the full finished cup,
recipe and authoritative tier with Back to café as the next action. The stopped,
ready-to-assemble cup already presents the filled drink before assembly.

The short completion sparkle derives from the session elapsed time since the
presentation observed completion. It cannot affect quality, rewards or transitions.
No reduced-motion setting exists in the current Settings placeholder; none was
invented. Animations remain subtle and do not intercept input.

## Responsive layout and desktop window

At 320×568 the workspace is at least 180 screen pixels high. Recipe/order information,
station tabs, the cup, Start/Stop and Back stay pinned. Only the ingredient palette
scrolls vertically; every ingredient has a 52px+ target and 14px+ name. The compact
palette can show fewer rows with two simultaneous accepted orders; the cup remains
visible during scrolling. Supporting state captions are 12px+.

At 720×1280 the workspace has a larger native minimum, retaining the same uniformly
scaled cup. The overall reference viewport, safe-area code and centered portrait
presentation remain unchanged. Critical buttons retain at least 44px targets.

Confirmed issues corrected during implementation include Settings clipping past
the phone edge, a wrapped description retaining stale height, rounding dropping
station tabs slightly below 44px, and cup text retaining the previous resize scale.
Regression tests cover these regions at both sizes, including the two-order layout.

Windows playtest exports now fit their initial window to 90% of the usable monitor
area, capped at 540×960, preserving 720:1280 proportions. Explicit CLI `--resolution`,
editor runs, Android and other platforms are untouched. Normal window resizing is
retained; the authoritative viewport/project settings are unchanged. This helper's
fit calculation is tested; native Windows OS execution remains unverified.

## Performance

There are no particle systems, large generated textures, network requests or new
dependencies in production. Drawing consists of a small number of vector shapes.
Idle snapshots avoid redundant redraws; ingredient controls do not repeatedly
rebuild layout when their state is unchanged. Text scale changes trigger re-layout.
The presentation cache is bounded by active orders and pruned after departure/service.

Native checks use Xvfb/Mesa software rendering. This is not a physical Android GPU,
battery, thermal or frame-time benchmark. Unsupported VSync warnings are a host
limitation. Actual device performance and touch behavior still require playtesting.

## Validation

All **16 headless suites pass**: the 15 existing suites plus Visual Preparation.
Existing coverage includes all recipes, quality boundaries/caps, Blaze, fractional
tips, cats/upgrades, independent orders, shifts/closing, purchases/rewards, saves,
migration, seasonal systems, ticket stale presses and export configuration.

The new suite passes **2,472 assertions** across 720×1280 and 320×568, including:

- Correct station/category/order and actual ingredient composition for all eight recipes.
- Selection/removal, Needed/Added labels, no fabricated missing ingredients.
- Pinned cup, complete ingredient accessibility, text sizes and non-overlapping controls.
- Real Start/Stop/Assemble behavior and authoritative elapsed/target values.
- No second timer, auto-stop, extra rewards or scoring changes.
- Actual completed ingredient snapshots and ready-ticket previews.
- Expiration, cancellation and stale completion safety.
- Two-order switching, canceled-draft clearing and compact layout.
- Windows fit calculation and no sizing changes to editor/Linux checks.

Native graphical Visual Preparation passes **2,512 assertions**, including 40
screenshots. Full native integration passes **740 assertions** at both portrait
sizes, including complete accelerated shifts and progression/navigation. Separate
process cold reload passes **17 assertions**.

The existing drink test's scroll checks now apply only to descendants of the
palette: tabs moved outside it. Their touch/selection/recipe assertions remain,
and the new suite checks all pinned tab bounds. No quality/reward assertions were
removed or weakened. A clean import passes.

Both Windows and Android debug re-exports complete with the existing presets.
Payload checks verify **144 PCK entries**, **146 Android game assets**, unchanged
runtime catalogs and exclusion of Tools, references, Docs and signing keys. Android
v2/v3 signature verification succeeds. Neither result claims native Windows or
physical Android execution. The existing Android host adb/home-directory and
unused-themed-icon limitations remain as documented in the Step 15 build guide.

## Screenshots and gameplay recording

Evidence is outside Git and production exports:
`/workspace/paw-pads-playtest-builds/step-16b/`.

- `screenshots/empty-coffee-{320,720}.png`
- `screenshots/selected-<recipe_id>-{320,720}.png` for all eight recipes.
- `screenshots/coffee-brewing-{320,720}.png`
- `screenshots/complete-<recipe_id>-{320,720}.png` for all eight recipes.
- `screenshots/missing-ingredient-{320,720}.png`
- `screenshots/ready-serve-ticket-{320,720}.png`
- `screenshots/review-contact-sheet.png` and `PawPadsCafe-Step16B-Screenshots.zip`.
- `PawPadsCafe-Step16B-Demo.mp4`: approximately one minute, 720×1280, H.264, 24fps,
  no audio. Full decode verification passes.
- `validation/`: suite, native, recording, import/export, signature and preservation logs.
- `windows/`, `android/`: actual development re-exports used for validation.

The video is a **scripted native Linux playtest**, not a human playtest or Windows/
Android device recording. It uses real mouse input and the normal session clock,
with an isolated in-memory profile and a one-customer fixture schedule to show four
stations clearly. It demonstrates Vanilla Cloud Coffee, Honey Hug Milk, Honey Blossom
Tea and Berry Breeze: tickets, selection, brewing, Stop/Assemble, completed-cup
inspection and manual Serve. All four reach 100 quality; Coins progress
120→136→149→162→175. Fixture scheduling and cat-effect isolation are confined to
`Tools/record_preparation_demo.gd`, which is excluded from exports. It does not
change production pacing, abilities or balance.

## Remaining limitations

Drink/ingredient artwork is temporary native vector presentation. Texture polish,
more expressive pouring/mixing and audio are future opportunities, not new mechanics
in this step. The existing official cat transparency imperfections are untouched.

On the smallest phone, ingredient rows may require a short vertical scroll,
particularly with two accepted orders. The timeline is a linear guide rather than
an asserted Perfect zone. The normal assembly transition remains immediate; the
large completed cup is inspectable in the station and its miniature appears on the
Ready ticket. This preserves the agreed flow without an extra mandatory screen.

Real phone cutouts, touch hardware, platform suspension, Windows drivers and device
performance remain unverified. The next human recording should evaluate whether the
pinned cup, ingredient palette, timing guide and completed-ticket feedback feel clear
and satisfying; automated assertions cannot establish enjoyment.
