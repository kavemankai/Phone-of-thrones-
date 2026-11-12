class_name PropSprite
extends Node2D
## The painted art of one piece of cover, as its own node on the iso layer so it sorts by
## depth with the characters: someone behind a wall is hidden by it, someone in front is not.
## Drawing only. What blocks movement is still the footprint rectangle in ArenaSpace.

var texture: Texture2D
var footprint := Rect2()
## Room style the art belongs to (see ArenaView.COVER_ART). The anvil is drawn narrower.
var style := 0


func place(art: Texture2D, area: Rect2, room_style: int) -> void:
	texture = art
	footprint = area
	style = room_style
	position = area.get_center()
	# Characters sort by x + y of their feet. The middle of the footprint is the fair line:
	# beyond it you are behind the prop, before it you are in front.
	z_index = int(position.x + position.y)
	queue_redraw()


func _draw() -> void:
	if texture == null:
		return
	# On screen the footprint is a diamond (x + y) wide and half that tall. The prop keeps
	# its painted proportions, is as wide as that diamond and stands on its front corner.
	var fill := 0.85 if style == 3 else 1.0
	var width := (footprint.size.x + footprint.size.y) * fill
	var height := width * float(texture.get_height()) / float(texture.get_width())
	# Painted running down to the right; mirrored for cover that is longer the other way.
	var mirror := -1.0 if footprint.size.y > footprint.size.x else 1.0
	draw_set_transform_matrix(Iso.upright() * Transform2D(0.0, Vector2(mirror, 1.0), 0.0, Vector2.ZERO))
	draw_texture_rect(texture, Rect2(-width * 0.5, -height + width * 0.25, width, height), false)
	draw_set_transform(Vector2.ZERO)
