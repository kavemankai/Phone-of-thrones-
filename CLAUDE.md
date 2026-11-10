# FORGEBREACH — Claude Code gameplay assignment

Read `docs/forgebreach/START_HERE.md`, `GAME_SPEC.md`, `ENGINEERING.md`, and `QA_PROTOCOL.md` before editing source. To resume a gameplay task, invoke `/forgebreach-takeover` (project skill); lower-cost QA uses `/forgebreach-qa` in a separate session. See `docs/forgebreach/TAKEOVER_PROMPT.md` for an ordinary-text fallback.

## Your role
You are the **gameplay implementation agent**, using the strongest Claude Code model for *new game code*. Your assignment is controller-first PC play and the finite interconnected arena-crawl. You are **not** the test-runner, QA analyst, release administrator or project manager.

- Work only in `feature/forgebreach-controller-arena-crawl` (or a clearly named child branch). Do not modify the protected baseline branch `combat-polish-v0.9`.
- Begin with Milestone 1 in `ENGINEERING.md`. Do not start the ten-arena campaign before the controller-first one-arena slice is integrated.
- Preserve all combat timing and rules already verified in the Shieldwall v0.9 regression suite unless a new product requirement specifically needs a change.
- Commit small, coherent implementation changes and update the brief status lines in `docs/forgebreach/PROGRESS.md`. Avoid unrelated refactors and broad dependency changes.
- **Do not run automated tests, headless test suites, CI workflows or build-verification loops yourself.** GitHub Actions performs repeatable automated checks on pushes. A separate lower-cost QA agent reviews the result, authors additional tests as needed and files precise failures. Fix only proven or well-characterized issues from that QA handoff.
- It is okay to read source and compiler/API documentation to implement code. Do not silently claim tests passed. No physical-controller, Windows, FPS or exported-build claims without evidence.
- On checkpoint completion, state which files changed, the behavior delivered, remaining implementation risks and the commit SHA, and hand off to QA. Do not spend your context window reading every CI log unprompted.

## Immutable product decisions
- Working name FORGEBREACH is provisional; naming/trademark validation is separate.
- Windows PC first; controller first; 16:9 landscape; keyboard secondary; no phone UI in the PC presentation.
- Godot 4.6.2 + existing isometric combat architecture, not Unity, not an engine rewrite.
- Ten finite encounter stages, with an obligatory champion at stage 5 and final boss at stage 10; two meaningful physical exit-door choices after ordinary stages where a choice is applicable.
- Five reusable handcrafted campaign arena layouts plus the prototype Test Room, five existing weapons, two new ordinary enemy identities maximum.
- No endless progression, open world, procedural maze, inventory, online systems, commerce or new metagame economy.
- Save only at stable arena boundaries; victory must lead to a genuine ending and credits.

## What to preserve
`scripts/game.gd`, `scripts/combat_input.gd`, `scripts/hero.gd`, `scripts/enemy.gd`, `scripts/encounter_controller.gd`, `scripts/iso.gd`, existing tuning and weapon resources, and `tests/run_tests.gd` are the combat baseline. Current tested contract includes 60 Hz substeps, attack telegraph/hit geometry parity, multi-touch behavior (for legacy baseline), guard/parry windows, dodge invulnerability, at-most-two simultaneous enemy commitments, immediate defensive pre-resolution and defeat winning simultaneous death ties.

## Handoff after each milestone
1. Commit the gameplay code.
2. Update `docs/forgebreach/PROGRESS.md` with concrete implemented items, any known limitations, and SHA; use "QA pending" unless actual results are supplied by QA.
3. Stop implementation expansion until the QA report for that milestone is reviewed.
4. Let GitHub Actions run tests; the separate QA agent owns reproductions, test changes and evidence.
