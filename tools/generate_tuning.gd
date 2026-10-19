extends SceneTree
## Writes resources/tuning.tres with every value spelled out (ResourceSaver would omit
## defaults, leaving an empty-looking file). Run from the project root:
##   godot --headless --path . --script tools/generate_tuning.gd

const PATH := "res://resources/tuning.tres"


func _init() -> void:
	var t := Tuning.new()
	var lines := PackedStringArray()
	lines.append("[gd_resource type=\"Resource\" script_class=\"Tuning\" format=3]")
	lines.append("")
	lines.append("[ext_resource type=\"Script\" path=\"res://scripts/tuning.gd\" id=\"1\"]")
	lines.append("")
	lines.append("[resource]")
	lines.append("script = ExtResource(\"1\")")
	for p in t.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.usage & PROPERTY_USAGE_STORAGE:
			lines.append("%s = %s" % [p.name, var_to_str(t.get(p.name))])
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write %s" % PATH)
		quit(1)
		return
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("wrote ", PATH, " (", lines.size() - 6, " values)")
	quit(0)
