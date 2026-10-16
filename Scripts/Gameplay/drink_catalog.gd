class_name DrinkCatalog
extends RefCounted
## Local prototype data; no global state or economy balancing is implied.
const CATEGORIES := ["Coffee", "Milk", "Tea", "Cold Drinks"]
const INGREDIENTS := ["Coffee", "Water", "Milk", "Vanilla", "Honey", "Tea", "Berries", "Ice", "Cocoa"]
var recipes: Array[Dictionary] = []
var errors: PackedStringArray = []

func _init() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://Data/Recipes/drinks.json"))
	if not data is Array:
		errors.append("Recipe catalog must be an array")
		return
	var ids: Array[String] = []
	for entry in data:
		var problem := validate_recipe(entry, ids)
		if not problem.is_empty():
			errors.append(problem)
			continue
		ids.append(entry.id)
		recipes.append(entry)

static func validate_recipe(entry: Variant, ids: Array[String] = []) -> String:
	if not entry is Dictionary:
		return "Recipe must be an object"
	for field in ["id", "name", "category", "station", "action"]:
		if not entry.get(field) is String or entry[field].is_empty():
			return "Missing recipe field: " + field
	if entry.id in ids or entry.category not in CATEGORIES or entry.station != entry.category:
		return "Duplicate ID or invalid station/category"
	if not entry.get("ingredients") is Array or entry.ingredients.is_empty():
		return "Ingredients required"
	var unique: Array = []
	for ingredient in entry.ingredients:
		if ingredient not in INGREDIENTS or ingredient in unique:
			return "Invalid/duplicate ingredient"
		unique.append(ingredient)
	if not entry.get("steps") is Array or entry.steps.size() != 3 or entry.steps[0] != "Select ingredients" or entry.steps[1] != entry.action or entry.steps[2] != "Assemble":
		return "Select, process and assemble steps required"
	for field in ["base_coins", "target_seconds"]:
		if not (entry.get(field) is float or entry.get(field) is int) or entry[field] <= 0:
			return "Positive numeric field required: " + field
	if entry.base_coins != floor(entry.base_coins):
		return "Coin values must be integers"
	return ""

func find(id: String) -> Dictionary:
	for recipe in recipes:
		if recipe.id == id:
			return recipe
	return {}
