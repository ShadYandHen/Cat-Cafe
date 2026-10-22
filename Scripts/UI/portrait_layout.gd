extends Control
## Shared landscape safe canvas. Kept at its existing path for scene compatibility.
@onready var content: MarginContainer = $Content
var ui_scale: float = 1.0
var safe_insets := Vector4.ZERO
var reflow_frames:=0
var simulated_safe_insets := Vector4.ZERO # Window pixels; isolated test injection.

func _ready() -> void:
	content.visibility_changed.connect(_update_layout)
	resized.connect(_update_layout)
	get_window().size_changed.connect(_update_layout)
	_update_layout()

func readable_font(base: int, minimum_pixels: float = 16.0) -> int:
	return maxi(base, ceili(minimum_pixels / ui_scale))

static func native_safe_insets(window_rect: Rect2, safe_rect: Rect2) -> Vector4:
	var usable := window_rect.intersection(safe_rect)
	if not usable.has_area():return Vector4.ZERO
	return Vector4(maxf(0,usable.position.x-window_rect.position.x),maxf(0,usable.position.y-window_rect.position.y),maxf(0,window_rect.end.x-usable.end.x),maxf(0,window_rect.end.y-usable.end.y))

func _update_layout() -> void:
	var pixels := Vector2(get_window().size)
	safe_insets=simulated_safe_insets
	if OS.has_feature("android"):
		safe_insets=native_safe_insets(Rect2(Vector2(DisplayServer.window_get_position()),pixels),Rect2(DisplayServer.get_display_safe_area()))
	elif OS.has_feature("web"):
		var result=JavaScriptBridge.eval("""(() => { const e=document.createElement('div');e.style.cssText='position:fixed;visibility:hidden;padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)';document.body.appendChild(e);const s=getComputedStyle(e);const v=[parseFloat(s.paddingLeft)||0,parseFloat(s.paddingTop)||0,parseFloat(s.paddingRight)||0,parseFloat(s.paddingBottom)||0];e.remove();return JSON.stringify(v);})()""")
		if result is String:
			var values=JSON.parse_string(result)
			if values is Array and values.size()==4:safe_insets=Vector4(values[0],values[1],values[2],values[3])
	ui_scale=maxf(0.01,minf(pixels.x/size.x,pixels.y/size.y))
	content.position=Vector2(safe_insets.x,safe_insets.y)/ui_scale
	content.size=size-Vector2(safe_insets.x+safe_insets.z,safe_insets.y+safe_insets.w)/ui_scale
	for side in ["left","right","top","bottom"]:content.add_theme_constant_override("margin_"+side,ceili(12/ui_scale))
	$SettingsPanel.configure(ui_scale,content.size.x,Rect2(content.position,content.size))
	reflow_frames=4
	_arrange.call_deferred()

func put(node: Control, box: Rect2) -> void:
	node.custom_minimum_size=Vector2.ZERO
	node.position=box.position.floor()
	node.size=box.size.floor()

func _arrange() -> void:
	var layout: Control=$Content/Layout
	var w:=layout.size.x
	var h:=layout.size.y
	var u:=1.0/ui_scale
	if layout.has_node("TopHUD"):
		var hud:=layout.get_node("TopHUD") as Control
		put(hud,Rect2(0,0,w,52*u))
		for label in hud.get_node("StatsRow").get_children():label.add_theme_font_size_override("font_size",readable_font(20))
		put(hud.get_node("TitleRow"),Rect2(0,0,w*0.45,52*u))
		put(hud.get_node("StatsRow"),Rect2(w*0.46,0,w*0.54,52*u))
		var name_label: Label=hud.get_node("TitleRow/CafeName")
		name_label.add_theme_constant_override("outline_size",2)
		var name_style:=name_label.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		name_style.content_margin_top=4*u
		name_style.content_margin_bottom=4*u
		name_label.add_theme_stylebox_override("normal",name_style)
		hud.get_node("TitleRow/CafeName").add_theme_font_size_override("font_size",readable_font(24))
		var settings:=hud.get_node("TitleRow/Settings") as Button
		settings.custom_minimum_size=Vector2(100,44)*u
		settings.add_theme_font_size_override("font_size",readable_font(18))
		put(layout.get_node("Welcome"),Rect2(w*0.52,60*u,w*0.48,32*u))
		layout.get_node("Welcome").add_theme_font_size_override("font_size",readable_font(18))
		layout.get_node("FoundationNote").hide()
		put(layout.get_node("Cafe"),Rect2(0,100*u,w,h-160*u))
		var nav:=layout.get_node("BottomNavigation")
		nav.configure(ui_scale,w*ui_scale)
		put(nav,Rect2(0,h-52*u,w,52*u))
	else:
		for n in ["TopSpace","BottomSpace"]:layout.get_node(n).hide()
		var left:=w*0.47
		put(layout.get_node("Name"),Rect2(12*u,h*0.12,left-24*u,170*u))
		put(layout.get_node("Tagline"),Rect2(12*u,h*0.12+178*u,left-24*u,40*u))
		put(layout.get_node("MochiPlaceholder"),Rect2(left+20*u,10*u,w-left-40*u,h-60*u))
		put(layout.get_node("MochiName"),Rect2(left,h-64*u,w-left,60*u))
		put(layout.get_node("Play"),Rect2(40*u,h*0.63,left-80*u,64*u))
		put(layout.get_node("Settings"),Rect2(40*u,h*0.63+76*u,left-80*u,48*u))
		for n in ["Tagline","MochiName"]:layout.get_node(n).add_theme_font_size_override("font_size",readable_font(1,20))
		for n in ["Play","Settings"]:layout.get_node(n).add_theme_font_size_override("font_size",readable_font(1,24))

func _process(_delta: float) -> void:
	if reflow_frames>0:
		reflow_frames-=1
		_arrange()
