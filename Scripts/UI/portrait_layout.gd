extends Control
## Keep the portrait content centered on wider screens; containers handle vertical space.
@onready var content: MarginContainer = $Content

func _ready() -> void:
	resized.connect(_update_layout)
	_update_layout()

func _update_layout() -> void:
	var content_width := minf(size.x, 720.0)
	content.position = Vector2((size.x - content_width) / 2.0, 0)
	content.size = Vector2(content_width, size.y)
