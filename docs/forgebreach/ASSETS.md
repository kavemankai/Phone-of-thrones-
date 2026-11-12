# FORGEBREACH production assets

The visual direction uses weathered iron and stone, cold slate in the Outer Walls, and hotter amber in the Forge and Crown Pit. The floor art is painted in ground space. Godot projects it onto the same arena the simulation uses. Cover outlines, attack sectors and door rings still come from gameplay geometry.

This pass is integrated against Ward I at `8650b87`. The art covers the five reusable arenas in the ten-stage design. The final-boss sprite has its own asset key, `crown_tyrant`, ready for the profile when that encounter is implemented. The working name for the boss is an art-side choice.

| Directory | Contents |
| --- | --- |
| `assets/actors/` | Hero in five poses, Gate Guard, Pike Sentinel, War Hound, Iron Warden, Chain Penitent, War Herald, Gate Captain and Crown Tyrant. The prototype Hall Sweeper uses the Penitent silhouette. |
| `assets/arenas/` | 508 × 508 ground paintings for the five campaign arenas and the Test Room. The room tint differentiates alternate routes. |
| `assets/equipment/` | Sword, spear, axe, dagger, zweihander and shield. Weapon art points right, with its grip at the left edge. Godot rotates it along the existing swing path and draws a second dagger for dual wielding. |
| `assets/props/` | Masonry cover, timber barricade, anvil, sealed and open doors, brazier. Existing collision still defines where cover blocks movement and attacks. |
| `assets/ui/` | 1440 × 810 title and ending backgrounds and a 512 × 512 game emblem. Menus render their own live text and focus cues. |
| `assets/audio/` | Twelve original layered combat and outcome cues, four looping stereo beds for the title, outer walls, forge and pit. |

The characters are painted 2D cutouts anchored at the feet, with mirrored facing, action poses for the hero and procedural movement and state accents for enemies. The project keeps its existing fixed camera, platform presets, rules and input paths.

## Art prompts

The paintings were generated with the built-in image generator. Character and prop sheets used a fixed 2:1 isometric view, hard silhouettes and isolated transparent sprites. The character pose sheet used the original hero as its reference. Floors used an orthographic six-material sheet with restrained contrast so attack warnings remain visible. Key art depicts a blue-cloaked knight approaching a ruined gate and a discarded crown on a parapet at dawn. Equipment was painted as separate, grip-left silhouettes. The icon pairs a forged crown and an upright sword. The audio is original procedural sound design.
