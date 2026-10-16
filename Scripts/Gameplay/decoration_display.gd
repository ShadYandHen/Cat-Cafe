class_name DecorationDisplay
extends Node2D
## Additive non-interactive markers in the existing 680x740 café coordinates.
const POSITIONS := {"wall_display":Vector2(335,370),"shelf_display":Vector2(355,610),"floor_display":Vector2(360,684)}
const MARKER_SIZE := Vector2(48,48)
var profile: CafeProfile

func setup(model: CafeProfile) -> void:
	profile=model
	profile.changed.connect(queue_redraw)
	queue_redraw()

func marker_rect(slot: String) -> Rect2:
	return Rect2(POSITIONS[slot]-MARKER_SIZE/2,MARKER_SIZE)

func _draw() -> void:
	if profile==null:
		return
	for slot in CafeCatalog.SLOT_IDS:
		var id: String=profile.equipped_decorations()[slot]
		if id.is_empty():
			continue
		var entry := CafeProfile.cafe_catalog.decoration(id)
		var center: Vector2=POSITIONS[slot]
		var ink := Color("805b46")
		var style := StyleBoxFlat.new()
		style.bg_color=Color(entry.color)
		style.border_color=ink
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		draw_style_box(style,marker_rect(slot))
		match entry.symbol:
			"paw":
				draw_circle(center+Vector2(0,5),9,ink)
				for offset in [Vector2(-12,-5),Vector2(-4,-13),Vector2(6,-12),Vector2(14,-4)]:
					draw_circle(center+offset,4,ink)
			"mug":
				draw_rect(Rect2(center-Vector2(12,9),Vector2(22,22)),ink,false,3)
				draw_arc(center+Vector2(12,1),8,-PI/2,PI/2,12,ink,3)
			"leaf":
				draw_line(center+Vector2(0,15),center-Vector2(0,14),ink,3)
				draw_circle(center+Vector2(-7,-2),7,ink)
				draw_circle(center+Vector2(6,-9),6,ink)
			"flower":
				for i in range(5):
					draw_circle(center+Vector2(11,0).rotated(i*TAU/5),6,ink)
				draw_circle(center,5,Color("fff6e7"))
			"star":
				var points := PackedVector2Array()
				for i in range(10):
					points.append(center+Vector2(0,-16 if i%2==0 else -7).rotated(i*PI/5))
				draw_colored_polygon(points,ink)
			"heart":
				draw_circle(center+Vector2(-7,-5),8,ink)
				draw_circle(center+Vector2(7,-5),8,ink)
				draw_colored_polygon(PackedVector2Array([center+Vector2(-15,-3),center+Vector2(15,-3),center+Vector2(0,16)]),ink)
