extends SceneTree
## Asset-import smoke test for the source art/audio set. This catches missing, corrupted or
## unimportable resources; it does not establish art quality or human-visible animation feel.
## Run after an import pass with Godot 4.6.2:
##   godot --headless --path . --script tests/visual_assets_qa.gd

const TEXTURES := {
	"actors": [
		"hero.webp", "hero_run.webp", "hero_windup.webp", "hero_strike.webp",
		"hero_roll.webp", "gate_guard.webp", "pike_sentinel.webp", "war_hound.webp",
		"iron_warden.webp", "chain_penitent.webp", "war_herald.webp",
		"gate_captain.webp", "crown_tyrant.webp",
	],
	"arenas": [
		"shattered_gatehouse.webp", "blood_kennels.webp", "hall_of_banners.webp",
		"cinder_forge.webp", "crown_pit.webp", "test_room.webp",
	],
	"equipment": [
		"sword.webp", "spear.webp", "axe.webp", "daggers.webp",
		"zweihander.webp", "shield.webp",
	],
	"props": [
		"masonry.webp", "barricade.webp", "anvil.webp",
		"door_sealed.webp", "door_open.webp", "brazier.webp",
	],
	"ui": ["title.webp", "ending.webp", "emblem.png"],
}

const AUDIO := [
	"block.wav", "captain.wav", "dodge.wav", "enemy_strike.wav",
	"guard_break.wav", "hit.wav", "hurt.wav", "lose.wav",
	"parry.wav", "swing_heavy.wav", "swing_light.wav", "win.wav",
	"crown_pit.ogg", "forge.ogg", "outer_walls.ogg", "title.ogg",
]

var passes := 0
var fails := 0


func check(label: String, valid: bool) -> void:
	if valid:
		passes += 1
		print("  PASS  ", label)
	else:
		fails += 1
		printerr("  FAIL  ", label)


func _initialize() -> void:
	await process_frame
	print("\n== FORGEBREACH asset loading QA ==")
	for category: String in TEXTURES:
		for filename: String in TEXTURES[category]:
			var path := "res://assets/%s/%s" % [category, filename]
			var texture := load(path) as Texture2D
			check("texture %s" % path, texture != null
					and texture.get_width() > 0 and texture.get_height() > 0
					and texture.get_width() <= 4096 and texture.get_height() <= 4096)
	for filename: String in AUDIO:
		var path := "res://assets/audio/" + filename
		var stream := load(path) as AudioStream
		check("audio %s" % path, stream != null and stream.get_length() > 0.0)

	# The player and AI cutouts are still paired to the same canonical source textures.
	check("hero pose atlas keys", ForgeArt.ACTORS.has("hero")
			and ForgeArt.HERO_RUN != null and ForgeArt.HERO_WINDUP != null
			and ForgeArt.HERO_STRIKE != null and ForgeArt.HERO_ROLL != null)
	check("all nine actor variants", ForgeArt.ACTORS.size() == 9)
	check("all five separate equipment drawings", ForgeArt.EQUIPMENT.size() == 5)
	check("all six arenas", ArenaView.FLOORS.size() == 6)

	print("Visual assets QA: ", passes, " passed, ", fails, " failed")
	quit(1 if fails > 0 else 0)
