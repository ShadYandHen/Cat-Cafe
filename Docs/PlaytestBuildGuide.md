# Step 15 — Playtest builds

## Status and artifacts

Godot **4.6.3.stable.official.7d41c59c4**, branch `work`, base commit
`898c1253139e7be5aa3ac2ff8f4e47c9abc1402f`, including existing uncommitted work.
These are development builds, not store-ready releases. No commit or push was made.

Both actual exports completed successfully in this cloud environment:

| Target | Ignored export output | Ready-to-copy package |
| --- | --- | --- |
| Windows x86-64 | `export/windows/PawPadsCafe.exe`, `.pck`, `.console.exe` | `/workspace/paw-pads-playtest-builds/step-15/PawPadsCafe-Windows-playtest.zip` |
| Android ARMv7 + ARM64 | `export/android/PawPadsCafe-debug.apk` | `/workspace/paw-pads-playtest-builds/step-15/PawPadsCafe-debug.apk` |

The same external directory contains checksums, this guide, a feedback CSV, screenshots,
and validation logs. Build products and SDKs are not added to Git. Distribute the full
Windows ZIP; the EXE needs its adjacent PCK. No Godot editor is required to play.

**Verification limits:** Windows cross-export succeeded, but the Windows executable
has not run on an actual Windows OS. A Wine smoke attempt was blocked by its locally
extracted runtime failing to locate `l_intl.nls`, before game startup. Android export,
APK signature verification, manifest inspection and payload checks succeeded; there
is no physical device/emulator validation. Host adb fails creating read-only
`/home/agent/.android`; it does not prevent APK generation. Do not treat either build
as device-approved until the checklist below is completed.

## Dependencies and reproducible exports

Install Godot 4.6.3 standard (GDScript), then **Editor → Manage Export Templates** and
install the matching 4.6.3 templates. An Internet connection is needed for setup,
not normal play. Use official downloads and their published checksums.

From the project folder, import then export with these exact preset names:

```sh
godot --headless --path . --editor --import --quit
mkdir -p export/windows export/android
godot --headless --path . --export-debug "Windows Playtest" export/windows/PawPadsCafe.exe
godot --headless --path . --export-debug "Android Playtest" export/android/PawPadsCafe-debug.apk
```

On Windows use `Godot_v4.6.3-stable_win64_console.exe` in place of `godot` if it is
not on PATH, and create output directories in Explorer or PowerShell first.
Alternatively use **Project → Export**, select the target preset, **Export Project**,
and leave **Export With Debug** enabled.

Windows requires no C++ compiler. The EXE is unsigned; SmartScreen may warn.
`application/modify_resources=false` avoids requiring rcedit/Wine for cross-export.
PE file icon/version metadata can retain Godot defaults; existing in-game art is
unchanged. This is not an installer or a production-signing configuration.

For Android install OpenJDK **17** (recommended by Godot), Android command-line tools,
platform-tools, **Android SDK platform 36**, and **build-tools 36.1.0**. Accept SDK
licenses. A standard installation can use:

```sh
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.1.0"
sdkmanager --licenses
```

Set **Editor Settings → Export → Android → Java SDK Path / Android SDK Path** to
your local installations. The cloud verified the same SDK with installed OpenJDK
21; Java 17 remains the recommended local setup. Non-Gradle export uses the stock
APK templates: no custom Android build template, NDK or Gradle project is needed.

Android preset details:

- Package: `org.shadyandhen.pawpadscafe.playtest`; label: `Paw Pads Café (Playtest)`.
- Version code 1; version name `0.15.0-playtest`.
- Minimum Android API 24 (Android 7), target API 36, ARMv7 and ARM64.
- Portrait, Compatibility renderer, touch controls, edge-to-edge enabled; system
  bars remain visible. Safe-area insets use Godot's native display-safe rectangle.
- Debug-signed; no production signing key, signing password or SDK path in Git.
- Internet and external-storage permissions are not requested by this preset.
- Local save storage is internal app storage. No server is involved.

The first Android export failed until mobile ETC2/ASTC import was enabled in
`project.godot`. This is the confirmed export blocker fixed in Step 15. Portrait
orientation is explicit. The native safe-area branch was added because the previous
layout only queried browser safe areas. Geometry tests pass; real Android cutout,
keyboard, gesture-bar and coordinate behavior still need device testing.

Godot 4.6.3 non-Gradle export removes unused `themed_icon.xml` when no monochrome
launcher override is supplied, leaving an unused resource-table reference. `aapt2`
reports that warning. The manifest's actual `mipmap/icon` and all its density assets
are present; APK signing verification passes. Themed-launcher appearance remains a
device check. No artwork was generated to silence this tooling warning.

## Installation and launch

**Windows:** extract the entire ZIP, keep all three files together, run
`PawPadsCafe.exe`. Use `.console.exe` to capture runtime diagnostics. Resize the
window; wider desktop presentation should stay centered in a portrait area. Test
on a dedicated Windows test account to isolate an existing player's save.

**Android:** copy the APK to the test phone, enable installation from that source
when prompted, and install. Or connect a USB-debug-enabled phone:

```sh
adb devices
adb install -r PawPadsCafe-debug.apk
adb shell am start -n org.shadyandhen.pawpadscafe.playtest/com.godot.game.GodotApp
adb logcat -c
# Reproduce the issue, then capture logs:
adb logcat -d > pawpads-android-log.txt
```

Updates require the **same debug signing key**. The cloud key is outside the
repository and is not distributed. Keep a local debug key private and stable for
local test updates. A locally rebuilt APK may fail to update this cloud-signed APK
with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`; back up test data before uninstalling.
Uninstalling deletes internal save data. Never uninstall to resolve an update error
on a valued player profile without a recoverable backup.

No development harness is packaged, even though these are debug builds. Progression
controls remain editor-only under `Tools/`; normal exported navigation has no cheats.
For Level 50/season boundary tests use the existing isolated editor harness described
in the integration documentation (`godot --path . --script res://Tools/development.gd
-- --slot=playtest --reset --coins=5000 --reputation=50:0 --tickets=11 --launch`).
This operates on `/tmp/paw-pads-development/playtest/profile.json`, never a real save.
Do not transplant a test profile into a live player account. Long-term unlock tests
in the automated journey use isolated profiles; a fresh exported player must earn
those unlocks normally.

## Save and relaunch

Godot stores `user://player_profile.json`, schema **5**, with staged writes and
backup recovery. Typical locations:

- Windows: `%APPDATA%\Godot\app_userdata\Paw Pads Café\`.
- Android: app-private `files/` under this package (debug access through
  `adb shell run-as org.shadyandhen.pawpadscafe.playtest ls files`).
- Linux cloud checks: isolated `XDG_DATA_HOME` under `/tmp/paw-15/`.

Copy the entire save directory, including backup/recovery files, while the app is
closed before deliberately testing corruption. Do not delete recovery evidence.
Backup recovery can lose changes since that backup checkpoint; it cannot reconstruct
transactions never written successfully. Completed services are durable; unfinished
customers/drinks are not restored. Relaunch returns to pre-day opening. An abandoned
shift must not award a completed day or Seasonal XP. Historical receipt fields may
remain in the file until the next shift; that does not restore active customers.

## Automated and native evidence

All **12 pre-existing suites passed**: balanced pacing, Step 13A, profile, shop,
lottery, seasons/challenges/Inbox, cats, drinks, day, gameplay UI, foundation and
integration. Their numbered suites total **8,145 assertions**, plus the foundation's
8-viewport checks. New `validate_playtest_exports.gd`: **26 assertions**. Run with
isolated XDG storage and `godot --headless --path . --script res://Tools/validate_NAME.gd`.

Native Linux graphical integration: **740 assertions**, actual scene/input journeys
at 720×1280 and 320×568, mouse/simulated touch, Settings/focus, full accelerated
300-second shifts, shops, reward screens and desktop resizing. A separate process
cold-loaded both journey checkpoints: **17 assertions**. Schema migrations, corruption,
backup/failed writes, fractional remainders, receipts and reward protections are
covered by the existing profile, Step 13A and integration suites. These are automated
checks, not human evaluations of game feel.

`Tools/verify_playtest_artifacts.py` checked all **130 Windows PCK entries** with MD5,
all **132 Android assets**, runtime JSON catalogs, both Android ABIs, and exclusion
of Tools, references, Docs and private signing files. Re-run from the project root:

```sh
python3 Tools/verify_playtest_artifacts.py export/windows/PawPadsCafe.pck export/android/PawPadsCafe-debug.apk
apksigner verify --verbose export/android/PawPadsCafe-debug.apk
```

The signed APK verifies v2/v3 signatures. Its manifest confirms portrait and debug mode.
An editor-free Linux export template loaded the **exact Windows-exported PCK** and
completed a real X11 mouse-driven coffee service at 320×568, then closed/relaunched
at 720×1280: 120→136 Coins, 15 Reputation XP and 1,050/10,000 fractional tip units
survived; no completed-day award or duplicate payment. This verifies standalone
project data, not Windows-specific APIs or Android runtime behavior.

Screenshots at both portrait sizes were inspected: essential navigation/order/station
controls visible. The foundation also tests 1280×720 and 1920×1080. Existing artwork
edge artifacts remain unchanged. Software-rendered FPS samples show responsive
standalone operation, but there is no physical GPU/device frame-time or battery
benchmark. Unsupported VSync under Xvfb/llvmpipe is a host limitation. Audio hardware,
Windows drivers, Android suspend/resume and OS memory pressure remain unverified.

## Manual playtest checklist

Record device/OS, build checksum, viewport/display scale and test-profile identity.
Use `Docs/PlaytestFeedback.csv` for each issue. Keep screenshots/logs and before/after
save copies with the issue; do not put private player data in a public report.

- [ ] First launch: title, Play, Settings/Back/focus; 120 Coins, Level 1, zero days.
- [ ] Before Day 1: select one active and two unique support cats; reopen team screen.
- [ ] Start shift: 5:00 countdown, both seats work, accept/select distinct orders.
- [ ] Prepare and manually serve **Basic Coffee, Vanilla Cloud Coffee, Warm Milk,
  Honey Hug Milk, Garden Tea, Honey Blossom Tea, Berry Breeze, Iced Cocoa Cloud**
  (orders are randomized; record which recipes were encountered).
- [ ] Try cancel/back, switch orders, double-tap, and let a selected order expire.
- [ ] Complete and incomplete ingredients: incomplete quality never exceeds 74;
  Blaze never promotes it; a complete good-timing drink can reach Perfect.
- [ ] Normal arrivals 20–26s, Rush arrivals 9–12s subject to full-seat skipping;
  Rush at 2:00 elapsed through 3:00 elapsed; base patience 75s before bonuses.
- [ ] Open Settings/order/station: clock and patience keep running. Verify expiration
  gives no rewards, releases seat and safely invalidates a prepared drink.
- [ ] Test each active cat on a separate day: Mochi threshold rescue; Fade/Max speed;
  Momo timing forgiveness; Odin premium tip; Blaze complete Excellent promotion.
  Check 30-second cooldown and passive effects from all three equipped cats.
- [ ] At 0:00 no arrivals; remaining customers can resolve; results reconcile Coins,
  Reputation, quality counts and 200 completed-day Seasonal XP (challenge XP separate).
- [ ] Between shifts buy an eligible upgrade and decoration, equip/replace/remove;
  insufficient funds, locked purchases and repeated taps never charge twice.
- [ ] Next day upgrade effects apply; mid-shift shop/team/claims are view-only.
- [ ] Daily/weekly challenge progress and 150/500 Seasonal XP rewards occur once.
- [ ] In isolated advanced profile: season milestone/manual claim, expired-season Inbox,
  lottery Level 50 lock/unlock, Roll 1/10, history, collections and duplicate fallback.
- [ ] Close after service, purchase, claim and day completion; reopen and verify all
  permanent values, team/equipment, seasonal state and fractional tip continuity.
- [ ] Close mid-shift: fresh opening, no restored orders or duplicate reward/day XP.
- [ ] Android: portrait rotation lock, cutouts/gesture navigation, touch scroll, back
  controls, background/foreground, force-stop/reopen, offline operation and updates.
- [ ] Windows: executable outside editor, mouse/keyboard/focus, resize portrait/wide,
  display scaling and minimized/restored window.
- [ ] Record responsiveness/stalls, overheating, audio/input errors, confusing actions,
  difficulty and suggestions. Automated tests do not establish fun or comfort.

## Troubleshooting

Missing PCK: extract all Windows files to one directory. Missing templates: install
exact 4.6.3 templates, not a different minor version. Android export rejection: verify
SDK paths, API36/build-tools36.1.0, licenses, debug keystore and mobile texture import.
APK ABI error: these builds target ARM, not x86 emulators. App fails to install: capture
`adb install` output; check API24+, available space and signature mismatch before deleting
data. Safe-area or touch errors: record phone model, navigation mode and screenshot.
Capture console/logcat errors and the build checksum before making project changes.

No gameplay logic, prices, bonuses, approved pacing, Step 13A corrections, save schema,
artwork or production catalogs were modified. Remaining platform verification is a
playtesting requirement; no physical-device or native Windows success is claimed.
