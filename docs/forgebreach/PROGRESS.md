# FORGEBREACH progress ledger

### 2026-11-12 — Visual assets and animation polish (QA pending)
- Working branch: `art/forgebreach-animation-polish-20261112`, based on the newer campaign branch, not the older default/prototype.
- 34 art and 16 audio source files enumerated; their binary artwork/audio was not edited. Added imported-resource QA plus a complete scope/limitations record at `docs/forgebreach/VISUAL_AUDIT_2026-11-12.md`.
- Presentation code: hero idle/run blending driven by measured travel, attack anticipation/follow-through, dodge afterimages, translucent weapon trails; enemy displacement-driven bobbing and action stretch; corrected rotating sparks, dodge dust and flickering single-room braziers.
- **QA PENDING:** No in-chat Godot runtime or physical PC/controller testing. Existing combat state/timers and attack hitboxes intentionally unchanged. Merge only after CI and screenshot/playtest review.


Updated 2026-11-10. This file is the durable checkpoint for handovers; distinguish implementation, automated evidence and physical verification.

| Milestone | Status | Evidence / blocker |
| --- | --- | --- |
| 0: baseline protected | DONE | `combat-polish-v0.9` at `6df060e606e9fc82a53dfc1302d226a4529047f1`. Historical successful 460-check/Android CI: https://github.com/kavemankai/Phone-of-thrones-/actions/runs/39247887572 |
| Admin: isolated work branch | DONE | `feature/forgebreach-controller-arena-crawl` |
| Admin: game brief, QA division and issue list | DONE | See `START_HERE.md`, `GAME_SPEC.md`, `ENGINEERING.md`, `QA_PROTOCOL.md` |
| Admin: automatic test + Windows export pipeline | CI PASS (baseline only) | [Run 42774512534](https://github.com/kavemankai/Phone-of-thrones-/actions/runs/42774512534): Godot import, existing combat tests, 120-frame boot and Windows cross-export succeeded on admin commit `3cb6885717eef2e81e022c2786e11b9268575891`. Windows/gamepad runtime NOT TESTED |
| M1: 16:9 controller-first combat | **SOFTWARE QA PASS; HARDWARE PENDING** | Gameplay fixes `ed213487`; QA PR #11 merged at `76be1892`; [QA run #42797533832](https://github.com/kavemankai/Phone-of-thrones-/actions/runs/42797533832): 460 legacy + 39 new tests passed; Windows cross-export passed. **Real Windows/gamepad check #15 still required.** |
| M2: three-arena door-choice vertical slice | **SOFTWARE QA PASS; HARDWARE PENDING** | Codex `ddd1dade`, QA PR #19 merged at `2e74d90f`. [Run #42809455997](https://github.com/kavemankai/Phone-of-thrones-/actions/runs/42809455997): original 460 + M1 39 + M2 31 automated checks passed, Windows cross-export. **Physical Windows/gamepad issue #20 remains open.** |
| M3: 10-stage finite campaign | NOT STARTED | After M2 QA handoff |
| M4: game-feel / art / audio polish | NOT STARTED | Requires human controller playtests |
| M5: Windows release acceptance | NOT STARTED | Native Windows and physical gamepad evidence required |

The existing project still runs as Shieldwall Combat Test; no new gameplay is claimed by these administrative commits. The displayed title FORGEBREACH is provisional.

### Activity log
- Combined test map (experiment; QA pending; not parsed, run or built by the gameplay agent). Menu footer: "All rooms (test map)". `Game.start_map()` lays one variant of each Ward I stage (`Game.MAP_ROOMS`: Gatehouse, Kennels "Feeding yard", Hall "Grand stairs", Forge "Bellows" with vents, Crown Pit) in one column, hero at the bottom, Gate Captain at the top, about 400 by 1990 ground units. Between neighbours is an 18-unit wall with an 84-unit gate. A gate is solid until every enemy of the room in front of it is dead, then it opens and you walk through; there is no screen change, no door choice and no pickup. Enemies of rooms the hero has not reached do not step. The camera scales as for one room and follows the hero. Clearing every room is victory; Retry and "Restart fight" restart the map.
  - How: walls, locked gates and props are ordinary cover rectangles in `hero.arena_cover`, so movement, attack blocking and line of sight use the existing `ArenaSpace` code. Enemy routing uses the new `hero.nav()`, which on the map is only the props of the room being fought in. `ArenaView` draws per-room floors, walls and gates when `tiles` is set. Ward runs and the Test Room do not take any of these paths.
  - Known limits: an enemy does not route through a gate, so if the hero retreats to an earlier room it walks into the wall; walls and gates are drawn under all characters; vents run on one clock from the start of the map; rooms are fixed, not drawn from the pools.
  - QA checks worth adding: `start_map` spawns nine enemies in five rooms; the hero cannot cross a locked gate; killing room k's enemies opens gate k only; enemies with a higher `map_room` meta do not move until the hero enters; clearing all rooms gives VICTORY; `start_fight` afterwards restores the Test Room size and empties the map lists.
- Batch A: game feel, more pickups, forge vents, options (QA pending; not parsed, run or built by the gameplay agent; built without a capture of PR #26, so none of it has been seen).
  - Impact feedback (`scripts/combat_fx.gd`): hit-stop of 0.045 s on a light hit, 0.09 s heavy, 0.12 s parry, 0.06 s when the hero is hurt, 0.15 s at the boss's phase change; screen shake on heavy hits, hero damage, guard break and phase change; sparks on hits and blocks, a gold ring on parry, a ring on kills. `Game._process` skips simulation steps while the freeze lasts; `Game.step()` is unchanged. Struck sprites rock back while their hit flash lasts.
  - Options on the pause menu: screen shake on/off and master volume in five steps, saved to `user://settings.cfg` (`scripts/game_settings.gd`). Pause buttons are smaller to fit eight of them.
  - Pickups: Executioner (+50% to staggered enemies), Bulwark (blocking costs a third less stamina), Momentum (a kill returns a roll charge), Long Reach (light reach +15%), Stonefoot (hits on the hero -20%), Afterimage (+0.06 s roll invulnerability). Fourteen in all. Riposte now adds at most 16 damage.
  - Forge vents: every Cinder Forge room has two floor strips (`WardData._FORGE_VENTS`) that warn for 1.4 s and burst for 0.8 s on a 5 s cycle, the second 2.5 s behind the first, starting 2 s into the fight. A body whose centre is inside the drawn strip takes 10 (hero) or 8 (enemy) once per burst. Door cards list "floor vents".
  - The ending shows the run seed.
  - First-guess numbers: every hit-stop and shake value, all six pickups, vent timing and damage.
  - QA checks worth adding: a button press during a freeze still acts on the first step after it; `Game.step()` results are unchanged with effects firing; `WardData.vent_state` over one cycle; a vent burns a body once per burst and only inside its rectangle, and a hero roll through it is refused then retried; `WardData.validate` still passes; each new pickup's effect; Riposte bonus never exceeds 16; settings survive a reload and a missing file gives defaults.
  - Human gate: one capture or play session covers this batch and PR #26 together.
- Presentation fixes from the Ward I simulated-run capture (QA pending; not parsed, run or built by the gameplay agent). Source: a 45 s scripted run on the art build, reviewed frame by frame; audio not assessed.
  - Arena is about 30% larger on PC: the status strip is a fixed 96 px (`Game.DESKTOP_BAR_HEIGHT`) instead of 28% of the height, and the room header moved to the top-left corner. The phone layout is unchanged.
  - Door choice is two opaque cards in the bottom corners above the strip, one per door; nothing is drawn over the health bars or legend any more. Cards also list second waves.
  - Cover art keeps its painted proportions, is as wide as its footprint's on-screen diamond and stands on the footprint's front corner; it is mirrored for cover that runs the other way. Collision rectangles are unchanged.
  - War Herald ring range 170 to 105, drawn fainter.
  - Menu column has a dark plate behind it. After a ward victory the campaign button reads "New run" and takes the focus.
  - A named boss health bar in the top-right corner with a notch at the second-phase threshold.
  - Not changed: the title screen still focuses Test Room first, because `tests/forgebreach_m1_qa.gd` asserts `focus == menu._fight_button` on a fresh title. Making New campaign the default needs that check retargeted by QA. Enemy death already tips and fades (the art pass added it); the capture's frame rate hid it.
  - Known limits: props are drawn under all characters, so a taller wall can show behind a character standing in front of it but also behind one standing beyond it; the left door card overlaps a sliver of the arena's lower-left edge; every position was chosen from arithmetic at 1280x720, not seen.
  - Check on the next capture: character height on screen, no text behind the door cards, cover art on its outline, Herald ring inside the room, focus on New run at the ending, boss bar visible, menu column fits inside 720 px.
- Ward I, "The Outer Walls" (QA pending; not parsed, run or built by the gameplay agent). The menu's New campaign now starts a five-room ward: Shattered Gatehouse, Blood Kennels, Hall of Banners, Cinder Forge, then the Gate Captain in the Crown Pit. Rooms 2 to 4 each have three variants in `scripts/ward_data.gd`; the run seed picks which two stand behind the doors, and both doors before the boss lead to the pit with different pickups. New enemies: Iron Warden (hits inside its 120 degree front arc do a quarter damage and cannot stagger; the shield is down during its own recovery and while staggered), Chain Penitent (two chained 170 degree sweeps; replaces the Sweeper stand-in in the ward), War Herald (never attacks, keeps away, other enemies inside its ring move 35% faster). The Gate Captain has 190 health and at half health reels for 1.2 s, then moves 20% faster and adds a full-circle Whirl. One Forge variant has a second wave that enters from the far end. The ending shows time, hits taken, parries and pickups; the pause screen lists pickups with their text. Checkpoints gain optional `plan` and `stats` keys; `VERSION` stays 1.
  - Kept on purpose: the three-room slice. `CampaignRun.ROOMS` and `Game._new_campaign(w, shield)` still run it by default because `tests/forgebreach_m2_qa.gd` drives them directly. It is no longer reachable from the menu. Once QA points those checks at the ward (`_new_campaign(w, shield, CampaignRun.PLAN_OUTER_WALLS)`), the slice table and the Sweeper profile can be deleted.
  - Not done: forge vent hazards, elites, vows, camp, weapon variants, wards two and three, any art or audio change. Run flow is still inside `game.gd`.
  - First-guess numbers: every value on the three enemies, the boss's second phase and room heals.
  - QA checks worth adding: `WardData.validate(WardData.OUTER_WALLS, CampaignRun.FOE_NAMES)` is empty; a ward run reaches room 5 through either door at every stage and ends in VICTORY with the checkpoint removed; `door_variants()` gives two different variants for pooled stages and is the same after save and reload; Warden `take_hit` from inside the arc deals a quarter and from behind, in RECOVER or in STAGGER deals full; a Herald sets `speed_buff` to 1.35 only inside `aura_range` and it returns to 1.0 when the Herald dies; the Herald never commits an attack; the boss enters phase 2 exactly once at or below half health, also through a dagger parry execute; in "Anvil row" the second wave spawns before ROOM_CLEAR and doors stay shut until it is dead; `plan` and `stats` survive a checkpoint round trip; a slice-era checkpoint without those keys still loads.
  - Human gate: play the ward through several times with different doors. Does a run feel different from the last, and do you want another go after the ending?
- Run pickups experiment (QA pending, not parsed or run by the gameplay agent). Purpose: find out whether pickups make two runs with the same weapon play differently, before any more rooms are built. Each door in the three-room slice now also offers one of eight pickups (`scripts/boon.gd`): Riposte, Second Wind, Third Step, Patient Guard, Heavy Hand, Blood Price, Slipstream, Iron Lungs. The two doors always offer different pickups not yet owned, fixed per run by a seed, so a reloaded run shows the same doors. Two are taken per slice run. Effects are applied in `scripts/hero.gd` and are inert outside a campaign (Test Room unchanged). Checkpoints store `boons` and `seed` as optional keys; `VERSION` stays 1 and older files load as a run with no pickups. The door panel is taller and wider and covers the button legend while doors are open. Not done: pickups are not listed on the pause or result screens; room and enemy tables are still hardcoded in `campaign_run.gd`. QA checks worth adding: the two offers differ and exclude owned pickups; `offer()` is stable across save and reload; each pickup's effect (double damage after parry, stamina refund, third roll charge, longer parry window, heavy reach and knockback, heal on kill, free faster attack after a roll, halved stamina delay); a checkpoint with an unknown or duplicate pickup id is rejected and preserved. Human gate: ten slice runs, then decide whether runs feel different.
- M2 content pass: Pike Sentinel with minimum thrust range and exposed recovery, War Hound with an orbit and a locked leap, and solid campaign-only cover in the renamed Shattered Gatehouse and Blood Kennels. Windows Gatehouse entry, two enemies, the pike, and central cover were observed in-game. QA should check corner routing, cover collision for rolls and lunges, hits blocked through cover, Pike recovery, and Hound lock and orbit. The Hall Sweeper stays in the slice as a stand-in. Expanded roster and arena brief captured in GAME_SPEC.md.
- Local M2 checkpoint: the Gatehouse opens from New Campaign. Doors show their enemy mix, healing and any run guard bonus. Continue and Retry use the room entry snapshot. Independent QA should verify both doors at each clear, reward carry and reload, retry, clear-to-door input, controller-only completion and Test Room regressions. The ten-stage route and five arena names are recorded in GAME_SPEC.md for M3.
- Local stamina and roll: light 12, heavy 26, roll 18, normal block 1 per damage before the attack modifier (0.55 with a shield). Parry remains free. Recovery is 28/s after a 0.65 s delay and requires lowering the guard. Windows arena and HUD observed; combat balance and independent QA pending.
- Local controls option: title and pause menus now allow saved keyboard and controller bindings. The Windows menu, save across relaunch, and restore defaults were checked in the running game. Independent QA and physical controller checks are pending.
- 2026-11-10: product direction switched from phone combat prototype to finite, controller-first, Windows 16:9 arena progression.
- 2026-11-10: initialized protected feature branch at latest confirmed v0.9, prepared model-role separation and independent CI/testing workflow.

- 2026-11-10: M1 code landed (commits `2a17f90`, `149c1bd`, `50f1f00`). Handed to QA; M2 not started.

### M1 checkpoint (2026-11-10)
Commit: `50f1f00b1a6d2d48119b6da945729a4bd51911b6`. Milestone: 1 (issue #3). QA: pending, nothing executed by the gameplay agent.

Changed files: `project.godot`, `scripts/game.gd`, `scripts/combat_input.gd`, `scripts/hero.gd` (facing only), `scripts/menu_panel.gd`, `scripts/combat_hud.gd`; new `scripts/input_actions.gd`, `scripts/input_prompts.gd`, `scripts/ui_focus.gd`, `scripts/pause_panel.gd`. No tuning, weapon, enemy or test file was touched.

Player-visible behaviour:
- 1280x720 landscape, 16:9 letterboxed (`stretch/aspect="keep"`). Title reads FORGEBREACH.
- Actions `fb_*` are registered in the InputMap by `InputActions.ensure()` for all devices. Gamepad: left stick move (radial dead zone 0.20), right stick facing (0.35), X light, Y heavy, B dodge, LB guard, Start pause. Keyboard: WASD/arrows, J light (tap/hold as in v0.9, or light-only with the split option), L heavy, Space dodge, K guard, Esc/P pause, F11 fullscreen.
- Right stick sets facing while the hero may turn (idle, charging, recovery, guard). At rest, walking sets facing as before; aim assist is unchanged and still only snaps inside its 90 degree cone.
- Menus take focus: D-pad/left stick/arrows move, A/Enter selects. Focus ring is drawn on every button and focus is pulled back into the visible panel each frame.
- Pause panel: resume, restart fight, change loadout, fullscreen, quit. Start/Esc/B also resume.
- Pad unplugged or window focus lost during a fight: all `fb_*` actions are released, CombatInput is cleared and the fight pauses with a reason line.
- PC HUD is a bar under the arena (HP, guard, dodges, enemies, loadout) with a button legend that follows the last device used (Xbox labels, PlayStation names, or keys). Touch buttons are hidden and disabled unless the `mobile` feature is present.

Known concerns for QA:
1. Nothing here has been parsed or run by Godot. A script error would fail the import step first.
2. `test_isometric_view` requires the arena's corners above `vp.y * (1 - control_band_fraction)`. To keep that check green the arena uses only the top 72% of the screen and the HUD bar takes the rest. A larger arena needs that test relaxed by QA.
3. `g.notification(FOCUS_OUT)` now also pauses the fight. The existing check only inspects cleared input, so it should hold.
4. The Enter-starts-fight shortcut is gone; Enter now activates the focused button (Fight is focused by default).
5. Space is both dodge and `ui_accept`: a keyboard player mashing Space at the end of a fight can trigger Retry as the result panel appears.
6. The title menu has no Quit entry; quitting by pad is only on the pause panel.
7. Toggling fullscreen during a fight may fire a focus-out on some window managers and pause it.
8. Phone build: orientation is now landscape and the touch layout was not re-authored for it. Android is no longer a target, but `godot-checks.yml` still exports an APK on pull requests.
9. PlayStation detection is a name match on `Input.get_joy_name`; unknown pads get Xbox labels.
10. Not verified by anyone: stick feel, dead zones, focus navigation order with a real pad, disconnect on Windows, 1920x1080 scaling.

New checks worth adding (QA owns them): actions exist after `Game._ready`; a synthetic `InputEventJoypadButton` X starts a light windup in one step and Y a heavy; `input.aim` turns facing without movement and leaves it when zeroed; LB press/hold/release via `_input`; `pause_game()` freezes `fight_time`; `_on_joy_connection_changed(0, false)` clears input and pauses; `return_to_menu()` leaves no enemies.

Next smallest gameplay task after QA sign-off: issue #4, RunState/ArenaCatalog and the `ROOM_CLEAR` state.

### M1 QA fixes (2026-11-10): issues #14, #12, #13
QA: pending. Not parsed, run or built by the gameplay agent. Files: `scripts/input_actions.gd`, `scripts/menu_panel.gd`, `scripts/game.gd`.
- #14: `InputActions.ensure()` now adds, only where missing, gamepad A to `ui_accept`, B to `ui_cancel`, and D-pad plus left stick to `ui_left/right/up/down` (all devices). Enter, Escape and the arrow keys are added the same way if absent. Repeat calls add nothing.
- #12: Space is removed from `ui_accept`. Space still dodges; Enter and gamepad A confirm. A Space press can no longer activate Retry, Resume or any other button.
- #13: the title/result panel has a focusable "Quit to desktop" button under Fight/Retry. It needs two presses ("Press again to quit"); moving focus away or re-showing the panel cancels the first. Fight/Retry stays the default focus. `MenuPanel.quit_requested` is the signal.
- Concerns: `ensure()` edits the global InputMap, so Space no longer confirms anywhere in the game. Whether a real A/Cross press activates a focused button is still unproven on hardware. The menu hint lost its third line to make room for Quit.

### Future checkpoint template
Date, milestone, commit SHA, code delivered, CI URL, QA sign-off, physical tests, next smallest implementation task.

### Implementation tickets
- [#3 Controller-first landscape combat](https://github.com/kavemankai/Phone-of-thrones-/issues/3) — gameplay owner Fable; first task.
- [#4 Three-room door-choice slice](https://github.com/kavemankai/Phone-of-thrones-/issues/4).
- [#5 Ten-stage complete campaign](https://github.com/kavemankai/Phone-of-thrones-/issues/5).
- [#6 Presentation and balance](https://github.com/kavemankai/Phone-of-thrones-/issues/6).
- [#7 Windows release candidate](https://github.com/kavemankai/Phone-of-thrones-/issues/7).
- [#8 Independent QA](https://github.com/kavemankai/Phone-of-thrones-/issues/8) — lower-cost model/human.

### Automated baseline verification
The first [FORGEBREACH CI workflow](https://github.com/kavemankai/Phone-of-thrones-/actions/runs/42774512534) completed successfully on 2026-11-10. It exported a Windows desktop artifact and retained QA logs. It did not perform physical controller tests, run the Windows binary, change UI orientation, or implement arena progression; those remain in M1 and later. 

### Claude Code handover setup
- Project-wide instructions: root `CLAUDE.md` (loaded at session start).
- Manual gameplay skill: `.claude/skills/forgebreach-takeover/SKILL.md`, invoke `/forgebreach-takeover`.
- Manual QA skill: `.claude/skills/forgebreach-qa/SKILL.md`, invoke `/forgebreach-qa` **in a separate session with a lower-cost model**.
- Standalone first-turn prompt and cloud-session fallback: `docs/forgebreach/TAKEOVER_PROMPT.md`.
- Both skills use `disable-model-invocation: true`, so they do not consume their full context until explicitly invoked.
- CI pipeline additionally accepts pull requests targeting the implementation branch, so QA-only child PRs can be verified before merging.

### Milestone 1 QA disposition (2026-11-10)
- **Software QA: GO.** Gamepad action bindings, synthetic A-confirm of Fight, independent right-stick aim, shield/dodge, focus/disconnect simulation, UI navigation mappings, Space-vs-accept separation, idempotent action setup, and two-press Quit tests passed (39/39).
- **Regression QA: GO.** Original v0.9 suite passed (460/460).
- **CI packaging: GO for cross-export only.** Import, headless scene boot and Windows Desktop cross-export succeeded in [run #42797533832](https://github.com/kavemankai/Phone-of-thrones-/actions/runs/42797533832).
- **Physical gamepad acceptance: PENDING.** No real Windows execution, controller comfort, 1080p legibility or end-of-fight A/Enter timing sweep was recorded. See [hardware issue #15](https://github.com/kavemankai/Phone-of-thrones-/issues/15). Do not treat software success as full M1 hardware signoff.
- **QA branch integrated.** Pull request [#11](https://github.com/kavemankai/Phone-of-thrones-/pull/11) merged into this development branch; production gameplay source was not changed by QA. The prior failed QA assertions were harness-state mistakes (not a proven gameplay defect); corrected tests retained the actual controller A event assertion.
- M2 issue #4 remains not started. Finish the controller hardware smoke before unconditional M2 acceptance. The next implementation step is a three-arena door-choice slice after signoff.

### Independent M2 QA disposition (2026-11-10)
- **Software QA GO:** [FORGEBREACH Actions #42809455997](https://github.com/kavemankai/Phone-of-thrones-/actions/runs/42809455997) passed import, original **460/460** combat checks, **39/39** M1 controller/menu checks, **31/31** Codex M2 checks, headless boot and Windows cross-export on feature-branch QA merge commit `2e74d90f160c5d3bd3c07868262554232170b8a4`.
- **New M2 regression coverage:** rooms/variants, actual route enemy/reward data, pike/hound definitions, line-of-attack blockage and cover collision, doors locked during combat and clear delay, A-proximity gating, both door paths, correct healing/guard reward, repeat-press immunity, checkpoint save/read, end-of-slice victory and checkpoint cleanup. See `tests/forgebreach_m2_qa.gd` and merged QA PR [#19](https://github.com/kavemankai/Phone-of-thrones-/pull/19).
- **Physical hardware NOT TESTED BY QA:** source records Codex local Windows smoke observations, but no independent controller/1080p run. Required validation is [issue #20](https://github.com/kavemankai/Phone-of-thrones-/issues/20). Also track residual M1 controller hardware testing [#15](https://github.com/kavemankai/Phone-of-thrones-/issues/15).
- **Scope remaining:** Codex implemented three arena environments (Gatehouse, Kennels, Hall) and two new planned regular archetypes (Pike Sentinel, War Hound) plus the temporary Hall Sweeper. Iron Warden, Chain Penitent, War Herald, Cinder Forge, Crown Pit, stages 4–10, champion/final boss and credits remain **NOT IMPLEMENTED** in this branch as of the referenced QA commit. Do not conflate the approved five-plus-five design with implemented content.
- **Next implementation step:** obtain real-controller acceptance of the three-room slice, then resume Milestone 3 by creating remaining content iteratively while preserving QA. PR #17's gameplay branch was merged into `ccr-7b5c3e78-buce4p`; the new QA tests were integrated into this feature branch and should be synced upstream separately when appropriate.
