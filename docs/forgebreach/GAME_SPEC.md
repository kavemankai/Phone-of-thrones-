# FORGEBREACH — locked product specification v1

## High concept
A premium, finite, single-player, controller-first arena-combat game. Clear a compact fixed arena using readable, deliberate melee combat; after victory, inspect two unlocked physical doors advertising alternate encounter risks and rewards; choose a door and move to the next arena. This is *not* an endless arena survivor, not an open-world RPG, not a touch-first mobile game, and not an engine rebuild.

**Name:** FORGEBREACH is an internal working title only. Do not publish or change public storefront metadata without a name/trademark availability review.  
**First platform:** Windows native PC. Controller is primary, keyboard secondary. Do not promise console release.  
**Engine/genre:** Godot 4.6.2; fixed 2:1 isometric combat plane; premium offline game; no accounts, ads, in-app purchases or network requests.

## Locked v1 content budget
| Element | Limit |
| --- | --- |
| Total sequential stages | **10** |
| Mandatory champion stage | **5** |
| Mandatory final boss stage | **10** |
| Reusable handcrafted arena layouts | **5**, plus the prototype Test Room |
| Visual environmental themes | **2** |
| Existing playable weapons | Sword, Spear, Axe, Daggers, Zweihander |
| Regular enemy identities | Existing grunt + at most **2 new** |
| Boss identities | Existing captain adapted as stage-5 champion + final boss with readable second phase |
| Doors after ordinary stages | Up to **2**, each has a truthful encounter and reward preview |
| Ending | Final victory screen/short closing presentation, credits, statistics and replay |

Target a 20–40 minute successful first run, subject to real balance evidence. If scope bites, polish the 10 stages with fewer cosmetic variants rather than inventing more systems.

## Loop and progression

Stages 1–2 introduce movement, reach and hounds in the Gatehouse and Kennels. Stages 3–4 move through the Hall and Forge and introduce support enemies and wide attacks. The Crown Pit hosts the champion at stage 5 and the final boss at stage 10. Stages 6–9 revisit the arenas with different lighting, harder enemy mixes and higher stakes at each door. Alternate doors converge on the mandatory bosses. The final victory leads to an ending and credits.
Start/title → controller-only loadout → stage entrance → active combat → stage clear → 2 physically located unlocked door choices → enter next authored stage variant → carry health, selected weapon/shield, earned temporary run buffs → mid-boss → final boss → credits/replay.

A door is locked while any hostile remains or the outcome is unresolved. After clear, doors and their plaques become visible; move the hero to a door and press Interact. Each door reveals a *real difference*: for example greater threat and larger heal, or safer enemy mix and minor guard boost. Each choice transitions to exactly one next-stage variant. Route choices may reconverge at the following stage; do not double total scope by implementing an exponential graph. Stage 5 and 10 are forced gates, not fake door choices.

Keep upgrade choices minimal: no inventory, currencies or permanent character build. Candidate run-only rewards: small max-HP increase, immediate heal, guard capacity, dodge recharge adjustment, modest damage trait. Upgrades must be data-driven and capped, never picked twice on duplicate door interaction. The player should be able to finish without a single compulsory reward gimmick.

## Combat and feel
Carry forward the v0.9 mechanical base: five distinct weapon timings, dodge windows, shields on one-handed weapons, parry/stagger, clear attack windups and exact damage wedges. Do not make free auto-combat or turn it into a crowd simulator. At most two enemy commitments at once until measured tuning says otherwise. Player death on a tie remains defeat. Avoid collisions through pillars; decorative pillars are permitted until actual collision, navigation and line of attack are tested.

## Gamepad-first control default
| Gamepad (Xbox labels; equivalent PlayStation inputs) | Action |
| --- | --- |
| Left stick | Screen-relative analogue movement; nominal dead zone 0.20 |
| Right stick | Independent directional facing/aim; return to last valid facing when neutral, movement-facing fallback as appropriate |
| X / Square | Immediate light attack |
| Y / Triangle | Immediate heavy attack; preserve heavy windup/recovery |
| B / Circle | Dodge in left-stick direction, otherwise backward |
| LB / L1 | Hold guard; timed parry on initial raise |
| A / Cross | Interact with nearby unlocked door; confirm focused UI item |
| Options/Menu | Pause/resume; controller-reachable pause settings |
| D-pad | Menu navigation and door-preview UI |

Define Godot InputMap actions rather than scattering raw physical key/controller button queries. Support Xbox-compatible pads first; generic pads and PlayStation-style labels where detected. Handle unplug, focus loss, held-input reset and predictable menu focus. Keyboard secondary controls must remain functional. Do not show touchscreen controls in desktop builds.

## Arena format and presentation
Native 1280×720 base; scale to 1920×1080 and 2560×1440 without distorting combat geometry. Preserve fixed elevated isometric view with a fully visible arena. Use five reusable layouts: Gatehouse, Kennels, Hall, Forge and Crown Pit. Physical obstacles require real authoritative collision/pathing and attack-block checks; otherwise implement them as non-colliding decoration. Use lighting variants to distinguish return visits and alternate routes. Combat HUD: HP, stamina, guard, roll charges, loadout, stage number, remaining enemies. Controller glyphs, highlighted focus, readable boss telegraphs and door icons.

## Save/restart
Versioned stable checkpoint written to `user://` on each room transition/reward settlement. Persist weapon, shield, current stage, HP, route history, capped run bonuses and a stable stage-entry snapshot. No mid-combat snapshot in v1.0. Quitting mid-battle resumes at that arena's **entry** with original entry health/bonuses; never award the same door reward twice. Corrupt/incompatible save must not be silently overwritten. Defeat offers new run/retry without requiring grind.

## Out of scope
Endless mode, open world, procedural maze generation, branching story, co-op, online leaderboards, army AI, additional weapons, collectible gear/inventory, shops, currency economy, monetization, external AI/runtime services, high-end cinematic pipeline and platform-console certification.

## Vertical slice before scaling
Stage 1 → two physical doors → either Stage 2 variant → Stage 3 → a clear end-of-slice placeholder. Gamepad-only, valid checkpoints, no duplicate rewards, no accidental transition. Ship this testable slice **before** adding stages 4–10.
