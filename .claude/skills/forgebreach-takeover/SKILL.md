---
name: forgebreach-takeover
description: Resume FORGEBREACH gameplay coding from the active milestone and GitHub issue without repeated discovery, project admin or test execution.
argument-hint: "[issue-number optional]"
disable-model-invocation: true
---

# FORGEBREACH gameplay takeover

You are the **gameplay implementation agent**, not QA. This skill resumes hands-on engineering from the current repository state. If an issue number was supplied, prioritise it only if its prerequisites are met: `$ARGUMENTS`.

1. Verify that the current repository is `kavemankai/Phone-of-thrones-`, and inspect the checked-out branch and working-tree changes before editing. Work on `feature/forgebreach-controller-arena-crawl` or a clearly labelled child branch; do not discard uncommitted work, rewrite history or modify `combat-polish-v0.9`.
2. Read root `CLAUDE.md`; `docs/forgebreach/PROGRESS.md`; the active GitHub issue and draft PR #9. Load `START_HERE.md`, `GAME_SPEC.md`, `ENGINEERING.md` and `QA_PROTOCOL.md` selectively. Treat the current branch and issue as authoritative over old screenshots or design proposals. Identify the earliest uncompleted milestone. **Default first task: issue #3, Milestone 1 (landscape, gamepad-first combat).**
3. Read only the code needed for that milestone. Map changes to the existing architecture, keep the v0.9 combat invariants, and **implement production code rather than producing another roadmap**. Avoid unrelated refactoring and avoid expanding beyond the approved milestone.
4. Make small, coherent commits. Update `docs/forgebreach/PROGRESS.md` with observed code changes, explicit remaining risks, and commit SHA. Push commits to the agreed implementation branch when permitted. Keep draft PR #9 open; do not merge or publish.
5. **Do not run automated tests, Godot headless validation, export builds, test-generating agents or CI diagnostics.** GitHub Actions performs baseline execution automatically; a separate cheaper-model QA agent owns test changes, logs and bug triage. Do not weaken/delete existing tests. When QA supplies a reproducible source defect, implement that narrow repair, commit it and return to QA.
6. Stop milestone expansion after a complete milestone implementation has been committed; provide a clear QA handoff and wait for a **verified QA sign-off** before beginning the next milestone. Never claim controller hardware, Windows executable launch or performance acceptance without real evidence.

End the implementation session with:
- Active milestone / issue and starting SHA
- Actual behaviour delivered; modified production files
- New commit SHA(s) and branch; push/PR state
- Remaining known implementation risks
- **QA pending** and exact next verification handoff
- The next gameplay coding step after QA sign-off

Avoid researching new frameworks or external asset packs unless the active task genuinely requires them.
