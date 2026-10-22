extends SceneTree
## Real scene/input checks, isolated in-memory profiles and optional native screenshots.
var checks := 0
var failures := 0
var captures := ""
var main: Control
var session: CafeSession
var view: Control
var cafe: Control
var touch := false

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for frame in range(10):
		await process_frame

func shot(name: String) -> void:
	if captures.is_empty() or DisplayServer.get_name()=="headless":
		return
	await settle()
	check(root.get_texture().get_image().save_png(captures.path_join("%s-%d.png" % [name, root.size.x]))==OK, "Save screenshot "+name)

func click(button: Button) -> void:
	check(button.is_visible_in_tree() and not button.disabled, "Enabled input "+button.name)
	var pos := button.get_global_rect().get_center()
	for pressed in [true,false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.position = root.get_final_transform()*pos
			event.pressed = pressed
			Input.parse_input_event(event)
		else:
			var event := InputEventMouseButton.new()
			event.position = pos
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event,true)
	await settle()

func make_cafe(id: String, start: bool = true) -> void:
	main = load("res://Scenes/Main.tscn").instantiate()
	var profile := CafeProfile.new()
	var slots: Array[String] = [id]
	for cat in CatTeam.IDS:
		if cat!=id and slots.size()<3:
			slots.append(cat)
	check(profile.set_team(slots), "Unique initial team "+id)
	session = main.get_node("CafeSession")
	session.profile = profile
	session.start_immediately = start
	root.add_child(main)
	session.set_process(false)
	view = main.get_node("GameplayView")
	cafe = main.get_node("Content/Layout/Cafe")
	await settle()

func geometry() -> void:
	var bounds := cafe.get_global_rect()
	var controls: Array[Control] = []
	for name in view.EQUIPMENT + ["Customer", "CustomerRight"]:
		var button: Button = view.get_node(name)
		if not button.is_visible_in_tree():
			continue
		controls.append(button)
		if button.has_node("Bunny"):
			check(button.get_node("Bunny").size.y*main.ui_scale>=35,"Recognizable customer face: "+name)
		check(bounds.encloses(button.get_global_rect()), "Café contains "+name)
		check(button.size.x*main.ui_scale>=44 and button.size.y*main.ui_scale>=44, "44px equipment/customer target "+name)
		for child in button.get_children():
			check(button.get_global_rect().encloses(child.get_global_rect()), "Child fits "+name+"/"+child.name)
	for i in range(controls.size()):
		for j in range(i):
			check(not controls[i].get_global_rect().intersects(controls[j].get_global_rect()), "Independent hit regions "+controls[i].name+"/"+controls[j].name)
	var hero: TextureRect = cafe.get_node("Stage/Barista")
	check(hero.texture!=null and hero.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Official art preserves aspect")
	check(bounds.encloses(hero.get_global_rect()), "Whole barista control inside café")
	check(hero.size.y*cafe.get_node("Stage").scale.y*main.ui_scale>=140, "Prominent 140px+ barista")
	var status: Label = view.get_node("Status")
	check(not status.get_global_rect().intersects(hero.get_global_rect()), "Status does not obscure cat")
	for control in controls:
		check(not status.get_global_rect().intersects(control.get_global_rect()), "Status leaves interactions clear")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			captures=arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(captures)
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	for dimensions in [Vector2i(1280,720), Vector2i(960,540)]:
		root.size=dimensions
		touch=dimensions.x==960
		for cat in CatTeam.IDS:
			await make_cafe(cat)
			check(cafe.active_cat_id==cat and cafe.get_node("Stage/Barista").texture.resource_path==session.team.active_cat().artwork, "Correct approved asset "+cat)
			geometry()
			await shot("barista-"+cat)
			main.queue_free()
			await process_frame
		await recipe_bubbles()
		await states()
		await team_change()
		print("PASS café visuals ",dimensions)
	print("%s: %d café visual assertions" % ["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)

func states() -> void:
	await make_cafe("fade")
	var order := session.get_order(session.order_at_seat(0))
	check(view.get_node("Customer").visible and not view.get_node("CustomerRight").visible, "One occupied seat")
	await shot("one-customer")
	session._arrive() # Isolated fixture requests second production arrival, no new scheduler.
	session.changed.emit()
	await settle()
	geometry()
	await shot("two-customers")
	for id in [session.order_at_seat(0),session.order_at_seat(1)]:
		await click(view._actor(session.get_order(id).seat))
		check(session.selected_order_id==id, "Customer selection stays order-specific")
		await click(view.get_node("OrderScreen/Content/Layout/Action"))
		check(session.view==CafeSession.View.CAFE,"Accept returns to café")
	check(view.get_node("Customer/Caption").text==order.requested_drink, "Full untruncated recipe bubble")
	check(view.get_node("Customer/State").text.contains("Preparing"), "Accepted order feedback")
	var previous: float = view.get_node("Customer/Patience").value
	session.advance_time(5)
	await settle()
	check(view.get_node("Customer/Patience").value < previous, "Bar follows authoritative deadline")
	for i in range(4):
		await click(view.get_node(view.EQUIPMENT[i]))
		check(session.view==CafeSession.View.STATION and session.station_category==DrinkCatalog.CATEGORIES[i], "Category equipment routes correctly")
		var elapsed := session.elapsed
		session.advance_time(1)
		check(session.elapsed>elapsed, "Station does not pause clock")
		if i==0:
			await shot("equipment-interaction")
		await click(view.get_node("CoffeeStation/Content/Layout/Back"))
	# No production station unlocks exist; disabled controls still cannot route.
	view.get_node("MilkEquipment").disabled=true
	view._open_equipment("Milk")
	check(session.view==CafeSession.View.CAFE,"Unavailable equipment cannot activate")
	view.get_node("MilkEquipment").disabled=false
	session.open_station()
	session.select_station_order(order.order_id)
	session.select_station(order.recipe.station)
	for ingredient in order.recipe.ingredients:
		session.toggle_ingredient(ingredient)
	session.start_brewing()
	session.advance_time(session.preparation_target())
	session.stop_preparation()
	session.finish_coffee()
	await settle()
	check(order.state==CafeSession.State.DRINK_READY and view.get_node("Customer/State").text=="Serve drink", "Prepared drink advertises manual service")
	await shot("ready-to-serve")
	order.deadline=session.elapsed+order.original_patience*0.2
	session.clock_changed.emit()
	await settle()
	check(view.get_node("Customer/State").text.begins_with("!"), "Non-color low-patience warning")
	check(is_equal_approx(view.get_node("Customer/Patience").value,0.2), "Independent patience fraction")
	await shot("low-patience")
	var before := session.coins
	session.advance_time(order.original_patience*0.2+0.01)
	await settle()
	check(order.state==CafeSession.State.DEPARTED and session.coins==before, "Expiration hides actor without reward")
	for active in session.active_orders():
		session._depart(active)
	session.changed.emit()
	await settle()
	check(not view.get_node("Customer").visible and not view.get_node("CustomerRight").visible,"Both empty seats")
	await shot("empty-cafe")
	session.advance_time(120-session.elapsed)
	await settle()
	check(session.phase==CafeSession.Phase.RUSH and view.get_node("Status").text.contains("Rush"), "Authoritative Rush display")
	geometry()
	await shot("rush-hour")
	session.advance_time(180-session.elapsed)
	session.ability_ready_at=session.elapsed+30
	session.clock_changed.emit()
	await settle()
	geometry()
	check(view.get_node("Status").get_line_count()==1,"Late-service cooldown remains a compact single line")
	await click(main.get_node("Content/Layout/TopHUD/TitleRow/Settings"))
	var elapsed := session.elapsed
	session.advance_time(1)
	check(session.elapsed==elapsed+1,"Settings preserves gameplay clock")
	await click(main.get_node("SettingsPanel/Center/Panel/Margins/Layout/Close"))
	check(root.gui_get_focus_owner()==main.get_node("Content/Layout/TopHUD/TitleRow/Settings"),"Settings restores focus")
	main.queue_free()
	await process_frame

func team_change() -> void:
	await make_cafe("mochi",false)
	await click(view.get_node("DayLobby/Content/Layout/CatTeam"))
	check(session.assign_cat(0,"odin"),"Team edit before shift")
	check(cafe.active_cat_id=="odin", "Hero updates immediately after team change")
	session.back_to_cafe()
	await settle()
	await click(view.get_node("DayLobby/Content/Layout/Action"))
	check(cafe.active_cat_id=="odin" and session.team.slots[0]=="odin","New shift uses selected barista")
	check(not session.assign_cat(0,"blaze"),"No in-shift team mutation")
	main.queue_free()
	await process_frame

func recipe_bubbles() -> void:
	await make_cafe("mochi")
	for recipe in session.catalog.recipes:
		for order in session.active_orders():
			session._depart(order)
		session.recipe_override=recipe.id
		session._arrive()
		session.changed.emit()
		await settle()
		var caption: Label = view.get_node("Customer/Caption")
		check(caption.text==recipe.name and caption.get_line_count()<=2, "Complete distinguishable two-line recipe: "+recipe.id)
		check(caption.get_minimum_size().y<=caption.size.y, "Recipe label height fits "+recipe.id)
	main.queue_free()
	await process_frame
