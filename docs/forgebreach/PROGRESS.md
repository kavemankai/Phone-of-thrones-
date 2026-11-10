# FORGEBREACH progress ledger

Updated 2026-11-10. This file is the durable checkpoint for handovers; distinguish implementation, automated evidence and physical verification.

| Milestone | Status | Evidence / blocker |
| --- | --- | --- |
| 0: baseline protected | DONE | `combat-polish-v0.9` at `6df060e606e9fc82a53dfc1302d226a4529047f1`. Historical successful 460-check/Android CI: https://github.com/kavemankai/Phone-of-thrones-/actions/runs/39247887572 |
| Admin: isolated work branch | DONE | `feature/forgebreach-controller-arena-crawl` |
| Admin: game brief, QA division and issue list | DONE | See `START_HERE.md`, `GAME_SPEC.md`, `ENGINEERING.md`, `QA_PROTOCOL.md` |
| Admin: automatic test + Windows export pipeline | CI PASS (baseline only) | [Run 42774512534](https://github.com/kavemankai/Phone-of-thrones-/actions/runs/42774512534): Godot import, existing combat tests, 120-frame boot and Windows cross-export succeeded on admin commit `3cb6885717eef2e81e022c2786e11b9268575891`. Windows/gamepad runtime NOT TESTED |
| M1: 16:9 controller-first combat | NOT STARTED | Fable gameplay assignment |
| M2: three-arena door-choice vertical slice | NOT STARTED | After M1 QA handoff |
| M3: 10-stage finite campaign | NOT STARTED | After M2 QA handoff |
| M4: game-feel / art / audio polish | NOT STARTED | Requires human controller playtests |
| M5: Windows release acceptance | NOT STARTED | Native Windows and physical gamepad evidence required |

The existing project still runs as Shieldwall Combat Test; no new gameplay is claimed by these administrative commits. The displayed title FORGEBREACH is provisional.

### Activity log
- 2026-11-10: product direction switched from phone combat prototype to finite, controller-first, Windows 16:9 arena progression.
- 2026-11-10: initialized protected feature branch at latest confirmed v0.9, prepared model-role separation and independent CI/testing workflow.

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
