extends Control
## Presentation and input binding only. All order/timing/reward rules live in CafeSession.
var session: CafeSession
var screen: Control
var previous_focus: Control
var _shown_view: int = -1
var _layout_signature: Array = []

func setup(cafe_screen: Control, cafe_session: CafeSession) -> void:
	screen = cafe_screen
	session = cafe_session
	$Customer.pressed.connect(session.open_order)
	$CoffeeEquipment.pressed.connect(session.open_station)
	$OrderScreen/Content/Layout/Action.pressed.connect(_order_action)
	$CoffeeStation/Content/Layout/Action.pressed.connect(_station_action)
	for panel in [$OrderScreen, $CoffeeStation]:
		panel.get_node("Content/Layout/Back").pressed.connect(session.back_to_cafe)
		panel.get_node("Content/Layout/Settings").pressed.connect(screen.get_node("SettingsPanel").open)
	session.changed.connect(_refresh)
	session.patience_changed.connect(_patience_changed)
	_refresh()

func _process(_delta: float) -> void:
	if session == null:
		return
	_layout()
	# Autowrapped Labels grow to an early minimum before their final width settles.
	$Status.size.y = $Status.get_minimum_size().y
	$CoffeeStation/Content/Layout/Progress.value = session.brew_elapsed / session.brew_seconds

func _unhandled_key_input(event: InputEvent) -> void:
	if session != null and session.view != CafeSession.View.CAFE and event.is_action_pressed("ui_cancel"):
		session.back_to_cafe()
		get_viewport().set_input_as_handled()

func _order_action() -> void:
	if session.state == CafeSession.State.WAITING_ORDER:
		session.accept_order()
	elif session.state == CafeSession.State.DRINK_READY:
		session.serve()

func _station_action() -> void:
	if session.brew_elapsed >= session.brew_seconds:
		session.finish_coffee()
	else:
		session.start_brewing()

func _refresh() -> void:
	screen.get_node("Content/Layout/TopHUD/StatsRow/Coins").text = "Coins\n%d" % session.coins
	var order := $OrderScreen/Content/Layout
	var station := $CoffeeStation/Content/Layout
	order.get_node("Progress").hide()
	var order_action := order.get_node("Action") as Button
	var station_action := station.get_node("Action") as Button
	order_action.disabled = true
	station_action.disabled = true
	station.get_node("Progress").visible = session.state == CafeSession.State.ORDER_ACCEPTED
	match session.state:
		CafeSession.State.WAITING_ORDER:
			order.get_node("Description").text = "Basic Coffee\nAccept this guest's order."
			order_action.text = "Accept Order"
			order_action.disabled = false
			station.get_node("Description").text = "No accepted order.\nTake the guest's order before brewing."
			station_action.text = "Take an order first"
		CafeSession.State.ORDER_ACCEPTED:
			order.get_node("Description").text = "Basic Coffee pending.\nReturn to the café and tap the coffee machine."
			order_action.text = "Waiting for coffee"
			if session.brewing:
				station.get_node("Description").text = "Brewing Basic Coffee…\nThe guest's patience keeps running."
				station_action.text = "Brewing…"
			elif session.brew_elapsed >= session.brew_seconds:
				station.get_node("Description").text = "Brewing complete!\nFinish the coffee to take it back to the café."
				station_action.text = "Finish coffee"
				station_action.disabled = false
			else:
				station.get_node("Description").text = "Basic Coffee\nStart brewing, then finish the coffee when the bar fills."
				station_action.text = "Start brewing"
				station_action.disabled = false
		CafeSession.State.DRINK_READY:
			order.get_node("Description").text = "Basic Coffee is ready.\nServe this guest manually to earn +%d Coins." % session.coffee_reward
			order_action.text = "Serve Basic Coffee"
			order_action.disabled = false
			station.get_node("Description").text = "You already have a Basic Coffee.\nReturn and tap the guest to serve it."
			station_action.text = "Drink already ready"
		_:
			var message := session.feedback + "\nRestart the game to begin a new test cycle."
			order.get_node("Description").text = message
			station.get_node("Description").text = message
			order_action.text = "Cycle complete"
			station_action.text = "Cycle complete"
	$Customer.visible = session.active() and session.view == CafeSession.View.CAFE
	$CoffeeEquipment.visible = session.view == CafeSession.View.CAFE
	$Status.visible = session.view == CafeSession.View.CAFE
	if _shown_view != session.view:
		if session.view != CafeSession.View.CAFE:
			previous_focus = get_viewport().gui_get_focus_owner()
		_shown_view = session.view
		screen.get_node("Content").visible = session.view == CafeSession.View.CAFE
		$OrderScreen.visible = session.view == CafeSession.View.ORDER
		$CoffeeStation.visible = session.view == CafeSession.View.STATION
		if session.view == CafeSession.View.CAFE:
			if session.state in [CafeSession.State.WAITING_ORDER, CafeSession.State.DRINK_READY]:
				$Customer.grab_focus()
			elif is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree() and previous_focus != $Customer:
				previous_focus.grab_focus()
			else:
				$CoffeeEquipment.grab_focus()
		else:
			var panel := $OrderScreen if session.view == CafeSession.View.ORDER else $CoffeeStation
			var action := panel.get_node("Content/Layout/Action") as Button
			if not action.disabled:
				action.grab_focus()
			else:
				panel.get_node("Content/Layout/Back").grab_focus()
	_patience_changed(session.patience.time_left)

func _patience_changed(seconds: float) -> void:
	var patience_text := "Patience: %ds" % ceili(seconds) if session.active() else "Guest served" if session.state == CafeSession.State.SERVED else "Guest departed"
	for panel in [$OrderScreen, $CoffeeStation]:
		panel.get_node("Content/Layout/Patience").text = patience_text
	$Status.text = session.feedback + ("\n" + patience_text if session.active() else "")

func _layout() -> void:
	var cafe := screen.get_node("Content/Layout/Cafe") as Control
	var stage := cafe.get_node("Stage") as Node2D
	var scale_factor: float = screen.ui_scale
	var content: Control = screen.get_node("Content")
	var signature: Array = [screen.size, scale_factor, content.position, content.size, cafe.get_global_rect(), stage.global_transform]
	if signature == _layout_signature:
		return
	_layout_signature = signature
	var font_size := ceili(maxf(28, 16.0 / scale_factor))
	$Customer.custom_minimum_size = Vector2(maxf(176, 88.0 / scale_factor), maxf(144, 72.0 / scale_factor))
	$Customer.size = $Customer.custom_minimum_size
	$Customer.add_theme_font_size_override("font_size", ceili(maxf(28, 14.0 / scale_factor)))
	$Customer.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var bunny := $Customer/Bunny as Control
	bunny.position = Vector2(maxf(8, 4.0 / scale_factor), maxf(8, 4.0 / scale_factor))
	bunny.size = Vector2(maxf(72, 36.0 / scale_factor), maxf(120, 60.0 / scale_factor))
	$Customer.position = stage.get_node("CustomerSeatLeft").global_position - global_position - Vector2($Customer.size.x / 2.0, $Customer.size.y)
	$CoffeeEquipment.custom_minimum_size = Vector2(maxf(160, 80.0 / scale_factor), maxf(96, 48.0 / scale_factor))
	$CoffeeEquipment.size = $CoffeeEquipment.custom_minimum_size
	$CoffeeEquipment.add_theme_font_size_override("font_size", ceili(maxf(28, 14.0 / scale_factor)))
	$CoffeeEquipment.position = stage.to_global(Vector2(132, 352)) - global_position - $CoffeeEquipment.size / 2.0
	$Status.position = cafe.global_position - global_position + Vector2(8, 0) / scale_factor
	$Status.size = Vector2(cafe.size.x - 16.0 / scale_factor, 0)
	$Status.add_theme_font_size_override("font_size", ceili(maxf(28, 16.0 / scale_factor)))
	for panel in [$OrderScreen, $CoffeeStation]:
		var column := panel.get_node("Content") as MarginContainer
		column.position = content.position
		column.size = content.size
		for side in ["left", "right", "top", "bottom"]:
			column.add_theme_constant_override("margin_" + side, ceili(16.0 / scale_factor))
		var layout := column.get_node("Layout") as VBoxContainer
		layout.add_theme_constant_override("separation", ceili(12.0 / scale_factor))
		for name in ["Heading", "Patience", "Description"]:
			layout.get_node(name).add_theme_font_size_override("font_size", font_size)
		layout.get_node("Heading").add_theme_font_size_override("font_size", ceili(maxf(36, 22.0 / scale_factor)))
		for name in ["Action", "Back", "Settings"]:
			var button := layout.get_node(name) as Button
			button.custom_minimum_size.y = ceili(48.0 / scale_factor)
			button.add_theme_font_size_override("font_size", font_size)
