# Shieldwall combat test

A Godot prototype for one question: does fighting melee enemies feel responsive and readable on a phone, with two thumbs? One hero with a choice of four weapons, one small arena, three identical enemies followed by a solo captain. Nothing from the larger Shieldwall game is in here.

The original brief limited the test to one hero and identical enemies, and listed bosses and combos as out of scope. The weapons and the captain were added later on request, so the "does the core fight work" question is now mixed with "do the extras work". Use 1 Enemy mode with the Sword to test the original question on its own.

The full brief is in [docs/shieldwall_design.md](docs/shieldwall_design.md). Test results are in [TEST_REPORT.md](TEST_REPORT.md).

- Engine: Godot **4.6.2-stable** (official build `71f334935`), GDScript, Compatibility renderer.
- Target: Android, portrait, design canvas 720 x 1280, arm64 only.
- View: fixed 2:1 isometric camera with plain shapes (a diamond arena, cylinder characters). The simulation is flat; only drawing and the stick mapping are isometric.
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

## Weapons

Pick one on the start screen. It stays for the whole fight and across Retry. Tap/hold, aim assist and dodge rules are the same for all of them; only these numbers change. All are starting values, not balance.

| Weapon | Light | Heavy | Other |
| --- | --- | --- | --- |
| Sword | 10 dmg, reach 65, 90 degrees | 25 dmg, reach 85, 140 degrees, pushes 35 | The brief's table; baseline |
| Spear | 10 dmg, reach 95, 30 degrees | 22 dmg, reach 120, 24 degrees, steps 35 forward | Reach and spacing; narrow arcs |
| Axe | 16 dmg, reach 70, 150 degrees, slower swing | 38 dmg, reach 90, 200 degrees, pushes 60, slowest | Walks at 0.9x, dodge charges return 1.2x slower |
| Daggers | 6 dmg, reach 45, 80 degrees, very fast | 14 dmg, reach 55, 100 degrees | Walks at 1.1x, 3 dodge charges, 0.8x recharge time |

## The fight

- **1 Enemy**: one grunt, for practice.
- **3 + Captain**: three grunts. When the last one dies you get a 2 second breather ("CAPTAIN INCOMING"), +30 health (never above 100) and a full set of dodges, then the captain spawns at the far end of the arena. You win when the captain dies.
- **Captain only**: skip to the captain.

The captain has 150 HP and a gold cap, and cycles lunge, slash, combo, slash, combo. Every attack is telegraphed like a grunt's (orange tracking wedge, solid red once the direction locks) and the wedge is the exact hit area.

| Attack | Damage | Shape | Timing (wind-up / strike / recovery) |
| --- | --- | --- | --- |
| Slash | 18 | reach 62, 120 degrees | 0.70 / 0.10 / 0.60 |
| Combo, hit 1 | 14 | reach 58, 110 degrees | 0.55 / 0.10 / 0.12 |
| Combo, hit 2 | 20 | reach 66, 130 degrees | 0.38 / 0.10 / 0.80 (its own telegraph, right after hit 1) |
| Lunge | 22 | reach 150, 28 degrees; the captain slides 120 forward along it | 0.80 / 0.12 / 0.90; used from 105 to 140 away |

To dodge the lunge, start the dodge in the last ~0.05 s of the wind-up: your i-frames last 0.16 s and the strike is 0.12 s long, so an early dodge runs out before the strike ends.

## Tuning

Combat numbers live in three places. All times are seconds and all distances are arena units.

- `resources/tuning.tres` (script `scripts/tuning.gd`): hero, dodge, grunt, arena, controls, and the sword (the brief's table). The grunt and the sword are built from this file at start.
- `resources/weapons/spear.tres`, `axe.tres`, `daggers.tres`: one file per weapon.
- `resources/captain.tres`: the captain's stats and attacks.

Edit any of them in the Godot inspector, or as text.

If you change `scripts/tuning.gd` defaults, regenerate the resource so the file lists every value. The weapons and captain have their own generator, which overwrites any hand edits to those files:

```
godot --headless --path . --script tools/generate_tuning.gd
godot --headless --path . --script tools/generate_resources.gd
```

Values you are most likely to touch:

| Question | Setting |
| --- | --- |
| Tap/hold feels laggy or heavies fire by accident | `heavy_hold_time` |
| Enemies too fast or too slow to read | `enemy_speed`, `enemy_windup` |
| Three enemies feel chaotic | `max_commits`, `enemy_stagger`, `enemy_attack_gap`, `enemy_hover_range` |
| Hits feel unfair or dodge too strict | `dodge_iframes`, `dodge_duration`, `enemy_lock_time` |
| Arena feels cramped or empty | `arena_size`, `spawn_axis_dist` (see above) |
| Captain too hard or too easy | `captain.tres` (HP, attack damage and timings), `captain_heal` |
| A weapon feels weak or too strong | its `.tres` damage and timings |

### Isometric view and arena size

The game simulates on a flat ground plane and draws it through a fixed 2:1 isometric projection (`scripts/iso.gd`). Attack wedges are the same sectors the damage test uses, projected, so a wedge still shows exactly what hurts. Each character is a cylinder standing on a ground circle; the cylinder's base ellipse is the real body position and size.

Controls follow the screen: stick up moves the hero up the screen (diagonally on the ground), and dodge uses the same mapping. Ground speed stays 180 per second in every direction, so movement along the screen's vertical looks slower than sideways, as in any isometric game.

An isometric arena is a 2:1 diamond, so in portrait it fills the screen width but only about half the height above the controls. To keep characters readable the default `arena_size` is 340 x 380 ground units (about 1x on screen). A larger arena gives more room to circle but makes everything smaller. Distances, speeds and radii in `tuning.tres` are ground units.

## Project layout

```
project.godot            portrait 720 x 1280, Compatibility renderer, canvas_items stretch
export_presets.cfg       Android debug preset (arm64-v8a, com.phoneofthrones.shieldwall)
resources/tuning.tres    base combat values (hero, dodge, grunt, sword, arena)
resources/weapons/       spear, axe, daggers
resources/captain.tres   the captain
scenes/                  main, hero, enemy (nodes built in code are not scenes)
scripts/
  game.gd                encounter flow, fixed-step simulation, win/lose, retry, layout
  combat_input.gd        the only thing the hero reads; touch and keyboard both write here
  touch_controls.gd      joystick, Attack, Dodge; one finger index per role
  iso.gd                 isometric projection and shared cylinder drawing
  attack_def.gd, weapon.gd, enemy_profile.gd   data resources for attacks, weapons and enemy types
  hero.gd                hero state machine (idle, charging, wind-up, active, recover, dodge, hurt, dead)
  enemy.gd               enemy state machine (approach, position, wind-up, active, recover, dead)
  encounter_controller.gd  at most 2 enemies committed to an attack at once
  hit_shapes.gd          one sector definition used for BOTH the drawn wedge and the damage test
  combat_hud.gd, menu_panel.gd, arena_view.gd, sfx.gd, tuning.gd
tests/run_tests.gd       headless state and timing tests
tools/                   resource generators, screenshot helper
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

- **Isometric view is render-only.** Simulation, hit tests and tuning stay in flat ground units. Arena is 340 x 380 units, scaled to fit.
- **2:1 projection fixed.** A steeper camera would use more of the screen height, but is not isometric. Not built.
- **Enemy wedge arc is 100 degrees** (`enemy_arc_deg`). The brief gives enemy reach (48) but no arc.
- **Hit area is the body circle touching the wedge.** If any part of a body overlaps the drawn wedge, it is hit. This is exact, and the telegraph is drawn from the same function.
- **Enemies resolve before the hero in each step.** If a strike on the hero and the hero's killing blow land in the same step, the hero is already down, so defeat wins. This is the brief's tie rule.
- **Heavy knockback does not interrupt an enemy's wind-up**, same as light. A pushed enemy can be shoved out of range, which is a legitimate tactic.
- **Aim assist snaps fully to the target** when one is inside the 90-degree cone and the swing's reach.
- **Dodge passes through enemy bodies.** Walking into an enemy pushes the enemy, not the hero.
- **The UI is built in code**, not as separate scenes. Only the main, hero and enemy nodes are scenes.
- **Weapons are fight styles, not just stat swaps**: reach and arc shape, a forward step (spear heavy), movement speed and dodge economy differ. Weapon choice is on the start screen only; there is no mid-fight swap button.
- **The sword and the grunt are defined by `tuning.tres`** (the brief's table), so the brief's numbers have one source. The other weapons and the captain are separate `.tres` files.
- **Lunge hit area stays at the start position.** The captain slides forward during the strike, but the wedge is the one drawn at the start of the lunge, so what you saw is what hits.
- **The captain's heal and dodge refill come at the start of the breather**, so you see the health jump before it appears.
- **Godot's default touch-to-mouse emulation stays on**, because the Start/Retry buttons need it. The on-screen controls only read touch events, so they are unaffected.

## Known limits

- Nothing here has been run on a phone by me. Feel, tap/hold latency, readability and frame rate on a real device are unknown.
- The tap/hold attack split is a hypothesis. A light attack fires on release, so it is delayed by the finger-down time. If that feels bad, the next experiment is separate light and heavy buttons. It was not changed in advance.
- Audio is synthesised noise bursts. I could not listen to it, only confirm it plays without errors.
- Balance is a first pass, tested only by a scripted player that never misreads a telegraph. With default health it beat 3 enemies and the captain with every weapon in 12 to 27 s (Spear ended with 14 HP, Daggers 28, Axe 58, Sword 72). A human will be slower and will get hit more. The 30 to 60 s target needs real play.
- The captain is a bigger version of the same telegraph idea. If the combo or lunge feels unfair in a 340 x 380 arena, tune `captain.tres` first.
