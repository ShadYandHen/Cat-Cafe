extends SceneTree
## Deterministic model coverage plus actual station mouse/touch controls.
const SESSION := preload("res://Scenes/Gameplay/CafeSession.tscn")
const MAIN := preload("res://Scenes/Main.tscn")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func make_session(recipe: String = "") -> CafeSession:
	var s := SESSION.instantiate() as CafeSession
	s.profile = CafeProfile.new()
	s.start_immediately = true
	s.cat_effects_enabled = false
	s.recipe_override = recipe
	root.add_child(s)
	s.set_process(false)
	return s

func prepare(s: CafeSession, id: int, ingredients: Array, timing: float) -> void:
	s.open_order(id)
	s.accept_order()
	s.open_station()
	s.select_station_order(id)
	for ingredient in ingredients:
		s.toggle_ingredient(ingredient)
	s.start_brewing()
	s.advance_time(timing)
	s.stop_preparation()
	s.finish_coffee()

func run() -> void:
	catalog_and_quality()
	recipe_services()
	cancellation_and_expiry()
	await station_inputs()
	await keyboard_preparation()
	if failures == 0:
		print("PASS: %d drink system assertions" % checks)
	quit(0 if failures == 0 else 1)

func catalog_and_quality() -> void:
	var catalog := DrinkCatalog.new()
	check(catalog.errors.is_empty() and catalog.recipes.size() == 8, "Eight valid recipes load from JSON")
	for category in DrinkCatalog.CATEGORIES:
		var count := 0
		for recipe in catalog.recipes:
			if recipe.category == category:
				count += 1
		check(count >= 2, "Two recipes for " + category)
	var invalid := catalog.recipes[0].duplicate(true)
	invalid.ingredients = ["Unknown"]
	check(not DrinkCatalog.validate_recipe(invalid).is_empty(), "Unknown ingredient rejected")
	invalid = catalog.recipes[0].duplicate(true)
	invalid.target_seconds = 0
	check(not DrinkCatalog.validate_recipe(invalid).is_empty(), "Invalid process duration rejected")
	check(not DrinkCatalog.validate_recipe(catalog.recipes[0], [catalog.recipes[0].id]).is_empty(), "Duplicate recipe ID rejected")
	check(not DrinkCatalog.validate_recipe({}).is_empty(), "Missing recipe fields rejected")
	for pair in [[0,0],[49,0],[50,1],[74,1],[75,2],[94,2],[95,3],[100,3]]:
		check(DrinkQuality.tier(pair[0]) == pair[1], "Quality boundary %d" % pair[0])
	check(DrinkQuality.score(["Milk"], ["Milk"], 3, 3, 3) == 100, "Exact ingredients/timing/steps perfect")
	check(DrinkQuality.score(["Milk"], ["Milk","Coffee"], 3, 3, 3) == 50, "Extra ingredient penalized")
	check(DrinkQuality.score(["Milk","Honey"], ["Milk"], 3, 3, 3) == 75, "Missing ingredient penalized")
	check(DrinkQuality.score(["Milk"], ["Milk"], 0, 3, 3) == 65, "Early timing penalized")
	check(DrinkQuality.score(["Milk"], ["Milk"], 6, 3, 3) == 65, "Late timing penalized")
	check(DrinkQuality.score(["Milk"], [], 0, 3, 0) == 0, "Missing required steps penalized")
	for tier in range(4):
		var score_value: int = [0,50,75,95][tier]
		var reward := DrinkQuality.reward(20, score_value)
		check(reward.coins == 20 + [0,1,2,3][tier] and reward.xp == [5,8,12,15][tier], "Reward tier %d" % tier)
	check(DrinkQuality.reward(14,100).tip == 2 and DrinkQuality.reward(10,50).tip == 0, "Whole Coin tips round down")

func recipe_services() -> void:
	var catalog := DrinkCatalog.new()
	for recipe in catalog.recipes:
		var s := make_session(recipe.id)
		check(s.get_order(1).recipe.id == recipe.id, "Requested recipe " + recipe.id)
		prepare(s, 1, recipe.ingredients, recipe.target_seconds)
		var order := s.get_order(1)
		check(order.state == CafeSession.State.DRINK_READY and order.quality_score == 100 and order.quality_tier == "Perfect", "Perfect preparation " + recipe.id)
		check(s.coins == 120 and s.reputation_earned == 0, "Preparation grants no service reward")
		s.open_order(1)
		s.serve()
		s.serve()
		var reward := DrinkQuality.reward(int(recipe.base_coins), 100)
		check(s.coins == 120 + reward.coins and s.reputation_earned == 15 and s.quality_counts == [0,0,0,1], "Exactly once service/reputation " + recipe.id)
		s.advance_time(400)
		check(s.phase == CafeSession.Phase.RESULTS, "Multi-drink shifts still resolve")
		s.start_next_day()
		check(s.reputation_earned == 0 and s.quality_counts == [0,0,0,0] and s.coins == 120 + reward.coins, "Next day resets only daily reward stats")
		s.free()
	var generated := make_session()
	var categories: Array = []
	var ids: Array = []
	for day in range(8):
		generated.advance_time(400)
		for order: CafeOrder in generated.orders.values():
			if order.recipe.category not in categories:
				categories.append(order.recipe.category)
			if order.recipe.id not in ids:
				ids.append(order.recipe.id)
		generated.start_next_day()
	check(categories.size() == 4 and ids.size() == 8, "Normal seeded order generation covers every recipe/category")
	generated.free()
	# Actual low-quality drinks can be served, paying the specified tier XP.
	var low := make_session("basic_coffee")
	prepare(low, 1, [], 0.01)
	low.open_order(1)
	low.serve()
	check(low.reputation_earned == 5 and low.coins == 130 and low.quality_counts[0] == 1, "Okay service pays base/no tip/5 XP")
	low.free()
	for fixture in [["Good", ["Coffee", "Water", "Milk", "Honey"], 3.0, 8], ["Excellent", ["Coffee", "Water"], 1.5, 12]]:
		var scored := make_session("basic_coffee")
		prepare(scored, 1, fixture[1], fixture[2])
		scored.open_order(1)
		scored.serve()
		check(scored.get_order(1).quality_tier == fixture[0] and scored.reputation_earned == fixture[3], "Service tier/XP " + fixture[0])
		scored.free()

func cancellation_and_expiry() -> void:
	var s := make_session("warm_milk")
	s.normal_arrival_interval = Vector2(30,30)
	s.advance_time(35)
	for id in [1,2]:
		s.open_order(id)
		s.accept_order()
	s.open_station()
	s.select_station_order(1)
	s.toggle_ingredient("Milk")
	s.toggle_ingredient("Milk")
	check(s.selected_ingredients.is_empty(), "Ingredients can be deselected")
	s.toggle_ingredient("Milk")
	s.select_station("Tea")
	s.start_brewing()
	check(s.brew_order_id == -1 and s.selected_ingredients.is_empty(), "Wrong station blocks brewing and clears draft")
	s.select_station("Milk")
	s.toggle_ingredient("Milk")
	s.start_brewing()
	s.toggle_ingredient("Honey")
	check(s.selected_ingredients == ["Milk"], "Ingredients lock after process begins")
	s.advance_time(1)
	s.select_station_order(2)
	check(s.brew_order_id == -1 and s.selected_ingredients.is_empty(), "Order switching clears draft ingredients/process")
	s.start_brewing()
	s.advance_time(1)
	s.stop_preparation()
	s.back_to_cafe()
	check(s.get_order(2).state == CafeSession.State.ORDER_ACCEPTED and s.brew_order_id == -1, "Back after stop discards draft without completing drink")
	s.open_station()
	s.select_station_order(1)
	s.toggle_ingredient("Milk")
	s.start_brewing()
	s.advance_time(40)
	s.stop_preparation()
	s.finish_coffee()
	check(s.get_order(1).state == CafeSession.State.DEPARTED and s.brew_order_id == -1 and s.coins == 120 and s.reputation_earned == 0, "Expiration while processing invalidates draft/rewards")
	check(s.get_order(2).state == CafeSession.State.ORDER_ACCEPTED, "Other order survives independently")
	s.select_station_order(2)
	s.toggle_ingredient("Milk")
	s.start_brewing()
	s.advance_time(3)
	s.stop_preparation()
	s.finish_coffee()
	s.open_order(2)
	s.serve()
	check(s.served == 1 and s.reputation_earned == 15, "Surviving order can still earn quality reward")
	s.free()
	var draft := make_session("warm_milk")
	draft.open_order(1)
	draft.accept_order()
	draft.open_station()
	draft.toggle_ingredient("Milk")
	draft.advance_time(75)
	check(draft.selected_ingredients.is_empty() and draft.brew_order_id == -1, "Expiry before processing clears selected ingredient draft")
	draft.free()

func settle() -> void:
	for frame in range(8):
		await process_frame

func input_button(button: Button, touch: bool, scroll: ScrollContainer = null) -> void:
	if scroll != null:
		scroll.ensure_control_visible(button)
		await settle()
	check(button.is_visible_in_tree() and not button.disabled, "Enabled input " + button.name)
	if scroll != null:
		check(scroll.get_global_rect().encloses(button.get_global_rect()), "Scrolled input fully accessible " + button.name)
	var center := button.get_global_rect().get_center()
	for pressed in [true, false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.position = root.get_final_transform() * center
			event.index = 0
			event.pressed = pressed
			Input.parse_input_event(event)
		else:
			var event := InputEventMouseButton.new()
			event.position = center
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event, true)
	await settle()

func station_inputs() -> void:
	root.content_scale_size = Vector2i(720,1280)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	for dimensions in [Vector2i(720,1280), Vector2i(320,568)]:
		root.size = dimensions
		var touch: bool = dimensions.x == 320
		for recipe in DrinkCatalog.new().recipes:
			var main := MAIN.instantiate() as Control
			main.get_node("CafeSession").profile = CafeProfile.new()
			main.get_node("CafeSession").start_immediately = true
			var s := main.get_node("CafeSession") as CafeSession
			s.cat_effects_enabled = false
			s.recipe_override = recipe.id
			root.add_child(main)
			s.set_process(false)
			await settle()
			s.open_order(1)
			s.accept_order()
			s.open_station()
			await settle()
			var layout := main.get_node("GameplayView/CoffeeStation/Content/Layout")
			var scroll := layout.get_node("Workspace") as ScrollContainer
			var body := scroll.get_node("Body")
			check(layout.get_node("Heading").text == recipe.category + " station", "Dedicated category interface " + recipe.id)
			var factor := float(dimensions.x) / main.size.x
			for group in ["Stations","Ingredients"]:
				for button in body.get_node(group).get_children():
					check(button.size.x * factor >= 44 and button.size.y * factor >= 44, "44px station target " + button.text)
					check(button.get_theme_font_size("font_size") * factor >= 14, "Readable station label " + button.text)
			for index in range(4):
				await input_button(body.get_node("Stations").get_child(index), touch, scroll)
				check(s.station_category == DrinkCatalog.CATEGORIES[index], "Station tab input " + DrinkCatalog.CATEGORIES[index])
			await input_button(body.get_node("Stations").get_child(DrinkCatalog.CATEGORIES.find(recipe.category)), touch, scroll)
			for ingredient in recipe.ingredients:
				var i := DrinkCatalog.INGREDIENTS.find(ingredient)
				await input_button(body.get_node("Ingredients").get_child(i), touch, scroll)
			check(s.selected_ingredients.size() == recipe.ingredients.size(), "Mouse/touch selects ingredients " + recipe.id)
			await input_button(layout.get_node("Action"), touch)
			check(s.brewing, "Manual process begins")
			s.advance_time(recipe.target_seconds)
			await input_button(layout.get_node("Action"), touch)
			check(s.brew_ready and s.get_order(1).state == CafeSession.State.ORDER_ACCEPTED, "Stop requires separate assembly")
			await input_button(layout.get_node("Action"), touch)
			check(s.get_order(1).quality_score == 100 and s.view == CafeSession.View.CAFE, "Input produces perfect drink " + recipe.id)
			s.open_order(1)
			await settle()
			check_panel_bounds(main, "OrderScreen")
			s.serve()
			s.advance_time(400)
			await settle()
			check_panel_bounds(main, "DayResults")
			main.queue_free()
			await process_frame
		print("PASS all eight recipe inputs at ", dimensions)

func keyboard_preparation() -> void:
	var main := MAIN.instantiate() as Control
	main.get_node("CafeSession").profile = CafeProfile.new()
	main.get_node("CafeSession").start_immediately = true
	var s := main.get_node("CafeSession") as CafeSession
	s.cat_effects_enabled = false
	s.recipe_override = "warm_milk"
	root.add_child(main)
	s.set_process(false)
	await settle()
	s.open_order(1)
	s.accept_order()
	s.open_station()
	await settle()
	var layout := main.get_node("GameplayView/CoffeeStation/Content/Layout")
	var ingredient := layout.get_node("Workspace/Body/Ingredients/Ingredient2") as Button
	ingredient.grab_focus()
	await settle()
	await enter_key()
	check(s.selected_ingredients == ["Milk"], "Keyboard selects ingredient")
	layout.get_node("Action").grab_focus()
	await enter_key()
	s.advance_time(3)
	await enter_key()
	await enter_key()
	check(s.get_order(1).quality_score == 100 and s.view == CafeSession.View.CAFE, "Keyboard starts, stops and assembles")
	main.queue_free()
	await process_frame

func enter_key() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		Input.parse_input_event(event)
	await settle()

func check_panel_bounds(main: Control, panel_name: String) -> void:
	var panel := main.get_node("GameplayView/" + panel_name)
	var bounds := Rect2(Vector2.ZERO, main.size)
	for name in ["Heading", "Patience", "Description", "Action", "Settings", "Back"]:
		var control := panel.get_node("Content/Layout/" + name) as Control
		if control.is_visible_in_tree():
			check(bounds.encloses(control.get_global_rect()), panel_name + "/" + name + " in viewport " + str(control.get_global_rect()))
