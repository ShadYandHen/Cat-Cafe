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
