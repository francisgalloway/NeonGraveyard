extends Node
## Autoload "Character": the player's money, XP and level, skill points, items,
## equipment, and health/morale. Modelled on Disco Elysium's character state.
##
## - One skill point per level. Raised skills can be reverted until the sheet closes.
## - Each skill group acts like a DE attribute: its score is the learning cap for
##   the skills in it, and the signature skill raises that cap by one.
## - Clothing gives signed skill modifiers (they count for checks, not for the cap).
## - Health is tied to Hardscrabble, Morale to Keel (DE uses Endurance and Volition).

signal changed

const SLOTS: Array[String] = ["headgear", "eyewear", "neckwear", "jacket", "shirt", "gloves", "pants", "shoes"]
const SLOT_LABELS := {
	"headgear": "Headgear", "eyewear": "Eyewear", "neckwear": "Neckwear", "jacket": "Jacket",
	"shirt": "Shirt", "gloves": "Gloves", "pants": "Pants", "shoes": "Shoes",
}
const HEALTH_SKILL := "hardscrabble"
const MORALE_SKILL := "keel"
const MAX_PIPS := 13

var currency := "$"
var money := 0
var xp := 0
var level := 1
var max_level := 15
var xp_to_next: Array = []
var skill_points := 0
var signature_skill := ""
var items: Dictionary = {}        # id -> item Dictionary
var equipment: Dictionary = {}    # slot -> item id ("" when empty)
var inventory: Array[String] = [] # item ids that are NOT worn
var health_damage := 0
var morale_damage := 0
var health_charges := 0
var morale_charges := 0

var _pending: Dictionary = {}     # skill id -> points raised since the sheet was opened


func _ready() -> void:
	load_data()


func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Could not read %s" % path)
		return {}
	return parsed


func load_data() -> void:
	items.clear()
	for it in _read("res://data/items.json").get("items", []):
		items[String(it["id"])] = it
	var prog := _read("res://data/progression.json")
	max_level = int(prog.get("max_level", 15))
	xp_to_next = prog.get("xp_to_next", [100])
	var c := _read("res://data/character.json")
	currency = String(c.get("currency", "$"))
	money = int(c.get("money", 0))
	xp = int(c.get("xp", 0))
	level = int(c.get("level", 1))
	skill_points = int(c.get("skill_points", 0))
	signature_skill = String(c.get("signature_skill", ""))
	equipment.clear()
	for slot in SLOTS:
		equipment[slot] = String(c.get("equipment", {}).get(slot, ""))
	inventory.clear()
	for id in c.get("inventory", []):
		inventory.append(String(id))
	health_damage = int(c.get("health_damage", 0))
	morale_damage = int(c.get("morale_damage", 0))
	health_charges = int(c.get("health_charges", 0))
	morale_charges = int(c.get("morale_charges", 0))
	_pending.clear()


# --- money and XP ------------------------------------------------------------

func add_money(amount: int) -> void:
	money = maxi(money + amount, 0)
	changed.emit()


## XP needed to go from the current level to the next; 0 at the level cap.
func xp_needed() -> int:
	if level >= max_level or xp_to_next.is_empty():
		return 0
	return int(xp_to_next[mini(level - 1, xp_to_next.size() - 1)])


func add_xp(amount: int) -> void:
	xp += amount
	while level < max_level and xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		skill_points += 1
	changed.emit()


# --- skills ------------------------------------------------------------------

func group_of(skill_id: String) -> String:
	return String(Skills.skills[skill_id]["group"])


func group_score(group_name: String) -> int:
	for g in Skills.groups:
		if g["name"] == group_name:
			return int(g["score"])
	return 0


## Learning cap: the group's score, plus one if the signature skill is in that group.
func skill_cap(skill_id: String) -> int:
	var group := group_of(skill_id)
	var cap := group_score(group)
	if signature_skill != "" and group_of(signature_skill) == group:
		cap += 1
	return cap


func can_raise(skill_id: String) -> bool:
	return skill_points > 0 and Skills.get_base_level(skill_id) < skill_cap(skill_id)


func raise_skill(skill_id: String) -> bool:
	if not can_raise(skill_id):
		return false
	Skills.set_level(skill_id, Skills.get_base_level(skill_id) + 1)
	skill_points -= 1
	_pending[skill_id] = int(_pending.get(skill_id, 0)) + 1
	changed.emit()
	return true


func has_pending() -> bool:
	return not _pending.is_empty()


func revert_pending() -> void:
	for id in _pending:
		Skills.set_level(id, Skills.get_base_level(id) - int(_pending[id]))
		skill_points += int(_pending[id])
	_pending.clear()
	changed.emit()


func commit_pending() -> void:
	_pending.clear()


# --- equipment and inventory -------------------------------------------------

func item_name(item_id: String) -> String:
	return String(items[item_id]["name"]) if items.has(item_id) else item_id


func is_worn(item_id: String) -> bool:
	return equipment.values().has(item_id)


func equip(item_id: String) -> void:
	var item: Dictionary = items.get(item_id, {})
	if item.is_empty() or item.get("type", "") != "clothes":
		return
	var slot := String(item["slot"])
	inventory.erase(item_id)
	var old := String(equipment.get(slot, ""))
	if old != "" and old != item_id:
		inventory.append(old)
	equipment[slot] = item_id
	changed.emit()


func unequip(slot: String) -> void:
	var old := String(equipment.get(slot, ""))
	if old == "":
		return
	equipment[slot] = ""
	inventory.append(old)
	changed.emit()


func add_item(item_id: String) -> bool:
	if not items.has(item_id):
		return false
	inventory.append(item_id)
	changed.emit()
	return true


func remove_item(item_id: String) -> bool:
	var i := inventory.find(item_id)
	if i < 0:
		return false
	inventory.remove_at(i)
	changed.emit()
	return true


## All clothes the player owns (worn first, in slot order), or all non-clothes items.
func owned_items(type: String) -> Array[String]:
	var out: Array[String] = []
	if type == "clothes":
		for slot in SLOTS:
			var id := String(equipment.get(slot, ""))
			if id != "":
				out.append(id)
	for id in inventory:
		if String(items[id]["type"]) == type:
			out.append(id)
	return out


## The signed skill bonus granted by worn clothing for one skill.
func equipment_bonus(skill_id: String) -> int:
	var total := 0
	for slot in SLOTS:
		var id := String(equipment.get(slot, ""))
		if id != "":
			total += int(items[id].get("modifiers", {}).get(skill_id, 0))
	return total


## [{ "name": item name, "value": signed int }] for worn clothing touching this skill.
func bonus_sources(skill_id: String) -> Array:
	var out: Array = []
	for slot in SLOTS:
		var id := String(equipment.get(slot, ""))
		if id == "":
			continue
		var v := int(items[id].get("modifiers", {}).get(skill_id, 0))
		if v != 0:
			out.append({"name": String(items[id]["name"]), "value": v})
	return out


## skill id -> total signed bonus from worn clothing (zero entries left out).
func total_modifiers() -> Dictionary:
	var out := {}
	for id in Skills.skills:
		var v := equipment_bonus(id)
		if v != 0:
			out[id] = v
	return out


# --- health and morale -------------------------------------------------------

func max_health() -> int:
	return clampi(Skills.get_level(HEALTH_SKILL), 1, MAX_PIPS)


func max_morale() -> int:
	return clampi(Skills.get_level(MORALE_SKILL), 1, MAX_PIPS)


func health() -> int:
	return maxi(max_health() - health_damage, 0)


func morale() -> int:
	return maxi(max_morale() - morale_damage, 0)


func damage_health(amount: int = 1) -> void:
	health_damage = clampi(health_damage + amount, 0, max_health())
	changed.emit()


func damage_morale(amount: int = 1) -> void:
	morale_damage = clampi(morale_damage + amount, 0, max_morale())
	changed.emit()


## Spend one healing charge to restore one point. Returns false if nothing happened.
func heal(kind: String) -> bool:
	if kind == "health":
		if health_charges <= 0 or health_damage <= 0:
			return false
		health_charges -= 1
		health_damage -= 1
	elif kind == "morale":
		if morale_charges <= 0 or morale_damage <= 0:
			return false
		morale_charges -= 1
		morale_damage -= 1
	else:
		return false
	changed.emit()
	return true
