extends Control
## A small native bunny placeholder; independent of the approved cat assets.
func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var factor := minf(size.x / 80.0, size.y / 80.0)
	draw_set_transform((size - Vector2(80, 80) * factor) / 2.0, 0, Vector2.ONE * factor)
	var cream := Color("fff1df")
	var brown := Color("805b46")
	for x in [26, 54]:
		draw_line(Vector2(x, 30), Vector2(x, 10), brown, 18, true)
		draw_line(Vector2(x, 30), Vector2(x, 10), cream, 12, true)
		draw_line(Vector2(x, 28), Vector2(x, 13), Color("ee9daf"), 5, true)
	draw_circle(Vector2(40, 49), 28, brown)
	draw_circle(Vector2(40, 49), 25, cream)
	for x in [30, 50]:
		draw_circle(Vector2(x, 46), 3, brown)
	draw_circle(Vector2(40, 56), 3, Color("ee9daf"))
