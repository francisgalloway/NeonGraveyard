extends Node
## Autoload "GameState": flags and the log of active checks already attempted.
##
## Disco Elysium rules: a "red" check can only be attempted once. A "white"
## check can be retried, but only after the skill level has gone up since the
## last failed attempt. A passed check is never offered again.

var flags: Dictionary = {}
var check_log: Dictionary = {}  # check key -> { "level": int, "success": bool }


func can_attempt(key: String, skill: String, red: bool) -> bool:
	if not check_log.has(key):
		return true
	var entry: Dictionary = check_log[key]
	if entry["success"] or red:
		return false
	return Skills.get_level(skill) > int(entry["level"])


func record_attempt(key: String, skill: String, success: bool) -> void:
	check_log[key] = {"level": Skills.get_level(skill), "success": success}


func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value


func has_flag(key: String) -> bool:
	return flags.has(key)
