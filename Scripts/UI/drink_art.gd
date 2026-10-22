class_name DrinkArt
extends RefCounted
## Original temporary vector symbols. No character artwork or recipe data lives here.
const COLORS := {"Coffee":"86563c", "Water":"a5d7df", "Milk":"fff1d4", "Vanilla":"e1b45f", "Honey":"d79c35", "Tea":"c79748", "Berries":"cf7198", "Ice":"d8eef1", "Cocoa":"9b6952"}
static func icon(canvas: CanvasItem, ingredient: String, origin: Vector2, scale_factor: float) -> void:
	canvas.draw_set_transform(origin,0,Vector2.ONE*scale_factor)
	var ink := Color("805b46")
	var color := Color(COLORS.get(ingredient,"fff6e7"))
	match ingredient:
		"Water", "Honey", "Vanilla":
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(12,1),Vector2(3,16),Vector2(6,23),Vector2(18,23),Vector2(21,16)]),color)
			canvas.draw_line(Vector2(12,6),Vector2(7,16),Color("fff6e7"),2,true)
		"Milk":
			canvas.draw_style_box(box(color),Rect2(5,6,14,18))
			canvas.draw_style_box(box(Color("eab9c7")),Rect2(6,1,12,6))
		"Tea":
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(3,20),Vector2(5,8),Vector2(21,2),Vector2(19,17)]),Color("85a577"))
			canvas.draw_line(Vector2(4,21),Vector2(18,5),ink,2,true)
		"Ice":
			canvas.draw_style_box(box(color),Rect2(2,2,15,15))
			canvas.draw_style_box(box(color),Rect2(10,11,13,13))
		"Berries":
			for point in [Vector2(8,14),Vector2(17,15),Vector2(12,7)]:
				canvas.draw_circle(point,6,color)
			canvas.draw_line(Vector2(12,2),Vector2(16,0),Color("85a577"),3,true)
		"Coffee", "Cocoa":
			canvas.draw_style_box(box(color),Rect2(2,4,20,18))
			canvas.draw_circle(Vector2(12,13),5,Color("fff1d4"))
			canvas.draw_line(Vector2(11,9),Vector2(13,17),ink,2,true)
	canvas.draw_set_transform(Vector2.ZERO)
static func box(color: Color, border: Color = Color("805b46"), width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=color
	style.border_color=border
	style.set_border_width_all(width)
	style.set_corner_radius_all(6)
	return style
