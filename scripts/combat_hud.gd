class_name CombatHud
extends Control
## Hero health, dodge charges and enemies remaining. Enemy health bars are drawn on the
## enemies themselves.

var game: Game
var inset_left := 0.0
var inset_top := 0.0
var inset_right := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func layout(vp: Vector2, insets: Vector4) -> void:
	position = Vector2.ZERO
	size = vp
	inset_left = insets.x
	inset_top = insets.y
	inset_right = insets.z


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if game == null or game.hero == null or game.tuning == null:
		return
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
