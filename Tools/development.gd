extends SceneTree
## Editor CLI only; production scenes never preload or reference this harness.
const MODEL := preload("res://Tools/development_profile.gd")
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not MODEL.permitted():
		push_error("Development harness is unavailable in exports or normal player startup")
		quit(1)
		return
	var arguments := OS.get_cmdline_user_args()
	var slot := "scratch"
	for argument in arguments:
		if argument.begins_with("--slot="):
			slot=argument.trim_prefix("--slot=")
	var model := MODEL.new(slot)
	if model.profile==null:
		push_error(model.error)
		quit(1)
		return
	var launch := false
	for argument in arguments:
		if argument.begins_with("--slot=") or argument=="--show":
			continue
		var success := false
		if argument=="--reset":
			success=model.reset()
		elif argument=="--launch":
			launch=true
			success=true
		elif argument.begins_with("--coins="):
			var value := argument.trim_prefix("--coins=")
			success=value.is_valid_int() and model.set_coins(int(value))
		elif argument.begins_with("--reputation="):
			var parts := argument.trim_prefix("--reputation=").split(":")
			success=parts.size()==2 and parts[0].is_valid_int() and parts[1].is_valid_int() and model.set_reputation(int(parts[0]),int(parts[1]))
		elif argument.begins_with("--season-xp="):
			var value := argument.trim_prefix("--season-xp=")
			success=value.is_valid_int() and model.set_seasonal_xp(int(value))
		elif argument.begins_with("--tickets="):
			var value := argument.trim_prefix("--tickets=")
			success=value.is_valid_int() and model.grant_tickets(int(value))
		elif argument.begins_with("--cycles="):
			var value := argument.trim_prefix("--cycles=")
			success=value.is_valid_int() and model.simulate_cycles(int(value))
		elif argument.begins_with("--advance="):
			var value := argument.trim_prefix("--advance=")
			success=value.is_valid_int() and model.advance(int(value))
		elif argument.begins_with("--boundary="):
			success=model.boundary(argument.trim_prefix("--boundary="))
		if not success:
			push_error("Invalid development action: %s — %s" % [argument,model.error])
			quit(1)
			return
	print(JSON.stringify(model.inspect(),"  "))
	if launch:
		root.get_node("PlayerProfile").profile=model.profile
		# Keep the RefCounted owner of the injected clock alive for the whole session.
		set_meta("development_profile",model)
		root.title="[DEVELOPMENT ONLY] Paw Pads Café — "+slot
		print("DEVELOPMENT ONLY — isolated save: ",model.path())
		change_scene_to_file("res://Scenes/Title.tscn")
	else:
		quit()
