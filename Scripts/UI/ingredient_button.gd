extends Button
## Icon + readable name + explicit required/added/extra state; never selects itself.
var ingredient := ""
var required := false
var selected := false
var pixel_scale := 1.0
var name_label: Label
var status_label: Label

func _ready() -> void:
	name_label=Label.new()
	name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(name_label)
	status_label=Label.new()
	status_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(status_label)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:
		add_theme_color_override(state,Color(0,0,0,0))
	resized.connect(_arrange)

func present(value: String, needed: bool, added: bool) -> void:
	if ingredient==value and required==needed and selected==added:return
	ingredient=value
	required=needed
	selected=added
	name_label.text=ingredient
	status_label.text="✓ Added" if selected and required else "+ Extra" if selected else "Needed" if required else ""
	tooltip_text=ingredient+" · "+status_label.text
	theme_type_variation=&"MintButton" if selected and required else &"PeachButton" if selected else &"Button"
	_arrange()
	queue_redraw()

func configure(scale_factor: float) -> void:
	pixel_scale=scale_factor
	_arrange()

func _arrange() -> void:
	if name_label==null:return
	var left := 28.0/pixel_scale
	name_label.position=Vector2(left,4.0/pixel_scale)
	name_label.size=Vector2(maxf(1,size.x-left-2.0/pixel_scale),24.0/pixel_scale)
	name_label.add_theme_font_size_override("font_size",ceili(16.0/pixel_scale))
	status_label.position=Vector2(left,30.0/pixel_scale)
	status_label.size=Vector2(maxf(1,size.x-left),22.0/pixel_scale)
	status_label.add_theme_font_size_override("font_size",ceili(14.0/pixel_scale))
	queue_redraw()

func _draw() -> void:
	if ingredient.is_empty():return
	DrinkArt.icon(self,ingredient,Vector2(4,13)/pixel_scale,20.0/(24.0*pixel_scale))
