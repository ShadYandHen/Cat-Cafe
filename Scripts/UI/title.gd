extends "res://Scripts/UI/portrait_layout.gd"

var _starting := false

func _ready() -> void:
	super._ready()
	$Content/Layout/Play.pressed.connect(_play)
	$Content/Layout/Settings.pressed.connect($SettingsPanel.open)
	$Content/Layout/Play.grab_focus()

func _play() -> void:
	if _starting:
		return
	_starting=true
	$Content/Layout/Play.disabled=true
	_open_cafe.call_deferred()

func _open_cafe() -> void:
	var error := get_tree().change_scene_to_file("res://Scenes/Main.tscn")
	if error != OK:
		_starting=false
		$Content/Layout/Play.disabled=false
		push_error("Unable to open café: %s" % error_string(error))
