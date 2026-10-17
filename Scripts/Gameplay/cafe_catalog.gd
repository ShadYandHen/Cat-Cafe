class_name CafeCatalog
extends RefCounted
## Small original prototype catalog; shared purchase/unlock definitions.
const SLOT_IDS := ["wall_display", "shelf_display", "floor_display"]
const SLOT_NAMES := ["Wall display", "Shelf display", "Floor display"]
const EFFECTS := ["speed", "patience", "quality", "tip"]
var upgrades: Array[Dictionary] = []
var decorations: Array[Dictionary] = []
var errors: PackedStringArray = []

func _init() -> void:
	_load("res://Data/Cafe/upgrades.json",true)
	_load("res://Data/Cafe/decorations.json",false)

func _load(path: String, upgrade: bool) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Array:
		errors.append("Catalog must be an array: " + path)
		return
	var seen: Array = []
	for entry in data:
		var problem := validate_upgrade(entry) if upgrade else validate_decoration(entry)
		if not problem.is_empty():
			errors.append(problem)
			continue
		if entry.id in seen:
			errors.append("Duplicate catalog ID: " + entry.id)
			continue
		seen.append(entry.id)
		if upgrade:
			upgrades.append(entry)
		else:
			decorations.append(entry)

static func integer(value: Variant, minimum: int, maximum: int = 1000000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=minimum and value<=maximum and floor(float(value))==float(value)

static func validate_upgrade(entry: Variant) -> String:
	if not entry is Dictionary:
		return "Upgrade must be an object"
	for field in ["id","name","description"]:
		if not entry.get(field) is String or entry[field].is_empty():
			return "Missing upgrade field: " + field
	if not integer(entry.get("max_level"),1,10) or entry.get("effect","") not in EFFECTS:
		return "Invalid upgrade cap/effect"
	var amount = entry.get("value_per_level")
	if not (amount is int or amount is float) or not is_finite(float(amount)) or amount<=0 or amount>(20 if entry.effect=="quality" else 1):
		return "Invalid upgrade effect value"
	if entry.effect=="quality" and floor(float(amount))!=float(amount):
		return "Quality bonuses must be whole points"
	if not entry.get("costs") is Array or not entry.get("minimum_reputation") is Array or entry.costs.size()!=entry.max_level or entry.minimum_reputation.size()!=entry.max_level:
		return "Missing per-level prices/unlocks"
	var previous := 0
	for i in range(int(entry.max_level)):
		if not integer(entry.costs[i],1) or entry.costs[i]<=previous or not integer(entry.minimum_reputation[i],1,50):
			return "Invalid increasing cost or Reputation requirement"
		previous=int(entry.costs[i])
	return ""

static func validate_decoration(entry: Variant) -> String:
	if not entry is Dictionary:
		return "Decoration must be an object"
	for field in ["id","name","category","rarity"]:
		if not entry.get(field) is String or entry[field].is_empty():
			return "Missing decoration field: " + field
	if not integer(entry.get("price"),1) or not integer(entry.get("minimum_reputation"),1,50) or entry.get("slot","") not in SLOT_IDS:
		return "Invalid decoration price/unlock/slot"
	if not entry.get("asset") is String or (not entry.asset.is_empty() and not ResourceLoader.exists(entry.asset)):
		return "Invalid optional decoration asset"
	if entry.get("symbol","") not in ["paw","mug","leaf","flower","star","heart"] or not entry.get("color") is String or not Color.html_is_valid(entry.color):
		return "Invalid placeholder symbol/color"
	return RewardCatalog.validate_item(entry,false)

func upgrade(id: String) -> Dictionary:
	for entry in upgrades:
		if entry.id==id:
			return entry
	return {}

func decoration(id: String) -> Dictionary:
	for entry in decorations:
		if entry.id==id:
			return entry
	return {}

static func purchase_gate(required: int, reputation: int, coins: int, cost: int, owned: bool = false) -> Dictionary:
	# Common requirements can be extended with future ownership/unlock predicates.
	if owned:
		return {"allowed":false,"reason":"Already owned"}
	if reputation<required:
		return {"allowed":false,"reason":"Requires Café Level %d" % required}
	if coins<cost:
		return {"allowed":false,"reason":"Not enough Coins (%d needed)" % cost}
	return {"allowed":true,"reason":"Available"}

func upgrade_offer(id: String, state: Dictionary) -> Dictionary:
	var entry := upgrade(id)
	if entry.is_empty():
		return {"allowed":false,"reason":"Invalid upgrade ID"}
	var current := int(state.upgrades.get(id,0))
	if current>=entry.max_level:
		return {"allowed":false,"reason":"Maximum level reached","current":current,"maximum":int(entry.max_level)}
	var result := purchase_gate(int(entry.minimum_reputation[current]),int(state.level),int(state.coins),int(entry.costs[current]))
	result.merge({"current":current,"maximum":int(entry.max_level),"cost":int(entry.costs[current]),"required":int(entry.minimum_reputation[current])})
	return result

func decoration_offer(id: String, state: Dictionary) -> Dictionary:
	var entry := decoration(id)
	if entry.is_empty():
		return {"allowed":false,"reason":"Invalid decoration ID"}
	if entry.get("source", "shop_or_reward") != "shop_or_reward":
		return {"allowed":false,"reason":"Reward only","cost":0,"required":50,"owned":id in state.owned_decorations}
	var result := purchase_gate(int(entry.minimum_reputation),int(state.level),int(state.coins),int(entry.price),id in state.owned_decorations)
	result.merge({"cost":int(entry.price),"required":int(entry.minimum_reputation),"owned":id in state.owned_decorations})
	return result

func bonuses(levels: Dictionary) -> Dictionary:
	var result := {"speed":0.0,"patience":0.0,"quality":0.0,"tip":0.0}
	for entry in upgrades:
		result[entry.effect] += clampi(int(levels.get(entry.id,0)),0,int(entry.max_level))*entry.value_per_level
	return result
