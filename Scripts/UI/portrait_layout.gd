extends Control
## Preserve the portrait canvas while giving interactive UI minimum screen-pixel sizes.
@onready var content: MarginContainer = $Content
var ui_scale: float = 1.0
var safe_insets := Vector4.ZERO # left, top, right, bottom in CSS/window pixels

func _ready() -> void:
	resized.connect(_update_layout)
	get_window().size_changed.connect(_update_layout)
	_update_layout()

func readable_font(base: int, minimum_pixels: float = 16.0) -> int:
	return maxi(base, ceili(minimum_pixels / ui_scale))

func _update_layout() -> void:
	var window_pixels := Vector2(get_window().size)
	safe_insets = Vector4.ZERO
	if OS.has_feature("web"):
		# Read CSS safe-area values without requiring a custom HTML shell.
		var result = JavaScriptBridge.eval("""(() => {
		 const e = document.createElement('div');
		 e.style.cssText = 'position:fixed;visibility:hidden;padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)';
		 document.body.appendChild(e); const s = getComputedStyle(e);
		 const v = [innerWidth, innerHeight, parseFloat(s.paddingLeft)||0, parseFloat(s.paddingTop)||0, parseFloat(s.paddingRight)||0, parseFloat(s.paddingBottom)||0];
		 e.remove(); return JSON.stringify(v);
		})()""")
		if result is String:
			var values = JSON.parse_string(result)
			if values is Array and values.size() == 6:
				window_pixels = Vector2(values[0], values[1])
				safe_insets = Vector4(values[2], values[3], values[4], values[5])
	ui_scale = maxf(0.01, minf(window_pixels.x / size.x, window_pixels.y / size.y))
	var usable_width := size.x - (safe_insets.x + safe_insets.z) / ui_scale
	var content_width := minf(usable_width, 720.0)
	content.position = Vector2(safe_insets.x / ui_scale + (usable_width - content_width) / 2.0, safe_insets.y / ui_scale)
	content.size = Vector2(content_width, size.y - (safe_insets.y + safe_insets.w) / ui_scale)
	var layout := $Content/Layout
	var compact := content_width * ui_scale < 400.0
	if layout.has_node("TopHUD"):
		content.add_theme_constant_override("margin_left", ceili(8.0 / ui_scale))
		content.add_theme_constant_override("margin_right", ceili(8.0 / ui_scale))
		content.add_theme_constant_override("margin_top", ceili(8.0 / ui_scale))
		content.add_theme_constant_override("margin_bottom", ceili(8.0 / ui_scale))
		layout.add_theme_constant_override("separation", ceili(8.0 / ui_scale))
		var hud := layout.get_node("TopHUD")
		hud.add_theme_constant_override("separation", ceili(6.0 / ui_scale))
		hud.get_node("TitleRow").add_theme_constant_override("separation", ceili(8.0 / ui_scale))
		hud.get_node("StatsRow").add_theme_constant_override("separation", ceili(6.0 / ui_scale))
		hud.get_node("TitleRow/CafeName").add_theme_font_size_override("font_size", readable_font(32, 16))
		var settings := hud.get_node("TitleRow/Settings") as Button
		settings.custom_minimum_size = Vector2(ceili(88.0 / ui_scale), ceili(48.0 / ui_scale))
		settings.add_theme_font_size_override("font_size", readable_font(28))
		for label in hud.get_node("StatsRow").get_children():
			label.add_theme_font_size_override("font_size", readable_font(28))
		layout.get_node("Welcome").visible = not compact
		layout.get_node("FoundationNote").hide()
		layout.get_node("BottomNavigation").configure(ui_scale, content_width * ui_scale)
	else:
		# Branding and Mochi stay intact; give the actions and tagline readable sizes.
		layout.get_node("Tagline").add_theme_font_size_override("font_size", readable_font(28))
		layout.get_node("MochiName").add_theme_font_size_override("font_size", readable_font(24, 14))
		var play := layout.get_node("Play") as Button
		play.custom_minimum_size.y = maxf(112.0, ceili(56.0 / ui_scale))
		play.add_theme_font_size_override("font_size", readable_font(36, 20))
		var settings := layout.get_node("Settings") as Button
		settings.custom_minimum_size.y = maxf(96.0, ceili(48.0 / ui_scale))
		settings.add_theme_font_size_override("font_size", readable_font(28))
	$SettingsPanel.configure(ui_scale, content_width, Rect2(content.position, content.size))
