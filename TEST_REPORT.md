# Test report

Build under test: version 0.6.0 (wider parry window, per-weapon stagger timers), Godot 4.6.2-stable (`71f334935`), Compatibility renderer.
Run date: 19 October 2026, in a Linux cloud container (no GPU, no phone, no audio device).

## Read this first

**Nothing was tested on an Android device.** Every result below comes from a desktop, either headless or under a virtual display with software OpenGL. I did not feel the controls, I did not see 60 fps on a phone, and I did not judge readability on a real screen. Do not read "passed" as "good on a phone". Section 4 is the checklist for you.

## 1. Build and import checks (desktop, headless)

| Check | Command | Result |
| --- | --- | --- |
| Project imports | `godot --headless --path . --import` | No errors or warnings |
| Every script parses | `godot --headless --path . --check-only --script res://<file>` for each file in `scripts/`, `tests/`, `tools/` | No errors (16 files) |
| Main scene boots | `godot --headless --path . --quit-after 300` | Ran 300 frames, no output, no errors |

## 2. Logic tests (desktop, headless): 366 checks, 0 failed

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
| Weapon and captain data | 14 | Four weapons load in order; sword equals the design table; spear, axe, daggers and captain values equal the specified numbers; pattern is lunge, slash, combo, slash, combo; the lunge is chosen from afar and skipped up close |
| Weapon mechanics | 22 | For each weapon: light hits once for its damage, a target just past reach is missed, heavy deals its damage and pushes by its knockback; a target 100 away is hit by the spear and not the sword; axe spin hits 95 degrees off axis and the sword heavy does not; daggers start with 3 dodges and recharge in 1.12 s; axe needs 1.68 s; walking speeds 162 / 198 / 180; spear heavy steps 35 forward |
| Every attack shape | 12 | Drawn wedge equals hit area for all 8 weapon attacks and the captain's 4 attacks, at two facings |
| Captain attacks | 13 | Slash lands 0.70 s after its wedge for 18; combo lands 14 then 20, hit 2 has its own wind-up and lands 0.60 s after hit 1, one commitment for the whole chain; lunge chosen at 125 away, hits a standing hero once for 22, slides the captain about 120, misses a hero who sidesteps after the lock, and is avoided by a dodge started 0.02 s before the strike |
| Wave and captain flow | 16 | Wave clear starts a breather (no victory), +30 HP capped at 100, dodges refilled, captain appears after 2.0 s at the far end with 150 HP, killing it wins, dying to it loses; 1 Enemy has no captain; Captain only starts with the captain; menu picks weapon and mode; Retry keeps the weapon; choosing the sword restores its stats |
| Scripted player per weapon | 4 | A full 3 enemies + captain fight is won with each weapon (inflated HP, to prove the flow completes) |
| Block button, keyboard, layout | 10 | BLOCK sits inside the control band and clear of ATTACK and DODGE; touch raises and lowers the guard; sliding well off lowers it; stick, BLOCK and ATTACK fingers work together; focus loss clears it; K key |
| Raising and lowering the guard | 23 | Up from idle and from a cancelled charge; refused in wind-up, strike, recovery and hurt, and goes up when those end if still held; dodge exits; attack presses ignored and not queued; 0.35 s re-raise lockout; walking speed 180 / 72 / 171 / 68.4 for bare, bare blocking, shield, shield blocking |
| Guard arc, damage and cost | 26 | Default arc is 360 degrees for both guards: a hit from each of 11 directions (front, sides, behind) is blocked, even after turning to face another way; with the arc narrowed to 140 / 100 degrees the old edge behaviour still holds (shield blocks at 69 degrees and not 75, bare at 45 and not 55, nothing from behind) and an unblocked hit hurts; shield cost 12 and no damage; bare cost 18 and 4.8 chip; no hurt state or immunity from a block; one enemy strike is one block; the drawn guard area equals the block test for every degree at 360, 140 and 100 degrees, both guards |
| Guard break and regen | 9 | An emptying block is still absorbed, then 0.8 s stun with no actions, hits land during it, guard returns at 50%; no regen for 0.6 s after a block, then 25/s; none while the guard is held |
| Parry | 16 | Works against an attacker behind you (parry, plain block with a shield, and a bare-handed block with 4.8 chip). Inside the window: no damage, no guard cost, slot released, attacker frozen for 3.0 s; 0.40 s early is a normal block; with a shield 0.25 s early parries and 0.35 s early only blocks (window 0.28); bare-handed 0.18 s early parries and 0.25 s early only blocks (window 0.20); parrying combo hit 1 cancels hit 2 |
| Parry freeze | 13 | Sword, grunt and captain: parried into a 3.0 s stagger, timer counts down (2.0 left after 1 s), still frozen at 2.8 s with position unchanged and no attack, wakes at 3.0 s with the 0.35 s gap; a light hit on a frozen enemy does x2.0 and wakes it at once with re-stagger immunity; the next hit is ordinary; small hits are doubled and a later hit can finish it |
| Frozen enemies held in place | 3 | Other bodies overlapping a frozen enemy and the hero walking into it do not move it; the other enemy is the one pushed apart |
| Stagger timer differs by weapon | 17 | Sword 3.0 / 1.0, Spear 3.5 / 0.8, Axe 2.5 / 1.5, Daggers 2.0 / 0.6 s (parry / heavy) against a grunt; a parry against the captain gives the same time and a heavy against it is halved; light hits never stagger; the data values load correctly |
| Parry timing sweep | 6 | The guard is raised 0.02 to 0.60 s before a grunt's strike (30 timings per guard type). With a shield every timing from 0.04 to 0.26 s early is a parry (parried 0.02 to 0.28 s early), bare-handed 0.04 to 0.18 s (parried 0.02 to 0.20 s early); every earlier timing is a plain block and none of the 60 runs took a hit |
| Heavy hits stagger | 16 | A heavy staggers a grunt for 1.0 s and the captain for 0.5 s, with ordinary damage and knockback; a light hit does not stagger; a heavy staggers both of two enemies in its arc; it cancels a wind-up, releases the slot and the strike never lands; `heavy_stagger_mult = 0` disables it; no stun-lock (heavy inside the 1.0 s window damages but does not stagger, after it does); a heavy on a parry-frozen captain does x2.0 and does not re-stagger it; a parry still works inside the window |
| Captain vs a guard | 6 | Lunge vs shield: blocked, 44 of 80 guard; lunge vs bare guard: full 22, guard untouched; a parry beats the lunge both ways; bare slash gives 7.2 chip and 27 guard; both combo hits blocked by a shield |
| Shield equipment | 11 | Sword and Spear one-handed, Axe and Daggers not; shield numbers with the sword; a shield with the axe is ignored; menu toggle enabled and disabled correctly and remembered; starting with a shield equips it; Retry keeps it and restores guard; "Sword + Shield" label |
| Scripted blocking player | 4 | Sword + Shield and Spear + Shield beat 3 enemies and the captain with inflated HP, and the runs really used blocks or parries |
| Multi-touch and focus | 13 | Stick, Attack and Dodge fingers work at the same time, each released independently; dragging off Attack cancels it and the later lift fires nothing; touches in dead zones ignored; focus loss clears stick, attack and finger tracking; disabled controls ignore touch |
| Touch to hero | 5 | Tap on Attack gives a light swing, hold-release a heavy, stick moves the hero at 180 px/s, Dodge button dodges |
| Commitment limit | 4 | Over 40 s with an idle hero (100,000 HP) never more than 2 enemies in wind-up/strike/recovery; two do attack together; the third visibly waits; killing a committed enemy frees its slot |
| Full fights | 5 | Scripted player beats 1 enemy; idle player dies against the grunts; hero and last enemy both down gives DEFEAT; a same-step strike and killing blow gives DEFEAT |
| Retry | 9 | After 10 dirtied cycles in each of the three modes, the whole state (hero, enemies, timers, input, commitments, finger tracking, weapon, breather and captain flags) equals a fresh start; Retry from the result screen works; focus loss through the Game node clears input |

How the touch tests work: they build `InputEventScreenTouch` and `InputEventScreenDrag` events with different finger indices and feed them to the real `TouchControls` handler. This proves the code tracks fingers separately. It does not prove Android delivers events the same way, or that two thumbs on glass behave.

How the "scripted player" works: a small bot in the test file walks to the nearest enemy, taps attack in range and dodges locked strikes. It beat 1 enemy in 1.6 s (88 of 100 HP left). Against 3 enemies and the captain with default health it won with every weapon: Sword 14.9 s (72 HP left), Spear 27.4 s (14 left), Axe 12.1 s (58 left), Daggers 16.6 s (28 left). The bot dodges every locked strike with correct timing, which people will not, so these are lower bounds on difficulty.

A second bot raises its guard in the last 0.28 s of a strike that covers it. With a shield and default health, Sword won in 12.9 s with 42 HP left (2 blocks, 2 parries, no guard break). Spear lost after 16.9 s (1 block, no parries). Both bots block only a few times a fight because they are usually mid-swing when a strike arrives, so they say little about how blocking plays for a person. That shows the fight can be won and the maths works. It says almost nothing about difficulty for a person, and it suggests a fight with these numbers is much shorter than the 30 to 60 s target.

One bug found by the tests along the way: my first bot left its attack button held after dodging out of a charge, which stalled it for 120 s. The game itself was fine (a held button after a dodge does not auto-attack, as specified); the bot now lifts its "finger" like a player would.

## 3. Visual checks (desktop, virtual display, software OpenGL)

Command: `xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 720x1280 --script tools/capture_screens.gd -- <dir>`

I looked at screenshots of: the start panel with the shield toggle on (Sword) and disabled (Axe), the shield raised inside its 360-degree guard ring, the bare-weapon guard, the parry freeze with its 3.0 timer and the same enemy 2 s later, a heavy-hit stagger timer, the captain frozen with its timer, the guard break (empty meter, dazed hero), the BLOCK button with its guard ring while held alongside the stick, the start panel (weapon row, mode row), fight start, a locked grunt wedge, heavy-ready charge, each weapon's heavy swing at its active frame (sword, spear, axe spin, daggers), the captain's lunge, slash, combo hit 1 and combo hit 2 wedges, the "CAPTAIN INCOMING" breather, the touch overlay with the daggers' three dodge pips, and the result panel; plus an earlier fight-start at 810 x 1080 (3:4). Observed: all render and fit at 720 x 1280. Fixes made from the block looks: the raised shield was small and hid behind the body, so it is larger and always drawn in front; the BLOCK label crowded the ATTACK ring, so it moved inside the button. Fixes made from earlier looks: the idle hero showed through the start panel (arena now hidden on the start screen), and an enemy health bar could overflow when HP exceeded max (clamped).

Known visual weaknesses:
- A 2:1 diamond uses only about half the screen height in portrait, so there is empty space above and below the arena. Characters are roughly 45 px wide on a 720 px screen (about the literal 1:1 size), smaller than the earlier top-down build.
- The stagger timer is small (about 17 px text over a 36 px bar on a grunt). It is readable in the renders but I have not judged it on a phone.
- The shield and guard ring are small on screen at this arena scale; the wedge is the clearest cue and the shield itself is easy to miss, especially when facing away from the camera.
- The captain is only about 1.4x the grunt's size and is distinguished mostly by colour and a gold cap; the lunge wedge is long and thin and may be hard to judge in the diamond.
- With three enemies crowded on top of an idle hero, bodies hide each other's wedges. Depth order is by ground x + y and looks right in the shots, but I have not looked at every overlap.

Not checked: real phone screen size and brightness, notches or rounded corners (safe-area code exists but ran only with zero insets on desktop), colour-blind readability, the 20:9 ratio and the 810 x 1080 shape for this iteration's new start panel (only 720 x 1280 was looked at) (the 720 x 1600 layout is covered only by the corner-fit check at 720 x 1280).

## 4. Android build

| Check | Result |
| --- | --- |
| Export | `godot --headless --path . --export-debug "Android" build/shieldwall-debug.apk` succeeded |
| Signature | `apksigner verify`: verifies, v2 and v3 schemes, debug certificate (CN=Android Debug) |
| Manifest | `aapt dump badging`: package `com.phoneofthrones.shieldwall`, versionName 0.6.0, versionCode 7, minSdk 24, targetSdk 35, native code `arm64-v8a` only, `screenOrientation` portrait, debuggable |
| Contents | Compiled scripts and scenes, `tuning.res`, icon; arm64 `libgodot_android.so` |

Final APK SHA-256 is printed at the end of the delivery message and can be recomputed with `sha256sum build/shieldwall-debug.apk`. The APK is not committed to git.

The APK has never been installed or launched, on a phone or an emulator. An APK that exports and verifies can still crash on start.

## 5. Not tested: what you need to do on a phone

Install the APK, play both modes for several minutes, and note:

- Device model, Android version, build (0.6.0), and whether it holds 60 fps (30 is the floor).
- Do the stick and an action button work at the same time? Any dropped or stuck touches?
- Did a tap ever turn into a heavy by accident, or a heavy feel delayed? (The tap/hold split is a hypothesis; if it fails, try separate buttons.)
- Did you miss dodge presses? Does the dodge button sit where your thumb lands?
- Did you need to reposition your left thumb repeatedly?
- Could you tell when an attack was coming, and why you were hit? Are the characters big enough?
- Do you want another attempt after losing?
- One enemy vs three: if one feels bad, fix controls and combat; if one is good and three are chaotic, fix spacing and attack scheduling (`max_commits`, `enemy_stagger`, `enemy_hover_range`).
- Is a fight roughly 30 to 60 s? Expect shorter against these numbers.
- Do the sounds play, and are they tolerable? I could not hear them (block clank, parry ping, guard-break thud).
- Stagger: after a parry, do you take the free hit or reposition? Is 3 s the right length, and is the timer readable at a glance? Do heavies now feel like the only attack worth using?
- Block: can you reach BLOCK with the right thumb without losing ATTACK or DODGE? Is the parry window (0.28 s with a shield, 0.20 s bare) now comfortable on your phone, or still too tight? Do the per-weapon freeze lengths (Sword 3.0, Spear 3.5, Axe 2.5, Daggers 2.0 s) feel like real differences?
- Safe area: anything hidden behind a notch or gesture bar?

This prototype does not validate large battles or the commercial game.
