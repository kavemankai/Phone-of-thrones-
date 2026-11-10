extends SceneTree
## Independent Codex M2 contract tests. No physical controller, Windows launch,
## FPS measurements or human gameplay evaluation are implied by these checks.
## Run in clean ephemeral CI user:// so checkpoints never affect player saves.

var passes := 0
var fails := 0


func check(name: String, ok: bool) -> void:
	if ok:
		passes += 1
		print("  PASS  ", name)
	else:
		fails += 1
		print("  FAIL  ", name)


func _button_a() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	return event


func _kill_room(g: Game) -> void:
	for e: Enemy in g.enemies:
		if not e.is_dead():
			e.take_hit(9999.0, g.hero.position, 0.0)
	g.step(1.0 / 60.0)


func _open_doors(g: Game) -> void:
	g._process(0.62)


func _initialize() -> void:
	await process_frame
	print("\n== FORGEBREACH Codex M2 progression and content QA ==")
	var t := load("res://resources/tuning.tres") as Tuning
	check("three stages explicitly defined", CampaignRun.ROOMS.size() == 3)
	check("first stage named Shattered Gatehouse", CampaignRun.ROOMS[0][0].name == "Shattered Gatehouse")
	check("second stage offers two Blood Kennels choices", CampaignRun.ROOMS[1].size() == 2
		and CampaignRun.ROOMS[1][0].name == "Blood Kennels"
		and CampaignRun.ROOMS[1][1].name == "Blood Kennels")
	check("third stage offers two Hall of Banners choices", CampaignRun.ROOMS[2].size() == 2
		and CampaignRun.ROOMS[2][0].name == "Hall of Banners")
	check("Kennels routes have distinct risk and heal", CampaignRun.ROOMS[1][0].foes.size() != CampaignRun.ROOMS[1][1].foes.size()
		and CampaignRun.ROOMS[1][0].heal != CampaignRun.ROOMS[1][1].heal)
	check("Hall routes have distinct foe combinations", CampaignRun.ROOMS[2][0].foes != CampaignRun.ROOMS[2][1].foes)
	var camp := CampaignRun.new()
	check("new campaign has two outgoing choices", camp.choices().size() == 2)
	var pike := CampaignRun.enemy_profile("pike", t, 0)
	var hound := CampaignRun.enemy_profile("hound", t, 1)
	check("pike has readable narrow thrust and minimum range", pike.id == "pike" and pike.attacks.size() == 1
		and pike.attacks[0].arc_deg < 40.0 and pike.attacks[0].min_range > 0.0)
	check("hound has orbit and locked lunging attack", hound.id == "hound" and hound.orbit_before_attack > 0.0
		and hound.attacks.size() == 1 and hound.attacks[0].lunge > 0.0 and hound.attacks[0].lock_time > 0.0)
	var cover: Array[Rect2] = [Rect2(126, 154, 88, 64)]
	check("solid cover blocks direct hit line", ArenaSpace.blocked(Vector2(90, 185), Vector2(245, 185), cover))
	check("free lane has clear hit line", not ArenaSpace.blocked(Vector2(90, 90), Vector2(245, 90), cover))
	var stopped := ArenaSpace.move(Vector2(96, 186), Vector2(175, 186), 16.0, Vector2(340, 380), cover)
	check("movement cannot pass through central cover", stopped.x <= 110.1)

	# Do not overwrite or delete a real local user's save. CI provides an empty user://.
	if FileAccess.file_exists(CampaignRun.CHECKPOINT):
		print("  SKIP  Campaign save/room integration tests: pre-existing checkpoint present")
		print("M2 independent QA: ", passes, " passed, ", fails, " failed; save tests skipped.")
		quit(1 if fails > 0 else 0)
		return

	var main := load("res://scenes/main.tscn") as PackedScene
	var g := main.instantiate() as Game
	root.add_child(g)
	g._new_campaign(0, false)
	check("campaign starts in Gatehouse combat", g.campaign != null and g.campaign.stage == 0
		and g.state == Game.State.FIGHTING and g.enemies_alive() == 2)
	check("first Gatehouse doors locked during combat", g.arena_view.has_doors and not g.arena_view.doors_open)
	var saved0 := CampaignRun.read()
	check("stage-entry checkpoint saves loadout and starting stage", saved0 != null
		and saved0.stage == 0 and saved0.variant == 0 and saved0.route.is_empty())
	# Attempt to choose a door while still fighting. This must not trigger transition.
	g.hero.position = g.arena_view.door_position(0)
	g._input(_button_a())
	check("door action before clear does not advance stage", g.campaign.stage == 0
		and g.state == Game.State.FIGHTING)
	g.hero.position = g.tuning.hero_spawn()

	g.hero.hp = 70.0
	_kill_room(g)
	check("last enemy triggers ROOM_CLEAR, not instant teleport", g.state == Game.State.ROOM_CLEAR
		and g.campaign.stage == 0 and not g.arena_view.doors_open)
	g._input(_button_a())
	check("doors still inactive during clear delay", g.campaign.stage == 0)
	_open_doors(g)
	check("after delay doors unlock and state is DOOR_CHOICE", g.state == Game.State.DOOR_CHOICE
		and g.arena_view.doors_open)
	g.hero.position = g.tuning.hero_spawn()
	g._input(_button_a())
	check("A too far from doors cannot transition", g.campaign.stage == 0)
	g.hero.position = g.arena_view.door_position(0)
	g._input(_button_a())
	check("first door advances to single-Hound Kennels", g.campaign.stage == 1
		and g.campaign.variant == 0 and g.enemies_alive() == 1 and g.state == Game.State.FIGHTING)
	check("first route carries HP and run-only guard reward", is_equal_approx(g.hero.hp, 80.0)
		and g.campaign.guard_bonus == 8 and g.campaign.route.size() == 1)
	var saved1 := CampaignRun.read()
	check("checkpoint round-trip includes stage, route and reward", saved1 != null
		and saved1.stage == 1 and saved1.variant == 0
		and saved1.route.size() == 1 and saved1.route[0] == 0
		and is_equal_approx(saved1.hp, 80.0) and saved1.guard_bonus == 8)
	g._input(_button_a())
	check("held/successive A during next fight does not duplicate reward", g.campaign.route.size() == 1
		and g.campaign.guard_bonus == 8)

	_kill_room(g)
	_open_doors(g)
	check("second room also unlocks doors on victory", g.state == Game.State.DOOR_CHOICE and g.arena_view.doors_open)
	g.hero.position = g.arena_view.door_position(1)
	g._input(_button_a())
	check("second route reaches Hall of Banners variant 1", g.campaign.stage == 2
		and g.campaign.variant == 1 and g.campaign.route.size() == 2
		and g.campaign.choices().is_empty() and g.state == Game.State.FIGHTING)
	check("final Hall has no misleading exit doors", not g.arena_view.has_doors)
	_kill_room(g)
	check("third-room clear leads to genuine slice victory", g.state == Game.State.RESULT
		and g.outcome == Game.Outcome.VICTORY)
	check("slice victory removes completed run checkpoint", not FileAccess.file_exists(CampaignRun.CHECKPOINT))
	g.queue_free()
	await process_frame

	# Alternate stage-one route: proves both physical exits genuinely differ.
	var g2 := main.instantiate() as Game
	root.add_child(g2)
	g2._new_campaign(0, false)
	_kill_room(g2)
	_open_doors(g2)
	g2.hero.position = g2.arena_view.door_position(1)
	g2._input(_button_a())
	check("alternate door reaches harder two-Hound Kennels", g2.campaign.stage == 1
		and g2.campaign.variant == 1 and g2.enemies_alive() == 2)
	check("alternate door awards different heal and no guard bonus", 
		g2.campaign.guard_bonus == 0 and g2.campaign.route.size() == 1
		and g2.campaign.route[0] == 1)
	g2.queue_free()
	await process_frame

	# This test created the checkpoint in clean CI user://; cleanup only that file.
	if FileAccess.file_exists(CampaignRun.CHECKPOINT):
		DirAccess.remove_absolute(CampaignRun.CHECKPOINT)
	print("\nM2 independent QA: ", passes, " passed; ", fails, " failed.")
	quit(1 if fails > 0 else 0)
