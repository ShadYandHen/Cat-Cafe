extends Control
## Landscape presentation only. Uniform stage scale preserves artwork proportions.
const DESIGN_SIZE:=Vector2(1280,520)
const INK:=Color("805b46")
const CREAM:=Color("fff6e7")
const MINT:=Color("b8d3bd")
const PINK:=Color("eac1c4")
var active_cat_id:=""
func _ready() -> void:
	$Stage/Counter.draw.connect(_draw_counter.bind($Stage/Counter))
	resized.connect(_update_stage)
	_update_stage()
func _update_stage() -> void:
	var factor:=minf(size.x/DESIGN_SIZE.x,size.y/DESIGN_SIZE.y)
	$Stage.position=(size-DESIGN_SIZE*factor)/2
	$Stage.scale=Vector2.ONE*factor
	queue_redraw()
func set_barista(cat: Dictionary) -> void:
	if active_cat_id==cat.id:return
	active_cat_id=cat.id
	$Stage/Barista.texture=load(cat.artwork)
	$Stage/Barista.tooltip_text=cat.name+" · Active barista"
func rounded(box: Rect2,color: Color,radius: int=16) -> void:
	var style:=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(radius)
	style.border_color=INK
	style.set_border_width_all(3)
	draw_style_box(style,box)
func _draw() -> void:
	var factor:=minf(size.x/DESIGN_SIZE.x,size.y/DESIGN_SIZE.y)
	draw_set_transform((size-DESIGN_SIZE*factor)/2,0,Vector2.ONE*factor)
	rounded(Rect2(4,4,1272,512),CREAM,28)
	rounded(Rect2(12,12,1256,350),Color("f6e1c8"),24)
	for x in range(28,1260,36):draw_line(Vector2(x,20),Vector2(x,360),Color("eed4b9"),2)
	rounded(Rect2(14,365,1252,142),Color("dfb58e"),20)
	for y in [400,450,500]:draw_line(Vector2(20,y),Vector2(1260,y),Color("c79b79"),2)
	rounded(Rect2(475,24,330,235),Color("c3dedb"),32)
	draw_circle(Vector2(734,65),25,Color("fff3c1"))
	draw_line(Vector2(640,28),Vector2(640,245),CREAM,8)
	draw_line(Vector2(480,130),Vector2(800,130),CREAM,8)
	for x in [72,1002]:
		rounded(Rect2(x,125,204,14),Color("b78865"),6)
		for cup in [x+20,x+80,x+140]:
			rounded(Rect2(cup,89,27,35),CREAM,7)
			draw_arc(Vector2(cup+28,107),8,-PI/2,PI/2,12,INK,3)
	for x in [395,885]:
		draw_line(Vector2(x,16),Vector2(x,45),INK,3)
		draw_circle(Vector2(x,67),25,Color("e9b87b"))
		draw_circle(Vector2(x,68),18,Color("fff0ba"))
	for x in [32,1215]:
		rounded(Rect2(x,281,30,37),PINK,8)
		for offset in [Vector2(-6,-8),Vector2(22,-16),Vector2(10,-34)]:draw_circle(Vector2(x+8,280)+offset,15,Color("9abd9b"))
	for x in [330,950]:
		rounded(Rect2(x-78,409,156,95),Color("cb9c79"),24)
		rounded(Rect2(x-70,415,140,42),PINK,23)
		rounded(Rect2(x-86,488,172,18),Color("a97a5b"),10)
func _draw_counter(canvas: Control) -> void:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("bd8c67")
	style.border_color=INK
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	canvas.draw_style_box(style,Rect2(18,285,1244,95))
	for x in [40,350,660,970]:
		style.bg_color=Color("d7ad88")
		canvas.draw_style_box(style,Rect2(x,302,270,60))
	style.bg_color=Color("f1cb9f")
	canvas.draw_style_box(style,Rect2(8,270,1264,25))
