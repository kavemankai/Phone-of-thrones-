class_name ForgeArt
extends RefCounted
## Runtime names for the painted textures. Actor sprites stand at their bottom centre.

const ACTORS := {
	"hero": preload("res://assets/actors/hero.webp"),
	"grunt": preload("res://assets/actors/gate_guard.webp"),
	"pike": preload("res://assets/actors/pike_sentinel.webp"),
	"hound": preload("res://assets/actors/war_hound.webp"),
	"warden": preload("res://assets/actors/iron_warden.webp"),
	"penitent": preload("res://assets/actors/chain_penitent.webp"),
	"herald": preload("res://assets/actors/war_herald.webp"),
	"captain": preload("res://assets/actors/gate_captain.webp"),
	"crown_tyrant": preload("res://assets/actors/crown_tyrant.webp"),
}
const HERO_RUN := preload("res://assets/actors/hero_run.webp")
const HERO_WINDUP := preload("res://assets/actors/hero_windup.webp")
const HERO_STRIKE := preload("res://assets/actors/hero_strike.webp")
const HERO_ROLL := preload("res://assets/actors/hero_roll.webp")

const EQUIPMENT := {
	"sword": preload("res://assets/equipment/sword.webp"),
	"spear": preload("res://assets/equipment/spear.webp"),
	"axe": preload("res://assets/equipment/axe.webp"),
	"daggers": preload("res://assets/equipment/daggers.webp"),
	"zweihander": preload("res://assets/equipment/zweihander.webp"),
}
const SHIELD := preload("res://assets/equipment/shield.webp")


static func actor(target: CanvasItem, texture: Texture2D, height: float, direction: Vector2,
		tint: Color, offset := Vector2.ZERO, tilt := 0.0) -> void:
	var width := height * float(texture.get_width()) / texture.get_height()
	var flip := -1.0 if direction.x < 0.0 else 1.0
	target.draw_set_transform_matrix(Iso.upright() * Transform2D(tilt, Vector2(flip, 1), 0.0, offset))
	target.draw_texture_rect(texture, Rect2(-width * 0.5, -height, width, height), false, tint)
	target.draw_set_transform_matrix(Iso.upright())


static func weapon(target: CanvasItem, id: String, start: Vector2, end: Vector2) -> void:
	var texture: Texture2D = EQUIPMENT.get(id, EQUIPMENT.sword)
	var direction := end - start
	var height := direction.length() * float(texture.get_height()) / texture.get_width()
	target.draw_set_transform_matrix(Iso.upright() * Transform2D(direction.angle(), start))
	target.draw_texture_rect(texture, Rect2(0.0, -height * 0.5, direction.length(), height), false)
	target.draw_set_transform_matrix(Iso.upright())
