class_name RunRecords
extends RefCounted
## What the player has achieved across runs: fortress wins and the best time. A small file
## under user://, separate from the checkpoint, which is deleted when a run ends.

const PATH := "user://records.cfg"

static var wins := 0
static var oathbound_wins := 0
## Seconds; 0 means no win yet.
static var best_time := 0.0
static var best_weapon := ""
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	var count: Variant = file.get_value("records", "wins", 0)
	if count is int:
		wins = maxi(0, count)
	var hard_count: Variant = file.get_value("records", "oathbound_wins", 0)
	if hard_count is int:
		oathbound_wins = maxi(0, hard_count)
	var seconds: Variant = file.get_value("records", "best_time", 0.0)
	if seconds is float or seconds is int:
		best_time = maxf(0.0, seconds)
	var weapon: Variant = file.get_value("records", "best_weapon", "")
	if weapon is String:
		best_weapon = weapon


static func has_won() -> bool:
	ensure_loaded()
	return wins > 0


## Records a finished fortress run. Returns true when it set a new best time.
static func note_win(weapon_name: String, seconds: float, oathbound: bool) -> bool:
	ensure_loaded()
	wins += 1
	if oathbound:
		oathbound_wins += 1
	var faster := best_time <= 0.0 or seconds < best_time
	if faster:
		best_time = seconds
		best_weapon = weapon_name
	var file := ConfigFile.new()
	file.set_value("records", "wins", wins)
	file.set_value("records", "oathbound_wins", oathbound_wins)
	file.set_value("records", "best_time", best_time)
	file.set_value("records", "best_weapon", best_weapon)
	file.save(PATH)
	return faster


static func clock(seconds: float) -> String:
	var whole := int(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]


## One line for the title screen, or "" before the first win.
static func summary() -> String:
	ensure_loaded()
	if wins <= 0:
		return ""
	var line := "Fortress taken %d time%s.  Best %s with the %s." % [
		wins, "" if wins == 1 else "s", clock(best_time), best_weapon]
	if oathbound_wins > 0:
		line += "  Oathbound wins: %d." % oathbound_wins
	return line
