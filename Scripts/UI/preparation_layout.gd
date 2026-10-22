extends Control
## Three landscape regions: ingredients / live drink / preparation and navigation.
var pixel_scale:=1.0
func configure(scale_factor: float) -> void:
	pixel_scale=scale_factor
	arrange()
func _ready() -> void:
	resized.connect(arrange)
	$Description.minimum_size_changed.connect(arrange.call_deferred)
	$Description.mouse_filter=Control.MOUSE_FILTER_IGNORE
func place(node: Control, rectangle: Rect2) -> void:
	node.custom_minimum_size=Vector2.ZERO
	node.position=rectangle.position.floor()
	node.size=rectangle.size.floor()
func arrange() -> void:
	if not is_node_ready() or size.x<1:return
	var u:=1.0/pixel_scale
	var gap:=12*u
	var left:=size.x*0.28
	var right_w:=size.x*0.23
	var right:=size.x-right_w
	var center:=left+gap
	var center_w:=right-center-gap
	place($Heading,Rect2(0,0,size.x-130*u,40*u))
	$Heading.add_theme_font_size_override("font_size",ceili(24*u))
	place($Settings,Rect2(size.x-116*u,0,116*u,45*u))
	place($Patience,Rect2(right,68*u,right_w,64*u))
	$Patience.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	$Patience.add_theme_font_size_override("font_size",ceili(18*u))
	place($Stations,Rect2(0,56*u,left,100*u))
	for i in range(4):
		var button: Button=$Stations.get_child(i)
		button.text=["Coffee","Milk","Tea","Cold"][i]
		button.add_theme_font_size_override("font_size",ceili(16*u))
		place(button,Rect2((i%2)*(left+gap)/2,floori(i/2.0)*52*u,(left-gap)/2,48*u))
	place($Description,Rect2(0,168*u,left,84*u))
	$Description.add_theme_font_size_override("font_size",ceili(16*u))
	place($Workspace,Rect2(0,260*u,left,maxf(60*u,size.y-260*u)))
	$Workspace/Body/Ingredients.columns=2
	for button in $Workspace/Body/Ingredients.get_children():
		button.custom_minimum_size.y=ceili(64*u)
		button.configure(pixel_scale)
	place($DrinkWorkspace,Rect2(center,64*u,center_w,size.y-80*u))
	$DrinkWorkspace.pixel_scale=pixel_scale
	place($OrderChoices,Rect2(right,148*u,right_w,116*u))
	$OrderChoices.add_theme_constant_override("separation",8*u)
	for button in $OrderChoices.get_children():
		button.custom_minimum_size.y=52*u
		button.add_theme_font_size_override("font_size",ceili(16*u))
	place($Action,Rect2(right,size.y-148*u,right_w,64*u))
	place($Back,Rect2(right,size.y-60*u,right_w,48*u))
	for button in [$Action,$Back,$Settings]:button.add_theme_font_size_override("font_size",ceili(18*u))
