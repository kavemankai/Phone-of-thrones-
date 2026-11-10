class_name CombatHud
extends Control
## Hero health, guard, dodge charges, loadout and enemies remaining. Enemy health bars are
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

	# Guard meter: always shown on PC so the bar does not jump about.
	var gy := y + h + 14.0
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
	draw_string(font, Vector2(x + 12.0 + charges * 34.0, dy + 6.0), "DODGE",
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

	# Dodge charges.
	var charges := hero.max_charges()
	for i in charges:
		var c := Vector2(x + 14.0 + i * 34.0, y + h + 22.0)
		if i < hero.dodge_charges:
			draw_circle(c, 11.0, Color(0.45, 0.75, 1.0))
		else:
			draw_arc(c, 11.0, 0.0, TAU, 20, Color(0.45, 0.75, 1.0, 0.6), 3.0)
			if i == hero.dodge_charges:
				var p := hero.dodge_recharge_t / hero.recharge_time()
				draw_arc(c, 11.0, -PI * 0.5, -PI * 0.5 + TAU * p, 20, Color(0.45, 0.75, 1.0), 4.0)
	draw_string(font, Vector2(x + 14.0 + charges * 34.0, y + h + 28.0), "DODGE",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.6))

	# Guard meter: only drawn while it matters.
	if hero.is_guarding() or hero.guard < hero.guard_max():
		var gy := y + h + 44.0
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
