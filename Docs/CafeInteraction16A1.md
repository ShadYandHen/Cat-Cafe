# Step 16A.1 — Customer tickets and simpler navigation

## New café flow

**Customer arrives → visible order ticket → tap Prepare → matching full-screen
station → assemble → return to café → tap Serve on that customer's ticket.**

The first ticket tap selects and accepts that exact order using the existing session
transitions. The Guest Order screen is not displayed for this path. An already
accepted order reopens its matching station; a ready drink displays **Serve**, which
is an explicit manual action through the existing guarded `open_order`/`serve`
transaction. Preparing and assembling never automatically serve a customer.

Existing Back/cancel behavior is retained: leaving a station cancels an unfinished
draft, while an assembled drink stays associated with its order. Patience, arrivals,
Rush, closing and cooldowns continue under the existing session clock.

## Changed files

- `Scenes/Gameplay/Customer.tscn`: reusable Ticket button with cup icon and action cue, retaining the full recipe label and existing character/patience components.
- `Scenes/UI/BottomNavigation.tscn`: remove the café's redundant Prepare control and its now-unused scene dependency; the source icon remains unchanged and is reused on tickets.
- `Scripts/UI/bottom_navigation.gd`: one row of four secondary menus, with minimum screen-pixel sizing.
- `Scripts/Gameplay/gameplay_view.gd`: bind ticket press identities, route preparation/serving, refresh ticket content, selection styling, optional inspection, selected-order station feedback and layout.
- `Scripts/Gameplay/cafe_session.gd`: a small `prepare_order(id)` navigation method reusing existing validation/accept/station operations; update obsolete help text. No scoring, timing, transaction, recipe or balance changes.
- `Tools/validate_foundation.gd`: expect four menus and no Prepare; retain viewport, labels, touch targets, Settings and navigation assertions.
- `Tools/validate_order_tickets.gd` and its Godot-generated UID: isolated state/input, stale-press and persistence regressions; optional screenshots.
- This report.

No official artwork, café environment scene/drawing, character illustration, recipe,
reward catalog, save schema, save storage, upgrade, ability or export preset changed.
No commits or pushes were made.

## Ticket content and selection

Each occupied seat automatically shows a pink button above its customer:

- Existing cup icon, used as a generic drink symbol rather than new artwork.
- Complete recipe name, wrapping to at most two lines at tested sizes.
- Unique order number and **Prepare ›** action.
- Selected tickets show **✓**, plus a stronger pink border.
- Ready drinks switch to a mint **Serve ›** ticket while retaining selected borders.

Ticket text and identity come from `CafeSession` and its `CafeOrder`. A departed or
served customer's entire interactive region disappears, and its ticket ID is cleared.
New occupants receive their own monotonically increasing order ID. Empty seats have
no visible/active ticket. Hidden ticket controls are not an inventory or saved order.

The same selected order gets a pink character-region outline, ticket outline and
patience-track outline. Low patience still has a darkened bar and visible **!** cue.
The station says **Selected order #N**, keeps the exact recipe/ingredients, and uses
the same pink selection treatment for the order indicator and multiple-order choices.
Selection is removed from the previous guest when another is selected, and does not
leak onto replacement customers after departure.

### Stale presses and repeated callbacks

`button_down` captures the rendered order ID. Release checks that ID against the
current ticket ID, seat occupancy and session view, then consumes the press token.
If a customer departs while the finger/mouse is held, the old release cannot accept,
prepare or serve the next occupant of that seat. Calls with no armed press, disabled
tickets, old IDs or hidden/inapplicable views do nothing.

`prepare_order(id)` uses existing `_available` deadline checks. It accepts waiting
orders through existing functions, preserves the requested ID, and opens the station
for that recipe. Repeated calls inside a station cannot create or reset a preparation.
Ready orders cannot be prepared again through this method.

Serve uses the existing durable service receipt, Coin/XP/fraction settlement and
exactly-once guards. No alternate reward calculation or transaction path was added.
A save failure still follows the existing retry/error behavior rather than paying a
partial reward. Expired customers never receive service rewards.

## Navigation hierarchy and optional details

**Primary:** customer order ticket. **Secondary:** four equipment stations.
**Supporting:** Upgrade, Decorate, Cat Team, Map and Settings; abilities remain
automatic with their existing availability display.

The four supporting bottom menus remain, now on one row. Prepare was removed from
the main café navigation only; existing station tabs, Back actions and order choices
are retained. No unrelated destinations were removed.

Tapping a customer's body retains the existing Guest Order screen as optional order
inspection. It still supports legacy Accept/Serve actions and reward previews, so
existing dependencies/tests remain functional. It is not required before ticket
preparation. Pending-order help now points to that customer's ticket.

Equipment remains visible and interactive. It opens the explicitly tapped category
while retaining the selected customer. If an intentionally selected order is still
waiting, the existing acceptance flow is applied first. With no selected/accepted
order, the existing no-selected-order station state remains available. Invalid or
disabled equipment is rejected. Production currently has **no level-based station
unlock gates**; all four existing categories remain available. No lock rules were
invented or removed.

If the equipment category differs from the customer's recipe, the existing station
instruction and disabled preparation action still require the matching category.
This prevents serving the wrong recipe without overriding a deliberate equipment tap.

## Responsive layout

- Preserve the 720×1280 reference, centered desktop portrait layout and safe-area code.
- The café remains the same layered front-facing scene. Cat source textures, region,
  aspect mode, counter and room art were not changed or shrunk.
- On compact phones, a single 64px bottom row replaces the previous 108px arrangement,
  giving the café more vertical space without removing other menus.
- Tickets have a 64px minimum height, 14px+ captions/action text and 44px+ hit dimensions.
- Full names fit in two lines with a separate icon/action area; no ellipsis makes
  recipes indistinguishable. All eight recipes are checked at both target sizes.
- Seat interaction height reserves space for the ticket, customer face, patience and
  status; native-size labels get sufficient line height as well as phone minimums.
- Tickets do not overlap one another, equipment, HUD or the visible barista. The
  existing foreground counter already covers the illustration's lower apron/feet;
  geometry checks distinguish that occluded region from the visible barista.
- No active-service scrolling, new artwork or preparation-screen overhaul was added.

## Automated validation

All **15 headless suites pass**: the 14 existing Foundation/Day/Drinks/Cats/Profile/
Shop/Lottery/Seasons/Game UI/Integration/13A/14/Export/Café Visual suites, plus Tickets.
The new suite passes **758 assertions** across 720×1280 mouse and 320×568 simulated
touch, using scratch saves under `/tmp/paw-16a1-tests-<pid>/`.

New coverage includes automatic arrival/expiry/service visibility, all recipe names
and routes, independent tickets, selected-customer styles, correct station identity,
order switching, duplicate prevention, serving and reload receipts, held-pointer
expiration with seat reuse, optional inspection, keyboard Enter/Escape, invalid or
disabled equipment/tickets, Rush with two guests, and closing/next-day preservation.

The existing full integration journey also passes graphically: **740 assertions**
for both portraits, full accelerated shifts, rewards, shop, teams, progression,
Settings, mouse/touch and desktop resizing. Separate-process cold reload passes
**17 assertions**. Native ticket tests pass **776 assertions**, including 18 saved
screenshots. A clean headless editor import passes.

Windows and Android debug re-exports use the unchanged Step 15 presets. Actual PCK
and APK payloads are checked for runtime catalogs and exclusion of Tools/references/
Docs/signing files; Android signatures are verified. These export checks do not mean
native Windows or physical Android execution was tested.

Reproduce with isolated storage:

```sh
godot --headless --path . --script res://Tools/validate_order_tickets.gd
# On a native display:
godot --path . --audio-driver Dummy --script res://Tools/validate_order_tickets.gd -- --capture-dir=/tmp/paw-16a1-screenshots
```

## Screenshots and evidence

`/workspace/paw-pads-playtest-builds/step-16a1/` contains:

- `screenshots/empty-cafe-{320,720}.png`
- `screenshots/one-waiting-customer-{320,720}.png`
- `screenshots/two-waiting-customers-{320,720}.png`
- `screenshots/selected-customer-{320,720}.png`
- `screenshots/low-patience-{320,720}.png`
- `screenshots/ticket-before-preparation-{320,720}.png`
- `screenshots/after-serving-{320,720}.png`
- `screenshots/rush-two-customers-{320,720}.png`
- `screenshots/selected-order-station-{320,720}.png`
- `PawPadsCafe-Step16A1-Screenshots.zip` and `screenshots/review-contact-sheet.png`.
- `validation/`: suite/native/cold-read/import/export/preservation evidence.
- `windows/`, `android/`: debug re-exports used for validation, outside Git.

Both portrait sets were inspected for clipping, ticket text, selection and separation
from the appliances/barista. Existing transparency residue in the approved PNGs is
unchanged and is not a ticket-rendering defect.

## Remaining limitations and usability review

Physical-device touch/safe areas, native Windows runtime, OS suspension and real-world
performance remain unverified. Xvfb/Mesa uses software rendering and cannot set VSync;
Android host adb still cannot create its read-only home directory, although export
succeeds. The existing Android themed-icon tooling warning remains documented in the
Step 15 build guide.

Tickets use a generic cup, not eight finished drink illustrations. The ready ticket
serves immediately when tapped; the word Serve and selected order number are therefore
important to review in the next recording. Optional body inspection and equipment
remain alternate paths as requested, but are deliberately secondary. Equipment can
still open without an accepted order and show the existing guidance state. Whether
players understand these affordances needs hands-on review; automated checks do not
establish usability or game feel. Step 16B preparation visuals are not implemented.
