extends SceneTree
## Run with: godot --headless --path . --script res://Tools/validate_foundation.gd
var failures: int = 0

func _initialize() -> void:
	call_deferred("validate")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func validate() -> void:
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	check(scene != null, "Main scene must load")
	if scene == null:
		quit(1)
		return
	check(get_tree_root_scene_path() == "res://Scenes/Title.tscn", "Title is the configured launch scene")
	change_scene_to_packed(scene)
	await scene_changed
	var title := current_scene as Control
	for physical_size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(1024, 768)]:
		var scale_factor := minf(physical_size.x / 720.0, physical_size.y / 1280.0)
		root.size = Vector2i(Vector2(physical_size) / scale_factor)
		for frame in range(3):
			await process_frame
		var bounds := Rect2(Vector2.ZERO, Vector2(root.size))
		for name in ["Name", "Tagline", "MochiPlaceholder", "MochiName", "Play", "Settings"]:
			var control := title.get_node("Content/Layout/" + name) as Control
			check(bounds.encloses(control.get_global_rect()), "Title %s fits at %s" % [name, physical_size])
			if control is Button:
				check(control.size.x * scale_factor >= 44 and control.size.y * scale_factor >= 44, "Title %s touch target at %s" % [name, physical_size])
		await check_settings(title, title.get_node("Content/Layout/Settings"), bounds, scale_factor)
		print("Checked title layout and settings: ", physical_size)
	title.get_node("Content/Layout/Play").pressed.emit()
	await scene_changed
	var main := current_scene as Control
	check(main.scene_file_path == "res://Scenes/Main.tscn", "Play opens café scene")
	for physical_size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(1024, 768)]:
		# Match canvas_items + expand: the base viewport fits inside the window.
		var scale_factor := minf(physical_size.x / 720.0, physical_size.y / 1280.0)
		var logical_size := Vector2(physical_size) / scale_factor
		root.size = Vector2i(logical_size)
		await process_frame
		await process_frame
		await process_frame
		var bounds := Rect2(Vector2.ZERO, Vector2(root.size))
		var cafe := main.get_node("Content/Layout/Cafe") as Control
		check(cafe.size.x > 0 and cafe.size.y >= 740, "Café has sufficient portrait space at %s" % physical_size)
		check(bounds.encloses(cafe.get_global_rect()), "Café stays inside viewport at %s" % physical_size)
		var stage := cafe.get_node("Stage") as Node2D
		check(is_equal_approx(stage.scale.x, stage.scale.y), "Actor stage uses uniform scaling")
		for marker_name in ["PrepStation", "CustomerSeatLeft", "CustomerSeatRight", "CatRest"]:
			check(cafe.get_global_rect().has_point(stage.get_node(marker_name).global_position), "Placement marker remains inside café")
		var navigation := main.get_node("Content/Layout/BottomNavigation")
		check(navigation.get_child_count() == 5, "Five navigation buttons present")
		for button in navigation.get_children():
			check(bounds.encloses(button.get_global_rect()), "%s stays accessible at %s" % [button.name, physical_size])
			check(button.size.x * scale_factor >= 44 and button.size.y * scale_factor >= 44, "%s has a 44px touch target at %s" % [button.name, physical_size])
			check(button.get_rect().size.x >= button.get_node("Caption").get_minimum_size().x, "%s caption fits" % button.name)
		var settings := main.get_node("Content/Layout/TopHUD/TitleRow/Settings") as Button
		check(settings.size.x * scale_factor >= 44 and settings.size.y * scale_factor >= 44, "Settings has a 44px touch target at %s" % physical_size)
		check(bounds.encloses(settings.get_global_rect()), "Settings stays accessible at %s" % physical_size)
		await check_settings(main, settings, bounds, scale_factor)
		print("Checked café layout and settings: ", physical_size)
	main.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: title launch, Play transition, settings open/close, scene resources and layouts at five screen sizes")
	quit(0 if failures == 0 else 1)

func get_tree_root_scene_path() -> String:
	return ProjectSettings.get_setting("application/run/main_scene")

func check_settings(screen: Control, button: Button, bounds: Rect2, scale_factor: float) -> void:
	button.grab_focus()
	button.pressed.emit()
	await process_frame
	await process_frame
	var panel := screen.get_node("SettingsPanel") as Control
	check(panel.visible, "Settings button opens panel")
	var card := panel.get_node("Center/Panel") as Control
	check(bounds.encloses(card.get_global_rect()), "Settings panel fits viewport")
	var close_button := panel.get_node("Center/Panel/Margins/Layout/Close") as Button
	check(close_button.size.y * scale_factor >= 44, "Settings Back touch target")
	close_button.pressed.emit()
	check(not panel.visible, "Back closes settings")
	check(root.gui_get_focus_owner() == button, "Settings restores keyboard focus")
