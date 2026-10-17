extends Control
## Only presentation/input: orders, scheduling, deadlines and rewards live in CafeSession.
var session: CafeSession
var screen: Control
var previous_focus: Control
var _shown_view: int = -1
var _layout_signature: Array = []

func setup(cafe_screen: Control, cafe_session: CafeSession) -> void:
	screen = cafe_screen
	session = cafe_session
	$CatTeamScreen.setup(session, screen)
	$CafeShopScreen.setup(session, screen)
	$RewardsScreen.setup(session, screen)
	$SeasonScreen.setup(session, screen)
	screen.get_node("Content/Layout/BottomNavigation/Map").pressed.connect(session.open_rewards)
	screen.get_node("Content/Layout/BottomNavigation/Map").tooltip_text="Golden Paw Lottery & Collections"
	for panel in [$DayLobby,$DayResults]:
		panel.get_node("Content/Layout/Shop").text="Shop & Golden Paw"
	var display := DecorationDisplay.new()
	display.name="DecorationDisplay"
	screen.get_node("Content/Layout/Cafe/Stage").add_child(display)
	display.setup(session.profile)
	screen.get_node("Content/Layout/BottomNavigation/Upgrade").pressed.connect(session.open_shop.bind(false))
	screen.get_node("Content/Layout/BottomNavigation/Decorate").pressed.connect(session.open_shop.bind(true))
	screen.get_node("Content/Layout/BottomNavigation/Upgrade").tooltip_text="Café upgrades"
	screen.get_node("Content/Layout/BottomNavigation/Decorate").tooltip_text="Decoration inventory"
	$DayLobby/Content/Layout/Shop.pressed.connect(session.open_shop.bind(false))
	$DayResults/Content/Layout/Shop.pressed.connect(session.open_shop.bind(false))
	screen.get_node("Content/Layout/BottomNavigation/CatTeam").pressed.connect(session.open_team)
	screen.get_node("Content/Layout/BottomNavigation/CatTeam").tooltip_text = "View team; edit between days"
	$DayResults/Content/Layout/CatTeam.pressed.connect(session.open_team)
	$DayLobby/Content/Layout/CatTeam.pressed.connect(session.open_team)
	$DayLobby/Content/Layout/Action.pressed.connect(session.start_next_day)
	$Customer.pressed.connect(_open_seat.bind(0))
	$CustomerRight.pressed.connect(_open_seat.bind(1))
	$CoffeeEquipment.text = "Prepare"
	$CoffeeEquipment.pressed.connect(session.open_station)
	screen.get_node("Content/Layout/BottomNavigation/Prepare").pressed.connect(session.open_station)
	screen.get_node("Content/Layout/BottomNavigation/Prepare").tooltip_text = "Prepare a drink"
	var body := $CoffeeStation/Content/Layout/Workspace/Body
	for i in range(4):
		body.get_node("Stations").get_child(i).pressed.connect(session.select_station.bind(DrinkCatalog.CATEGORIES[i]))
	for i in range(DrinkCatalog.INGREDIENTS.size()):
		body.get_node("Ingredients").get_child(i).pressed.connect(session.toggle_ingredient.bind(DrinkCatalog.INGREDIENTS[i]))
	$OrderScreen/Content/Layout/Action.pressed.connect(_order_action)
	$CoffeeStation/Content/Layout/Action.pressed.connect(_station_action)
	$DayResults/Content/Layout/Action.pressed.connect(session.start_next_day)
	for panel in [$OrderScreen, $CoffeeStation, $DayResults, $DayLobby]:
		panel.get_node("Content/Layout/Back").pressed.connect(session.back_to_cafe)
		panel.get_node("Content/Layout/Settings").pressed.connect(screen.get_node("SettingsPanel").open)
	for button in $CoffeeStation/Content/Layout/OrderChoices.get_children():
		button.pressed.connect(_choose_order.bind(button))
	session.changed.connect(_refresh)
	session.clock_changed.connect(_clock_changed)
	_refresh()

func _open_seat(seat: int) -> void:
	session.open_order(session.order_at_seat(seat))

func _choose_order(button: Button) -> void:
	session.select_station_order(button.get_meta("order_id", -1))

func _process(_delta: float) -> void:
	if session == null:
		return
	_layout()
	$Status.size.y = $Status.get_minimum_size().y
	var selected := session.get_order(session.selected_order_id)
	var target: float = session.preparation_target()
	$CoffeeStation/Content/Layout/Workspace/Body/Progress.value = minf(1.0, session.brew_elapsed / (target * 2))
	if session.brewing:
		$CoffeeStation/Content/Layout/Action.text = "Stop %s · %.1f / %.1fs" % [selected.recipe.action, session.brew_elapsed, target]
	if not screen.get_node("SettingsPanel").visible:
		var focus := get_viewport().gui_get_focus_owner()
		if focus == null or not focus.is_visible_in_tree():
			_focus_default()

func _unhandled_key_input(event: InputEvent) -> void:
	if session != null and session.view in [CafeSession.View.ORDER, CafeSession.View.STATION, CafeSession.View.TEAM, CafeSession.View.UPGRADES, CafeSession.View.DECORATE, CafeSession.View.REWARDS, CafeSession.View.SEASON] and event.is_action_pressed("ui_cancel"):
		session.back_to_cafe()
		get_viewport().set_input_as_handled()

func _order_action() -> void:
	var order := session.get_order(session.selected_order_id)
	if order == null:
		return
	if order.state == CafeSession.State.WAITING_ORDER:
		session.accept_order()
	elif order.state == CafeSession.State.DRINK_READY:
		session.serve()

func _station_action() -> void:
	if session.brewing:
		session.stop_preparation()
	elif session.brew_ready:
		session.finish_coffee()
	else:
		session.start_brewing()

func _refresh() -> void:
	var order_panel := $OrderScreen/Content/Layout
	var station := $CoffeeStation/Content/Layout
	var selected := session.get_order(session.selected_order_id)
	var order_action := order_panel.get_node("Action") as Button
	var station_action := station.get_node("Action") as Button
	order_action.disabled = true
	station_action.disabled = true
	order_panel.get_node("Progress").hide()
	station.get_node("Workspace/Body/Progress").visible = selected != null and selected.state == CafeSession.State.ORDER_ACCEPTED
	var available := selected != null and selected.state not in [CafeSession.State.SERVED, CafeSession.State.DEPARTED]
	if not available:
		order_panel.get_node("Description").text = "This guest has left.\nTheir order cannot be served."
		order_action.text = "Guest departed"
		station.get_node("Workspace/Body/Description").text = "Select an accepted order." if session.selected_order_id < 0 else "This guest has left.\nSelect another order or return to the café."
		station_action.text = "No selected order"
	else:
		var title := "#%d · %s\nNeeds: %s" % [selected.order_id, selected.requested_drink, ", ".join(selected.recipe.ingredients)]
		match selected.state:
			CafeSession.State.WAITING_ORDER:
				order_panel.get_node("Description").text = title + "\nAccept this guest's order."
				order_action.text = "Accept Order"
				order_action.disabled = false
				station.get_node("Workspace/Body/Description").text = "Take the guest's order before preparation."
				station_action.text = "Accept an order first"
			CafeSession.State.ORDER_ACCEPTED:
				order_panel.get_node("Description").text = title + "\nPending. Tap Prepare."
				order_action.text = "Waiting for drink"
				if session.brewing:
					station.get_node("Workspace/Body/Description").text = title + "\n%s: stop at %.1fs. Patience runs." % [selected.recipe.action, session.preparation_target()]
					station_action.text = "Stop preparation"
					station_action.disabled = false
				elif session.brew_ready:
					station.get_node("Workspace/Body/Description").text = title + "\nProcess stopped. Assemble drink."
					station_action.text = "Assemble drink"
					station_action.disabled = false
				else:
					station.get_node("Workspace/Body/Description").text = title + "\nSelect ingredients; stop %s at %.1fs." % [selected.recipe.action, session.preparation_target()]
					station_action.text = "Start " + selected.recipe.action
					station_action.disabled = selected.recipe.station != session.station_category
			CafeSession.State.DRINK_READY:
				order_panel.get_node("Description").text = title + "\n%s · %d/100\n+%d Coins · +%d XP" % [selected.quality_tier, selected.quality_score, session.service_preview(selected).coins, selected.reward_xp]
				order_action.text = "Serve drink"
				order_action.disabled = false
				station.get_node("Workspace/Body/Description").text = title + "\nAlready ready. Tap this guest to serve."
				station_action.text = "Drink already ready"
	if session.view == CafeSession.View.ORDER and not session.profile.last_error.is_empty():
		order_panel.get_node("Description").text += "\nSave failed. Reward not applied; retry."
	station.get_node("Heading").text = session.station_category + " station"
	var can_prepare: bool = available and selected.state == CafeSession.State.ORDER_ACCEPTED and selected.recipe.station == session.station_category
	for i in range(4):
		var tab := station.get_node("Workspace/Body/Stations").get_child(i) as Button
		tab.theme_type_variation = &"MintButton" if DrinkCatalog.CATEGORIES[i] == session.station_category else &"Button"
	for i in range(DrinkCatalog.INGREDIENTS.size()):
		var ingredient: String = DrinkCatalog.INGREDIENTS[i]
		var button := station.get_node("Workspace/Body/Ingredients").get_child(i) as Button
		button.disabled = not can_prepare or session.brew_order_id >= 0
		button.theme_type_variation = &"MintButton" if ingredient in session.selected_ingredients else &"Button"
		button.text = ("✓ " if ingredient in session.selected_ingredients else "") + ingredient
	var choices := session.accepted_orders()
	station.get_node("OrderChoices").visible = choices.size() > 1 or (not available and not choices.is_empty())
	for i in range(2):
		var button := station.get_node("OrderChoices").get_child(i) as Button
		button.visible = i < choices.size()
		if button.visible:
			button.set_meta("order_id", choices[i].order_id)
			button.theme_type_variation = &"MintButton" if choices[i].order_id == session.selected_order_id else &"Button"
	var lobby := $DayLobby/Content/Layout
	lobby.get_node("Progress").hide()
	lobby.get_node("Back").hide()
	lobby.get_node("Heading").text = "Before opening"
	lobby.get_node("Patience").text = "Day %d" % (session.profile.completed_days + 1)
	var notice := "Choose your team before opening."
	if not session.profile.writable:
		notice = "Newer save version. Saving disabled; file preserved."
	elif not session.profile.last_error.is_empty():
		notice = "Save failed. Progress unchanged; retry."
	elif not session.profile.diagnostic.is_empty():
		notice = "Save notice: see startup log for details."
	lobby.get_node("Description").text = "Coins: %d\n%s\nCompleted days: %d\n%s" % [session.coins,session.profile.progress_text(),session.profile.completed_days,notice]
	lobby.get_node("Action").text = "Start Day %d" % (session.profile.completed_days + 1)
	lobby.get_node("Action").disabled = not session.profile.writable
	var results := $DayResults/Content/Layout
	results.get_node("Progress").hide()
	results.get_node("Back").hide()
	results.get_node("Patience").text = "Day %d complete" % session.day
	results.get_node("Description").text = "Served: %d · Lost: %d\nCoins: +%d · Total: %d\nReputation XP: +%d\nOkay %d · Good %d\nExcellent %d · Perfect %d" % [session.served, session.lost, session.earned, session.coins, session.reputation_earned, session.quality_counts[0], session.quality_counts[1], session.quality_counts[2], session.quality_counts[3]]
	if not session.completion_pending:
		results.get_node("Description").text += "\nCafé day: +%d Seasonal XP (up to cap)" % int(CafeProfile.season_catalog.data.day_xp)
	results.get_node("Description").text += "\n%s" % session.profile.progress_text()
	if session.profile.level > session.starting_level:
		results.get_node("Description").text += "\nGained %d café levels!" % (session.profile.level-session.starting_level)
	if session.completion_pending:
		results.get_node("Description").text += "\nDay save pending; retry to continue."
	elif not session.profile.last_error.is_empty():
		results.get_node("Description").text += "\nSave failed. Retry starting the day."
	results.get_node("Action").text = "Retry save & continue" if session.completion_pending else "Start Day %d" % (session.day + 1)
	for i in range(2):
		var actor := _actor(i)
		actor.visible = session.view == CafeSession.View.CAFE and session.order_at_seat(i) >= 0
		if actor.visible:
			var order := session.get_order(session.order_at_seat(i))
			actor.theme_type_variation = [&"PeachButton", &"GoldButton", &"MintButton"][order.state]
	$CoffeeEquipment.visible = session.view == CafeSession.View.CAFE
	$Status.visible = session.view == CafeSession.View.CAFE
	if _shown_view != session.view:
		if session.view != CafeSession.View.CAFE:
			previous_focus = get_viewport().gui_get_focus_owner()
		_shown_view = session.view
		screen.get_node("Content").visible = session.view == CafeSession.View.CAFE
		$OrderScreen.visible = session.view == CafeSession.View.ORDER
		$CoffeeStation.visible = session.view == CafeSession.View.STATION
		$DayResults.visible = session.view == CafeSession.View.RESULTS
		$CatTeamScreen.visible = session.view == CafeSession.View.TEAM
		$DayLobby.visible = session.view == CafeSession.View.LOBBY
		$SeasonScreen.visible = session.view == CafeSession.View.SEASON
		if $SeasonScreen.visible:
			$SeasonScreen.on_open()
		$RewardsScreen.visible = session.view == CafeSession.View.REWARDS
		if $RewardsScreen.visible:
			$RewardsScreen.on_open()
		$CafeShopScreen.visible = session.view in [CafeSession.View.UPGRADES,CafeSession.View.DECORATE]
		if $CafeShopScreen.visible:
			$CafeShopScreen.on_open()
		if not screen.get_node("SettingsPanel").visible:
			_focus_default()
	_clock_changed()

func _clock_changed() -> void:
	var hud := screen.get_node("Content/Layout/TopHUD/StatsRow")
	hud.get_node("Coins").text = "Coins\n%d" % session.coins
	hud.get_node("Day").text = "Day\n%d" % session.day
	hud.get_node("Level").text = "Level\n%d" % session.profile.level
	screen.get_node("Content/Layout/Welcome").text = session.profile.progress_text()
	$Status.add_theme_stylebox_override("normal", screen.theme.get_stylebox("normal", "GoldButton" if session.phase == CafeSession.Phase.RUSH else "CreamLabel"))
	var shift := "%s · %s" % [session.countdown(), session.phase_label()]
	$Status.text = "%s · %d/2 guests\n%s\n%s" % [shift, session.active_count(), session.ability_status(), session.feedback]
	var selected := session.get_order(session.selected_order_id)
	var detail := "No selected order"
	if selected != null:
		detail = "Order #%d · %ds patience" % [selected.order_id, ceili(selected.remaining(session.elapsed))] if selected.state not in [CafeSession.State.SERVED, CafeSession.State.DEPARTED] else "Order #%d · Guest left" % selected.order_id
	for panel in [$OrderScreen, $CoffeeStation]:
		panel.get_node("Content/Layout/Patience").text = shift + "\n" + detail + "\n" + session.ability_status()
	for i in range(2):
		var order := session.get_order(session.order_at_seat(i))
		if order != null:
			var state_label: String = ["Order", "Pending", "Ready"][order.state]
			_actor(i).text = "Guest #%d: %s" % [order.customer_id, state_label]
			_actor(i).get_node("Caption").text = "#%d\n%s\n%ds" % [order.order_id, state_label, ceili(order.remaining(session.elapsed))]
	for button in $CoffeeStation/Content/Layout/OrderChoices.get_children():
		var order := session.get_order(button.get_meta("order_id", -1))
		if order != null:
			button.text = "Order #%d\n%s" % [order.order_id, "Ready" if order.state == CafeSession.State.DRINK_READY else "%ds" % ceili(order.remaining(session.elapsed))]

func _actor(seat: int) -> Button:
	return $Customer if seat == 0 else $CustomerRight

func _focus_default() -> void:
	if session.view == CafeSession.View.SEASON:
		$SeasonScreen/Content/Layout/Back.grab_focus()
		return
	if session.view == CafeSession.View.REWARDS:
		$RewardsScreen/Content/Layout/Back.grab_focus()
		return
	if session.view in [CafeSession.View.UPGRADES,CafeSession.View.DECORATE]:
		$CafeShopScreen/Content/Layout/Back.grab_focus()
		return
	if session.view == CafeSession.View.TEAM:
		$CatTeamScreen/Content/Layout/Back.grab_focus()
		return
	if session.view == CafeSession.View.CAFE:
		if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
			previous_focus.grab_focus()
		else:
			for i in range(2):
				if _actor(i).visible:
					_actor(i).grab_focus()
					return
			$CoffeeEquipment.grab_focus()
	else:
		var panel := $OrderScreen if session.view == CafeSession.View.ORDER else $CoffeeStation if session.view == CafeSession.View.STATION else $DayResults if session.view == CafeSession.View.RESULTS else $DayLobby
		var action := panel.get_node("Content/Layout/Action") as Button
		if not action.disabled:
			action.grab_focus()
		else:
			panel.get_node("Content/Layout/Back").grab_focus()

func _layout() -> void:
	var progress_label := screen.get_node("Content/Layout/Welcome") as Label
	progress_label.visible = true
	progress_label.add_theme_font_size_override("font_size", ceili(maxf(28, 16.0 / screen.ui_scale)))
	var cafe := screen.get_node("Content/Layout/Cafe") as Control
	var stage := cafe.get_node("Stage") as Node2D
	var scale_factor: float = screen.ui_scale
	var content: Control = screen.get_node("Content")
	var signature: Array = [screen.size, scale_factor, content.position, content.size, cafe.get_global_rect(), stage.global_transform]
	# Autowrapped labels can temporarily grow a hidden container before its width
	# settles. Reapply the viewport bounds even when style metrics are unchanged.
	for panel in [$OrderScreen, $CoffeeStation, $DayResults, $DayLobby]:
		panel.get_node("Content").position = content.position
		panel.get_node("Content").size = content.size
	if signature == _layout_signature:
		return
	_layout_signature = signature
	var font_size := ceili(maxf(28, 16.0 / scale_factor))
	for i in range(2):
		var actor := _actor(i)
		actor.custom_minimum_size = Vector2(maxf(120, 60.0 / scale_factor), maxf(200, 96.0 / scale_factor))
		actor.size = actor.custom_minimum_size
		var face := actor.get_node("Bunny") as Control
		var face_size := maxf(44.0, 22.0 / scale_factor)
		face.position = Vector2((actor.size.x - face_size) / 2, 4.0 / scale_factor)
		face.size = Vector2.ONE * face_size
		var caption := actor.get_node("Caption") as Label
		caption.add_theme_font_size_override("font_size", ceili(maxf(24, 14.0 / scale_factor)))
		caption.position = Vector2(4.0 / scale_factor, face.position.y + face_size)
		caption.size = Vector2(actor.size.x - 8.0 / scale_factor, actor.size.y - caption.position.y - 4.0 / scale_factor)
		var marker := "CustomerSeatLeft" if i == 0 else "CustomerSeatRight"
		actor.position = stage.get_node(marker).global_position - global_position - Vector2(actor.size.x / 2, actor.size.y)
	$CoffeeEquipment.custom_minimum_size = Vector2(maxf(160, 80.0 / scale_factor), maxf(96, 48.0 / scale_factor))
	$CoffeeEquipment.size = $CoffeeEquipment.custom_minimum_size
	$CoffeeEquipment.add_theme_font_size_override("font_size", ceili(maxf(28, 14.0 / scale_factor)))
	$CoffeeEquipment.position = stage.to_global(Vector2(132, 352)) - global_position - $CoffeeEquipment.size / 2
	$Status.position = cafe.global_position - global_position + Vector2(8, 0) / scale_factor
	$Status.size = Vector2(cafe.size.x - 16.0 / scale_factor, 0)
	$Status.add_theme_font_size_override("font_size", ceili(maxf(28, 16.0 / scale_factor)))
	for panel in [$OrderScreen, $CoffeeStation, $DayResults, $DayLobby]:
		var column := panel.get_node("Content") as MarginContainer
		column.position = content.position
		column.size = content.size
		for side in ["left", "right", "top", "bottom"]:
			column.add_theme_constant_override("margin_" + side, ceili(12.0 / scale_factor))
		var layout := column.get_node("Layout") as VBoxContainer
		layout.add_theme_constant_override("separation", ceili(8.0 / scale_factor))
		for name in (["Heading", "Patience"] if panel == $CoffeeStation else ["Heading", "Patience", "Description"]):
			layout.get_node(name).add_theme_font_size_override("font_size", font_size)
		layout.get_node("Heading").add_theme_font_size_override("font_size", ceili(maxf(36, 22.0 / scale_factor)))
		for name in (["Action", "Back", "Settings", "CatTeam", "Shop"] if panel in [$DayResults, $DayLobby] else ["Action", "Back", "Settings"]):
			var button := layout.get_node(name) as Button
			button.custom_minimum_size.y = ceili(48.0 / scale_factor)
			button.add_theme_font_size_override("font_size", font_size)
		if panel == $CoffeeStation:
			var body := layout.get_node("Workspace/Body")
			body.get_node("Description").add_theme_font_size_override("font_size", font_size)
			for group in ["Stations", "Ingredients"]:
				for button in body.get_node(group).get_children():
					button.custom_minimum_size.y = ceili(44.0 / scale_factor)
					button.add_theme_font_size_override("font_size", ceili(14.0 / scale_factor))
			for button in layout.get_node("OrderChoices").get_children():
				button.custom_minimum_size.y = ceili(52.0 / scale_factor)
				button.add_theme_font_size_override("font_size", ceili(maxf(24, 14.0 / scale_factor)))
