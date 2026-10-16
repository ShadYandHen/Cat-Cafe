class_name CatTeam
extends RefCounted
## Session-owned roster and three unique slots. No ownership or persistence.
const IDS := ["mochi", "fade", "momo", "odin", "max", "blaze"]
var roster: Array[Dictionary] = []
var errors: PackedStringArray = []
var slots: Array[String] = ["mochi", "fade", "max"]

func _init() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://Data/Cats/roster.json"))
	if not data is Array:
		errors.append("Cat roster must be an array")
		return
	var seen: Array = []
	for entry in data:
		if not entry is Dictionary or entry.get("id", "") not in IDS or entry.id in seen:
			errors.append("Invalid or duplicate cat ID")
			continue
		if not entry.get("name") is String or not entry.get("passive") is Dictionary or not entry.get("active") is Dictionary:
			errors.append("Missing cat definition")
			continue
		var passive: Dictionary = entry.passive
		var active: Dictionary = entry.active
		if passive.get("kind", "") not in ["patience", "tip", "quality", "speed"] or not _number(passive.get("value")) or passive.value < 0 or not passive.get("description") is String:
			errors.append("Invalid passive")
			continue
		if active.get("kind", "") not in ["care", "speed", "precision", "premium", "finish"] or not active.get("parameters") is Dictionary or not active.get("description") is String:
			errors.append("Invalid active ability")
			continue
		var required: Array = {"care": ["threshold", "restore"], "speed": ["speed"], "precision": ["forgiveness"], "premium": ["tip"], "finish": ["minimum", "maximum", "score"]}[active.kind]
		var valid := true
		for key in required:
			valid = valid and _number(active.parameters.get(key)) and active.parameters.get(key, -1) > 0
		if active.kind == "care" and valid:
			valid = active.parameters.threshold < 1.0
		if active.kind == "finish" and valid:
			valid = active.parameters.minimum <= active.parameters.maximum and active.parameters.maximum < active.parameters.score and active.parameters.score <= 100
		if not valid or not _number(entry.get("cooldown")) or entry.cooldown <= 0:
			errors.append("Invalid ability parameters/cooldown")
			continue
		if not entry.get("artwork") is String or not ResourceLoader.exists(entry.artwork):
			errors.append("Missing official artwork reference")
			continue
		seen.append(entry.id)
		roster.append(entry)
	if seen.size() != IDS.size():
		errors.append("All six cats are required")

static func _number(value: Variant) -> bool:
	return value is float or value is int

func find(id: String) -> Dictionary:
	for cat in roster:
		if cat.id == id:
			return cat
	return {}

func active_cat() -> Dictionary:
	return find(slots[0])

func assign(slot: int, id: String) -> bool:
	if slot < 0 or slot >= 3 or find(id).is_empty() or slots[slot] == id:
		return false
	var occupied := slots.find(id)
	if occupied >= 0:
		slots[occupied] = slots[slot] # Assigning an equipped cat swaps its slots.
	slots[slot] = id
	return true

func bonuses() -> Dictionary:
	var result := {"patience": 0.0, "tip": 0.0, "quality": 0.0, "speed": 0.0}
	for id in slots:
		var passive: Dictionary = find(id).passive
		result[passive.kind] += passive.value
	return result
