# FORGEBREACH visual assets and animation review — 2026-11-12

**Source branch:** `feature/forgebreach-controls-stamina-campaign` at `fc12b997c22fc46ebb4de4c21ac479c72578f536`.
**Review branch:** `art/forgebreach-animation-polish-20261112`.
**Status:** Implemented, awaiting CI and visual/controller playtest. This is a visual-presentation-only pass; gameplay rules and attack geometry are unchanged.

## Inventory and integration

The review covers the full committed art/audio inventory inherited from `art/forgebreach-finished-assets`:

| Asset group | Count | Current use |
| --- | ---: | --- |
| Actor textures | 13 | Five hero poses plus eight enemy identities, including the final-boss artwork |
| Arena ground paintings | 6 | Five campaign locations and the Test Room |
| Equipment textures | 6 | Five weapon art keys plus shield |
| Prop textures | 6 | Barricade, masonry, anvil, doors and brazier |
| UI textures | 3 | Title, ending and emblem |
| Combat sounds / music beds | 16 | Twelve short cues and four ambience/music beds |
| **Total** | **50** | 34 image sources and 16 audio sources |

The code still renders actors as isolated 2D cutouts on a fixed isometric projection. Hero poses are separate images, **not** multi-frame sprite animations. Enemies each have one base cutout; their actions are portrayed through transform, tint and telegraph geometry. Arena floor art is a single painted image per stage; prop hitboxes and telegraph sectors remain defined by combat code. The image files themselves are unchanged in this pass.

## Findings and improvements made

1. **Hero movement could animate without travelling.** Idle/run selection previously relied on pressed movement input and wall-clock bobbing; pressing into cover could still look like running. Locomotion now derives from actual ground displacement and blends idle/run source art over several frames.
2. **Hero actions changed pose abruptly.** Windup, active attack and recovery now use state-timed anticipation, stretch and follow-through, preserving the existing hit windows. Active swings add low-opacity copies of the painted weapon as a motion trail. The dodge adds two receding afterimages.
3. **Enemy locomotion was largely cosmetic.** Each enemy now measures actual displacement and uses a light walk bounce and squash/stretch; windup, attack, recovery and stagger get distinct readable motion. This applies to existing enemy identities without requiring new files.
4. **The impact spark orientation was not moving.** Its rotation used lifetime instead of elapsed age. It now rotates during the effect. Ground dust is triggered from the existing dodge signal.
5. **Braziers were entirely static.** Single-room braziers now flicker subtly, with a restrained glow and small procedural flame shapes. This is presentation-only and separate from vent hazard timing.
6. **Imported resource completeness lacked its own check.** `tests/visual_assets_qa.gd` loads every one of the 50 source assets, checks non-empty image dimensions and non-zero audio length, and validates the art mapping counts. It is included in the existing Godot CI workflow.

## Unverified items and remaining art debt

- **Visual inspection limitation:** This pass used the committed file inventory, mapping code, import descriptions and animation logic, but did not perform a pixel-level comparison of the 34 binary image sources, alpha borders or silhouette consistency. Likewise, audio was not auditioned. The automated script checks asset *loading*, not aesthetic quality.
- **No true frame-by-frame locomotion or attack animation** exists for the enemy roster. A future art pass should create consistent keyframes or skeletal cutout rigs for each enemy, with matching feet anchors, weapon hand positions and anticipation/contact/recovery timing.
- **Facing is left/right mirroring**, not four- or eight-direction artwork. Obvious asymmetric details may look wrong when facing away from the originally painted direction.
- **Visual occlusion and ground contact** require screenshot and in-game review at 1280×720 across all arenas. Check sprite overlap with cover, shadow placement, doors, crowded telegraphs, HUD safe zones and readability at combat speed.
- **Hardware and release:** CI imports, source tests and cross-exports are not equivalent to a Windows render, measured FPS or physical-controller playtest. Those still require separate acceptance.

## Acceptance checklist

- [ ] Run `godot --headless --path . --import`
- [ ] Run `godot --headless --path . --script tests/visual_assets_qa.gd`
- [ ] Run the regression and controller/campaign QA suites without new failures
- [ ] Boot and export the Windows build through the existing workflow
- [ ] Capture short in-game clips showing idle → run → idle, each weapon, dodge, parry and stagger in every enemy class
- [ ] Review all five campaign arenas and the Test Room in motion with effects, cover and HUD
- [ ] Review title, ending and emblem artwork at target resolution
- [ ] Check performance, motion legibility, photosensitivity and controller feedback on physical hardware

**Scope guard:** This branch must not be merged into the older `combat-polish-v0.9` baseline. Target the latest campaign gameplay branch instead.
