extends SceneTree
## Direct ticket input, immutable press IDs and existing service/persistence guards.
var checks := 0
var failures := 0
var captures := ""
var touch := false
var main: Control
var view: Control
var session: CafeSession
var folder := "/tmp/paw-16a1-tests-%d" % OS.get_process_id()
var sequence := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func settle() -> void:
	for frame in range(10):
		await process_frame

func shot(name: String) -> void:
	if captures.is_empty() or DisplayServer.get_name()=="headless":
		return
	await settle()
	check(root.get_texture().get_image().save_png(captures.path_join("%s-%d.png" % [name,root.size.x]))==OK,"Screenshot "+name)

func make_cafe() -> void:
	sequence+=1
	main=load("res://Scenes/Main.tscn").instantiate()
	session=main.get_node("CafeSession")
	var profile := CafeProfile.new()
	profile.open(folder.path_join("%d/profile.json" % sequence))
	session.profile=profile
	session.start_immediately=true
	session.cat_effects_enabled=false
	session.recipe_override="basic_coffee"
	session.normal_arrival_interval=Vector2(100,100) # Isolated scheduler fixture, not production balance.
	root.add_child(main)
	session.set_process(false)
	view=main.get_node("GameplayView")
	await settle()

func close_cafe() -> void:
	main.queue_free()
	await process_frame

func ticket(seat: int) -> Button:
	return view._actor(seat).get_node("Ticket")

func input(button: Button, pressed: bool) -> void:
	var point := button.get_global_rect().get_center()
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

func click(button: Button) -> void:
	check(button.is_visible_in_tree() and not button.disabled,"Input available: "+button.name)
	input(button,true)
	input(button,false)
	await settle()

func key(keycode: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=keycode
		event.pressed=pressed
		Input.parse_input_event(event)
	await settle()

func geometry() -> void:
	var cafe: Control=main.get_node("Content/Layout/Cafe")
	var hero: TextureRect=cafe.get_node("Stage/Barista")
	check(hero.size.y*cafe.get_node("Stage").scale.y*main.ui_scale>=140,"Barista remains prominent")
	var visible_hero := hero.get_global_rect()
	# The approved foreground counter already occludes the lower apron/feet.
	visible_hero.size.y=minf(visible_hero.size.y,cafe.get_node("Stage").to_global(Vector2(0,428)).y-visible_hero.position.y)
	check(not main.get_node("Content/Layout/BottomNavigation").has_node("Prepare"),"Redundant Prepare navigation removed")
	check(main.get_node("Content/Layout/BottomNavigation").get_child_count()==4,"Four unrelated menus retained")
	for seat in range(2):
		var target := ticket(seat)
		if not target.is_visible_in_tree():
			continue
		check(target.get_meta("order_id")==session.order_at_seat(seat),"Ticket bound to current unique ID")
		check(target.size.x*main.ui_scale>=44 and target.size.y*main.ui_scale>=44,"44px+ ticket touch target")
		check(cafe.get_global_rect().encloses(target.get_global_rect()),"Ticket stays in safe café area")
		check(not target.get_global_rect().intersects(visible_hero),"Ticket does not obscure barista")
		var label: Label=view._actor(seat).get_node("Caption")
		check(label.get_theme_font_size("font_size")*main.ui_scale>=14,"Readable recipe name")
		check(label.get_line_count()<=2,"Recipe uses at most two lines without ellipsis")
		check(target.get_global_rect().encloses(label.get_global_rect()),"Recipe label inside ticket")
		for child in target.get_children():
			check(target.get_global_rect().encloses(child.get_global_rect()),"Ticket child fits "+child.name)
		for name in view.EQUIPMENT:
			check(not target.get_global_rect().intersects(view.get_node(name).get_global_rect()),"Ticket leaves equipment accessible")
	if ticket(0).is_visible_in_tree() and ticket(1).is_visible_in_tree():
		check(not ticket(0).get_global_rect().intersects(ticket(1).get_global_rect()),"Independent tickets do not overlap")

func direct_service() -> void:
	await make_cafe()
	var first: int=session.order_at_seat(0)
	check(ticket(0).is_visible_in_tree() and not ticket(1).is_visible_in_tree(),"Arrival shows exactly one ticket")
	check(view.get_node("Customer/Caption").text=="Basic Coffee" and ticket(0).get_node("DrinkIcon").texture!=null,"Ticket has correct recipe and cup icon")
	geometry()
	await shot("one-waiting-customer")
	await shot("ticket-before-preparation")
	session._arrive()
	session.changed.emit()
	await settle()
	var second: int=session.order_at_seat(1)
	geometry()
	await shot("two-waiting-customers")
	await click(ticket(0))
	check(session.view==CafeSession.View.STATION and session.selected_order_id==first,"Ticket directly selects correct order and opens station")
	check(not view.get_node("OrderScreen").visible and session.get_order(first).state==CafeSession.State.ORDER_ACCEPTED,"No mandatory Guest Order screen")
	check(session.get_order(second).state==CafeSession.State.WAITING_ORDER,"Other customer remains independent")
	check(session.station_category==session.get_order(first).recipe.station,"Correct recipe station")
	check(view.get_node("CoffeeStation/Content/Layout/Patience").text.contains("#%d" % first),"Station identifies selected customer")
	await shot("selected-order-station")
	var ingredients := session.selected_ingredients.duplicate()
	session.prepare_order(first)
	check(session.selected_ingredients==ingredients and session.brew_order_id==-1,"Duplicate ticket call cannot create another preparation")
	await click(view.get_node("CoffeeStation/Content/Layout/Back"))
	await shot("selected-customer")
	check(view.get_node("Customer").get_theme_stylebox("normal").border_width_left==2 and ticket(0).get_theme_stylebox("normal").border_width_left==3,"Selected character and ticket agree")
	check(view.get_node("Customer/Patience").get_theme_stylebox("background").border_width_left==2,"Selected patience indicator agrees")
	await click(ticket(1))
	check(session.selected_order_id==second,"Second ticket switches customer")
	await click(view.get_node("CoffeeStation/Content/Layout/Back"))
	check(view.get_node("Customer").get_theme_stylebox("normal").border_width_left==0,"Previous character selection cleared")
	await click(ticket(0))
	for ingredient in session.get_order(first).recipe.ingredients:
		session.toggle_ingredient(ingredient)
	session.start_brewing()
	var brewing_id := session.brew_order_id
	session.prepare_order(second)
	check(session.brew_order_id==brewing_id and session.selected_order_id==first,"Hidden/stale ticket call cannot change running draft")
	session.advance_time(session.preparation_target())
	session.stop_preparation()
	session.finish_coffee()
	await settle()
	check(session.get_order(first).state==CafeSession.State.DRINK_READY and ticket(0).get_node("Cue").text.contains("Serve"),"Completed drink changes ticket action to Serve")
	var balance := session.coins
	var expected: int=session.service_preview(session.get_order(first)).coins
	await click(ticket(0))
	check(session.served==1 and session.coins==balance+expected,"Ready ticket manually serves correct customer once")
	check(session.get_order(second).state==CafeSession.State.ORDER_ACCEPTED,"Serving first leaves second order intact")
	check(not ticket(0).is_visible_in_tree() and ticket(1).is_visible_in_tree(),"Served ticket disappears without hiding other ticket")
	view._use_ticket(ticket(0))
	check(session.coins==balance+expected and session.served==1,"Repeated callback cannot duplicate reward")
	await shot("after-serving")
	var loaded := CafeProfile.new()
	loaded.open(session.profile.store.path)
	check(loaded.coins==session.coins and loaded.snapshot().ordinary_tip_remainder==session.profile.snapshot().ordinary_tip_remainder,"Service and tip checkpoint survives reload")
	check(not loaded.apply_service(session.shift_id,first,expected,15,3),"Reloaded receipt rejects duplicate reward")
	session.get_order(second).deadline=session.elapsed+10
	session.clock_changed.emit()
	await settle()
	check(view.get_node("CustomerRight/State").text.begins_with("!"),"Low patience retains non-color warning")
	await shot("low-patience")
	session.advance_time(10.01)
	await settle()
	check(not ticket(0).is_visible_in_tree() and not ticket(1).is_visible_in_tree(),"Expired customer ticket disappears")
	check(ticket(1).get_meta("order_id")==-1,"Departed selection has no active ticket identity")
	await shot("empty-cafe")
	session.advance_time(120-session.elapsed)
	while session.active_count()<2:
		session._arrive()
	session.changed.emit()
	await settle()
	geometry()
	check(session.phase==CafeSession.Phase.RUSH and ticket(0).is_visible_in_tree() and ticket(1).is_visible_in_tree(),"Two ticketed customers during Rush")
	await shot("rush-two-customers")
	session.advance_time(300-session.elapsed)
	session.advance_time(80)
	check(session.view==CafeSession.View.RESULTS,"Existing closing/results resolves remaining customers")
	var days := session.profile.completed_days
	session.start_next_day()
	check(session.profile.completed_days==days and session.elapsed==0,"Next shift does not duplicate completed-day rewards")
	await close_cafe()

func stale_press() -> void:
	await make_cafe()
	var old_id: int=session.order_at_seat(0)
	var target := ticket(0)
	input(target,true)
	await settle()
	check(target.get_meta("pressed_order_id")==old_id,"Press-down captures original order")
	session.advance_time(76)
	check(session.get_order(old_id).state==CafeSession.State.DEPARTED,"Pressed customer expires")
	session._arrive()
	session.changed.emit()
	await settle()
	var new_id: int=session.order_at_seat(0)
	check(new_id!=old_id and new_id>=0,"Seat reused with different ID")
	input(target,false)
	await settle()
	check(session.view==CafeSession.View.CAFE and session.get_order(new_id).state==CafeSession.State.WAITING_ORDER,"Old pointer release cannot target new occupant")
	session.prepare_order(old_id)
	check(session.view==CafeSession.View.CAFE and session.get_order(new_id).state==CafeSession.State.WAITING_ORDER,"Stale programmatic ticket ID rejected")
	await click(target)
	check(session.selected_order_id==new_id and session.view==CafeSession.View.STATION,"Fresh press selects replacement customer")
	await click(view.get_node("CoffeeStation/Content/Layout/Back"))
	session.open_order(new_id)
	await settle()
	check(view.get_node("OrderScreen").visible,"Optional order inspection retained")
	await click(view.get_node("OrderScreen/Content/Layout/Back"))
	await close_cafe()

func recipes_and_secondary_routes() -> void:
	await make_cafe()
	for recipe in session.catalog.recipes:
		for order in session.active_orders():
			session._depart(order)
		session.recipe_override=recipe.id
		session._arrive()
		session.changed.emit()
		await settle()
		var id: int=session.order_at_seat(0)
		geometry()
		check(view.get_node("Customer/Caption").text==recipe.name,"Full authoritative recipe "+recipe.id)
		await click(ticket(0))
		check(session.selected_order_id==id and session.station_category==recipe.station,"Direct routing for "+recipe.id)
		await click(view.get_node("CoffeeStation/Content/Layout/Back"))
		for i in range(4):
			await click(view.get_node(view.EQUIPMENT[i]))
			check(session.selected_order_id==id and session.station_category==DrinkCatalog.CATEGORIES[i],"Equipment preserves selected order and routes category")
			await click(view.get_node("CoffeeStation/Content/Layout/Back"))
	var equipment: Button=view.get_node("MilkEquipment")
	equipment.disabled=true
	view._open_equipment("Milk")
	check(session.view==CafeSession.View.CAFE,"Disabled equipment cannot activate")
	equipment.disabled=false
	view._open_equipment("Unknown")
	check(session.view==CafeSession.View.CAFE,"Invalid equipment category rejected")
	ticket(0).disabled=true
	view._arm_ticket(ticket(0))
	view._use_ticket(ticket(0))
	check(session.view==CafeSession.View.CAFE,"Disabled ticket cannot prepare")
	ticket(0).disabled=false
	ticket(0).grab_focus()
	await key(KEY_ENTER)
	check(session.view==CafeSession.View.STATION,"Keyboard Enter opens ticket")
	await key(KEY_ESCAPE)
	check(session.view==CafeSession.View.CAFE,"Escape returns to café")
	await close_cafe()

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			captures=argument.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(captures)
	root.content_scale_size=Vector2i(720,1280)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	for dimensions in [Vector2i(720,1280),Vector2i(320,568)]:
		root.size=dimensions
		touch=dimensions.x==320
		await direct_service()
		await stale_press()
		await recipes_and_secondary_routes()
		print("PASS %s order-ticket input %s" % ["touch" if touch else "mouse", dimensions])
	print("%s: %d order-ticket assertions; isolated %s" % ["PASS" if failures==0 else "FAIL",checks,folder])
	quit(0 if failures==0 else 1)
