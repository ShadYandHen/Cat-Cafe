extends Control
## Four secondary menus; primary preparation starts from a customer ticket.
var pixel_scale: float = 1.0
var compact: bool = false

func _ready() -> void:
	resized.connect(_arrange)

func configure(scale_factor: float, column_pixels: float) -> void:
	pixel_scale = scale_factor
	compact = column_pixels < 400.0
	custom_minimum_size.y = 52.0 / pixel_scale
	for button in get_children():
		button.add_theme_font_size_override("font_size",1)
		var caption := button.get_node("Caption") as Label
		caption.add_theme_font_size_override("font_size", ceili(16.0 / pixel_scale))
	_arrange()

func _arrange() -> void:
	# Four secondary menus share one row; order tickets are the primary café action.
	var gap := 6.0 / pixel_scale
	var tile_width := (size.x - gap * (get_child_count()-1)) / get_child_count()
	for i in range(get_child_count()):
		_place(get_child(i), Rect2(i*(tile_width+gap), 0, tile_width, size.y), true)

func _place(button: Button, box: Rect2, horizontal: bool) -> void:
	button.position = box.position.floor()
	button.size = box.size.floor()
	var icon := button.get_node("Icon") as TextureRect
	var caption := button.get_node("Caption") as Label
	var padding := 5.0 / pixel_scale
	if horizontal:
		var icon_size := 20.0 / pixel_scale
		icon.position = Vector2(padding, (box.size.y - icon_size) / 2.0)
		icon.size = Vector2.ONE * icon_size
		caption.position = Vector2(icon_size + padding * 1.5, 0)
		caption.size = Vector2(box.size.x - caption.position.x - padding, box.size.y)
	else:
		var icon_size := minf(36.0 / pixel_scale, box.size.y * 0.42)
		icon.position = Vector2((box.size.x - icon_size) / 2.0, padding)
		icon.size = Vector2.ONE * icon_size
		caption.position = Vector2(padding, padding + icon_size)
		caption.size = Vector2(box.size.x - padding * 2.0, box.size.y - caption.position.y - padding)
