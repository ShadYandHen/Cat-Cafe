extends SceneTree
## Native mouse/touch integration plus layout, modal, clock and multi-order checks.
const MAIN := preload("res://Scenes/Main.tscn")
var failures: int = 0
var checks: int = 0
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

func make_cafe() -> Control:
	var main := MAIN.instantiate() as Control
	main.get_node("CafeSession").profile = CafeProfile.new()
	main.get_node("CafeSession").start_immediately = true
	main.get_node("CafeSession").normal_arrival_interval = Vector2(30, 30)
	main.get_node("CafeSession").cat_effects_enabled = false
	main.get_node("CafeSession").recipe_override = "basic_coffee"
	root.add_child(main)
	main.get_node("CafeSession").set_process(false)
	await settle()
	return main

func click(button: Button) -> void:
	check(button.is_visible_in_tree() and not button.disabled, "Input target visible/enabled: " + button.name)
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
	var session := main.get_node("CafeSession") as CafeSession
	var bounds := Rect2(Vector2.ZERO, main.size)
	var scale_factor := minf(float(root.size.x) / main.size.x, float(root.size.y) / main.size.y)
	var controls: Array[Control] = []
	if session.view == CafeSession.View.CAFE:
		for name in ["Customer", "CustomerRight", "CoffeeEquipment"]:
			var button := view.get_node(name) as Button
			if button.visible:
				controls.append(button)
				check(not view.get_node("Status").get_global_rect().intersects(button.get_global_rect()), "Status does not cover " + name)
				for child in button.get_children():
					check(button.get_global_rect().encloses(child.get_global_rect()), "Actor child fits " + name)
		check(not view.get_node("Customer").get_global_rect().intersects(view.get_node("CustomerRight").get_global_rect()), "Seat interactions do not overlap")
	else:
		var panel := view.get_node("OrderScreen") if session.view == CafeSession.View.ORDER else view.get_node("CoffeeStation") if session.view == CafeSession.View.STATION else view.get_node("DayResults")
		check(panel.size.is_equal_approx(main.size), "Dedicated interface fills viewport")
		for name in (["Heading", "Patience", "Action", "Back", "Settings"] if session.view == CafeSession.View.STATION else ["Heading", "Patience", "Description", "Action", "Back", "Settings"]):
			var control := panel.get_node("Content/Layout/" + name) as Control
			if control.is_visible_in_tree():
				controls.append(control)
		if session.view == CafeSession.View.STATION:
			for button in panel.get_node("Content/Layout/OrderChoices").get_children():
				if button.is_visible_in_tree():
					controls.append(button)
	for control in controls:
		check(bounds.encloses(control.get_global_rect()), control.name + " within viewport " + str(control.get_global_rect()) + " in " + str(bounds))
		if control is Button:
			check(control.size.x * scale_factor >= 44 and control.size.y * scale_factor >= 44, control.name + " 44px target")
		else:
			check(control.get_theme_font_size("font_size") * scale_factor >= 16, control.name + " readable")
	for i in range(controls.size()):
		for j in range(i):
			check(not controls[i].get_global_rect().intersects(controls[j].get_global_rect()), "Essential controls do not overlap: %s/%s" % [controls[i].name, controls[j].name])

func run() -> void:
	root.content_scale_size = Vector2i(720, 1280)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	for dimensions in [Vector2i(720, 1280), Vector2i(320, 568)]:
		root.size = dimensions
		touch_mode = dimensions.x == 320
		await complete_shift_ui()
		print("PASS %s multi-order shift UI: %s" % ["touch" if touch_mode else "mouse", dimensions])
	await expiry_and_live_clock()
	await keyboard_case()
	if failures == 0:
		print("PASS: %d gameplay UI assertions" % checks)
	quit(0 if failures == 0 else 1)

func complete_shift_ui() -> void:
	var main := await make_cafe()
	var s := main.get_node("CafeSession") as CafeSession
	s.cat_effects_enabled = false
	var view := main.get_node("GameplayView")
	s.advance_time(30)
	await settle()
	layout_checks(main)
	for actor in ["Customer", "CustomerRight"]:
		await click(view.get_node(actor))
		layout_checks(main)
		await click(view.get_node("OrderScreen/Content/Layout/Action"))
	check(s.get_order(1).state == CafeSession.State.ORDER_ACCEPTED and s.get_order(2).state == CafeSession.State.ORDER_ACCEPTED, "Both orders accepted independently")
	await settle()
	layout_checks(main)
	await click(view.get_node("CoffeeEquipment"))
	layout_checks(main)
	check(view.get_node("CoffeeStation/Content/Layout/OrderChoices").visible, "Multiple accepted orders expose selector")
	await click(view.get_node("CoffeeStation/Content/Layout/OrderChoices/Choice1"))
	check(s.selected_order_id == 1, "Order selector targets first customer")
	await click(view.get_node("CoffeeStation/Content/Layout/Action"))
	s.advance_time(1)
	var before := s.get_order(1).remaining(s.elapsed)
	await click(view.get_node("CoffeeStation/Content/Layout/Settings"))
	s.advance_time(1)
	check(s.get_order(1).remaining(s.elapsed) < before, "Patience continues in station Settings")
	await click(main.get_node("SettingsPanel/Center/Panel/Margins/Layout/Close"))
	check(root.gui_get_focus_owner() == view.get_node("CoffeeStation/Content/Layout/Settings"), "Station Settings focus restored")
	await click(view.get_node("CoffeeStation/Content/Layout/OrderChoices/Choice2"))
	check(s.brew_order_id == -1 and s.selected_order_id == 2, "Switching selection safely cancels partial brew")
	await click(view.get_node("CoffeeStation/Content/Layout/OrderChoices/Choice1"))
	await click(view.get_node("CoffeeStation/Content/Layout/Action"))
	s.advance_time(3)
	await settle()
	await click(view.get_node("CoffeeStation/Content/Layout/Action"))
	await click(view.get_node("CoffeeStation/Content/Layout/Action"))
	check(s.get_order(1).state == CafeSession.State.DRINK_READY and s.coins == 120, "Drink ready but not automatically served")
	await click(view.get_node("CustomerRight"))
	check(view.get_node("OrderScreen/Content/Layout/Action").disabled, "Other guest cannot receive mismatched drink")
	await click(view.get_node("OrderScreen/Content/Layout/Back"))
	await click(view.get_node("Customer"))
	await click(view.get_node("OrderScreen/Content/Layout/Action"))
	s.serve()
	check(s.coins == 130 and s.served == 1, "First service pays exactly once")
	await click(view.get_node("CoffeeEquipment"))
	await click(view.get_node("CoffeeStation/Content/Layout/Action"))
	s.advance_time(3)
	await settle()
	await click(view.get_node("CoffeeStation/Content/Layout/Action"))
	await click(view.get_node("CoffeeStation/Content/Layout/Action"))
	await click(view.get_node("CustomerRight"))
	await click(view.get_node("OrderScreen/Content/Layout/Action"))
	check(s.coins == 140 and s.served == 2, "Second independent reward")
	s.advance_time(300 - s.elapsed)
	check(s.phase == CafeSession.Phase.SOFT_CLOSING, "Soft closing keeps remaining guests")
	for order in s.active_orders():
		s.open_order(order.order_id)
		s.accept_order()
		s.open_station()
		s.select_station_order(order.order_id)
		s.start_brewing()
		s.advance_time(3)
		s.stop_preparation()
		s.finish_coffee()
		s.open_order(order.order_id)
		s.serve()
	await settle()
	check(s.view == CafeSession.View.RESULTS and view.get_node("DayResults").visible, "Results shown after final guest")
	layout_checks(main)
	var balance := s.coins
	await click(view.get_node("DayResults/Content/Layout/Settings"))
	await click(main.get_node("SettingsPanel/Center/Panel/Margins/Layout/Close"))
	await click(view.get_node("DayResults/Content/Layout/Action"))
	s.start_next_day()
	check(s.day == 2 and s.coins == balance and s.served == 0 and s.earned == 0, "Next day preserves coins and resets counters once")
	check(main.get_node("Content/Layout/TopHUD/StatsRow/Day").text == "Day\n2", "Runtime day HUD updates")
	layout_checks(main)
	main.queue_free()
	await process_frame

func expiry_and_live_clock() -> void:
	var main := await make_cafe()
	var s := main.get_node("CafeSession") as CafeSession
	s.cat_effects_enabled = false
	var view := main.get_node("GameplayView")
	s.advance_time(30)
	for id in [1, 2]:
		s.open_order(id)
		s.accept_order()
	s.open_station()
	s.select_station_order(1)
	s.start_brewing()
	s.advance_time(30)
	await settle()
	check(s.get_order(1).state == CafeSession.State.DEPARTED and s.get_order(2).state == CafeSession.State.ORDER_ACCEPTED, "Selected guest expires independently")
	check(view.get_node("CoffeeStation/Content/Layout/OrderChoices").visible, "Remaining order selectable after expiry")
	check(view.get_node("CoffeeStation/Content/Layout/Action").disabled, "Expired selected order cannot finish")
	await click(view.get_node("CoffeeStation/Content/Layout/OrderChoices/Choice1"))
	check(s.selected_order_id == 2, "Can recover station with surviving order")
	layout_checks(main)
	s.set_process(true)
	var before := s.elapsed
	await create_timer(0.06).timeout
	check(s.elapsed > before, "Real runtime clock advances inside station")
	main.get_node("SettingsPanel").open()
	before = s.elapsed
	await create_timer(0.06).timeout
	check(s.elapsed > before, "Real runtime clock advances inside Settings")
	s.set_process(false)
	s.advance_time(400)
	check(s.view == CafeSession.View.RESULTS, "Expiry can finish shift while Settings stays open")
	main.get_node("SettingsPanel").close()
	await settle()
	var focus := root.gui_get_focus_owner()
	check(focus != null and focus.is_visible_in_tree(), "Results recover visible focus after Settings closes")
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
	var s := main.get_node("CafeSession") as CafeSession
	s.cat_effects_enabled = false
	s.open_order(1)
	await settle()
	await key_press(KEY_ENTER)
	check(s.get_order(1).state == CafeSession.State.ORDER_ACCEPTED, "Keyboard accepts order")
	main.get_node("GameplayView/CoffeeEquipment").grab_focus()
	await key_press(KEY_ENTER)
	check(s.view == CafeSession.View.STATION, "Keyboard opens station")
	main.get_node("GameplayView/CoffeeStation/Content/Layout/Settings").grab_focus()
	await key_press(KEY_ENTER)
	await key_press(KEY_ESCAPE)
	check(not main.get_node("SettingsPanel").visible and s.view == CafeSession.View.STATION, "Escape closes Settings first")
	await key_press(KEY_ESCAPE)
	check(s.view == CafeSession.View.CAFE, "Escape returns from station")
	main.queue_free()
	await process_frame
