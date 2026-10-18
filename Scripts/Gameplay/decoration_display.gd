class_name DecorationDisplay
extends Node2D
## Additive non-interactive markers in the existing 680x760 café coordinates.
const POSITIONS := {"wall_display":Vector2(340,105),"shelf_display":Vector2(600,295),"floor_display":Vector2(340,592)}
const MARKER_SIZE := Vector2(48,48)
var profile: CafeProfile

func setup(model: CafeProfile) -> void:
	profile=model
	profile.changed.connect(queue_redraw)
	queue_redraw()

func marker_rect(slot: String) -> Rect2:
	var dimensions := MARKER_SIZE * Vector2(0.5 if slot=="floor_display" else 1.0,1.0)
	return Rect2(POSITIONS[slot]-dimensions/2,dimensions)

func _draw() -> void:
	if profile==null:
		return
	# A café badge indicator, never painted onto the official character illustrations.
	var badge: String=profile.snapshot().equipped_cosmetics.cafe_badge
	if not badge.is_empty():
		var center := Vector2(80,295)
		draw_circle(center,20,Color("805b46"))
		draw_circle(center,17,Color(CafeProfile.reward_catalog.cosmetic(badge).color))
		draw_circle(center+Vector2(0,5),7,Color("fff6e7"))
		for offset in [Vector2(-10,-4),Vector2(-3,-10),Vector2(5,-9),Vector2(11,-3)]:
			draw_circle(center+offset,3,Color("fff6e7"))
	for slot in CafeCatalog.SLOT_IDS:
		var id: String=profile.equipped_decorations()[slot]
		if id.is_empty():
			continue
		var entry := CafeProfile.cafe_catalog.decoration(id)
		var center: Vector2=POSITIONS[slot]
		var horizontal := 0.5 if slot=="floor_display" else 1.0
		draw_set_transform(Vector2(center.x*(1.0-horizontal),0),0,Vector2(horizontal,1))
		var ink := Color("805b46")
		var style := StyleBoxFlat.new()
		style.bg_color=Color(entry.color)
		style.border_color=ink
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		draw_style_box(style,Rect2(center-MARKER_SIZE/2,MARKER_SIZE))
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
