extends Node
## Autoload "Skills": skill data, levels, and 2d6 check resolution.
##
## Active check:  2d6 + skill level >= target. Double sixes always succeed and
##                double ones always fail (Disco Elysium's rule).
## Passive check: no dice. Passes if skill level + PASSIVE_BASE >= target,
##                i.e. as if you had rolled an average 2d6.

const PASSIVE_BASE := 7
const DIFFICULTIES := {
	"trivial": 5,
	"easy": 8,
	"medium": 10,
	"challenging": 12,
	"high": 15,
	"legendary": 18,
}

var skills: Dictionary = {}   # id -> skill Dictionary (name, group, color, description, voice, level)
var groups: Array = []        # [{ "name": String, "color": Color, "skills": [id, ...] }]
var levels: Dictionary = {}   # id -> int, the player's current levels
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	load_skills()


func load_skills(path: String = "res://data/skills.json") -> void:
	skills.clear()
	groups.clear()
	levels.clear()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Could not read %s" % path)
		return
	for g in data["groups"]:
		var ids: Array = []
		var group_color := Color(g["color"])
		for s in g["skills"]:
			var id: String = s["id"]
			s["group"] = g["name"]
			s["color"] = group_color
			skills[id] = s
			levels[id] = int(s["level"])
			ids.append(id)
		groups.append({"name": g["name"], "color": group_color, "score": int(g.get("score", 3)), "skills": ids})


## The learned level: points the player has spent, without clothing modifiers.
func get_base_level(id: String) -> int:
	return int(levels.get(id, 0))


## The level used for checks: learned level plus modifiers from worn clothing.
func get_level(id: String) -> int:
	var bonus := 0
	var character := get_node_or_null("/root/Character")
	if character != null:
		bonus = character.equipment_bonus(id)
	return get_base_level(id) + bonus


func set_level(id: String, value: int) -> void:
	levels[id] = value


func skill_name(id: String) -> String:
	return String(skills[id]["name"]) if skills.has(id) else id


func skill_color(id: String) -> Color:
	return skills[id]["color"] if skills.has(id) else Color.WHITE


## Accepts a difficulty name ("medium") or a raw target number.
func target_for(difficulty: Variant) -> int:
	if typeof(difficulty) == TYPE_STRING:
		return int(DIFFICULTIES.get(String(difficulty).to_lower(), 10))
	return int(difficulty)


func difficulty_label(target: int) -> String:
	for key in DIFFICULTIES:
		if DIFFICULTIES[key] == target:
			return String(key).capitalize()
	return "Target"


func _combo_succeeds(d1: int, d2: int, level: int, target: int) -> bool:
	if d1 == 6 and d2 == 6:
		return true
	if d1 == 1 and d2 == 1:
		return false
	return d1 + d2 + level >= target


func success_chance(level: int, target: int) -> float:
	var wins := 0
	for a in range(1, 7):
		for b in range(1, 7):
			if _combo_succeeds(a, b, level, target):
				wins += 1
	return wins / 36.0


func roll_active(id: String, target: int) -> Dictionary:
	var d1 := rng.randi_range(1, 6)
	var d2 := rng.randi_range(1, 6)
	var level := get_level(id)
	return {
		"skill": id,
		"dice": [d1, d2],
		"level": level,
		"total": d1 + d2 + level,
		"target": target,
		"auto": "success" if (d1 == 6 and d2 == 6) else ("fail" if (d1 == 1 and d2 == 1) else ""),
		"success": _combo_succeeds(d1, d2, level, target),
	}


func passes_passive(id: String, target: int) -> bool:
	return get_level(id) + PASSIVE_BASE >= target
