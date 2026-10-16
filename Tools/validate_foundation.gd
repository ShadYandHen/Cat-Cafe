extends SceneTree
## Exercises real canvas stretch, UI bounds, text sizes, touch targets and interactions.
const VIEWPORTS := [Vector2i(320, 568), Vector2i(360, 640), Vector2i(375, 667), Vector2i(390, 844), Vector2i(430, 932), Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(1920, 1080)]
const NAV_NAMES := ["Upgrade", "Decorate", "Prepare", "Cat Team", "Map"]
var failures: int = 0
var capture_directory: String = ""

func _initialize() -> void:
	call_deferred("validate")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in range(8):
		await process_frame

func screen_scale(screen: Control) -> float:
	return minf(float(root.size.x) / screen.size.x, float(root.size.y) / screen.size.y)

func text_fits(label: Label, message: String, minimum: float, scale_factor: float) -> void:
	check(label.get_theme_font_size("font_size") * scale_factor >= minimum - 0.01, message + " readable size")
	check(label.size.x >= label.get_minimum_size().x - 0.1, message + " fits horizontally")
	check(label.size.y >= label.get_minimum_size().y - 0.1, message + " fits vertically")

func touch_target(button: Button, scale_factor: float) -> void:
	check(button.size.x * scale_factor >= 44.0 and button.size.y * scale_factor >= 44.0, "%s has 44px target" % button.name)

func validate() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_directory = argument.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(capture_directory)
	root.content_scale_size = Vector2i(720, 1280)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://Scenes/Title.tscn", "Title configured at launch")
	change_scene_to_file("res://Scenes/Title.tscn")
	await scene_changed
	var title := current_scene as Control
	for dimensions in VIEWPORTS:
		root.size = dimensions
		await settle()
		var scale_factor := screen_scale(title)
		var bounds := Rect2(Vector2.ZERO, title.size)
		check_centered(title)
		for name in ["Name", "Tagline", "MochiPlaceholder", "MochiName", "Play", "Settings"]:
			var control := title.get_node("Content/Layout/" + name) as Control
			check(bounds.encloses(control.get_global_rect()), "Title %s stays visible at %s" % [name, dimensions])
			if control is Button:
				touch_target(control, scale_factor)
				check(control.get_theme_font_size("font_size") * scale_factor >= 16.0, "Title action text is at least 16px")
		text_fits(title.get_node("Content/Layout/Tagline"), "Tagline", 16, scale_factor)
		await check_settings(title, title.get_node("Content/Layout/Settings"), bounds, scale_factor)
		await capture("title-%dx%d" % [dimensions.x, dimensions.y])
		print("PASS title: ", dimensions)
	title.get_node("Content/Layout/Play").pressed.emit()
	await scene_changed
	var cafe_screen := current_scene as Control
	check(cafe_screen.scene_file_path == "res://Scenes/Main.tscn", "Play opens café")
	for dimensions in VIEWPORTS:
		root.size = dimensions
		await settle()
		var scale_factor := screen_scale(cafe_screen)
		var bounds := Rect2(Vector2.ZERO, cafe_screen.size)
		check_centered(cafe_screen)
		var layout := cafe_screen.get_node("Content/Layout")
		var cafe := layout.get_node("Cafe") as Control
		check(bounds.encloses(cafe.get_global_rect()), "Café stays visible")
		check(cafe.size.y * scale_factor >= 250.0, "Café retains useful visual space")
		var hud := layout.get_node("TopHUD")
		for label in hud.get_node("StatsRow").get_children():
			text_fits(label, "HUD " + label.name, 16, scale_factor)
			check(bounds.encloses(label.get_global_rect()), "HUD labels stay visible")
		var settings := hud.get_node("TitleRow/Settings") as Button
		touch_target(settings, scale_factor)
		check(settings.get_theme_font_size("font_size") * scale_factor >= 16.0, "HUD Settings is readable")
		var nav := layout.get_node("BottomNavigation") as Control
		check(nav.get_child_count() == 5, "Five navigation controls")
		for i in range(5):
			var button := nav.get_child(i) as Button
			check(button.text == NAV_NAMES[i], "Navigation has correct accessible label")
			check(button.get_node("Caption").text == NAV_NAMES[i], "Navigation has correct visible label")
			touch_target(button, scale_factor)
			check(bounds.encloses(button.get_global_rect()), "%s stays inside viewport" % button.name)
			text_fits(button.get_node("Caption"), button.name, 14, scale_factor)
			for child in button.get_children():
				check(button.get_global_rect().encloses(child.get_global_rect()), "%s child fits button" % button.name)
			for j in range(i):
				check(not button.get_global_rect().intersects(nav.get_child(j).get_global_rect()), "Navigation controls do not overlap")
		check(nav.get_node("Prepare").size.y > nav.get_node("Upgrade").size.y, "Prepare has stronger size hierarchy")
		await check_settings(cafe_screen, settings, bounds, scale_factor)
		await capture("cafe-%dx%d" % [dimensions.x, dimensions.y])
		print("PASS café: %s | HUD %.1fpx | nav %.1fpx | Settings %.1fpx" % [dimensions, hud.get_node("StatsRow/Coins").get_theme_font_size("font_size") * scale_factor, nav.get_node("Prepare/Caption").get_theme_font_size("font_size") * scale_factor, settings.size.y * scale_factor])
	check_theme(cafe_screen.theme)
	if failures == 0:
		print("PASS: 8 viewports, real stretch, readable labels, touch targets, navigation, settings and theme states")
	quit(0 if failures == 0 else 1)

func check_centered(screen: Control) -> void:
	var column := screen.get_node("Content") as Control
	check(column.size.x <= 720.1, "Portrait column width remains capped")
	check(absf(column.position.x + column.size.x / 2.0 - screen.size.x / 2.0) <= 0.1, "Portrait column stays centered")

func check_settings(screen: Control, button: Button, bounds: Rect2, scale_factor: float) -> void:
	button.grab_focus()
	button.pressed.emit()
	await settle()
	var panel := screen.get_node("SettingsPanel") as Control
	check(panel.visible, "Settings opens")
	check(bounds.encloses(panel.get_node("Center/Panel").get_global_rect()), "Settings card fits")
	var layout := panel.get_node("Center/Panel/Margins/Layout")
	text_fits(layout.get_node("Description"), "Settings description", 16, scale_factor)
	if root.size == Vector2i(320, 568):
		await capture("settings-320x568")
	var back := layout.get_node("Close") as Button
	touch_target(back, scale_factor)
	check(back.get_theme_font_size("font_size") * scale_factor >= 16.0, "Back text readable")
	back.pressed.emit()
	check(not panel.visible, "Back closes settings")
	check(root.gui_get_focus_owner() == button, "Focus restored")
	button.pressed.emit()
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	Input.parse_input_event(tab)
	await process_frame
	check(root.gui_get_focus_owner() == back, "Tab stays inside modal")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	check(not panel.visible, "Escape closes modal")
	check(root.gui_get_focus_owner() == button, "Escape restores focus")

func check_theme(ui_theme: Theme) -> void:
	for variant in ["Button", "PrimaryButton", "MintButton", "PeachButton", "GoldButton"]:
		var normal := ui_theme.get_stylebox("normal", variant) as StyleBoxFlat
		for state in ["hover", "pressed", "disabled"]:
			var style := ui_theme.get_stylebox(state, variant) as StyleBoxFlat
			check(style != null and style.bg_color != normal.bg_color, "%s distinct %s state" % [variant, state])
		var focus := ui_theme.get_stylebox("focus", variant) as StyleBoxFlat
		check(focus != null and focus.border_width_left >= 4, "%s visible focus ring" % variant)
		for state in ["normal", "hover", "pressed"]:
			var box := ui_theme.get_stylebox(state, variant) as StyleBoxFlat
			var text_color := ui_theme.get_color("font_color", variant)
			var ratio := (luminance(box.bg_color) + 0.05) / (luminance(text_color) + 0.05)
			check(ratio >= 4.5, "%s %s text contrast at least 4.5:1" % [variant, state])
	var wood := ui_theme.get_stylebox("normal", "WoodLabel") as StyleBoxFlat
	check((luminance(ui_theme.get_color("font_color", "WoodLabel")) + 0.05) / (luminance(wood.bg_color) + 0.05) >= 4.5, "HUD name contrast")

func capture(file_name: String) -> void:
	if capture_directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	check(picture.save_png(capture_directory.path_join(file_name + ".png")) == OK, "Screenshot saved")

func luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return linear.r * 0.2126 + linear.g * 0.7152 + linear.b * 0.0722
