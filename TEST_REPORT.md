# Test report

Build under test: version 0.2.0 (isometric), Godot 4.6.2-stable (`71f334935`), Compatibility renderer.
Run date: 19 October 2026, in a Linux cloud container (no GPU, no phone, no audio device).

## Read this first

**Nothing was tested on an Android device.** Every result below comes from a desktop, either headless or under a virtual display with software OpenGL. I did not feel the controls, I did not see 60 fps on a phone, and I did not judge readability on a real screen. Do not read "passed" as "good on a phone". Section 4 is the checklist for you.

## 1. Build and import checks (desktop, headless)

| Check | Command | Result |
| --- | --- | --- |
| Project imports | `godot --headless --path . --import` | No errors or warnings |
| Every script parses | `godot --headless --path . --check-only --script res://<file>` for each file in `scripts/`, `tests/`, `tools/` | No errors (16 files) |
| Main scene boots | `godot --headless --path . --quit-after 300` | Ran 300 frames, no output, no errors |

## 2. Logic tests (desktop, headless): 122 checks, 0 failed

Command: `godot --headless --path . --script tests/run_tests.gd`. Run repeatedly during development; results are deterministic. Time is stepped by hand with fixed sub-steps, so there is no timing flake.

| Area | Checks | What is verified |
| --- | --- | --- |
| Tuning file | 1 | `tuning.tres` holds every value in the brief's table |
| Light vs heavy | 10 | 0.10 s hold is light; 0.34 s total is light; 0.36 s total is heavy; 0.8 s is heavy; heavy-ready cue off at 0.30 s and on at 0.36 s; holding 3 s fires nothing; release fires exactly one heavy; sliding off the button cancels |
| One hit per swing | 5 | Two enemies in a light arc each take exactly 10 once; an enemy behind is untouched; hit event fires once per target; heavy deals 25 once and pushes 35 px once |
| Invulnerability | 7 | Hit 2 ms before the 0.16 s dodge i-frame end is ignored, 2 ms after lands; hurt state lasts 0.15 s; hit 0.34 s after a hit is ignored, 0.36 s after lands |
| Dodge charges | 9 | Starts with 2; third dodge refused; none back at 1.35 s, one at 1.45 s, still one at 2.75 s, full at 2.85 s; never above 2 |
| Wedge equals hit area | 12 | For hero light, hero heavy and enemy wedges, at two facings, 2,800 to 5,900 grid points each: the drawn polygon and the damage test agree everywhere more than 0.6 px from an edge, for point targets and hero-sized circles |
| Cancellation and refusals | 17 | Dodge cancels charge (no attack fires afterwards) and recovery; dodge refused in wind-up and active frames and spends no charge; attack presses during dodge, hurt and recovery are dropped, not queued; no auto-attack after hurt with the button still held; dead hero ignores input; death overrides wind-up |
| Wall containment | 4 | Dodging into both corners, walking into a wall, and heavy knockback against a wall all stay inside the arena |
| Enemy telegraph | 6 | Hit lands 0.65 s after the wedge first appears (measured 0.650 s); wedge follows the hero before the lock and does not after; stepping out of the locked wedge takes no damage |
| Enemy hits once | 1 | With post-hit immunity set to 0, one strike still causes exactly one hit |
| Dodge vs strike | 2 | Standing still takes 12; dodging into the strike at 0.60 s of wind-up takes 0 |
| Isometric view | 13 | Projection round trip; ground (1,1) is screen-down; a projected wedge contains exactly the projected hit area; stick up goes straight up the screen at 180 ground px/s, stick right goes straight right; dodge follows the mapped direction (90 ground px); the game enables the mapping; all spawns are inside the arena, outside melee range and enemies start above the hero on screen; all four arena corners fit above the control band at 720 x 1280; scene tree is ArenaRoot > IsoLayer > characters |
| Multi-touch and focus | 13 | Stick, Attack and Dodge fingers work at the same time, each released independently; dragging off Attack cancels it and the later lift fires nothing; touches in dead zones ignored; focus loss clears stick, attack and finger tracking; disabled controls ignore touch |
| Touch to hero | 5 | Tap on Attack gives a light swing, hold-release a heavy, stick moves the hero at 180 px/s, Dodge button dodges |
| Commitment limit | 4 | Over 40 s with an idle hero (100,000 HP) never more than 2 enemies in wind-up/strike/recovery; two do attack together; the third visibly waits; killing a committed enemy frees its slot |
| Full fights | 6 | Scripted player beats 1 enemy and 3 enemies; idle player dies; hero and last enemy both down gives DEFEAT; a same-step strike and killing blow gives DEFEAT |
| Retry | 7 | After 10 dirtied cycles in each mode, the whole state (hero, enemies, timers, input, commitments, finger tracking) equals a fresh start; Retry from the result screen works; focus loss through the Game node clears input |

How the touch tests work: they build `InputEventScreenTouch` and `InputEventScreenDrag` events with different finger indices and feed them to the real `TouchControls` handler. This proves the code tracks fingers separately. It does not prove Android delivers events the same way, or that two thumbs on glass behave.

How the "scripted player" works: a small bot in the test file walks to the nearest enemy, taps attack in range and dodges locked strikes. It beat 1 enemy in 1.6 s (88 of 100 HP left) and 3 enemies in 4.8 s (64 left). That shows the fight can be won and the maths works. It says almost nothing about difficulty for a person, and it suggests a fight with these numbers is much shorter than the 30 to 60 s target.

One bug found by the tests along the way: my first bot left its attack button held after dodging out of a charge, which stalled it for 120 s. The game itself was fine (a held button after a dodge does not auto-attack, as specified); the bot now lifts its "finger" like a player would.

## 3. Visual checks (desktop, virtual display, software OpenGL)

Command: `xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 720x1280 --script tools/capture_screens.gd -- <dir>`

I looked at screenshots of: start panel, fight start, a locked enemy wedge, heavy-ready charge (yellow ring on the ground and HEAVY! on the button), a heavy swing arc, the touch overlay with stick and Attack held (stick up-right moved the hero up-right on screen), and the result panel; plus fight-start at 810 x 1080 (3:4). Observed: the diamond arena, cylinder characters, projected wedges and the control band all render and fit.

Known visual weaknesses:
- A 2:1 diamond uses only about half the screen height in portrait, so there is empty space above and below the arena. Characters are roughly 45 px wide on a 720 px screen (about the literal 1:1 size), smaller than the earlier top-down build.
- With three enemies crowded on top of an idle hero, bodies hide each other's wedges. Depth order is by ground x + y and looks right in the shots, but I have not looked at every overlap.

Not checked: real phone screen size and brightness, notches or rounded corners (safe-area code exists but ran only with zero insets on desktop), colour-blind readability, the 20:9 ratio in the isometric build (the 720 x 1600 layout is covered only by the corner-fit check at 720 x 1280).

## 4. Android build

| Check | Result |
| --- | --- |
| Export | `godot --headless --path . --export-debug "Android" build/shieldwall-debug.apk` succeeded |
| Signature | `apksigner verify`: verifies, v2 and v3 schemes, debug certificate (CN=Android Debug) |
| Manifest | `aapt dump badging`: package `com.phoneofthrones.shieldwall`, versionName 0.2.0, versionCode 2, minSdk 24, targetSdk 35, native code `arm64-v8a` only, `screenOrientation` portrait, debuggable |
| Contents | Compiled scripts and scenes, `tuning.res`, icon; arm64 `libgodot_android.so` |

Final APK SHA-256 is printed at the end of the delivery message and can be recomputed with `sha256sum build/shieldwall-debug.apk`. The APK is not committed to git.

The APK has never been installed or launched, on a phone or an emulator. An APK that exports and verifies can still crash on start.

## 5. Not tested: what you need to do on a phone

Install the APK, play both modes for several minutes, and note:

- Device model, Android version, build (0.2.0), and whether it holds 60 fps (30 is the floor).
- Do the stick and an action button work at the same time? Any dropped or stuck touches?
- Did a tap ever turn into a heavy by accident, or a heavy feel delayed? (The tap/hold split is a hypothesis; if it fails, try separate buttons.)
- Did you miss dodge presses? Does the dodge button sit where your thumb lands?
- Did you need to reposition your left thumb repeatedly?
- Could you tell when an attack was coming, and why you were hit? Are the characters big enough?
- Do you want another attempt after losing?
- One enemy vs three: if one feels bad, fix controls and combat; if one is good and three are chaotic, fix spacing and attack scheduling (`max_commits`, `enemy_stagger`, `enemy_hover_range`).
- Is a fight roughly 30 to 60 s? Expect shorter against these numbers.
- Do the sounds play, and are they tolerable? I could not hear them.
- Safe area: anything hidden behind a notch or gesture bar?

This prototype does not validate large battles or the commercial game.
