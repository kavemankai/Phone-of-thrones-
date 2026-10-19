class_name EncounterController
extends RefCounted
## Limits how many enemies may be committed to an attack at once. A commitment runs from
## the start of the wind-up to the end of the recovery.

var max_commits := 2
var committed: Array = []
## Highest number of simultaneous commitments seen since the last reset (used by tests).
var peak := 0


func configure(tuning: Tuning) -> void:
	max_commits = tuning.max_commits


func reset() -> void:
	committed.clear()
	peak = 0


func count() -> int:
	return committed.size()


func has_slot(enemy: Object) -> bool:
	return committed.has(enemy) or committed.size() < max_commits


func try_commit(enemy: Object) -> bool:
	if committed.has(enemy):
		return true
	if committed.size() >= max_commits:
		return false
	committed.append(enemy)
	peak = maxi(peak, committed.size())
	return true


func release(enemy: Object) -> void:
	committed.erase(enemy)
