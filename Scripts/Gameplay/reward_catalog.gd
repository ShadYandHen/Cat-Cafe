class_name RewardCatalog
extends RefCounted
## Catalog-only eligibility. Future seasonal releases supply trusted season IDs.
const GROUPS := ["regular_cosmetics", "regular_decorations", "exclusive_cosmetics", "exclusive_decorations"]
var cosmetics: Array[Dictionary] = []
var errors: PackedStringArray = []

func _init() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://Data/Rewards/cosmetics.json"))
	if not data is Array:
		errors.append("Cosmetic catalog must be an array")
		return
	var seen: Array = []
	for entry in data:
		var problem := validate_item(entry, true)
		if not problem.is_empty() or entry.id in seen:
			errors.append(problem if not problem.is_empty() else "Duplicate cosmetic ID")
			continue
		seen.append(entry.id)
		cosmetics.append(entry)

static func validate_item(entry: Variant, cosmetic: bool) -> String:
	if not entry is Dictionary:
		return "Reward item must be an object"
	for key in ["id","name","category","rarity","collection","source","slot","origin_season","eligibility_start","asset"]:
		if not entry.get(key) is String:
			return "Invalid reward field: " + key
	if entry.id.is_empty() or entry.name.is_empty() or entry.source.is_empty():
		return "Missing reward identity/source"
	if entry.rarity not in ["regular","exclusive"] or not entry.get("exclusive") is bool or entry.exclusive != (entry.rarity=="exclusive"):
		return "Invalid exclusive classification"
	if entry.collection != entry.rarity + ("_cosmetics" if cosmetic else "_decorations"):
		return "Invalid collection classification"
	if not entry.get("lottery_eligible") is bool or entry.eligibility_start not in ["immediate","season_released"]:
		return "Invalid eligibility policy"
	if (not entry.origin_season.is_empty() and entry.eligibility_start!="season_released") or (entry.eligibility_start=="season_released" and entry.origin_season.is_empty()):
		return "Seasonal items require an explicit release"
	if not entry.asset.is_empty() and not ResourceLoader.exists(entry.asset):
		return "Missing optional reward asset"
	if cosmetic and (entry.slot!="cafe_badge" or not entry.get("color") is String or not Color.html_is_valid(entry.color)):
		return "Invalid cosmetic compatibility/color"
	return ""

func cosmetic(id: String) -> Dictionary:
	for entry in cosmetics:
		if entry.id==id:
			return entry
	return {}

func all_items(decorations: Array[Dictionary]) -> Array[Dictionary]:
	var items: Array[Dictionary] = cosmetics.duplicate()
	items.append_array(decorations)
	return items

static func eligible(entry: Dictionary, released_seasons: Array) -> bool:
	return entry.lottery_eligible and (entry.eligibility_start=="immediate" or entry.origin_season in released_seasons)

func pool(category: String, decorations: Array[Dictionary], released_seasons: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in all_items(decorations):
		var matches: bool = entry.exclusive if category=="exclusive" else entry.collection==category
		if matches and eligible(entry,released_seasons):
			result.append(entry)
	return result

func collection_summary(data: Dictionary, decorations: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for group in GROUPS:
		result[group]={"owned":0,"total":0,"percent":0.0}
	for entry in all_items(decorations):
		# Unreleased seasonal items are visible as locked previews, excluded from completion.
		if not eligible(entry,data.released_seasons):
			continue
		result[entry.collection].total+=1
		if entry.id in data.owned_cosmetics or entry.id in data.owned_decorations:
			result[entry.collection].owned+=1
	for group in GROUPS:
		var row: Dictionary=result[group]
		row.percent=100.0*row.owned/row.total if row.total>0 else 0.0
	return result
