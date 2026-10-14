extends Control
## Simple native storefront framing; illustrative reference sheets are never used as UI.
const BROWN := Color("946a52")

func _ready() -> void:
	resized.connect(queue_redraw)

func box(rect: Rect2, color: Color, radius: int = 20) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = BROWN
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func _draw() -> void:
	var left := (size.x - 720.0) / 2.0
	draw_set_transform(Vector2(left, 0))
	# Warm side posts and a simple striped canopy.
	box(Rect2(12, 40, 48, size.y - 80), Color("c29572"), 16)
	box(Rect2(660, 40, 48, size.y - 80), Color("c29572"), 16)
	box(Rect2(40, 16, 640, 38), Color("ac7d5d"), 12)
	for i in range(8):
		box(Rect2(64 + i * 74, 62, 74, 46), Color("efb6b3") if i % 2 == 0 else Color("fff0d8"), 12)
	# Light-blue shop windows behind the mascot.
	box(Rect2(84, size.y * 0.36, 552, 320), Color("c7dcd5"), 32)
	draw_line(Vector2(360, size.y * 0.36), Vector2(360, size.y * 0.36 + 320), BROWN, 6)
	draw_line(Vector2(85, size.y * 0.36 + 165), Vector2(635, size.y * 0.36 + 165), BROWN, 6)
	for x in [40, 680]:
		draw_line(Vector2(x, 115), Vector2(x, 193), BROWN, 3)
		draw_circle(Vector2(x, 219), 30, Color("f7dcaa"))
		draw_circle(Vector2(x, 219), 16, Color("fff1cc"))
		box(Rect2(x - 24, size.y - 163, 48, 82), Color("d6a080"), 12)
		for offset in [Vector2(-10, -184), Vector2(13, -205), Vector2(0, -235)]:
			draw_circle(Vector2(x, size.y) + offset, 19, Color("9fbe99"))
