# Paw Pads Café

A standalone Godot 4, GDScript, portrait-first 2D café foundation. Open `project.godot` in Godot 4.3 or newer and press **F5** to launch `Scenes/Title.tscn`. Choose **Play** to open the café; **F6** on `Scenes/Main.tscn` runs the café directly. Validated with Godot 4.6.3.

## Foundation

Native vector placeholders draw the cream-and-peach dollhouse, daylight window, coffee machine and grinder, preparation counter, seating nook, cat resting cushion, plant, shelf, and cups. There are no downloaded assets. The title screen features “Little Paws. Big Dreams.” and a simple original orange-tabby Mochi vector placeholder with a white muzzle, dark apron, coffee cup, and pink paw badge. Play opens the café. Settings on both screens opens a shared modal placeholder with Back/Escape closing and keyboard focus restoration. HUD values are static sample data and the five navigation buttons are focusable placeholders. No gameplay, character behavior, managers, or singletons are implemented.

```text
Title (configured launch scene)
├── Background, Storefront
├── Content / Layout
│   ├── Name (BrandLogo), Tagline
│   ├── MochiPlaceholder, MochiName
│   └── Play, Settings
└── SettingsPanel (shared modal)

Main (café Control)
├── Background (ColorRect)
└── Content (MarginContainer, centered, maximum 720 logical pixels)
    └── Layout (VBoxContainer)
        ├── TopHUD (reusable scene)
        │   ├── TitleRow → CafeName, Settings
        │   └── StatsRow → Day, Coins, Level
        ├── Welcome (Label)
        ├── Cafe (reusable Control scene; native vector environment)
        │   └── Stage → PrepStation, CustomerSeatLeft, CustomerSeatRight, CatRest markers
        ├── FoundationNote (Label)
        └── BottomNavigation (reusable scene)
            └── Upgrade, Decorate, Prepare, CatTeam, Map
Main also instances SettingsPanel above its content.
```

`Scenes/` separates main, environment, and UI scenes. `Scripts/Environment/` contains café drawing, and `Scripts/UI/` handles shared portrait layout, title navigation, settings interactions, and native storefront framing. `Assets/UI/` holds the shared rounded pastel theme; `Assets/Branding/` contains paw and icon assets, `Assets/Characters/` contains the Mochi placeholder, and `Assets/Environment/` and `Data/` reserve locations for later content. `Tools/` contains the foundation validation runner. Finished character art is intentionally deferred.

## Display and browser configuration

The base viewport is **720 × 1280**; the initial desktop window is **432 × 768** and is resizable. `canvas_items` stretch with `expand` aspect preserves uniform scale and adds logical space for different aspect ratios. The café uses a fixed **680 × 740** coordinate system, uniformly fitted and centered in the flexible middle region. The UI stays within a centered 720-pixel column on wide screens, with extra cream background space around it. Navigation and Settings targets remain at least 44 physical pixels at the tested phone sizes.

GL Compatibility rendering supports Godot's WebGL 2 web workflow. The included **Web** export preset excludes reference sheets and validation tools and disables threads, so shared-memory isolation headers are not needed for threading. Install matching Godot export templates through the editor before exporting to `export/web/index.html`; serve the generated files over HTTP(S), rather than opening the HTML directly. Browser export and device testing have not been performed.

## Validation

From this repository:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --quit-after 5
godot --headless --path . --script res://Tools/validate_foundation.gd
```

In a restricted cloud sandbox, direct Godot's writable user directories outside the checkout first:

```sh
mkdir -p /tmp/cat-coffee-godot/{data,config,cache}
export XDG_DATA_HOME=/tmp/cat-coffee-godot/data
export XDG_CONFIG_HOME=/tmp/cat-coffee-godot/config
export XDG_CACHE_HOME=/tmp/cat-coffee-godot/cache
```

Headless import, title launch, Play-to-café transition, settings open/close and focus restoration, and layout checks passed on Godot 4.6.3. The layout runner exercises 360 × 640, 390 × 844, 720 × 1280, 1280 × 720, and 1024 × 768 using logical viewport sizes corresponding to the configured stretch policy. It checks both screens, resources, café bounds, all navigation buttons, settings panel bounds and interactions, and touch target dimensions. Graphical Godot GL Compatibility runs under Xvfb/Mesa were also inspected at 720 × 1280, 360 × 640, and 1280 × 720, including the settings modal. Screenshots are in `ArtReferences/Validation/`. Browser and real-device testing remain outstanding. The official visual reference pack is preserved in `ArtReferences/`; see `ArtReferences/DESIGN_NOTES.md` for the reviewed direction and current visual gaps. The revised foundation uses original simple vector placeholders and native Godot shapes guided by references 01 and 02.

## Official visual references

The supplied Paw Pads Café reference pack is in `ArtReferences/`. Reference 01 guides title, logo, icon, and Mochi branding; reference 02 guides the café. See [design notes](ArtReferences/DESIGN_NOTES.md) for the comparison with the current foundation. These references do not add gameplay scope.

## Reference-guided foundation revision

The title now uses a reusable editable `BrandLogo` scene: wooden sign, cream “Paw” and “Café,” pink “Pads,” and a paw mark. Native storefront framing adds a striped canopy, daylight window, hanging lights, and modest foliage. The pink Play button is the primary action; Settings stays cream. `Assets/Branding/app_icon.svg` is a matching placeholder project icon, not a final browser installable-app icon.

The café retains fixed side-view geometry and named zones, now with warmer wood, peach walls, pink seating, a paw wall sign, and lamps. The HUD uses cream statistic cards. Each bottom navigation tile has a separate editable caption and original SVG icon; mint, pink/peach, and coffee-gold colors echo the references. The `Cafe/Stage` transform keeps future actor placement markers aligned with the uniformly scaled environment. These markers implement no behavior.

All control states retain visible keyboard focus; Settings remains modal with Back/Escape closing. There are no third-party art downloads, concept sheets embedded into the interface, new managers, or gameplay systems. The source reference directory has `.gdignore` and is excluded from exports.
