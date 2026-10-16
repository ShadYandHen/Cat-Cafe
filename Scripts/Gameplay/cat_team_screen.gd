extends Control
## Presentation only: session guards every assignment, including stale button input.
var session: CafeSession
var cafe_screen: Control
var selected_slot: int = 0
var slot_buttons: Array[Button] = []
var cards: Dictionary = {}
var _metrics: Array = []

func setup(model: CafeSession, owner_screen: Control) -> void:
	session = model
	cafe_screen = owner_screen
	for i in range(3):
		var button := Button.new()
		button.name = "Slot%d" % i
		button.pressed.connect(_select_slot.bind(i))
		$Content/Layout/Scroll/Body/Slots.add_child(button)
		slot_buttons.append(button)
	for cat in session.team.roster:
		var card := VBoxContainer.new()
		card.name = cat.id
		$Content/Layout/Scroll/Body/Roster.add_child(card)
		var row := HBoxContainer.new()
		row.name = "Row"
		card.add_child(row)
		var portrait := TextureRect.new()
		portrait.name = "Portrait"
		portrait.texture = load(cat.artwork)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(portrait)
		var description := Label.new()
		description.name = "Description"
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(description)
		var assign := Button.new()
		assign.name = "Assign"
		assign.pressed.connect(_assign.bind(cat.id))
		card.add_child(assign)
		cards[cat.id] = card
	$Content/Layout/Back.pressed.connect(session.back_to_cafe)
	$Content/Layout/Settings.pressed.connect(cafe_screen.get_node("SettingsPanel").open)
	session.changed.connect(refresh)
	session.clock_changed.connect(_status)
	refresh()

func _select_slot(slot: int) -> void:
	selected_slot = slot
	refresh()

func _assign(id: String) -> void:
	session.assign_cat(selected_slot, id)

func slot_name(slot: int) -> String:
	return ["Active", "Support 1", "Support 2"][slot]

func refresh() -> void:
	if session == null:
		return
	var editable := session.can_edit_team()
	for i in range(3):
		slot_buttons[i].text = "%s: %s" % [slot_name(i), session.team.find(session.team.slots[i]).name]
		slot_buttons[i].theme_type_variation = &"MintButton" if i == selected_slot else &"Button"
	var bonuses := session.cat_bonuses()
	$Content/Layout/Scroll/Body/Summary.text = "Team passives\nPatience +%d%% · Tips +%d%%\nQuality +%d · Speed +%d%%\nOnly %s uses an active ability." % [roundi(bonuses.patience * 100), roundi(bonuses.tip * 100), roundi(bonuses.quality), roundi(bonuses.speed * 100), session.team.active_cat().name]
	for cat in session.team.roster:
		var card: VBoxContainer = cards[cat.id]
		var equipped := session.team.slots.find(cat.id)
		var role := slot_name(equipped) if equipped >= 0 else "Available"
		card.get_node("Row/Description").text = "%s · %s\nPassive: %s\nActive: %s (%ds cooldown)" % [cat.name, role, cat.passive.description, cat.active.description, int(cat.cooldown)]
		var button := card.get_node("Assign") as Button
		button.text = "Use as " + slot_name(selected_slot)
		button.disabled = not editable or session.team.slots[selected_slot] == cat.id
	$Content/Layout/Back.text = "Back to opening" if session.phase == CafeSession.Phase.PRE_DAY else "Back to results" if editable else "Back to café"
	_status()

func _status() -> void:
	if session == null:
		return
	$Content/Layout/Status.text = "Choose a slot, then a cat. Equipped cats swap slots." if session.can_edit_team() else "View only during shift.\nEdit before opening or after results · " + session.ability_status()
	if not session.profile.last_error.is_empty():
		$Content/Layout/Status.text = "Save failed. Team unchanged; try again."

func _process(_delta: float) -> void:
	if cafe_screen == null:
		return
	var bounds: Control = cafe_screen.get_node("Content")
	$Content.position = bounds.position
	$Content.size = bounds.size
	var factor: float = cafe_screen.ui_scale
	var metrics: Array = [factor, bounds.size]
	if metrics == _metrics:
		return
	_metrics = metrics
	var font_size := ceili(maxf(28, 16.0 / factor))
	for side in ["left", "right", "top", "bottom"]:
		$Content.add_theme_constant_override("margin_" + side, ceili(12 / factor))
	$Content/Layout.add_theme_constant_override("separation", ceili(8 / factor))
	$Content/Layout/Heading.add_theme_font_size_override("font_size", ceili(maxf(36, 22.0 / factor)))
	$Content/Layout/Status.add_theme_font_size_override("font_size", font_size)
	$Content/Layout/Scroll/Body/Summary.add_theme_font_size_override("font_size", font_size)
	$Content/Layout/Scroll/Body.add_theme_constant_override("separation", ceili(12 / factor))
	var buttons: Array[Button] = slot_buttons.duplicate()
	buttons.append($Content/Layout/Settings)
	buttons.append($Content/Layout/Back)
	for card: VBoxContainer in cards.values():
		card.add_theme_constant_override("separation", ceili(8 / factor))
		card.get_node("Row/Portrait").custom_minimum_size = Vector2(64, 96) / factor
		card.get_node("Row/Description").add_theme_font_size_override("font_size", font_size)
		buttons.append(card.get_node("Assign"))
	for button in buttons:
		button.custom_minimum_size.y = ceili(48 / factor)
		button.add_theme_font_size_override("font_size", font_size)
