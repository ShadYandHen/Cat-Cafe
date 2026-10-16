extends Control
## Modal placeholder, shared by the title and café. No settings persistence yet.
var previous_focus: Control

func _ready() -> void:
	$Center/Panel/Margins/Layout/Close.pressed.connect(close)

func open() -> void:
	previous_focus = get_viewport().gui_get_focus_owner()
	show()
	$Center/Panel/Margins/Layout/Close.grab_focus()

func close() -> void:
	hide()
	if is_instance_valid(previous_focus):
		previous_focus.grab_focus()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		# The modal has one interactive control; keep keyboard focus inside it.
		$Center/Panel/Margins/Layout/Close.grab_focus()
		get_viewport().set_input_as_handled()

func configure(pixel_scale: float, column_width: float, usable_rect: Rect2) -> void:
	var center := $Center as CenterContainer
	center.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	center.position = usable_rect.position
	center.size = usable_rect.size
	var panel := $Center/Panel as PanelContainer
	panel.custom_minimum_size.x = minf(560.0, column_width - 32.0 / pixel_scale)
	var margins := $Center/Panel/Margins as MarginContainer
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, ceili(16.0 / pixel_scale))
	var layout := $Center/Panel/Margins/Layout as VBoxContainer
	layout.add_theme_constant_override("separation", ceili(16.0 / pixel_scale))
	layout.get_node("Heading").add_theme_font_size_override("font_size", maxi(36, ceili(20.0 / pixel_scale)))
	layout.get_node("Description").add_theme_font_size_override("font_size", maxi(28, ceili(16.0 / pixel_scale)))
	var back := layout.get_node("Close") as Button
	back.add_theme_font_size_override("font_size", maxi(28, ceili(16.0 / pixel_scale)))
	back.custom_minimum_size.y = maxf(96.0, ceili(48.0 / pixel_scale))
