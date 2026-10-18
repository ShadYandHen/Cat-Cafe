extends Button
## Original native equipment placeholders; category routes to the existing station UI.
@export_enum("Coffee", "Milk", "Tea", "Cold Drinks") var category := "Coffee"
var pixel_scale := 1.0

func _ready() -> void:
	resized.connect(queue_redraw)

func configure(scale_factor: float) -> void:
	pixel_scale = scale_factor
	var caption := $Caption as Label
	caption.add_theme_font_size_override("font_size", ceili(maxf(24, 14.0 / pixel_scale)))
	caption.text = "Cold" if category == "Cold Drinks" else category
	caption.position = Vector2(0, size.y - maxf(36, 22.0 / pixel_scale))
	caption.size = Vector2(size.x, maxf(36, 22.0 / pixel_scale))
	text = category + " station" # Accessible name; hidden native Button text.
	tooltip_text = "Open " + category + " station"
	queue_redraw()

func box(rect: Rect2, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("805b46")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	draw_style_box(style, rect)

func _draw() -> void:
	var height := maxf(1, size.y - maxf(38, 24.0 / pixel_scale))
	var factor := minf((size.x - 8.0 / pixel_scale) / 68.0, height / 45.0)
	draw_set_transform(Vector2((size.x - 68 * factor) / 2, 2.0 / pixel_scale), 0, Vector2.ONE * factor)
	var ink := Color("805b46")
	var cream := Color("fff6e7")
	match category:
		"Coffee":
			box(Rect2(5, 1, 58, 41), Color("b8d3bd"))
			box(Rect2(10, 6, 48, 12), cream)
			draw_circle(Vector2(17, 12), 3, Color("c38e67"))
			draw_line(Vector2(34, 19), Vector2(34, 28), ink, 3)
			box(Rect2(24, 29, 20, 12), cream)
		"Milk":
			box(Rect2(22, 8, 24, 34), cream)
			box(Rect2(23, 2, 22, 9), Color("edbbc8"))
			draw_circle(Vector2(34, 26), 6, Color("edbbc8"))
		"Tea":
			draw_circle(Vector2(32, 27), 16, ink)
			draw_circle(Vector2(32, 27), 14, Color("b8d3bd"))
			draw_arc(Vector2(51, 26), 9, -PI/2, PI/2, 16, ink, 3)
			draw_colored_polygon(PackedVector2Array([Vector2(19,23),Vector2(7,16),Vector2(17,34)]), Color("b8d3bd"))
			box(Rect2(22, 8, 20, 6), cream)
			draw_circle(Vector2(32, 6), 3, ink)
		"Cold Drinks":
			box(Rect2(20, 10, 28, 32), Color("c3dedb"))
			draw_line(Vector2(38, 30), Vector2(44, 1), Color("d291a5"), 4)
			for at in [Vector2(29,22), Vector2(39,31)]:
				box(Rect2(at, Vector2(7,7)), cream)
