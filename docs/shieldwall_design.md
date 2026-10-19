# Shieldwall — Godot Combat Test

19 October 2026 · Coding-agent prompt and design document

## Part 1 — Copy this prompt into your coding agent

Build a complete, runnable Godot combat prototype using the design document in Part 2 below. This is an implementation task, not a request for another plan. Read the whole document first, then implement and verify the project.

The entire game is one hero versus three melee enemies in a small arena. Its purpose is to test mobile movement, attack commitment, readable threats and dodging. Do not build the larger Shieldwall battle game.

Use Godot 4, GDScript and the Compatibility renderer. Use the stable Godot 4 version available in the working environment and record its exact version in README.md. Verify version-specific settings against the installed engine or official documentation. Build a native Godot project, not a web page or an engine embedded in another application.

First inspect the workspace and any AGENTS.md instructions. If a project exists, preserve unrelated work and integrate safely. Otherwise create a self-contained project. Make routine implementation decisions autonomously. Do not stop to ask about colours, placeholder art, filenames or tuning values. Do not add paid services, plugins or external asset dependencies.

Implement in this order:
1. A bootable portrait project, arena, hero movement and touch controls, with desktop controls for development.
2. Light attack, heavy attack, directional dodge, damage and feedback.
3. One enemy with clearly separated approach, wind-up, strike and recovery states.
4. Three-enemy mode with limited simultaneous attack commitments.
5. Win, defeat, retry and the one/three-enemy selector.
6. Verification, tuning instructions and Android export configuration.

Use ordinary scenes and nodes for four characters. Keep code readable and combat values centralised in an editable tuning resource. Do not introduce an ECS, MultiMesh crowd renderer, C++, networking, procedural content or future campaign frameworks. Separate touch input from combat actions so keyboard and touch use the same gameplay code. Use explicit combat states to prevent overlapping actions and duplicate damage.

Create readable placeholder graphics in the project: coloured bodies, facing markers, weapon arcs and telegraphs. Include simple locally generated impact sounds if possible. Missing art must never block completion. No AI art-generation pipeline is needed.

Deliver the complete project, README.md, this design document, and TEST_REPORT.md. README must explain opening/running the project, controls, tuning and Android export. Record the exact tests performed and distinguish desktop checks from actual Android testing. Run import/parse checks and available gameplay checks. Do not claim phone testing or enjoyment unless observed. If Android tooling and export templates are available, produce a debug APK; otherwise finish the runnable project and report the exact missing prerequisites. Never fabricate a build or download link.

Acceptance: the project opens without errors; one and three enemies can be fought to victory; the hero can die; retry resets all state; simultaneous joystick and action touches work; enemies telegraph their attacks; each attack damages a target at most once; dodging avoids damage only during its defined invulnerability interval. Finish the playable test before considering anything outside this scope.

## Part 2 — Compact design document

### Goal and scope

Prove that fighting three enemies feels responsive, understandable and worth repeating on a phone. One enclosed arena, one hero, three identical enemies. Default to three enemies; allow one-enemy practice from the start/result screen. Target a 30–60-second encounter initially, adjusted through testing rather than enforced by a timer.

Godot 4 / GDScript / Compatibility. Android first, portrait, two thumbs. Design reference size 720 × 1280; adapt to device aspect ratio and safe areas. Target 60 fps, with 30 fps as the minimum on the actual test device. This is a target, not a measured result.

Visuals: top-down 2D with a fixed camera. A flat ground, visible arena boundary, blue hero and red enemies. Faces/weapon markers show direction. AoE2-style finished art is deferred. Reserve approximately the bottom 28% for controls; fit the entire arena in the remaining space so no attacks originate off-screen. Leave enough room to circle and retreat.

Three rules: every hit is explainable; movement and attacks remain deliberate; no feature is added unless it helps evaluate this fight.

### Controls

| Input | Action |
| --- | --- |
| Left thumb | Floating joystick within the left half of the control band. Release stops movement. |
| Right thumb: Attack | Short release before 0.35 s performs one light attack. Hold at least 0.35 s enters heavy-ready; release performs heavy. Show charge progress and a ready cue. Holding does not repeat attacks. |
| Right thumb: Dodge | Immediate dodge in joystick direction; with neutral stick, dodge backwards relative to facing. |
| Desktop | WASD/arrows move; J uses the same tap/hold attack behaviour; Space dodges. |

Use two generous right-side buttons with distinct shapes/icons and labels. Maintain separate touch IDs for movement and action touches. Leaving a button cancels its pending attack; losing focus clears held input. Dodge cancels charging without releasing an attack. Use no additional skill button.

Facing follows movement except during committed attacks. At attack release, gently aim toward the nearest enemy within a 90-degree cone centred on facing and within that attack's reach. Never snap behind the hero. Lock direction during the swing. No target-lock mode, automatic attacks or camera manipulation.

Tap/hold ambiguity is a hypothesis to test. Do not silently redesign the controls if it feels delayed; document the issue for a later comparison with separate light/heavy buttons.

### Initial combat tuning

All timings are seconds. Distances are design-space pixels. Values are starting points, not final balance.

| Mechanic | Starting specification |
| --- | --- |
| Hero | 100 HP; movement 180 px/s; collision radius about 16 px |
| Light | 10 damage; 65 px reach; 90-degree arc; 0.10 wind-up / 0.08 active / 0.22 recovery |
| Heavy | After charging: 25 damage; 85 px reach; 140-degree arc; 0.15 wind-up / 0.10 active / 0.40 recovery; pushes enemies 35 px |
| Dodge | 90 px over 0.30 s; invulnerable for first 0.16 s; two charges; one charge restored every 1.4 s until full |
| Enemy | 30 HP; movement 105 px/s; melee reach 48 px; 12 damage |
| Enemy attack | 0.65 wind-up / 0.10 active / 0.65 recovery; at least 0.35 s before requesting another attack |

Light and heavy attacks stop movement during wind-up and active frames; recovery permits half-speed movement. Charging permits half-speed movement. Dodge can cancel charging and recovery, but cannot cancel attack wind-up or active frames. Attacks cannot start during dodge, hurt or death states. No attack input queue initially; ignore invalid presses without firing them later.

Each swing can hit multiple enemies in its arc, once each. Basic attacks do not interrupt an enemy's wind-up: positioning and dodge must remain relevant. Heavy knockback respects arena walls. Hero hits interrupt the hero's attack and cause a brief 0.15 s hurt state, followed by total damage immunity lasting 0.35 s from the hit. Death overrides every state. Dodge stops at walls and cannot escape the arena.

### Enemy behaviour and readability

States: approach, position/wait, wind-up, active strike, recover, dead. Use local separation and simple steering in this obstacle-free arena; enemies must not occupy the same spot or push the hero uncontrollably. Permit the hero's dodge to pass through enemy bodies for this test.

A small encounter controller permits at most two enemies to commit to attacks at once. A commitment lasts from wind-up through recovery. Others visibly reposition nearby; they do not attack invisibly. Stagger initial attack eligibility so all three do not start together. Release commitments on death and retry.

During wind-up, show a clear ground wedge and weapon preparation. Lock the attack direction for the final 0.25 s before impact, so movement can evade it. The visible wedge must match the actual damage area. Resolve contact against the hero during active frames, once per attack; do not use random hit chances.

Show hero HP, enemy HP, dodge charges and remaining enemies. Use hit flash, a brief weapon arc and impact sound. Avoid full-screen effects, slow motion and camera shake for now. All combat feedback must remain readable on a physical phone.

### Encounter and boundaries

Start: choose one or three enemies and tap Fight. Hero spawns near the lower arena centre; enemies spawn ahead, outside melee range. All enemies dead means victory; zero hero HP means defeat, taking priority if both occur together. Result panel offers Retry and mode selection. Retry resets HP, positions, timers, input, attack commitments, effects and dodge charges.

Explicitly out: guards/orders, armies, officers/bosses, archers, stamina, blocking, three-hit combos, shield bash, perfect-dodge rewards, morale, reinforcements, campaign, upgrades, inventory, saving, final art, animation-generation tools, music, monetisation and crowd optimisation.

### Verification and decision gate

Verify light/heavy separation, damage once per swing, invulnerability boundaries, dodge-charge recharge, telegraph/hit-area agreement, action cancellation, wall containment, simultaneous touch input, focus loss, victory, defeat and repeated retry. Prefer a few meaningful state/timing tests over a large test framework.

On the actual phone, play both modes for several minutes. Record device, build/version and observed performance; desktop results do not establish mobile performance. Ask testers whether they understood incoming attacks and why they were hit. Watch for unwanted heavy attacks, missed dodge presses and repeated thumb repositioning.

Continue only when movement and actions register reliably, damage is understandable and players want another attempt. If one enemy feels poor, fix controls and combat. If one feels good but three feel chaotic, fix spacing and attack scheduling. Add the guard only after this test succeeds. This prototype does not validate large battles or the commercial game.
