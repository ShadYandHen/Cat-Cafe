extends RefCounted
## Side navigation and full-height content, preserving existing scene paths and handlers.
static func put(node: Control, box: Rect2) -> void:
	node.custom_minimum_size=Vector2.ZERO
	node.position=box.position.floor()
	node.size=box.size.floor()

static func arrange(layout: Control, factor: float) -> void:
	var u:=1.0/factor
	var w:=layout.size.x
	var h:=layout.size.y
	if w<1 or h<1:return
	for grid in layout.find_children("*","GridContainer",true,false):
		for card in grid.get_children():card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var gap:=12*u
	var sidebar:=minf(w*0.29,330*u)
	var right:=sidebar+gap
	var content_w:=w-right
	put(layout.get_node("Heading"),Rect2(0,0,sidebar,52*u))
	layout.get_node("Heading").add_theme_font_size_override("font_size",ceili(24*u))
	var status:=layout.get_node_or_null("Status") as Label
	if status:
		put(status,Rect2(0,64*u,sidebar,h-260*u))
		status.add_theme_font_size_override("font_size",ceili(16*u))
	if layout.has_node("Tabs"):put(layout.get_node("Tabs"),Rect2(right,0,content_w,48*u))
	if layout.has_node("Scroll"):
		var y:=60*u if layout.has_node("Tabs") else 0.0
		put(layout.get_node("Scroll"),Rect2(right,y,content_w,h-y))
	put(layout.get_node("Settings"),Rect2(0,h-108*u,sidebar,48*u))
	put(layout.get_node("Back"),Rect2(0,h-48*u,sidebar,48*u))

static func dialog(layout: Control, factor: float) -> void:
	var u:=1.0/factor
	var w:=layout.size.x
	var h:=layout.size.y
	var right:=w*0.65
	var button_w:=w-right
	for name in ["SpaceAbove","SpaceBelow","Progress"]:
		if layout.has_node(name):layout.get_node(name).hide()
	layout.get_node("Heading").add_theme_font_size_override("font_size",ceili(24*u))
	layout.get_node("Patience").add_theme_font_size_override("font_size",ceili(16*u))
	put(layout.get_node("Heading"),Rect2(0,0,w,42*u))
	put(layout.get_node("Patience"),Rect2(0,46*u,w,64*u))
	put(layout.get_node("Description"),Rect2(0,120*u,right-24*u,h-130*u))
	layout.get_node("Description").vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	layout.get_node("Description").add_theme_font_size_override("font_size",ceili(18*u))
	var names: Array=["Action","CatTeam","Shop","Settings","Back"] if layout.has_node("CatTeam") else ["Action","Settings","Back"]
	var y:=maxf(130*u,(h-names.size()*60*u)/2)
	for name in names:
		put(layout.get_node(name),Rect2(right,y,button_w,48*u))
		layout.get_node(name).add_theme_font_size_override("font_size",ceili(18*u))
		y+=60*u
