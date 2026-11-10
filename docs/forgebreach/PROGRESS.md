# FORGEBREACH progress ledger

Updated 2026-11-10. This file is the durable checkpoint for handovers; distinguish implementation, automated evidence and physical verification.

| Milestone | Status | Evidence / blocker |
| --- | --- | --- |
| 0: baseline protected | DONE | `combat-polish-v0.9` at `6df060e606e9fc82a53dfc1302d226a4529047f1`. Historical successful 460-check/Android CI: https://github.com/kavemankai/Phone-of-thrones-/actions/runs/39247887572 |
| Admin: isolated work branch | DONE | `feature/forgebreach-controller-arena-crawl` |
| Admin: game brief, QA division and issue list | DONE | See `START_HERE.md`, `GAME_SPEC.md`, `ENGINEERING.md`, `QA_PROTOCOL.md` |
| Admin: automatic test + Windows export pipeline | CI PASS (baseline only) | [Run 42774512534](https://github.com/kavemankai/Phone-of-thrones-/actions/runs/42774512534): Godot import, existing combat tests, 120-frame boot and Windows cross-export succeeded on admin commit `3cb6885717eef2e81e022c2786e11b9268575891`. Windows/gamepad runtime NOT TESTED |
| M1: 16:9 controller-first combat | **SOFTWARE QA PASS; HARDWARE PENDING** | Gameplay fixes `ed213487`; QA PR #11 merged at `76be1892`; [QA run #42797533832](https://github.com/kavemankai/Phone-of-thrones-/actions/runs/42797533832): 460 legacy + 39 new tests passed; Windows cross-export passed. **Real Windows/gamepad check #15 still required.** |
| M2: three-arena door-choice vertical slice | NOT STARTED | After M1 QA handoff |
| M3: 10-stage finite campaign | NOT STARTED | After M2 QA handoff |
| M4: game-feel / art / audio polish | NOT STARTED | Requires human controller playtests |
| M5: Windows release acceptance | NOT STARTED | Native Windows and physical gamepad evidence required |

The existing project still runs as Shieldwall Combat Test; no new gameplay is claimed by these administrative commits. The displayed title FORGEBREACH is provisional.

### Activity log
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
