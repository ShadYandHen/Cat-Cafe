extends SceneTree
## Native scene/input and renderer checks. Production rules and saves are not changed.
const WINDOW := preload("res://Scripts/UI/playtest_window.gd")
var checks := 0
var failures := 0
var capture_dir := ""
var main: Control
var s: CafeSession
var view: Control
var layout: Control
var canvas: Control
var touch := false

func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(text)
func settle() -> void:
	for frame in range(12):await process_frame
func click(button: Button, palette: bool = false) -> void:
	if palette:
		layout.get_node("Workspace").ensure_control_visible(button)
		await settle()
	check(button.is_visible_in_tree() and not button.disabled,"Enabled visual input "+button.name)
	var point := button.get_global_rect().get_center()
	for pressed in [true,false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.index=0
			event.position=root.get_final_transform()*point
			event.pressed=pressed
			Input.parse_input_event(event)
		else:
			var event := InputEventMouseButton.new()
			event.position=point
			event.button_index=MOUSE_BUTTON_LEFT
			event.pressed=pressed
			root.push_input(event,true)
	await settle()
func shot(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name()=="headless":return
	await settle()
	check(root.get_texture().get_image().save_png(capture_dir.path_join("%s-%d.png" % [name,root.size.x]))==OK,"Capture "+name)
func open_recipe(id: String) -> void:
	main=load("res://Scenes/Main.tscn").instantiate()
	s=main.get_node("CafeSession")
	s.profile=CafeProfile.new()
	s.cat_effects_enabled=false
	s.recipe_override=id
	s.start_immediately=true
	s.normal_arrival_interval=Vector2(600,600) # Isolated fixture schedule.
	root.add_child(main)
	s.set_process(false)
	view=main.get_node("GameplayView")
	layout=view.get_node("CoffeeStation/Content/Layout")
	canvas=layout.get_node("DrinkWorkspace")
	await settle()
	await click(view.get_node("Customer/Ticket"))
	check(s.view==CafeSession.View.STATION and s.selected_order_id==1,"Ticket retains order identity")
func close_recipe() -> void:
	main.queue_free()
	await process_frame
func geometry() -> void:
	var bounds := Rect2(Vector2.ZERO,main.size)
	var nodes: Array[Control]=[]
	for name in ["Heading","Patience","Stations","DrinkWorkspace","Description","Workspace","Action","Settings","Back"]:
		var node: Control=layout.get_node(name)
		nodes.append(node)
		check(bounds.encloses(node.get_global_rect()),"Station contains "+name)
	for i in range(nodes.size()):
		for j in range(i):
			check(not nodes[i].get_global_rect().intersects(nodes[j].get_global_rect()),"Pinned regions do not overlap: "+nodes[i].name+"/"+nodes[j].name)
	check(canvas.size.y*main.ui_scale>=179,"Prominent 180px workspace")
	check(layout.get_node("Workspace").size.y*main.ui_scale>=52,"Palette has a full ingredient row")
	check(layout.get_node("Workspace").horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,"No horizontal scrolling")
	for button in layout.get_node("Stations").get_children():
		check(button.size.x*main.ui_scale>=44 and button.size.y*main.ui_scale>=44,"44px station tabs")
		check(layout.get_node("Stations").get_global_rect().encloses(button.get_global_rect()),"Pinned station tab remains inside viewport")
	for child in [canvas.recipe_label,canvas.timing_label]:
		check(child.get_theme_font_size("font_size")*main.ui_scale>=14,"Readable cup text")
		check(canvas.get_global_rect().encloses(child.get_global_rect()),"Cup text stays within workspace")
	var before: Rect2=canvas.get_global_rect()
	for button in layout.get_node("Workspace/Body/Ingredients").get_children():
		layout.get_node("Workspace").ensure_control_visible(button)
		await settle()
		check(canvas.get_global_rect()==before,"Cup stays pinned while ingredients scroll")
		check(layout.get_node("Workspace").get_global_rect().encloses(button.get_global_rect()),"Entire ingredient target accessible "+button.name+str(button.get_global_rect())+" in "+str(layout.get_node("Workspace").get_global_rect()))
		check(button.size.x*main.ui_scale>=44 and button.size.y*main.ui_scale>=44,"44px ingredient target")
		check(button.name_label.get_theme_font_size("font_size")*main.ui_scale>=14,"Ingredient text readable")
		check(button.get_global_rect().encloses(button.name_label.get_global_rect()) and button.get_global_rect().encloses(button.status_label.get_global_rect()),"Ingredient captions fit")
	layout.get_node("Workspace").scroll_vertical=0
	await settle()
func prepare_case(recipe: Dictionary) -> void:
	await open_recipe(recipe.id)
	check(canvas.visual.category==recipe.category and canvas.visual.ingredients.is_empty(),"Correct empty station appearance "+recipe.id)
	check(canvas.visual.order_id==1,"Canvas identity matches customer")
	await geometry()
	if recipe.id=="basic_coffee":await shot("empty-coffee")
	var ingredients: Control=layout.get_node("Workspace/Body/Ingredients")
	for ingredient in recipe.ingredients:
		var button := ingredients.get_child(DrinkCatalog.INGREDIENTS.find(ingredient)) as Button
		check(button.required and not button.selected and button.status_label.text=="Needed","Required vs missing "+ingredient)
		await click(button,true)
		check(button.selected and button.status_label.text=="✓ Added" and ingredient in canvas.visual.ingredients,"Added ingredient updates actual cup "+ingredient)
		await click(button,true)
		check(not button.selected and ingredient not in canvas.visual.ingredients,"Removing ingredient updates cup "+ingredient)
		await click(button,true)
	check(canvas.visual.ingredients==s.selected_ingredients,"No invented ingredients")
	layout.get_node("Workspace").scroll_vertical=0
	await settle()
	await shot("selected-"+recipe.id)
	var coins := s.coins
	await click(layout.get_node("Action"))
	check(s.brewing and canvas.visual.state=="brewing","Start controls authoritative process")
	s.advance_time(s.preparation_target()*0.5)
	await settle()
	check(is_equal_approx(canvas.visual.elapsed,s.brew_elapsed) and is_equal_approx(canvas.visual.target,s.preparation_target()),"Visual timing comes from session")
	var elapsed := s.elapsed
	await create_timer(0.06).timeout
	check(s.elapsed==elapsed and canvas.visual.elapsed==s.brew_elapsed,"No second gameplay timer in renderer")
	if recipe.id=="basic_coffee":await shot("coffee-brewing")
	s.advance_time(s.preparation_target()*0.5)
	await click(layout.get_node("Action"))
	check(s.brew_ready and canvas.visual.state=="stopped","Stop retains separate assembly")
	await click(layout.get_node("Action"))
	var order := s.get_order(1)
	check(order.state==CafeSession.State.DRINK_READY and order.quality_score==100 and s.coins==coins,"Rendering preserves scoring, no service reward")
	check(s.view==CafeSession.View.CAFE,"Existing immediate return to café preserved")
	var miniature := view.get_node("Customer/Ticket/DrinkIcon/CompletedDrink")
	check(miniature.visible and miniature.visual.state=="complete" and miniature.visual.ingredients==recipe.ingredients,"Finished cup on Ready ticket has actual ingredients")
	check(view.get_node("Customer/Ticket/Cue").text.contains("Serve"),"Existing Serve ticket authoritative")
	if recipe.id=="basic_coffee":await shot("ready-serve-ticket")
	s.open_station()
	await settle()
	check(canvas.visual.state=="complete" and canvas.visual.recipe_name==recipe.name,"Finished cup remains inspectable with recipe name")
	await shot("complete-"+recipe.id)
	var state_before := s.profile.snapshot()
	await settle()
	check(s.profile.snapshot()==state_before,"Rendering completed drink cannot grant rewards")
	s.advance_time(80)
	await settle()
	check(order.state==CafeSession.State.DEPARTED and canvas.visual.state=="departed" and canvas.visual.ingredients.is_empty(),"Expiration clears drink visuals safely")
	check(not view.drink_visuals.has(1) and s.coins==coins,"Expired snapshot removed without reward")
	await close_recipe()
func missing_case() -> void:
	await open_recipe("vanilla_coffee")
	s.toggle_ingredient("Coffee")
	s.toggle_ingredient("Milk")
	await settle()
	check(not "Vanilla" in canvas.visual.ingredients,"Missing Vanilla is never painted as added")
	await shot("missing-ingredient")
	s.start_brewing()
	s.advance_time(s.preparation_target())
	s.stop_preparation()
	s.finish_coffee()
	await settle()
	check(s.get_order(1).quality_score==74 and s.get_order(1).quality_tier=="Good","Incomplete quality cap unchanged")
	check(not "Vanilla" in view.drink_visuals[1].ingredients,"Completed snapshot does not fabricate missing ingredient")
	await close_recipe()
func no_auto_stop() -> void:
	await open_recipe("garden_tea")
	s.toggle_ingredient("Tea")
	s.toggle_ingredient("Water")
	s.start_brewing()
	s.advance_time(s.preparation_target()*2.5)
	await settle()
	check(s.brewing and not s.brew_ready and canvas.visual.state=="brewing","Animation does not automatically stop or assemble")
	s.back_to_cafe()
	check(s.get_order(1).state==CafeSession.State.ORDER_ACCEPTED and s.brew_order_id==-1,"Cancel behavior unchanged")
	await close_recipe()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir=arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(capture_dir)
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	for usable in [Vector2i(1366,680),Vector2i(1920,1040),Vector2i(3840,2080)]:
		var fit := WINDOW.fitted_size(usable)
		check(fit.y<=720 and fit.x<usable.x and fit.y<usable.y and absf(float(fit.x)/fit.y-1280.0/720.0)<0.002,"Desktop fit preserves portrait and stays in usable display")
	var before := root.size
	WINDOW.configure(root)
	check(root.size==before,"Native editor/Linux tests are not resized by Windows playtest helper")
	for dimensions in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size=dimensions
		touch=dimensions.x==960
		for recipe in DrinkCatalog.new().recipes:
			await prepare_case(recipe)
		await missing_case()
		await no_auto_stop()
		await multiple_orders()
		print("PASS visual preparation at ",dimensions)
	print("%s: %d visual preparation assertions" % ["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)

func multiple_orders() -> void:
	await open_recipe("basic_coffee")
	s.back_to_cafe()
	s._arrive()
	s.changed.emit()
	s.prepare_order(2)
	await settle()
	check(layout.get_node("OrderChoices").visible,"Two accepted orders keep selector")
	await geometry()
	s.selected_ingredients.assign(["Coffee","Water"])
	s.changed.emit()
	s.start_brewing()
	s.advance_time(1)
	await click(layout.get_node("OrderChoices/Choice1"))
	check(s.selected_order_id==1 and s.brew_order_id==-1 and canvas.visual.ingredients.is_empty(),"Switching orders clears canceled draft and ingredient visuals")
	var coins := s.coins
	s.advance_time(80)
	await settle()
	s.finish_coffee()
	check(s.coins==coins and canvas.visual.state=="departed","Stale completion after departure gives no reward")
	await close_recipe()
