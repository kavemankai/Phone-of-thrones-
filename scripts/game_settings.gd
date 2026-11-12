class_name GameSettings
extends RefCounted
## Player options that are not key bindings. Kept in their own small file under user://.

const PATH := "user://settings.cfg"
const VOLUME_STEPS: Array[float] = [1.0, 0.75, 0.5, 0.25, 0.0]

static var screen_shake := true
static var volume := 1.0
## The first-room control prompts have been completed once on this machine.
static var tutorial_done := false
static var _loaded := false


## Reads the file once and applies it. Missing or unreadable files leave the defaults.
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := ConfigFile.new()
	if file.load(PATH) == OK:
		var shake: Variant = file.get_value("options", "screen_shake", true)
		if shake is bool:
			screen_shake = shake
		var level: Variant = file.get_value("options", "volume", 1.0)
		if level is float or level is int:
			volume = clampf(level, 0.0, 1.0)
		var taught: Variant = file.get_value("options", "tutorial_done", false)
		if taught is bool:
			tutorial_done = taught
	apply_volume()


static func save() -> Error:
	var file := ConfigFile.new()
	file.set_value("options", "screen_shake", screen_shake)
	file.set_value("options", "volume", volume)
	file.set_value("options", "tutorial_done", tutorial_done)
	return file.save(PATH)


static func toggle_shake() -> void:
	screen_shake = not screen_shake
	save()


## Steps the master volume down through VOLUME_STEPS and back to full.
static func cycle_volume() -> void:
	var at := 0
	for i in VOLUME_STEPS.size():
		if absf(VOLUME_STEPS[i] - volume) < 0.01:
			at = i
	volume = VOLUME_STEPS[(at + 1) % VOLUME_STEPS.size()]
	apply_volume()
	save()


static func apply_volume() -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, volume <= 0.0)
	if volume > 0.0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(volume))


static func volume_label() -> String:
	return "Volume: %d%%" % roundi(volume * 100.0)


static func shake_label() -> String:
	return "Screen shake: ON" if screen_shake else "Screen shake: OFF"
