# Shieldwall combat test

A Godot prototype for one question: does fighting three melee enemies feel responsive and readable on a phone, with two thumbs? One hero, one small arena, one or three identical enemies. Nothing from the larger Shieldwall game is in here.

The full brief is in [docs/shieldwall_design.md](docs/shieldwall_design.md). Test results are in [TEST_REPORT.md](TEST_REPORT.md).

- Engine: Godot **4.6.2-stable** (official build `71f334935`), GDScript, Compatibility renderer.
- Target: Android, portrait, design canvas 720 x 1280, arm64 only.
- No plugins, no paid services, no asset files. All art and sound is generated in code.

## Run it on a desktop

1. Install Godot 4.6.2 (standard build, not .NET).
2. Open `project.godot` in the editor and press F5, or run `godot --path .` from this folder.

First open or a fresh clone needs one import pass so the editor learns the class names: `godot --headless --path . --import`.

## Controls

| Input | Touch | Desktop |
| --- | --- | --- |
| Move | Floating joystick: touch anywhere in the left half of the bottom control band | WASD or arrow keys |
| Light attack | Tap ATTACK (release in under 0.35 s) | Tap J |
| Heavy attack | Hold ATTACK for 0.35 s, wait for the yellow HEAVY! cue, release | Hold J, release |
| Dodge | DODGE button (diamond). Goes where the stick points, or backwards if the stick is neutral | Space |
| Start / Retry | Buttons on the panel | Enter |

Sliding your finger off the ATTACK button cancels the attack. Dodge cancels a charge without attacking. Losing focus (phone call, app switch) releases every held input.

You have 100 HP and two dodge charges (one comes back every 1.4 s). The dodge is invulnerable for its first 0.16 s only. Enemies show an orange wedge while they wind up; it turns solid red when the direction locks (last 0.25 s). Step out of the wedge or dodge through the strike.

## Tuning

Every combat number is in `resources/tuning.tres` (script: `scripts/tuning.gd`). Edit it in the Godot inspector, or as text. All times are seconds and all distances are arena units.

If you change `scripts/tuning.gd` defaults, regenerate the resource so the file lists every value:

```
godot --headless --path . --script tools/generate_tuning.gd
```

Values you are most likely to touch:

| Question | Setting |
| --- | --- |
| Tap/hold feels laggy or heavies fire by accident | `heavy_hold_time` |
| Enemies too fast or too slow to read | `enemy_speed`, `enemy_windup` |
| Three enemies feel chaotic | `max_commits`, `enemy_stagger`, `enemy_attack_gap`, `enemy_hover_range` |
| Hits feel unfair or dodge too strict | `dodge_iframes`, `dodge_duration`, `enemy_lock_time` |
| Arena feels cramped or empty | `arena_size` (see below) |

### Arena size and zoom

The brief gives the combat numbers but not an arena size. With the literal values (16 px body radius) on a 720-wide canvas, a body is about 2.9 mm wide on a typical phone, so I did not use a 640 x 720 arena. The default is `arena_size = 420 x 480` arena units, and the layout scales it to fill the space above the control band (about 1.65x on a 720 x 1280 screen). Speeds, reaches and radii keep their briefed values in arena units; on screen they look 1.65x larger. Set `arena_size` to `640 x 720` for a literal 1:1 arena.

## Project layout

```
project.godot            portrait 720 x 1280, Compatibility renderer, canvas_items stretch
export_presets.cfg       Android debug preset (arm64-v8a, com.phoneofthrones.shieldwall)
resources/tuning.tres    all combat values
scenes/                  main, hero, enemy (nodes built in code are not scenes)
scripts/
  game.gd                encounter flow, fixed-step simulation, win/lose, retry, layout
  combat_input.gd        the only thing the hero reads; touch and keyboard both write here
  touch_controls.gd      joystick, Attack, Dodge; one finger index per role
  hero.gd                hero state machine (idle, charging, wind-up, active, recover, dodge, hurt, dead)
  enemy.gd               enemy state machine (approach, position, wind-up, active, recover, dead)
  encounter_controller.gd  at most 2 enemies committed to an attack at once
  hit_shapes.gd          one sector definition used for BOTH the drawn wedge and the damage test
  combat_hud.gd, menu_panel.gd, arena_view.gd, sfx.gd, tuning.gd
tests/run_tests.gd       headless state and timing tests
tools/                   tuning generator, screenshot helper
docs/shieldwall_design.md  the brief
```

## Tests

```
godot --headless --path . --import
godot --headless --path . --script tests/run_tests.gd
```

The exit code is the number of failed checks. These are logic checks on a desktop. They cannot tell you anything about touch feel or phone performance. See TEST_REPORT.md.

## Build the Android APK

You need: Godot 4.6.2, its **export templates** for the same version, JDK 17 or newer, and an Android SDK with `platform-tools`, `build-tools;35.0.1` and `platforms;android-35`. No NDK is needed (this uses the prebuilt template, not a Gradle build).

One-time setup:

1. Godot editor: Editor > Manage Export Templates > install 4.6.2 templates. Headless equivalent: unzip `Godot_v4.6.2-stable_export_templates.tpz` and copy `templates/android_debug.apk`, `android_release.apk`, `android_source.zip` and `version.txt` into `~/.local/share/godot/export_templates/4.6.2.stable/`.
2. Android SDK, command line:
   ```
   sdkmanager --licenses
   sdkmanager "platform-tools" "build-tools;35.0.1" "platforms;android-35"
   ```
3. A debug keystore:
   ```
   keytool -genkeypair -keystore debug.keystore -alias androiddebugkey -keyalg RSA -keysize 2048 \
     -validity 10000 -storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US"
   ```
4. Editor Settings > Export > Android: set the Android SDK path, Java SDK path and the debug keystore (user `androiddebugkey`, password `android`). Headless, the same values go in `~/.config/godot/editor_settings-4.6.tres`:
   ```
   export/android/java_sdk_path = "/path/to/jdk"
   export/android/android_sdk_path = "/path/to/android-sdk"
   export/android/debug_keystore = "/path/to/debug.keystore"
   export/android/debug_keystore_user = "androiddebugkey"
   export/android/debug_keystore_pass = "android"
   ```

Then build:

```
mkdir -p build
godot --headless --path . --export-debug "Android" build/shieldwall-debug.apk
```

Install on a phone: copy the APK over and open it (allow "install unknown apps" for your file manager), or `adb install -r build/shieldwall-debug.apk` with USB debugging on. The APK is signed with a throwaway debug key, so it only suits testing. `build/` is git-ignored.

## Decisions I made where the brief was silent

- **Arena size 420 x 480 units, scaled to fit.** Reason above.
- **Enemy wedge arc is 100 degrees** (`enemy_arc_deg`). The brief gives enemy reach (48) but no arc.
- **Hit area is the body circle touching the wedge.** If any part of a body overlaps the drawn wedge, it is hit. This is exact, and the telegraph is drawn from the same function.
- **Enemies resolve before the hero in each step.** If a strike on the hero and the hero's killing blow land in the same step, the hero is already down, so defeat wins. This is the brief's tie rule.
- **Heavy knockback does not interrupt an enemy's wind-up**, same as light. A pushed enemy can be shoved out of range, which is a legitimate tactic.
- **Aim assist snaps fully to the target** when one is inside the 90-degree cone and the swing's reach.
- **Dodge passes through enemy bodies.** Walking into an enemy pushes the enemy, not the hero.
- **The UI is built in code**, not as separate scenes. Only the main, hero and enemy nodes are scenes.
- **Godot's default touch-to-mouse emulation stays on**, because the Start/Retry buttons need it. The on-screen controls only read touch events, so they are unaffected.

## Known limits

- Nothing here has been run on a phone by me. Feel, tap/hold latency, readability and frame rate on a real device are unknown.
- The tap/hold attack split is a hypothesis. A light attack fires on release, so it is delayed by the finger-down time. If that feels bad, the next experiment is separate light and heavy buttons. It was not changed in advance.
- Audio is synthesised noise bursts. I could not listen to it, only confirm it plays without errors.
- The 3-enemy fight is short against a scripted player (about 4 s). A human will be slower. The 30 to 60 s target needs real play and tuning.
