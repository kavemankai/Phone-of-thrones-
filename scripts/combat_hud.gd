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
	elif game.map_active and not game.map_label.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(inset_left + 24.0, inset_top + 32.0),
				game.map_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.86, 0.64))


func _draw_campaign() -> void:
	if game.touch_ui:
		_draw_campaign_touch()
	else:
		_draw_campaign_desktop()


## PC: room name and carried pickups in the top-left corner, which the arena diamond leaves
## free. When the doors open, one card per door sits in the bottom corners above the status
## strip, so nothing is drawn over the health bars or the button legend.
func _draw_campaign_desktop() -> void:
	var font := ThemeDB.fallback_font
	var run := game.campaign
	var room := run.room()
	var x := inset_left + 24.0
	var y := inset_top + 32.0
	draw_string(font, Vector2(x, y), "%d / %d   %s" % [run.stage + 1, run.stage_count(), room.name],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, room.light.lightened(0.45))
	y += 22.0
	if not game.checkpoint_message.is_empty():
		draw_string(font, Vector2(x, y), game.checkpoint_message,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.ORANGE)
		y += 20.0
	for title in Boon.titles(run.boons):
		draw_string(font, Vector2(x, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
				Color(1.0, 0.83, 0.35, 0.9))
		y += 18.0

	var mid_y := (size.y - bar_height) * 0.46
	if game.wave_notice > 0.0 and game.state == Game.State.FIGHTING:
		_draw_banner(font, "REINFORCEMENTS", mid_y, Color(1.0, 0.8, 0.3))
	if game.state == Game.State.ROOM_CLEAR:
		_draw_banner(font, "ROOM CLEAR", mid_y, Color.WHITE)
	if game.tutorial_showing():
		_draw_note(font, game.tutorial_text(), Color(0.55, 0.85, 1.0))
	if game.state != Game.State.DOOR_CHOICE:
		return

	var near := game.arena_view.near_door
	var instruction := "Walk to a door" if near < 0 else "Press %s to enter door %d" % [
		InputPrompts.confirm(game.prompt_style), near + 1]
	var strip_top := size.y - bar_height
	var note_w := font.get_string_size(instruction, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 36.0
	var note := Rect2((size.x - note_w) * 0.5, strip_top - 44.0, note_w, 34.0)
	draw_rect(note, Color(0.05, 0.05, 0.06))
	draw_rect(note, Color(1.0, 0.83, 0.35, 0.8), false, 2.0)
	draw_string(font, Vector2(note.position.x, note.position.y + 24.0), instruction,
			HORIZONTAL_ALIGNMENT_CENTER, note_w, 20, Color.WHITE)

	var choices := run.choices()
	var card := Vector2(340.0, 158.0)
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var left := inset_left + 24.0 if i == 0 else size.x - inset_right - 24.0 - card.x
		var box := Rect2(left, strip_top - card.y - 10.0, card.x, card.y)
		var chosen := near == i
		var ink := Color(1.0, 0.83, 0.35) if chosen else Color(0.82, 0.86, 0.92)
		draw_rect(box, Color(0.05, 0.05, 0.06))
		draw_rect(box, ink if chosen else Color(1, 1, 1, 0.25), false, 3.0 if chosen else 2.0)
		var line := box.position.y + 28.0
		draw_string(font, Vector2(left, line), "Door %d   %s" % [i + 1, choice.door],
				HORIZONTAL_ALIGNMENT_CENTER, card.x, 21, ink)
		var foes := CampaignRun.foe_summary(choice.foes)
		for wave: Array in choice.get("waves", []):
			foes.append("then " + ", ".join(CampaignRun.foe_summary(wave)))
		if not choice.get("vents", []).is_empty():
			foes.append("floor vents")
		line += 24.0
		draw_string(font, Vector2(left, line), " + ".join(foes.slice(0, 2)),
				HORIZONTAL_ALIGNMENT_CENTER, card.x, 16, ink)
		line += 20.0
		if foes.size() > 2:
			draw_string(font, Vector2(left, line), "+ " + " + ".join(foes.slice(2)),
					HORIZONTAL_ALIGNMENT_CENTER, card.x, 16, ink)
		line += 22.0
		var reward := "+%d health" % choice.heal
		var bonus := run.guard_reward(i)
		if bonus > 0:
			reward += "   +%d max guard" % bonus
		draw_string(font, Vector2(left, line), reward,
				HORIZONTAL_ALIGNMENT_CENTER, card.x, 15, ink)
		var pickup := run.offer(i)
		if pickup != "":
			line += 28.0
			draw_string(font, Vector2(left, line), Boon.title(pickup),
					HORIZONTAL_ALIGNMENT_CENTER, card.x, 19, Color(1.0, 0.83, 0.35))
			line += 19.0
			draw_string(font, Vector2(left, line), Boon.text(pickup),
					HORIZONTAL_ALIGNMENT_CENTER, card.x, 13, Color(0.82, 0.86, 0.92))


## A boxed line centred just above the status strip.
func _draw_note(font: Font, text: String, edge: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 36.0
	var box := Rect2((size.x - w) * 0.5, size.y - bar_height - 44.0, w, 34.0)
	draw_rect(box, Color(0.05, 0.05, 0.06))
	draw_rect(box, Color(edge, 0.8), false, 2.0)
	draw_string(font, Vector2(box.position.x, box.position.y + 24.0), text,
			HORIZONTAL_ALIGNMENT_CENTER, w, 20, Color.WHITE)


func _draw_banner(font: Font, text: String, y: float, tint: Color) -> void:
	draw_string(font, Vector2(2.0, y + 2.0), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 40,
			Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(0.0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, tint)


## A named health bar in the top-right corner while a captain is alive, with a notch where
## its second phase begins.
func _draw_boss_bar(font: Font) -> void:
	var boss: Enemy = null
	for e: Enemy in game.enemies:
		if e.is_captain() and not e.is_dead():
			boss = e
			break
	if boss == null:
		return
	var w := 360.0
	var x := size.x - inset_right - 24.0 - w
	var y := inset_top + 18.0
	draw_string(font, Vector2(x, y + 16.0), boss.profile.display_name,
			HORIZONTAL_ALIGNMENT_RIGHT, w, 20, Color(1.0, 0.8, 0.3))
	var bar := Rect2(x, y + 24.0, w, 14.0)
	var frac := clampf(boss.hp / maxf(boss.profile.max_hp, 1.0), 0.0, 1.0)
	draw_rect(bar, Color(0, 0, 0, 0.7))
	draw_rect(Rect2(bar.position, Vector2(w * frac, bar.size.y)), Color(0.85, 0.22, 0.2))
	draw_rect(bar, Color(1, 1, 1, 0.55), false, 2.0)
	if boss.phase == 1 and boss.profile.phase2_at > 0.0:
		var notch := x + w * boss.profile.phase2_at
		draw_line(Vector2(notch, bar.position.y - 3.0), Vector2(notch, bar.end.y + 3.0),
				Color(1.0, 0.85, 0.3), 2.0)


func _draw_campaign_touch() -> void:
	var font := ThemeDB.fallback_font
	var room := game.campaign.room()
	var header := "%d / %d   %s" % [game.campaign.stage + 1, game.campaign.stage_count(), room.name]
	var width := 620.0 if game.touch_ui else 780.0
	var x := (size.x - width) * 0.5
	var y := (150.0 if game.touch_ui else 36.0) + inset_top
	draw_string(font, Vector2(x, y), header, HORIZONTAL_ALIGNMENT_CENTER, width, 24, room.light.lightened(0.45))
	if not game.checkpoint_message.is_empty():
		draw_string(font, Vector2(x, y + 26.0), game.checkpoint_message,
				HORIZONTAL_ALIGNMENT_CENTER, width, 18, Color.ORANGE)
	if game.wave_notice > 0.0 and game.state == Game.State.FIGHTING:
		draw_string(font, Vector2(x, size.y * 0.5), "REINFORCEMENTS",
				HORIZONTAL_ALIGNMENT_CENTER, width, 38, Color(1.0, 0.8, 0.3))
	if game.state == Game.State.ROOM_CLEAR:
		draw_string(font, Vector2(x, size.y * 0.5), "ROOM CLEAR",
				HORIZONTAL_ALIGNMENT_CENTER, width, 38, Color.WHITE)
	if game.state != Game.State.DOOR_CHOICE:
		# Pickups carried this run, in the status bar.
		if not game.touch_ui and not game.campaign.boons.is_empty():
			draw_string(font, Vector2(x, size.y - bar_height + 34.0),
					"  ·  ".join(Boon.titles(game.campaign.boons)),
					HORIZONTAL_ALIGNMENT_CENTER, width, 17, Color(1.0, 0.83, 0.35))
		return
	var choices := game.campaign.choices()
	var interact := "Tap the door" if game.touch_ui else "Press %s" % InputPrompts.confirm(game.prompt_style)
	var instruction := "Approach either door" if game.arena_view.near_door < 0 else "%s to enter Door %d" % [
		interact, game.arena_view.near_door + 1,
	]
	var panel_y := size.y * 0.28 if game.touch_ui else size.y - bar_height + 12.0
	draw_rect(Rect2(x, panel_y, width, 178.0), Color(0.05, 0.06, 0.07, 0.94))
	draw_string(font, Vector2(x, panel_y + 25.0), instruction,
			HORIZONTAL_ALIGNMENT_CENTER, width, 22, Color.WHITE)
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var column_x := x + i * width * 0.5
		var color := Color(1.0, 0.83, 0.35) if game.arena_view.near_door == i else Color(0.80, 0.85, 0.92)
		draw_string(font, Vector2(column_x, panel_y + 54.0), "%d   %s" % [i + 1, choice.door],
				HORIZONTAL_ALIGNMENT_CENTER, width * 0.5, 21, color)
		var foes := CampaignRun.foe_summary(choice.foes)
		var first_line := " + ".join(foes.slice(0, 2))
		draw_string(font, Vector2(column_x, panel_y + 78.0), first_line,
				HORIZONTAL_ALIGNMENT_CENTER, width * 0.5, 17, color)
		if foes.size() > 2:
			draw_string(font, Vector2(column_x, panel_y + 96.0), "+ " + " + ".join(foes.slice(2)),
					HORIZONTAL_ALIGNMENT_CENTER, width * 0.5, 17, color)
		var bonus := game.campaign.guard_reward(i)
		var reward := "+%d HP" % choice.heal
		if bonus > 0:
			reward += "  ·  +%d max guard for this run" % bonus
		draw_string(font, Vector2(column_x, panel_y + 119.0), reward,
				HORIZONTAL_ALIGNMENT_CENTER, width * 0.5, 16, color)
		var pickup := game.campaign.offer(i)
		if pickup != "":
			draw_string(font, Vector2(column_x, panel_y + 146.0), Boon.title(pickup),
					HORIZONTAL_ALIGNMENT_CENTER, width * 0.5, 19, Color(1.0, 0.83, 0.35))
			draw_string(font, Vector2(column_x, panel_y + 166.0), Boon.text(pickup),
					HORIZONTAL_ALIGNMENT_CENTER, width * 0.5, 14, color)


## PC layout: a thin strip under the arena. Top row: health, stamina, guard and roll
## charges on the left, enemies and loadout on the right. Bottom row: what each button does.
func _draw_bar_layout() -> void:
	var t := game.tuning
	var hero := game.hero
	var font := ThemeDB.fallback_font
	var top := size.y - bar_height
	draw_rect(Rect2(0.0, top, size.x, bar_height), Color(0, 0, 0, 0.45))
	draw_line(Vector2(0.0, top), Vector2(size.x, top), Color(1, 1, 1, 0.14), 2.0)

	var x := inset_left + 24.0
	var y := top + 11.0
	var w := 300.0
	var h := 26.0
	draw_rect(Rect2(x, y, w, h), Color(0, 0, 0, 0.55))
	var frac := clampf(hero.hp / t.hero_max_hp, 0.0, 1.0)
	var col := Color(0.35, 0.8, 0.4) if frac > 0.35 else Color(0.95, 0.3, 0.25)
	draw_rect(Rect2(x, y, w * frac, h), col)
	draw_rect(Rect2(x, y, w, h), Color(1, 1, 1, 0.5), false, 2.0)
	draw_string(font, Vector2(x + 8.0, y + h - 6.0), "HP %d" % ceili(hero.hp),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color.WHITE)

	# Stamina over guard, beside the health bar.
	var sx := x + w + 16.0
	var sw := 170.0
	var sfrac := clampf(hero.stamina / maxf(t.stamina_max, 1.0), 0.0, 1.0)
	var stint := Color(0.95, 0.75, 0.28) if sfrac > 0.25 else Color(1.0, 0.46, 0.21)
	draw_rect(Rect2(sx, y, sw, 11.0), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(sx, y, sw * sfrac, 11.0), stint)
	draw_rect(Rect2(sx, y, sw, 11.0), Color(1, 1, 1, 0.5), false, 1.5)
	draw_string(font, Vector2(sx + sw + 8.0, y + 11.0), "STAMINA", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 14, stint)
	var gy := y + 15.0
	var gfrac := clampf(hero.guard / hero.guard_max(), 0.0, 1.0)
	draw_rect(Rect2(sx, gy, sw, 11.0), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(sx, gy, sw * gfrac, 11.0),
			Color(0.55, 0.85, 1.0) if gfrac > 0.3 else Color(1.0, 0.5, 0.25))
	draw_rect(Rect2(sx, gy, sw, 11.0), Color(1, 1, 1, 0.5), false, 1.5)
	draw_string(font, Vector2(sx + sw + 8.0, gy + 11.0), "GUARD", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 14, Color(1, 1, 1, 0.6))

	# Roll charges.
	var charges := hero.max_charges()
	var rx := sx + sw + 96.0
	var ry := y + h * 0.5
	for i in charges:
		var c := Vector2(rx + i * 26.0, ry)
		if i < hero.dodge_charges:
			draw_circle(c, 9.0, Color(0.45, 0.75, 1.0))
		else:
			draw_arc(c, 9.0, 0.0, TAU, 20, Color(0.45, 0.75, 1.0, 0.6), 2.5)
			if i == hero.dodge_charges:
				var p := hero.dodge_recharge_t / hero.recharge_time()
				draw_arc(c, 9.0, -PI * 0.5, -PI * 0.5 + TAU * p, 20, Color(0.45, 0.75, 1.0), 3.5)
	draw_string(font, Vector2(rx + charges * 26.0 - 6.0, ry + 5.0), "ROLL",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.6))

	var right := size.x - inset_right - 24.0
	var captain := game.captain_alive()
	var label := game.captain_name() if captain else "Enemies: %d" % game.enemies_alive()
	draw_string(font, Vector2(right - 300.0, y + 20.0), label, HORIZONTAL_ALIGNMENT_RIGHT,
			300.0, 24, Color(1.0, 0.8, 0.3) if captain else Color.WHITE)
	var loadout := game.loadout_name()
	if game.directional_guard:
		loadout += "  ·  directional guard"
	draw_string(font, Vector2(right - 300.0, y + 38.0), loadout,
			HORIZONTAL_ALIGNMENT_RIGHT, 300.0, 15, Color(1, 1, 1, 0.7))

	if game.intermission_active:
		var cx := size.x * 0.5
		draw_string(font, Vector2(cx - 300.0, 150.0), "CAPTAIN INCOMING", HORIZONTAL_ALIGNMENT_CENTER,
				600.0, 52, Color(1.0, 0.8, 0.3))
		draw_string(font, Vector2(cx - 300.0, 190.0), "+%d health, dodges restored" % int(t.captain_heal),
				HORIZONTAL_ALIGNMENT_CENTER, 600.0, 24, Color(0.7, 1.0, 0.7))

	_draw_boss_bar(font)
	_draw_prompts(font, size.x * 0.5, size.y - inset_bottom - 24.0)


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
	var captain := game.captain_name()
	var label := captain if not captain.is_empty() else "Enemies: %d" % game.enemies_alive()
	draw_string(font, Vector2(right - 260.0, y + h - 2.0), label,
			HORIZONTAL_ALIGNMENT_RIGHT, 260.0, 28, Color(1.0, 0.8, 0.3) if not captain.is_empty() else Color.WHITE)
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
