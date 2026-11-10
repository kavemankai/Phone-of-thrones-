class_name CombatHud
extends Control
## Hero health, stamina, guard, roll charges, loadout and enemies remaining. Enemy health bars are
## drawn on the enemies themselves. On PC everything sits in a bar under the arena, with the
## button legend for the device in use; the phone build keeps the old top-of-screen layout.

var game: Game
var inset_left := 0.0
var inset_top := 0.0
var inset_right := 0.0
var inset_bottom := 0.0
## Height of the bar under the arena (the arena layout leaves this strip free).
var bar_height := 200.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func layout(vp: Vector2, insets: Vector4, band_h := 200.0) -> void:
	position = Vector2.ZERO
	size = vp
	inset_left = insets.x
	inset_top = insets.y
	inset_right = insets.z
	inset_bottom = insets.w
	bar_height = band_h


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if game == null or game.hero == null or game.tuning == null:
		return
	if game.touch_ui:
		_draw_touch_layout()
	else:
		_draw_bar_layout()
	if game.campaign != null:
		_draw_campaign()


func _draw_campaign() -> void:
	var font := ThemeDB.fallback_font
	var room := game.campaign.room()
	var header := "%d / %d   %s" % [game.campaign.stage + 1, CampaignRun.ROOMS.size(), room.name]
	var width := 620.0
	var x := (size.x - width) * 0.5
	var y := (150.0 if game.touch_ui else 36.0) + inset_top
	draw_string(font, Vector2(x, y), header, HORIZONTAL_ALIGNMENT_CENTER, width, 24, room.light.lightened(0.45))
	if not game.checkpoint_message.is_empty():
		draw_string(font, Vector2(x, y + 26.0), game.checkpoint_message,
				HORIZONTAL_ALIGNMENT_CENTER, width, 18, Color.ORANGE)
	if game.state == Game.State.ROOM_CLEAR:
		draw_string(font, Vector2(x, size.y * 0.5), "ROOM CLEAR",
				HORIZONTAL_ALIGNMENT_CENTER, width, 38, Color.WHITE)
	if game.state != Game.State.DOOR_CHOICE:
		return
	var choices := game.campaign.choices()
	var interact := "Tap the door" if game.touch_ui else "Press %s" % InputPrompts.confirm(game.prompt_style)
	var instruction := "Approach either door" if game.arena_view.near_door < 0 else "%s to enter Door %d" % [
		interact, game.arena_view.near_door + 1,
	]
	var panel_y := size.y * 0.28 if game.touch_ui else size.y - bar_height + 12.0
	draw_rect(Rect2(x, panel_y, width, 110.0), Color(0.05, 0.06, 0.07, 0.94))
	draw_string(font, Vector2(x, panel_y + 25.0), instruction,
			HORIZONTAL_ALIGNMENT_CENTER, width, 22, Color.WHITE)
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var column_x := x + i * width * 0.5
		var color := Color(1.0, 0.83, 0.35) if game.arena_view.near_door == i else Color(0.80, 0.85, 0.92)
		draw_string(font, Vector2(column_x, panel_y + 54.0), "%d   %s" % [i + 1, choice.door],
				HORIZONTAL_ALIGNMENT_CENTER, width * 0.5, 21, color)
		var preview := "%s  ·  +%d HP" % [CampaignRun.foe_summary(choice.foes), choice.heal]
		draw_string(font, Vector2(column_x, panel_y + 80.0), preview,
				HORIZONTAL_ALIGNMENT_CENTER, width * 0.5, 17, color)
		var bonus := game.campaign.guard_reward(i)
		if bonus > 0:
			draw_string(font, Vector2(column_x, panel_y + 100.0), "+%d max guard for this run" % bonus,
					HORIZONTAL_ALIGNMENT_CENTER, width * 0.5, 16, color)


## PC layout: one bar under the arena. Left: health, dodges, guard. Right: enemies and
## loadout. Bottom row: what each button does.
func _draw_bar_layout() -> void:
	var t := game.tuning
	var hero := game.hero
	var font := ThemeDB.fallback_font
	var top := size.y - bar_height
	draw_rect(Rect2(0.0, top, size.x, bar_height), Color(0, 0, 0, 0.3))
	draw_line(Vector2(0.0, top), Vector2(size.x, top), Color(1, 1, 1, 0.14), 2.0)

	var x := inset_left + 40.0
	var y := top + 20.0
	var w := 380.0
	var h := 28.0
	draw_rect(Rect2(x, y, w, h), Color(0, 0, 0, 0.55))
	var frac := clampf(hero.hp / t.hero_max_hp, 0.0, 1.0)
	var col := Color(0.35, 0.8, 0.4) if frac > 0.35 else Color(0.95, 0.3, 0.25)
	draw_rect(Rect2(x, y, w * frac, h), col)
	draw_rect(Rect2(x, y, w, h), Color(1, 1, 1, 0.5), false, 2.0)
	draw_string(font, Vector2(x + 8.0, y + h - 6.0), "HP %d" % ceili(hero.hp),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	_draw_stamina(font, Vector2(x, y + h + 8.0), 240.0)

	# Guard meter: always shown on PC so the bar does not jump about.
	var gy := y + h + 33.0
	var gw := 240.0
	var gfrac := clampf(hero.guard / hero.guard_max(), 0.0, 1.0)
	draw_rect(Rect2(x, gy, gw, 14.0), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(x, gy, gw * gfrac, 14.0),
			Color(0.55, 0.85, 1.0) if gfrac > 0.3 else Color(1.0, 0.5, 0.25))
	draw_rect(Rect2(x, gy, gw, 14.0), Color(1, 1, 1, 0.5), false, 1.5)
	draw_string(font, Vector2(x + gw + 10.0, gy + 13.0), "GUARD", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 18, Color(1, 1, 1, 0.6))

	# Dodge charges.
	var charges := hero.max_charges()
	var dy := gy + 14.0 + 26.0
	for i in charges:
		var c := Vector2(x + 12.0 + i * 34.0, dy)
		if i < hero.dodge_charges:
			draw_circle(c, 11.0, Color(0.45, 0.75, 1.0))
		else:
			draw_arc(c, 11.0, 0.0, TAU, 20, Color(0.45, 0.75, 1.0, 0.6), 3.0)
			if i == hero.dodge_charges:
				var p := hero.dodge_recharge_t / hero.recharge_time()
				draw_arc(c, 11.0, -PI * 0.5, -PI * 0.5 + TAU * p, 20, Color(0.45, 0.75, 1.0), 4.0)
	draw_string(font, Vector2(x + 12.0 + charges * 34.0, dy + 6.0), "ROLL",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.6))

	var right := size.x - inset_right - 40.0
	var captain := game.captain_alive()
	var label := "Captain" if captain else "Enemies: %d" % game.enemies_alive()
	draw_string(font, Vector2(right - 320.0, y + h - 2.0), label, HORIZONTAL_ALIGNMENT_RIGHT,
			320.0, 30, Color(1.0, 0.8, 0.3) if captain else Color.WHITE)
	draw_string(font, Vector2(right - 320.0, y + h + 28.0), game.loadout_name(),
			HORIZONTAL_ALIGNMENT_RIGHT, 320.0, 22, Color(1, 1, 1, 0.7))
	if game.directional_guard:
		draw_string(font, Vector2(right - 320.0, y + h + 54.0), "Directional guard trial",
				HORIZONTAL_ALIGNMENT_RIGHT, 320.0, 18, Color(1.0, 0.85, 0.45))

	if game.intermission_active:
		var cx := size.x * 0.5
		draw_string(font, Vector2(cx - 300.0, 150.0), "CAPTAIN INCOMING", HORIZONTAL_ALIGNMENT_CENTER,
				600.0, 52, Color(1.0, 0.8, 0.3))
		draw_string(font, Vector2(cx - 300.0, 190.0), "+%d health, dodges restored" % int(t.captain_heal),
				HORIZONTAL_ALIGNMENT_CENTER, 600.0, 24, Color(0.7, 1.0, 0.7))

	_draw_prompts(font, size.x * 0.5, size.y - inset_bottom - 34.0)


## A centred row of "button badge + action" pairs for the device in use.
func _draw_stamina(font: Font, origin: Vector2, width: float) -> void:
	var hero := game.hero
	var frac := clampf(hero.stamina / maxf(game.tuning.stamina_max, 1.0), 0.0, 1.0)
	var bar := Rect2(origin, Vector2(width, 14.0))
	var tint := Color(0.95, 0.75, 0.28) if frac > 0.25 else Color(1.0, 0.46, 0.21)
	draw_rect(bar, Color(0, 0, 0, 0.55))
	draw_rect(Rect2(origin, Vector2(width * frac, bar.size.y)), tint)
	draw_rect(bar, Color(1, 1, 1, 0.5), false, 1.5)
	draw_string(font, origin + Vector2(width + 10.0, 13.0),
			"STAMINA %d" % ceili(hero.stamina), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, tint)


func _draw_prompts(font: Font, center_x: float, y: float) -> void:
	var rows := InputPrompts.combat(game.prompt_style, not game.split_attacks)
	var glyph_size := 18
	var gap := 26.0
	var pad := 8.0
	var glyph_w: Array[float] = []
	var label_w: Array[float] = []
	var total := 0.0
	for row: Array in rows:
		var glyph: String = row[0]
		var action: String = row[1]
		var gw := maxf(32.0, font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size).x + 18.0)
		var lw := font.get_string_size(action, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size).x
		glyph_w.append(gw)
		label_w.append(lw)
		total += gw + pad + lw
	total += gap * maxf(0.0, rows.size() - 1.0)
	var x := center_x - total * 0.5
	for i in rows.size():
		var row: Array = rows[i]
		var glyph: String = row[0]
		var action: String = row[1]
		var tint: Color = row[2]
		var box := Rect2(x, y - 15.0, glyph_w[i], 30.0)
		draw_rect(box, tint)
		draw_rect(box, Color(1, 1, 1, 0.75), false, 2.0)
		draw_string(font, Vector2(x, y + 6.5), glyph, HORIZONTAL_ALIGNMENT_CENTER, glyph_w[i],
				glyph_size, Color.WHITE)
		draw_string(font, Vector2(x + glyph_w[i] + pad, y + 6.5), action, HORIZONTAL_ALIGNMENT_LEFT,
				-1, glyph_size, Color(1, 1, 1, 0.8))
		x += glyph_w[i] + pad + label_w[i] + gap


## Phone layout, unchanged from v0.9: status at the top, touch buttons own the bottom band.
func _draw_touch_layout() -> void:
	var t := game.tuning
	var hero := game.hero
	var font := ThemeDB.fallback_font
	var x := inset_left + 24.0
	var y := inset_top + 22.0
	var w := 320.0
	var h := 26.0
	draw_rect(Rect2(x, y, w, h), Color(0, 0, 0, 0.55))
	var frac := clampf(hero.hp / t.hero_max_hp, 0.0, 1.0)
	var col := Color(0.35, 0.8, 0.4) if frac > 0.35 else Color(0.95, 0.3, 0.25)
	draw_rect(Rect2(x, y, w * frac, h), col)
	draw_rect(Rect2(x, y, w, h), Color(1, 1, 1, 0.5), false, 2.0)
	draw_string(font, Vector2(x + 8.0, y + h - 5.0), "HP %d" % ceili(hero.hp),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	_draw_stamina(font, Vector2(x, y + h + 8.0), 200.0)

	# Dodge charges.
	var charges := hero.max_charges()
	for i in charges:
		var c := Vector2(x + 14.0 + i * 34.0, y + h + 42.0)
		if i < hero.dodge_charges:
			draw_circle(c, 11.0, Color(0.45, 0.75, 1.0))
		else:
			draw_arc(c, 11.0, 0.0, TAU, 20, Color(0.45, 0.75, 1.0, 0.6), 3.0)
			if i == hero.dodge_charges:
				var p := hero.dodge_recharge_t / hero.recharge_time()
				draw_arc(c, 11.0, -PI * 0.5, -PI * 0.5 + TAU * p, 20, Color(0.45, 0.75, 1.0), 4.0)
	draw_string(font, Vector2(x + 14.0 + charges * 34.0, y + h + 48.0), "ROLL",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.6))

	# Guard meter: only drawn while it matters.
	if hero.is_guarding() or hero.guard < hero.guard_max():
		var gy := y + h + 64.0
		var gw := 200.0
		var gfrac := clampf(hero.guard / hero.guard_max(), 0.0, 1.0)
		draw_rect(Rect2(x, gy, gw, 12.0), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(x, gy, gw * gfrac, 12.0), Color(0.55, 0.85, 1.0) if gfrac > 0.3 else Color(1.0, 0.5, 0.25))
		draw_rect(Rect2(x, gy, gw, 12.0), Color(1, 1, 1, 0.5), false, 1.5)
		draw_string(font, Vector2(x + gw + 10.0, gy + 12.0), "GUARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.6))

	var right := size.x - inset_right - 24.0
	var label := "Captain" if game.captain_alive() else "Enemies: %d" % game.enemies_alive()
	draw_string(font, Vector2(right - 260.0, y + h - 2.0), label,
			HORIZONTAL_ALIGNMENT_RIGHT, 260.0, 28, Color(1.0, 0.8, 0.3) if game.captain_alive() else Color.WHITE)
	draw_string(font, Vector2(right - 260.0, y + h + 24.0), game.loadout_name(),
			HORIZONTAL_ALIGNMENT_RIGHT, 260.0, 20, Color(1, 1, 1, 0.6))
	var trial := ("SPLIT" if game.split_attacks else "HOLD") + " / " + ("DIR" if game.directional_guard else "360")
	draw_string(font, Vector2(right - 260.0, y + h + 48.0), trial,
			HORIZONTAL_ALIGNMENT_RIGHT, 260.0, 18, Color(1.0, 0.85, 0.45))
	if game.intermission_active:
		var cx := size.x * 0.5
		draw_string(font, Vector2(cx - 300.0, 210.0), "CAPTAIN INCOMING", HORIZONTAL_ALIGNMENT_CENTER,
				600.0, 52, Color(1.0, 0.8, 0.3))
		draw_string(font, Vector2(cx - 300.0, 252.0), "+%d health, dodges restored" % int(t.captain_heal),
				HORIZONTAL_ALIGNMENT_CENTER, 600.0, 24, Color(0.7, 1.0, 0.7))
