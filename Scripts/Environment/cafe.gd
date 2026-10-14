extends Control
## Native vector placeholder set. Every coordinate belongs to a fixed 680 × 740 dollhouse.
const DESIGN_SIZE := Vector2(680, 740)
const INK := Color("805b46")
const CREAM := Color("fff6e7")
const PEACH := Color("efc0a7")
const MINT := Color("b8d3bd")
const PINK := Color("eac1c4")

func _ready() -> void:
	resized.connect(_update_stage)
	_update_stage()

func _update_stage() -> void:
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	$Stage.position = (size - DESIGN_SIZE * factor) / 2.0
	$Stage.scale = Vector2.ONE * factor
	queue_redraw()

func paw(center: Vector2, scale_factor: float = 1.0) -> void:
	draw_circle(center, 13 * scale_factor, PINK)
	for offset in [Vector2(-17, -16), Vector2(-6, -24), Vector2(8, -24), Vector2(19, -13)]:
		draw_circle(center + offset * scale_factor, 6 * scale_factor, PINK)

func rounded(box: Rect2, color: Color, radius: float = 16.0, border: bool = true) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	if border:
		style.border_color = INK
		style.set_border_width_all(3)
	draw_style_box(style, box)

func label_at(position: Vector2, text: String, font_size: int = 20) -> void:
	draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)

func _draw() -> void:
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	var origin := (size - DESIGN_SIZE * factor) / 2.0
	draw_set_transform(origin, 0, Vector2.ONE * factor)
	# Shell, wallpaper and warm plank floor.
	rounded(Rect2(8, 8, 664, 724), CREAM, 28)
	rounded(Rect2(20, 20, 640, 485), Color("f1d3bd"), 20, false)
	for y in range(45, 490, 47):
		draw_line(Vector2(22, y), Vector2(658, y), Color("e8c4a9"), 2)
	# Hanging lamps and restrained foliage reference the approved café.
	for x in [186, 497]:
		draw_line(Vector2(x, 22), Vector2(x, 86), INK, 3)
		draw_circle(Vector2(x, 106), 22, Color("f9dfa1"))
		draw_circle(Vector2(x, 106), 11, Color("fff1cc"))
	rounded(Rect2(20, 493, 640, 227), Color("e2bb96"), 16, false)
	for y in range(525, 720, 39):
		draw_line(Vector2(22, y), Vector2(658, y), Color("bf9678"), 2)
	draw_line(Vector2(20, 493), Vector2(660, 493), INK, 5)
	# Daylight window and curtains.
	rounded(Rect2(217, 65, 250, 212), Color("bcd9d8"), 22)
	draw_circle(Vector2(396, 110), 26, Color("fff2bf"))
	rounded(Rect2(238, 204, 208, 52), MINT, 20, false)
	draw_line(Vector2(342, 67), Vector2(342, 275), CREAM, 8)
	draw_line(Vector2(218, 166), Vector2(465, 166), CREAM, 8)
	rounded(Rect2(202, 56, 51, 227), PINK, 12)
	rounded(Rect2(431, 56, 51, 227), PINK, 12)
	# Wall sign and framed heart.
	rounded(Rect2(48, 80, 122, 117), Color("806452"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(62, 116), "COFFEE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, CREAM)
	draw_string(font, Vector2(64, 146), "little paws", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, CREAM)
	draw_string(font, Vector2(62, 175), "big dreams", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, CREAM)
	rounded(Rect2(517, 91, 99, 101), CREAM)
	paw(Vector2(565, 153), 1.25)
	# Preparation station and equipment.
	rounded(Rect2(45, 415, 298, 153), Color("c99973"))
	for x in [109, 174, 239, 304]:
		draw_line(Vector2(x, 431), Vector2(x, 554), Color("ab7a57"), 2)
	rounded(Rect2(32, 394, 324, 36), Color("a88268"), 12)
	rounded(Rect2(60, 446, 122, 92), Color("e9c29f"), 10)
	rounded(Rect2(200, 446, 122, 92), Color("e9c29f"), 10)
	draw_circle(Vector2(160, 488), 5, INK)
	draw_circle(Vector2(220, 488), 5, INK)
	rounded(Rect2(63, 310, 137, 85), MINT, 12)
	rounded(Rect2(76, 322, 110, 29), CREAM, 7)
	draw_circle(Vector2(88, 336), 6, PEACH)
	draw_line(Vector2(135, 351), Vector2(135, 368), INK, 5)
	rounded(Rect2(117, 368, 37, 24), CREAM, 5)
	rounded(Rect2(230, 341, 51, 51), Color("d4bfb0"), 9)
	rounded(Rect2(233, 313, 45, 34), Color("b39479"), 12)
	label_at(Vector2(93, 600), "PREP COUNTER", 20)
	# Seating zone: small round table, two stools.
	rounded(Rect2(409, 539, 223, 115), Color("e8c7bb"), 48, false)
	rounded(Rect2(412, 474, 52, 81), PINK, 14)
	rounded(Rect2(575, 474, 52, 81), PINK, 14)
	rounded(Rect2(504, 465, 26, 118), Color("a88268"), 8)
	rounded(Rect2(444, 442, 151, 46), Color("d4a579"), 23)
	rounded(Rect2(496, 421, 30, 22), PINK, 6)
	label_at(Vector2(451, 690), "CUSTOMER NOOK", 18)
	# Cat resting area and tiny plant.
	rounded(Rect2(69, 640, 227, 59), PINK, 26)
	rounded(Rect2(85, 649, 193, 38), Color("ecd1d1"), 20, false)
	label_at(Vector2(121, 675), "CAT LOUNGE", 17)
	rounded(Rect2(568, 349, 49, 52), PEACH, 12)
	draw_line(Vector2(592, 350), Vector2(592, 292), INK, 4)
	draw_ellipse_leaf(Vector2(573, 310), -0.5)
	draw_ellipse_leaf(Vector2(609, 291), 0.5)
	# Potted foliage beside the lounge; room remains for future actors.
	rounded(Rect2(36, 562, 40, 45), PEACH, 8)
	draw_ellipse_leaf(Vector2(40, 545), -0.6)
	draw_ellipse_leaf(Vector2(68, 528), 0.6)
	# Clear shelf with cups.
	rounded(Rect2(51, 238, 119, 14), Color("a88268"), 5)
	for x in [66, 105, 144]:
		rounded(Rect2(x, 213, 23, 24), CREAM, 6)

func draw_ellipse_leaf(center: Vector2, angle: float) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var theta := TAU * i / 24.0
		points.append(center + Vector2(cos(theta) * 23, sin(theta) * 11).rotated(angle))
	draw_colored_polygon(points, Color("91b79a"))
