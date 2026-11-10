# START HERE — FORGEBREACH

**Owner:** gameplay coding by Claude Code (Fable 5.2); automated tests by GitHub Actions; QA review/test authoring by a cheaper model or human. Do not combine those roles by default.

**Repository:** https://github.com/kavemankai/Phone-of-thrones-  
**Development branch:** `feature/forgebreach-controller-arena-crawl`  
**Baseline branch:** `combat-polish-v0.9`, SHA `6df060e606e9fc82a53dfc1302d226a4529047f1`  
**Historical verified evidence:** v0.9 CI, 460 Godot checks and Android debug export, https://github.com/kavemankai/Phone-of-thrones-/actions/runs/39247887572  
**Platform:** Windows PC native, 16:9 gamepad-first, offline single-player.  
**Engine:** Godot 4.6.2 stable / GDScript / Compatibility renderer.  
**Working title:** FORGEBREACH, unapproved for public marketing.

Read in order:
1. `GAME_SPEC.md` — the product and scope lock.
2. `ENGINEERING.md` — implementation milestones and architecture guidance.
3. `QA_PROTOCOL.md` — separation of responsibilities and independent acceptance checks.
4. `PROGRESS.md` — current facts and outstanding tasks.
5. Existing `README.md`, `docs/v0.9-playtest.md`, `TEST_REPORT.md`, `scripts/game.gd`, `scripts/combat_input.gd`, `scripts/hero.gd`, `scripts/menu_panel.gd` and `tests/run_tests.gd`.

## Exact task for Claude Code / Fable

You are the gameplay engineer. Use the checked-out development branch and follow `CLAUDE.md`. Implement **Milestone 1 only first**: change the existing Shieldwall single arena from 720×1280 portrait/touch to a fully navigable 1280×720 landscape PC build with primary gamepad controls. Implement left-stick movement, right-stick independent facing, X light, Y heavy, B dodge, LB guard/parry, A menu/interact, Options pause, and keyboard fallback. Keep the existing combat simulation and its regression contract. Replace on-screen mobile buttons with gamepad-aware HUD prompts. All menus (including weapon/shield, combat, victory/defeat/retry, pause) must work gamepad-only, with robust disconnect/focus behavior.

Implement code, not a fresh design proposal. Make small commits and update PROGRESS.md. **Do not execute tests or verification builds**; the separate QA workflow performs these automatically and a cheaper QA agent diagnoses failures. Do not weaken the old tests. After Milestone 1 is implemented, hand the exact commit SHA to QA; only then proceed to Milestone 2's three-arena door-choice slice.

## Project-wide done criterion

Start new run → choose weapon → beat each bounded stage → physically approach one of two doors after a clear → choose route and carry health/perks → stage 5 champion → stage 10 final boss → closing scene/credits → replay. All through a controller with no mouse.
