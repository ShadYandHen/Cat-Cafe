extends Control
## Compact phones use two side pairs around Prepare; wider portraits retain five tiles.
var pixel_scale: float = 1.0
var compact: bool = false

func _ready() -> void:
	resized.connect(_arrange)

func configure(scale_factor: float, column_pixels: float) -> void:
	pixel_scale = scale_factor
	compact = column_pixels < 400.0
	custom_minimum_size.y = maxf(144.0, (108.0 if compact else 84.0) / pixel_scale)
	for button in get_children():
		var caption := button.get_node("Caption") as Label
		caption.add_theme_font_size_override("font_size", maxi(24, ceili(14.0 / pixel_scale)))
	_arrange()

func _arrange() -> void:
	var gap := 6.0 / pixel_scale
	if compact:
		var center_width := 80.0 / pixel_scale
		var side_width := (size.x - center_width - gap * 2.0) / 2.0
		var row_height := (size.y - gap) / 2.0
		_place($Upgrade, Rect2(0, 0, side_width, row_height), true)
		_place($Decorate, Rect2(0, row_height + gap, side_width, row_height), true)
		_place($Prepare, Rect2(side_width + gap, 0, center_width, size.y), false)
		_place($CatTeam, Rect2(side_width + center_width + gap * 2.0, 0, side_width, row_height), true)
		_place($Map, Rect2(side_width + center_width + gap * 2.0, row_height + gap, side_width, row_height), true)
	else:
		var tile_width := (size.x - gap * 4.0) / 5.0
		for i in range(5):
			var button := get_child(i) as Button
			var inset := 0.0 if button == $Prepare else 8.0 / pixel_scale
			_place(button, Rect2(i * (tile_width + gap), inset, tile_width, size.y - inset), false)

func _place(button: Button, box: Rect2, horizontal: bool) -> void:
	button.position = box.position
	button.size = box.size
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
