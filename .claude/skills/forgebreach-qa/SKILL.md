---
name: forgebreach-qa
description: Independently triage FORGEBREACH GitHub Actions and gameplay regressions using a lower-cost QA model; produce evidence-based reports and tests without implementing gameplay.
argument-hint: "[commit-sha or issue-number optional]"
disable-model-invocation: true
---

# FORGEBREACH independent QA takeover

**Role:** a separately started, lower-cost-model QA session. This skill does **not** automatically select a cheap model or schedule an agent; choose that model before invoking. Optional target: `$ARGUMENTS`.

1. Read `docs/forgebreach/QA_PROTOCOL.md`, `PROGRESS.md`, `GAME_SPEC.md` and the active issue/PR #9. Identify the exact implementation commit and its GitHub Actions run. Never use a green run from a different SHA.
2. Prefer GitHub Actions results and retained logs. Tests run in GitHub Actions without LLM token cost. Do not rerun the full suite repeatedly or spend time reimplementing the test runner; if targeted reproduction is essential, make it small and document the command and environment.
3. Preserve the v0.9 combat test contract. Design and commit independent **test-only** scenarios for controller input, arena-door transitions, checkpoint saves, ending routes and regressions. Work on a QA child branch / pull request when modifying tests; do not overwrite Fable's in-progress gameplay changes.
4. If the failure is gameplay code, produce a focused issue/report with exact source location, expected vs actual, repro steps, SHA and CI link. Hand the fix back to Fable. Do not silently rewrite gameplay logic or lower test expectations.
5. Classify success honestly: unit tests, headless boot, Linux-produced Windows export, actual Windows execution, human controller testing and store acceptance are distinct evidence categories. Automated tests cannot certify controller feel.
6. Report a **GO / NO GO** decision for the specific milestone only, with its evidence and blockers. If the run or artifact is inaccessible, state that rather than guessing.

Return this compact format: SHA; CI URL/status; existing tests summary; new test files/coverage; reproducible failures with owners; Windows export status; physical controller evidence; milestone GO/NO GO; next handoff.
