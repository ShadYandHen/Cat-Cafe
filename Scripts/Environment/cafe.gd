extends Control
## Front-facing presentation only. Fixed coordinates preserve the layered café proportions.
const DESIGN_SIZE := Vector2(680, 760)
const INK := Color("805b46")
const CREAM := Color("fff6e7")
const MINT := Color("b8d3bd")
const PINK := Color("eac1c4")
var active_cat_id := ""

func _ready() -> void:
	$Stage/Counter.draw.connect(_draw_counter.bind($Stage/Counter))
	resized.connect(_update_stage)
	_update_stage()

func _update_stage() -> void:
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	$Stage.position = (size - DESIGN_SIZE * factor) / 2.0
	$Stage.scale = Vector2.ONE * factor
	queue_redraw()

func set_barista(cat: Dictionary) -> void:
	if active_cat_id == cat.id:
		return
	active_cat_id = cat.id
	$Stage/Barista.texture = load(cat.artwork)
	$Stage/Barista.tooltip_text = cat.name + " · Active barista"

func rounded(box: Rect2, color: Color, radius: int = 16) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = INK
	style.set_border_width_all(3)
	draw_style_box(style, box)

func _draw() -> void:
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	draw_set_transform((size - DESIGN_SIZE * factor) / 2.0, 0, Vector2.ONE * factor)
	# One room: cream wall, a window behind the barista, and a warm timber floor.
	rounded(Rect2(4, 4, 672, 752), CREAM, 28)
	rounded(Rect2(12, 12, 656, 495), Color("f6e1c8"), 24)
	for x in range(28, 670, 36):
		draw_line(Vector2(x, 25), Vector2(x, 495), Color("eed4b9"), 2)
	rounded(Rect2(14, 500, 652, 244), Color("dfb58e"), 20)
	for y in range(530, 740, 48):
		draw_line(Vector2(20, y), Vector2(660, y), Color("c79b79"), 2)
	# Window and two small shelves frame, rather than cover, the official illustration.
	rounded(Rect2(210, 114, 260, 270), Color("c3dedb"), 40)
	draw_circle(Vector2(403, 166), 25, Color("fff3c1"))
	draw_line(Vector2(340, 118), Vector2(340, 380), CREAM, 8)
	draw_line(Vector2(214, 245), Vector2(466, 245), CREAM, 8)
	for x in [36, 514]:
		rounded(Rect2(x, 227, 130, 14), Color("b78865"), 6)
		for cup in [x + 18, x + 63, x + 100]:
			rounded(Rect2(cup, 195, 23, 31), CREAM, 7)
			draw_arc(Vector2(cup + 24, 211), 8, -PI/2, PI/2, 12, INK, 3)
	for x in [105, 575]:
		draw_line(Vector2(x, 90), Vector2(x, 120), INK, 3)
		draw_circle(Vector2(x, 142), 28, Color("e9b87b"))
		draw_circle(Vector2(x, 143), 21, Color("fff0ba"))
	# Wall greenery and fixed display niches stay out of interaction areas.
	for x in [56, 594]:
		rounded(Rect2(x, 326, 30, 37), PINK, 8)
		for offset in [Vector2(-6,-8), Vector2(22,-16), Vector2(10,-34)]:
			draw_circle(Vector2(x + 8, 325) + offset, 15, Color("9abd9b"))
	# Empty seats remain recognizable when their customer buttons are hidden.
	for x in [183, 497]:
		rounded(Rect2(x - 72, 602, 144, 125), Color("cb9c79"), 24)
		rounded(Rect2(x - 65, 608, 130, 57), PINK, 23)
		rounded(Rect2(x - 83, 706, 166, 25), Color("a97a5b"), 12)

func _draw_counter(canvas: Control) -> void:
	# Counter is a separate foreground layer so it naturally occludes only the lower apron.
	var style := StyleBoxFlat.new()
	style.bg_color = Color("bd8c67")
	style.border_color = INK
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	canvas.draw_style_box(style, Rect2(18, 442, 644, 106))
	for x in [36, 252, 468]:
		style.bg_color = Color("d7ad88")
		canvas.draw_style_box(style, Rect2(x, 458, 176, 68))
	style.bg_color = Color("f1cb9f")
	canvas.draw_style_box(style, Rect2(8, 428, 664, 29))
