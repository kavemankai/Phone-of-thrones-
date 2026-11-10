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


## Verified follow-up: PASS
**Source gameplay head:** `ed213487a220d4e924b26d2ce387261f37616967`.  
**QA branch SHA:** `8ab06e089d07f903543aa4979ac58c876d7c0a81`.  
**QA run:** [42797533832](https://github.com/kavemankai/Phone-of-thrones-/actions/runs/42797533832): **460/460 existing combat, 39/39 new M1 checks, successful import, boot and Windows cross-export.**  
**Merged into feature branch:** PR #11 as `76be1892b0dad137e0789daac23597ce9fa763e0`.

The new tests confirm explicit gamepad A confirmation, B cancellation, directional menu navigation, duplicate-safe InputMap registration, Space removal from ui_accept while preserving combat dodge, first-launch Fight focus and actual synthetic A-to-Fight activation, and Quit's two-confirmation/focus-disarm semantics.

The original focus assertion was written against a Game instance left in a different menu state by an earlier test. The corrected test checks a new Game instance on its first displayed title screen, without removing the A activation test. No gameplay source fix was made.

**Software-only M1 QA: GO. Physical Windows/gamepad acceptance: NOT YET VERIFIED.** Hardware smoke and any repeated A/Enter menu-transition risk remain tracked by [issue #15](https://github.com/kavemankai/Phone-of-thrones-/issues/15).
