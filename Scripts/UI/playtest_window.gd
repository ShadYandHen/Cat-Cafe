extends RefCounted
## Windows playtest exports only; leave Android, editor, CLI sizing and viewport intact.
static func fitted_size(usable: Vector2i) -> Vector2i:
	var height := minf(720,minf(usable.y*0.9,usable.x*0.9/(1280.0/720.0)))
	return Vector2i(roundi(height*1280.0/720.0),roundi(height))
static func configure(window: Window) -> void:
	if not OS.has_feature("windows") or not OS.has_feature("playtest") or OS.has_feature("editor") or window.has_meta("playtest_fitted"):
		return
	for argument in OS.get_cmdline_args():
		if argument.begins_with("--resolution"):return
	var usable := DisplayServer.screen_get_usable_rect()
	if usable.size.x<1 or usable.size.y<1:return
	window.set_meta("playtest_fitted",true)
	window.size=fitted_size(usable.size)
	window.position=usable.position+(usable.size-window.size)/2
