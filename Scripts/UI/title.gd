extends "res://Scripts/UI/portrait_layout.gd"

func _ready() -> void:
	super._ready()
	$Content/Layout/Play.pressed.connect(_play)
	$Content/Layout/Settings.pressed.connect($SettingsPanel.open)
	$Content/Layout/Play.grab_focus()

func _play() -> void:
	var error := get_tree().change_scene_to_file("res://Scenes/Main.tscn")
	if error != OK:
		push_error("Unable to open café: %s" % error_string(error))
