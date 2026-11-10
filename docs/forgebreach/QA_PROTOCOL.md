# Independent QA protocol — GitHub Actions + lower-cost review model

## Role allocation and budget policy
- **Fable 5.2 / Claude Code:** implements *new game code only*, with checkpoints and coherent commits. It does **not** execute test suites or spend thinking time re-running test matrices.
- **GitHub Actions:** automatically runs Godot import, existing regression suite, main-scene headless boot and an **unvalidated** Windows desktop export, at *zero language-model tokens*.
- **Cheaper QA model / human:** triages CI results, writes/updates test-only fixtures and checks, inspects artifacts/screenshots, files reproducible defects, and signs off test claims. Does not silently rewrite gameplay mechanics.
- **User:** actual hands-on controller assessment and release approval. CI cannot feel input latency or verify in-person gameplay.

`.github/workflows/forgebreach-qa.yml` is the automation entry point. Every push to the dedicated branch triggers it. Logs are uploaded even when a step fails. The Windows artifact is explicitly a CI export, **not** a verified executable-on-Windows or physically tested controller build.

## Old invariants that cannot be weakened
Historical v0.9 460 checks: damage once per swing, 5 weapon identities, attack timing, telegraphs exactly matching hit volumes, dodge i-frames and recharge, shield/guard/parry, stagger timing, same-frame defensive pre-resolution, multi-actor collision, at-most-two attack commitments, simultaneous death = defeat, input cancellation and old one-arena retry. Do not delete old tests merely because old on-screen touch input is no longer displayed on PC. Old mobile UI checks may be separated as a legacy test fixture when truly incompatible, not silently suppressed.

## New QA matrix by milestone
**M1 input:** left-stick directions and analog dead zone; right-stick neutral facing; X immediate light; Y separate heavy; B dodge; LB press/hold/release; A menu; Options pause; D-pad focus; no double press through substeps; focus loss; disconnect and reconnect; keyboard fallback. Viewports 1280×720 and 1920×1080; UI focus visible.

**M2 doors:** locked in combat; unlock after last enemy; physical proximity required; truthful previews; A interacts exactly once; no post-mortem transition; carried HP/perks valid; enemies disposed; old action flags cleared; save round-trip; no double award; stage-3 slice ending.

**M3 campaign:** all 10 stages reachable; both branches reachable and finite; champion stage 5, final boss stage 10; every content ID resolves; win→credits; defeat/new run; save across transitions; corrupt save safe failure; no required upgrade or soft lock.

**M4:** visual/presentation screenshot sweeps, telegraph alignment, controller glyphs, legible UI at TV distance; source and licence provenance.

**M5:** exported Windows EXE/PCK present; smoke launch on an actual Windows machine; full gamepad run; pause/resume; unplug behavior; save persistence; packaging hygiene.

## Test-agent prompt (paste into a cheaper model)
You are FORGEBREACH's independent QA engineer, not its gameplay developer. Read `docs/forgebreach/QA_PROTOCOL.md`, `GAME_SPEC.md` and the latest `PROGRESS.md`. Fetch GitHub Actions run logs and artifacts for branch `feature/forgebreach-controller-arena-crawl`. Verify result on the exact HEAD SHA. Add or repair *tests and CI configuration only* where needed, without changing production combat logic or weakening established regressions. Inspect actionable failures and produce a concise bug report: commit SHA, failing test, reproducible steps, expected, actual, smallest implicated source area, evidence link, and severity. Record untested physical controller/Windows behavior honestly. Mark PASS only for checks actually executed. Hand each gameplay fix back to Fable. Do not claim successful release or recommend broad refactors on the basis of one warning.

## QA sign-off format
- HEAD SHA:
- CI run URL and conclusion:
- Existing combat suite checks/failures:
- New tests added and exact command:
- Windows export outcome/artifact:
- Physical controller validation: NOT DONE unless real recorded evidence
- Blocking bugs with file/line evidence:
- Safe next milestone: GO / NO GO and rationale

## Human controller acceptance — mandatory later
Test at least Xbox-compatible controller on Windows, all menu navigation, two-stick movement/aim, fighting with all five weapons, dodge/block timing, door interaction and safe reconnect. A second controller type and couch-distance display check are strongly preferred. A green GitHub run does **not** discharge this requirement.
