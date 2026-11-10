# FORGEBREACH — content workshop v1
Approved design direction: dark, grounded medieval fortress. Grim iron-and-stone, battered armour, fire and banners; supernatural elements are **not** part of this scope without a later explicit decision.

This is a **design approval, not implemented game code**. Target Windows controller-first Godot 4.6.2, five base weapons, fixed bounded isometric arenas. The ten sequential stages and mandatory stage-5 and stage-10 bosses remain the campaign.

## Five regular enemy archetypes (in addition to existing grunt)
| ID | Enemy | Combat read | Mechanical distinction | Counterplay | Implementation order |
| --- | --- | --- | --- | --- | --- |
| `iron_warden` | Iron Warden | Massive forward shield, slow raised bash | Frontal light-hit mitigation / shield guard; telegraphed stagger bash; short post-bash opening | Flank with right-stick facing or punish recovery | After vertical slice |
| `pike_sentinel` | Pike Sentinel | Long straight two-handed pike | Narrow, long-reach thrust; holds outer distance; significant missed-thrust recovery | Sidestep and close into inner range | First new enemy |
| `chain_penitent` | Chain Penitent | Oversized chain/flail sweep | Wide arc, long readable wind-up and recovery; no invisible back-hit | Read wedge, dodge inward or step outside arc | After vertical slice |
| `war_hound` | War Hound | Fast animal with low HP | Reposition/circle then telegraphed locked lunge; fast recovery, cannot silently retarget mid-leap | Anticipate lane, dodge sideways; aggressive counter | Second new enemy |
| `war_herald` | War Herald | Banner/horn carrier, obvious horn tell | Periodic interruptible call temporarily increases ally **movement speed only** (no hidden attack speed increase) | Prioritise support unit and interrupt call | After vertical slice |

All hostile hits use the existing visibly matched hit geometry and fixed-step simulation. Honour the encounter controller's max-two simultaneous attack commitments. No random unavoidable damage. For support buffs, apply explicit deterministic duration/stacking rules; prefer a single non-stacking refresh. Set precise HP, damage and cooldowns **after** playable balance tests; values are not falsely settled here.

## Five handcrafted bounded arenas
| ID | Arena | Geometry/visual identity | Intended encounters | Hazard/content scope |
| --- | --- | --- | --- | --- |
| `shattered_gatehouse` | Shattered Gatehouse | Gate ruins and two flanking lanes, with a central landmark | Pike Sentinel, Iron Warden | Establish door proximity and arena transition here |
| `blood_kennels` | Blood Kennels | Cage-yard, broken barriers and open circling lanes | War Hound + grunt | Movable-feeling layout, but no moving collision for v1 |
| `hall_of_banners` | Hall of Banners | Ruined hall, banner posts and centre dais | War Herald plus pressure fighter | Prioritisation and line of sight; scenery decorative until colliders are tested |
| `cinder_forge` | Cinder Forge | Industrial stone foundry, molten channels, clear hazard lanes | Chain Penitent, Pike Sentinel | **Later** deterministic telegraph→active→cooldown heat vents; affect enemies and player consistently |
| `crown_pit` | Crown Pit | Circular royal ruin, visually exposed boss ring | Stage-5 champion, stage-10 final boss | Clean boss arena, broad telegraph visibility, no random hazards |

Do not create fake physical cover: any prop that obstructs movement must have actual hero/enemy collision, pathing/avoidance, spawn validation and melee hit/telegraph consistency. Until that is integrated and independently tested, use **non-colliding visual decoration** rather than misleading solid-looking obstacles. Never allow unreachable enemies or doorway obstruction softlocks.

## Ten-stage journey using five reusable arenas
- Stages 1–2: Gatehouse/Kennels, teach reach and dodging.
- Stages 3–4: Hall/Forge, introduce support and wide attacks only when their implementations are tested.
- Stage 5: Crown Pit champion.
- Stages 6–9: alternate compositions across existing handcrafted arenas; door choices offer actual distinct enemy/reward data.
- Stage 10: Crown Pit final boss with readable phase 2, victory/credits/replay.
These are targets, not active content implementations. The door graph must remain finite and reconverge, not double the number of scenes per branch.

## Immediate Milestone 2 content order
1. RunDirector/RunState/ArenaCatalog with 3 fixed stages, clear-state and two doors that unlock only after last enemy falls.
2. Stage 1: Shattered Gatehouse with existing grunt while testing transitions.
3. Stage 2 alternate: Blood Kennels (War Hound) or Hall of Banners (initially grunt or Pike Sentinel), with truly different declared encounter and reward.
4. Stage 3: convergence to a third room; clear end-of-slice screen.
5. Only after traversal/save recovery works, implement and tune Pike Sentinel then War Hound as independent archetype profiles, preserving regression behavior.
6. Hand complete 3-room build to independent QA and real controller tester before adding Stage 4 or the remaining enemies.

## Acceptance
Every room is bounded and readable at 720p/1080p; victory unlocks physical doors only; A/Cross commits a single valid nearby door; route differences are truthful; entry-state checkpoint cannot double-award rewards; all paths reach the third-room completion screen; no encounter can spawn unreachable enemies; all existing combat regression tests continue to pass. No assertions about hardware feel from CI alone.

## Scope exclusions
No added player weapons, endless survival, co-op, large open-world geometry, destructible battlefield physics, shops/economy, dynamic maze generation or simultaneous multitudes of enemy units. Prefer a finished 10-stage campaign to an ever-growing catalogue.
