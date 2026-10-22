extends Control
## Presentation snapshot supplied by GameplayView; never modifies orders or clocks.
var visual: Dictionary = {}
var miniature := false
var pixel_scale := 1.0:
	set(value):
		pixel_scale=value
		_update_labels()
		queue_redraw()
var recipe_label: Label
var timing_label: Label

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	recipe_label=Label.new()
	recipe_label.name="RecipeName"
	timing_label=Label.new()
	timing_label.name="TimingHint"
	for label in [recipe_label,timing_label]:
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		add_child(label)
	resized.connect(_update_labels)
	resized.connect(queue_redraw)

func present(data: Dictionary) -> void:
	if visual==data:return
	visual=data
	_update_labels()
	queue_redraw()

func liquid_color() -> Color:
	var ingredients: Array=visual.get("ingredients",[])
	var color := Color("badde1")
	if "Coffee" in ingredients: color=Color("895940")
	if "Tea" in ingredients: color=Color("cfaa5e")
	if "Berries" in ingredients: color=Color("cc789d")
	if "Cocoa" in ingredients: color=Color("91644e")
	if "Milk" in ingredients:
		color=color.lerp(Color("fff2d8"),0.55) if ingredients.any(func(item): return item in ["Coffee","Tea","Berries","Cocoa"]) else Color("fff2d8")
	return color

func _draw() -> void:
	if visual.is_empty(): return
	var base := Vector2(320,200)
	var factor := minf(size.x/base.x,size.y/base.y)
	if miniature:
		base=Vector2(140,150)
		factor=minf(size.x/base.x,size.y/base.y)
	var origin := (size-base*factor)/2
	draw_set_transform(origin,0,Vector2.ONE*factor)
	var ink := Color("805b46")
	var category: String=visual.get("category","Coffee")
	var ingredients: Array=visual.get("ingredients",[])
	var state: String=visual.get("state","empty")
	var center := Vector2(70,75) if miniature else Vector2(160,99)
	var cup := Rect2(center-Vector2(47,56),Vector2(94,112))
	if category=="Cold Drinks":
		cup=Rect2(center-Vector2(43,61),Vector2(86,122))
	if not miniature:
		var backgrounds := {"Coffee":"f1dfca","Milk":"fae6de","Tea":"e6eddc","Cold Drinks":"e1edf0"}
		draw_style_box(DrinkArt.box(Color(backgrounds.get(category,"fff6e7")),Color("d7bca2"),1),Rect2(3,3,314,194))
		# Station-specific backdrop and a counter/saucer keep the workspace grounded.
		draw_line(Vector2(16,151),Vector2(304,151),Color("c5a58a"),2)
		draw_style_box(DrinkArt.box(Color("ead0b5"),Color("c5a58a"),1),Rect2(86,144,148,9))
	# Clear cup with intact silhouette, even with no ingredients.
	draw_style_box(DrinkArt.box(Color("fff8eb"),ink,4),cup)
	if category!="Cold Drinks":
		draw_arc(center+Vector2(48,-6),21,-PI/2,PI/2,24,ink,5,true)
	var valid := state not in ["departed","unavailable"]
	var liquids: Array=[]
	if valid:
		for ingredient in ingredients:
			if ingredient!="Ice": liquids.append(ingredient)
	if not liquids.is_empty():
		var fill := 0.72
		if state=="brewing": fill=lerpf(0.32,0.82,clampf(float(visual.get("elapsed",0))/maxf(0.1,float(visual.get("target",3))),0,1))
		var height := (cup.size.y-14)*fill
		var region := Rect2(cup.position+Vector2(6,cup.size.y-7-height),Vector2(cup.size.x-12,height))
		if state in ["brewing","stopped","complete"]:
			draw_style_box(DrinkArt.box(liquid_color(),liquid_color(),0),region)
		else:
			for i in range(liquids.size()):
				var layer := Rect2(region.position+Vector2(0,height*i/liquids.size()),Vector2(region.size.x,height/liquids.size()+1))
				draw_rect(layer,Color(DrinkArt.COLORS[liquids[i]]))
		if "Milk" in ingredients:
			for i in range(5):
				draw_circle(region.position+Vector2(9+14*i,3),6,Color("fff6e7"))
	if valid and "Ice" in ingredients:
		for p in [Vector2(-20,21),Vector2(4,32),Vector2(-7,5)]:
			draw_style_box(DrinkArt.box(Color("d8edf0"),Color("a1c6ce"),2),Rect2(center+p,Vector2(19,18)))
	if valid and "Tea" in ingredients:
		draw_line(cup.position+Vector2(45,0),center+Vector2(15,7),ink,2,true)
		draw_style_box(DrinkArt.box(Color("e5bd73"),ink,1),Rect2(center+Vector2(7,5),Vector2(17,22)))
	if valid and "Berries" in ingredients:
		for p in [Vector2(-22,32),Vector2(7,16),Vector2(-10,5)]: draw_circle(center+p,5,Color("ae567e"))
	if valid and "Cocoa" in ingredients:
		for p in [Vector2(-27,-12),Vector2(17,0),Vector2(-5,30)]: draw_circle(center+p,2,Color("704431"))
	if valid and "Honey" in ingredients:
		draw_line(center+Vector2(-23,-16),center+Vector2(-13,32),Color("d59c38"),4,true)
	if valid and "Vanilla" in ingredients:
		draw_line(center+Vector2(22,-18),center+Vector2(15,28),Color("f3d696"),4,true)
	# Pour/stir/steep animations depend only on authoritative elapsed preparation.
	if state=="brewing":
		var elapsed: float=visual.get("elapsed",0)
		if category=="Coffee":
			draw_line(Vector2(center.x,cup.position.y-12),Vector2(center.x,cup.position.y+32),liquid_color(),5,true)
		else:
			var point := center+Vector2(cos(elapsed*5)*23,sin(elapsed*5)*6)
			draw_line(point-Vector2(0,55),point,Color("ac8061"),4,true)
		for i in range(3):
			draw_circle(center+Vector2(-25+i*23,20-sin(elapsed*4+i)*12),2,Color("fff6e7"))
	if state=="complete" and float(visual.get("celebration",0))<2:
		for p in [Vector2(-64,-35),Vector2(65,-14),Vector2(58,43)]:
			var at: Vector2 = center+p
			draw_line(at-Vector2(0,6),at+Vector2(0,6),Color("d69e43"),3,true)
			draw_line(at-Vector2(6,0),at+Vector2(6,0),Color("d69e43"),3,true)
	if miniature:
		draw_set_transform(Vector2.ZERO)
		return
	# A linear timeline, not a new timing window: ideal target is exactly halfway.
	var track := Rect2(24,156,272,8)
	draw_style_box(DrinkArt.box(Color("e0cbb7"),ink,1),track)
	var ratio := clampf(float(visual.get("elapsed",0))/(maxf(0.1,float(visual.get("target",3)))*2),0,1)
	draw_rect(Rect2(track.position,Vector2(track.size.x*ratio,track.size.y)),Color("9cbea5"))
	draw_line(Vector2(160,152),Vector2(160,168),ink,3)
	draw_set_transform(Vector2.ZERO)

func _update_labels() -> void:
	if recipe_label==null:return
	for label in [recipe_label,timing_label]:label.visible=not miniature
	recipe_label.text=visual.get("recipe_name","Choose an order")
	recipe_label.position=Vector2(4,0)/pixel_scale
	recipe_label.size=Vector2(size.x-8.0/pixel_scale,maxf(44,24.0/pixel_scale))
	recipe_label.add_theme_font_size_override("font_size",ceili(maxf(28,16.0/pixel_scale)))
	timing_label.position=Vector2(4.0/pixel_scale,size.y-maxf(36,24.0/pixel_scale))
	timing_label.size=Vector2(size.x-8.0/pixel_scale,maxf(36,24.0/pixel_scale))
	timing_label.add_theme_font_size_override("font_size",ceili(maxf(24,14.0/pixel_scale)))
	match visual.get("state","empty"):
		"brewing": timing_label.text="%.1fs / %.1fs · Stop at the marker" % [visual.get("elapsed",0),visual.get("target",3)]
		"stopped": timing_label.text="Process stopped · Assemble drink"
		"complete": timing_label.text="%s · Return to café to serve" % visual.get("quality_tier","Ready")
		"departed": timing_label.text="Guest left · Select another order"
		"unavailable": timing_label.text="Select the matching station"
		_: timing_label.text="Select ingredients · Target %.1fs" % visual.get("target",3)
