extends "res://Scripts/UI/portrait_layout.gd"

func _ready() -> void:
	super._ready()
	$Content/Layout/TopHUD/TitleRow/Settings.pressed.connect($SettingsPanel.open)
