# Implementation contract — engineer-only tasks

## Baseline technical map
- `scripts/game.gd`: encounter state, 60 Hz fixed substeps, main scene wiring, keyboard poll, touch controls and menu.
- `scripts/combat_input.gd`: input aggregator consumed by Hero; currently touch/key-centric with one-step flags.
- `scripts/hero.gd`: attack, dodge, guard, parry, state transitions and movement-facing logic.
- `scripts/enemy.gd`, `scripts/encounter_controller.gd`: enemy state and max-two attack commitments.
- `scripts/iso.gd`, `scripts/arena_view.gd`: spatial projection and arena display.
- `scripts/menu_panel.gd`, `scripts/combat_hud.gd`, `scripts/touch_controls.gd`: current portrait/touch interface.
- `resources/tuning.tres`, `resources/weapons/`, `resources/captain.tres`: proven combat values.
- `tests/run_tests.gd`: v0.9 combat baseline (historical 460 passing checks; new revision must be rechecked by QA).
- `project.godot`: currently 720×1280 portrait. `export_presets.cfg`: Android baseline; Windows export preset added as admin infrastructure.

## Milestone 1 — controller + PC landscape conversion (FIRST; gameplay owner Fable)
1. Implement declarative InputMap and one device-agnostic CombatInput translator. Preserve reliable one-step press edges across the 60 Hz substep accumulator; held block and aim cannot stick after device loss.
2. Left-stick movement maps through `Iso.stick_to_ground`. Right-stick aim/facing does not teleport targeting behind hero. Use defined dead zones; preserve existing reach and directional protection semantics.
3. X light/Y heavy must be separate immediate commands (the heavy has its normal committed windup); no tap/hold timing on primary gamepad. B dodge, LB guard, A confirm/interact, Options pause. Keyboard fallback retained.
4. Re-layout viewport to 1280×720, remove/hide touch UI on PC, change menu/title/result/selection focus to gamepad navigation, show controller prompts. Disconnect pauses safely.
5. A single arena must start, play, pause, defeat/win and retry without mouse. **Stop and hand commit to QA.**

## Milestone 2 — three-stage physical-door vertical slice
1. Introduce RunDirector/RunState and ArenaCatalog (names flexible). Keep combat rules owned by Game/Hero/Enemy; move progression/door state out of low-level combat.
2. Add `ROOM_CLEAR` and `DOOR_CHOICE` states separate from FIGHTING, VICTORY and DEFEAT. Door collisions and button prompts must work only after enemies are cleared.
3. Two **physical** doors in arena world coordinates and a focused preview with real enemy/reward differences. A proximity + Interact commits exactly once and transfers to one authored next-stage variant.
4. Carry HP, chosen weapon/shield and capped temporary buffs; clear enemies/signals/input across transition. Have an end-of-slice screen after stage 3.
5. Save at stable stage boundaries and recover on boot. **Stop and hand commit to QA.**

## Milestone 3 — finite 10-stage campaign
- Five named arena layouts with lighting variants, five added regular enemy identities total, stage-5 champion, stage-10 final boss with two readable phases. Pike Sentinel and War Hound enter in M2; add the Iron Warden, Chain Penitent and War Herald after M2 QA.
- Every door variant resolves to a real encounter and terminates. All branch paths reach the final encounter. No unbounded procedural population.
- Intro/onboarding, settings, pause, death, restart, completion, credits, run statistics and replay.
- Use data-driven, validated content IDs instead of hardcoding every branch in Game.

## Milestone 4 — presentation and usability
- Polish readable attacks, enemy identities, controller cues, parry feedback, door targeting, sound and arena scale without invalidating collision/hit tests.
- Tune combat for both strong and weak player skill, not only deterministic bot wins. Never self-certify real controller feel based on CI.

## Milestone 5 — desktop build completion
- Produce a native Windows distribution, a reproducible export path and release-ready menus/credits, but leave store publishing and title clearance for explicit approval.
- QA and physical human input acceptance are independent and tracked in QA_PROTOCOL.md.

## Scope and hard guardrails
No renderer replacement, no Unity migration, no network, no unlicensed assets. Preserve regressions for the old isolated one-room arena. Avoid changing combat tuning as a side effect of remapping input or changing resolution. Fable is responsible for code implementation; **do not run tests or CI commands**, because QA is separately assigned. When source changes land, automatically triggered GitHub Actions and a cheaper QA agent handle verification.

## Coding completion note template
Commit: SHA. Milestone: N. Changed files: names. Player-visible behavior: precise. Known concerns: precise. QA: pending (until confirmed by QA, with link to run). Next smallest gameplay task: precise.
