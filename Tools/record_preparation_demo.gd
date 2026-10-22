extends SceneTree
## Scripted native playtest recording, isolated in-memory profile, actual mouse input.
var main: Control
var s: CafeSession
var view: Control
var layout: Control
var sync_path := "/tmp/paw-16b/record-start"
func _initialize() -> void:
	call_deferred("run")
func settle() -> void:
	for frame in range(8):await process_frame
func pause(seconds: float) -> void:
	await create_timer(seconds).timeout
func click(button: Button, palette: bool = false) -> void:
	if palette:
		layout.get_node("Workspace").ensure_control_visible(button)
		await settle()
	assert(button.is_visible_in_tree() and not button.disabled,"Demo target "+button.name)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=button.get_global_rect().get_center()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		root.push_input(event,true)
	await settle()
func run() -> void:
	Engine.max_fps=60
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size=Vector2i(1280,720)
	root.position=Vector2i.ZERO
	main=load("res://Scenes/Main.tscn").instantiate()
	s=main.get_node("CafeSession")
	s.profile=CafeProfile.new()
	s.start_immediately=true
	s.cat_effects_enabled=false
	s.recipe_override="vanilla_coffee"
	s.normal_arrival_interval=Vector2(600,600) # Fixture: one customer per station demonstration.
	root.add_child(main)
	s.set_process(false)
	view=main.get_node("GameplayView")
	layout=view.get_node("CoffeeStation/Content/Layout")
	await settle()
	var ready := FileAccess.open(sync_path+".ready",FileAccess.WRITE)
	ready.store_string("ready")
	ready.close()
	while not FileAccess.file_exists(sync_path):await pause(0.05)
	s.set_process(true) # The production session clock runs during the entire recording.
	for id in ["vanilla_coffee","honey_milk","honey_tea","berry_cooler"]:
		if s.active_count()==0:
			s.recipe_override=id
			s._arrive()
			s.changed.emit()
		await pause(1)
		var order := s.get_order(s.order_at_seat(0))
		await click(view.get_node("Customer/Ticket"))
		await pause(0.9)
		for ingredient in order.recipe.ingredients:
			await click(layout.get_node("Workspace/Body/Ingredients").get_child(DrinkCatalog.INGREDIENTS.find(ingredient)),true)
			await pause(0.5)
		await pause(0.5)
		await click(layout.get_node("Action"))
		while s.brewing and s.brew_elapsed<s.preparation_target():await process_frame
		await click(layout.get_node("Action"))
		await pause(0.8)
		await click(layout.get_node("Action"))
		assert(order.state==CafeSession.State.DRINK_READY)
		await pause(1)
		await click(view.get_node(view.EQUIPMENT[DrinkCatalog.CATEGORIES.find(order.recipe.category)]))
		await pause(1.3)
		await click(layout.get_node("Back"))
		await click(view.get_node("Customer/Ticket"))
		assert(order.state==CafeSession.State.SERVED)
		print("DEMO served ",id," quality ",order.quality_score," coins ",s.coins)
		await pause(1)
	await pause(1)
	print("PASS recorded four-station ticket/preparation/service demo using isolated profile")
	quit()
