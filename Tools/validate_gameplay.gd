extends SceneTree
## End-to-end input tests plus short, configurable real-Timer race/expiry scenarios.
const MAIN := preload("res://Scenes/Main.tscn")
var failures: int = 0
var checks: int = 0
var departures: int = 0
var services: int = 0
var touch_mode: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in range(8):
		await process_frame

func make_cafe(patience_seconds: float = 60.0, brew_seconds: float = 0.1) -> Control:
	var main := MAIN.instantiate() as Control
	main.get_node("CafeSession").patience_seconds = patience_seconds
	main.get_node("CafeSession").brew_seconds = brew_seconds
	root.add_child(main)
	await settle()
	return main

func click(button: Button) -> void:
	check(button.is_visible_in_tree() and not button.disabled, "Clicked button is visible and enabled: " + button.name)
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	root.push_input(motion, true)
	for pressed in [true, false]:
		if touch_mode:
			var touch := InputEventScreenTouch.new()
			touch.index = 0
			touch.position = root.get_final_transform() * motion.position
			touch.pressed = pressed
			Input.parse_input_event(touch)
		else:
			var event := InputEventMouseButton.new()
			event.position = motion.position
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event, true)
	await settle()

func layout_checks(main: Control) -> void:
	var view := main.get_node("GameplayView")
	var bounds := Rect2(Vector2.ZERO, main.size)
	var scale_factor := minf(float(root.size.x) / main.size.x, float(root.size.y) / main.size.y)
	if main.get_node("CafeSession").view == CafeSession.View.CAFE:
		for name in ["Customer", "CoffeeEquipment"]:
			var button := view.get_node(name) as Button
			if button.visible:
				check(bounds.encloses(button.get_global_rect()), name + " inside viewport")
				check(button.size.x * scale_factor >= 44 and button.size.y * scale_factor >= 44, name + " touch target")
				check(not view.get_node("Status").get_global_rect().intersects(button.get_global_rect()), "Status does not cover " + name)
		check(view.get_node("Status").size.y * scale_factor <= maxf(90.0, 120.0 * scale_factor), "Status remains compact")
	else:
		var panel := view.get_node("OrderScreen") if main.get_node("CafeSession").view == CafeSession.View.ORDER else view.get_node("CoffeeStation")
		check(is_equal_approx(panel.size.x, main.size.x) and is_equal_approx(panel.size.y, main.size.y), "Dedicated interface covers full viewport")
		for name in ["Heading", "Patience", "Description", "Action", "Back", "Settings"]:
			var control := panel.get_node("Content/Layout/" + name) as Control
			check(bounds.encloses(control.get_global_rect()), name + " inside full-screen interface")
			check(control.get_theme_font_size("font_size") * scale_factor >= 16, name + " readable")
			if control is Button:
				check(control.size.x * scale_factor >= 44 and control.size.y * scale_factor >= 44, name + " touch target")

func run() -> void:
	root.content_scale_size = Vector2i(720, 1280)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	for dimensions in [Vector2i(720, 1280), Vector2i(320, 568)]:
		root.size = dimensions
		touch_mode = dimensions.x == 320
		var main := await make_cafe()
		var session := main.get_node("CafeSession") as CafeSession
		var view := main.get_node("GameplayView")
		layout_checks(main)
		check(session.coins == 120, "Starting coins")
		await click(view.get_node("CoffeeEquipment"))
		check(view.get_node("CoffeeStation/Content/Layout/Action").disabled, "Cannot brew before accepting")
		await click(view.get_node("CoffeeStation/Content/Layout/Back"))
		await click(view.get_node("Customer"))
		check(session.view == CafeSession.View.ORDER, "Customer click opens order")
		layout_checks(main)
		await click(view.get_node("OrderScreen/Content/Layout/Action"))
		check(session.state == CafeSession.State.ORDER_ACCEPTED, "Order accepted")
		session.accept_order()
		check(session.state == CafeSession.State.ORDER_ACCEPTED, "Duplicate acceptance ignored")
		await click(view.get_node("Customer"))
		check(view.get_node("OrderScreen/Content/Layout/Action").disabled, "Pending order cannot be served")
		await click(view.get_node("OrderScreen/Content/Layout/Back"))
		await click(view.get_node("CoffeeEquipment"))
		layout_checks(main)
		var before := session.patience.time_left
		await click(view.get_node("CoffeeStation/Content/Layout/Settings"))
		check(main.get_node("SettingsPanel").visible, "Station settings opens above station")
		await click(main.get_node("SettingsPanel/Center/Panel/Margins/Layout/Close"))
		check(root.gui_get_focus_owner() == view.get_node("CoffeeStation/Content/Layout/Settings"), "Station Settings restores focus")
		await click(view.get_node("CoffeeStation/Content/Layout/Action"))
		session.start_brewing() # duplicate tap must not restart the brew
		await create_timer(0.16).timeout
		await settle()
		check(session.patience.time_left < before, "Patience continues in station/settings")
		check(session.state == CafeSession.State.ORDER_ACCEPTED, "Brew alone does not create drink")
		await click(view.get_node("CoffeeStation/Content/Layout/Action"))
		session.finish_coffee()
		check(session.state == CafeSession.State.DRINK_READY and session.coins == 120, "Finished coffee returns without automatic service/reward")
		check(session.view == CafeSession.View.CAFE, "Finished coffee returns to café")
		await click(view.get_node("Customer"))
		await click(view.get_node("OrderScreen/Content/Layout/Action"))
		session.serve()
		check(session.coins == 130 and session.state == CafeSession.State.SERVED, "Exactly one +10 reward")
		check(not view.get_node("Customer").visible, "Served customer leaves")
		check(main.get_node("Content/Layout/TopHUD/StatsRow/Coins").text == "Coins\n130", "Runtime HUD updates")
		main.queue_free()
		await process_frame
		print("PASS %s-driven complete cycle at %s" % ["touch" if touch_mode else "mouse", dimensions])
	await keyboard_case()
	await touch_case()
	await deadline_case()
	await cancellation_case()
	for mode in ["cafe", "order", "station", "ready", "settings"]:
		await expiry_case(mode)
	if failures == 0:
		print("PASS: %d gameplay assertions; reward, cancellation, expiry, races, layouts and modal focus" % checks)
	quit(0 if failures == 0 else 1)

func cancellation_case() -> void:
	var main := await make_cafe()
	var session := main.get_node("CafeSession") as CafeSession
	session.open_order()
	session.accept_order()
	session.open_station()
	session.start_brewing()
	session.back_to_cafe()
	await create_timer(0.2).timeout
	check(session.state == CafeSession.State.ORDER_ACCEPTED and not session.brewing and session.brew_elapsed == 0.0, "Back cancels in-progress brew without drink")
	session.open_station()
	session.start_brewing()
	await create_timer(0.16).timeout
	session.back_to_cafe()
	check(session.state == CafeSession.State.ORDER_ACCEPTED and session.brew_elapsed == 0.0, "Back after brewing also creates no drink")
	main.queue_free()
	await process_frame

func expiry_case(mode: String) -> void:
	departures = 0
	services = 0
	var main := await make_cafe(0.6, 0.1)
	var session := main.get_node("CafeSession") as CafeSession
	session.customer_departed.connect(func(): departures += 1)
	session.customer_served.connect(func(): services += 1)
	var before := session.patience.time_left
	if mode != "cafe":
		session.open_order()
	if mode in ["station", "ready", "settings"]:
		session.accept_order()
		session.open_station()
		session.start_brewing()
	if mode == "ready":
		await create_timer(0.16).timeout
		session.finish_coffee()
	if mode == "settings":
		main.get_node("SettingsPanel").open()
	await create_timer(0.7).timeout
	await settle()
	check(before > 0 and session.state == CafeSession.State.DEPARTED, "Patience expires in " + mode)
	check(session.coins == 120 and departures == 1 and services == 0, "Expiry gives no reward and one event: " + mode)
	check(not session.brewing and not main.get_node("GameplayView/Customer").visible, "Expiry cancels brewing/removes guest")
	session._depart()
	session.finish_coffee()
	session.serve()
	check(session.coins == 120 and departures == 1, "Late finish/serve/depart cannot reward twice")
	if main.get_node("SettingsPanel").visible:
		main.get_node("SettingsPanel").close()
	session.back_to_cafe()
	check("left" in session.feedback and session.view == CafeSession.View.CAFE, "Clear departure feedback on return")
	main.queue_free()
	await process_frame
	print("PASS expiry: ", mode)

func touch_case() -> void:
	root.size = Vector2i(320, 568)
	var main := await make_cafe()
	var view := main.get_node("GameplayView")
	var button := view.get_node("Customer") as Button
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.pressed = pressed
		event.position = root.get_final_transform() * button.get_global_rect().get_center()
		Input.parse_input_event(event)
	await settle()
	check(main.get_node("CafeSession").view == CafeSession.View.ORDER, "Screen touch opens customer interface")
	main.queue_free()
	await process_frame

func deadline_case() -> void:
	var main := await make_cafe()
	var session := main.get_node("CafeSession") as CafeSession
	session.open_order()
	session.accept_order()
	session.open_station()
	session.start_brewing()
	await create_timer(0.16).timeout
	session.finish_coffee()
	session.open_order()
	# Simulate the zero-time window before the Timer timeout callback is dispatched.
	session.patience.stop()
	session.serve()
	check(session.state == CafeSession.State.DEPARTED and session.coins == 120, "A zero-time serve cannot beat expiry dispatch")
	main.queue_free()
	await process_frame

func key_press(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
	await settle()

func keyboard_case() -> void:
	var main := await make_cafe()
	var session := main.get_node("CafeSession") as CafeSession
	var view := main.get_node("GameplayView")
	session.open_order()
	await settle()
	await key_press(KEY_ENTER)
	check(session.state == CafeSession.State.ORDER_ACCEPTED, "Enter accepts focused order")
	check(root.gui_get_focus_owner() == view.get_node("CoffeeEquipment"), "Coffee equipment receives focus after accepting")
	await key_press(KEY_ENTER)
	check(session.view == CafeSession.View.STATION, "Enter opens focused equipment")
	view.get_node("CoffeeStation/Content/Layout/Settings").grab_focus()
	await key_press(KEY_ENTER)
	check(main.get_node("SettingsPanel").visible, "Keyboard opens station Settings")
	await key_press(KEY_ESCAPE)
	check(not main.get_node("SettingsPanel").visible and session.view == CafeSession.View.STATION, "Escape closes Settings without closing underlying station")
	check(root.gui_get_focus_owner() == view.get_node("CoffeeStation/Content/Layout/Settings"), "Keyboard Settings restores station focus")
	await key_press(KEY_ESCAPE)
	check(session.view == CafeSession.View.CAFE, "Escape returns from station")
	main.queue_free()
	await process_frame
