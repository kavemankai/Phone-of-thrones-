# FORGEBREACH Milestone 1 — Independent QA, second pass

**Gameplay commit under test:** `ed213487a220d4e924b26d2ce387261f37616967` (issue #3 fixes #12/#13/#14).
**Known source result:** [CI #42779829096](https://github.com/kavemankai/Phone-of-thrones-/actions/runs/42779829096) succeeded (existing baseline test suite, import, boot, Windows cross-export) at that exact SHA.
**QA change set:** `qa/forgebreach-m1-controller-regressions` (test-only, CI-only and documentation).

## Prior findings and corrective changes
- Issue #14: explicit A-to-`ui_accept`, B-to-`ui_cancel`, D-pad/left-stick menu navigation and Enter/Esc/arrow bindings were added by Fable. Independent assertions check these at runtime. A synthetic button activation test additionally attempts to open the Fight panel using Godot's own GUI event flow.
- Issue #12: Space is removed from `ui_accept`; explicit test checks it remains mapped to `fb_dodge`. A subsequent held/rapid A/Enter test may still be needed because no general panel-transition debounce was introduced.
- Issue #13: focusable two-confirmation Quit is implemented. Independent signals check first press, second press, focus loss disarm, and result-display disarm.
- Legacy touch-band test now verifies arena corners fit above the **actual** HUD strip, rather than a historical mobile-only percentage.
- Obsolete Android workflow is already limited on the development branch by administrative commit `befb0825`.

## Honest acceptance boundary
The original v0.9 regression suite has 460 checks. The new independent test adds synthetic (software) input and UI checks and can only be marked passed after **this QA branch CI** finishes. Windows export from Linux is not execution on Windows. Real gamepad, focus movement, Windows input mapping and 1920×1080 visual readability still need human checks.

**Disposition:** QA decision pending the exact refreshed QA PR CI result. On failure: classify test harness fault versus production defect, do not silently remove an assertion; file a reproducible issue for Fable if a genuine gameplay fault is identified.
