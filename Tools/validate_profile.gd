extends SceneTree
## Persistent tests use only unique temporary paths. Never open the real player save.
const SESSION := preload("res://Scenes/Gameplay/CafeSession.tscn")
const MAIN := preload("res://Scenes/Main.tscn")
var folder := "/tmp/paw-profile-tests-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
var checks := 0
var failures := 0
var serial := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func path_for(name: String) -> String:
	serial += 1
	return folder.path_join("%d-%s/profile.json" % [serial,name])

func write_raw(path: String, value: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	assert(file != null)
	file.store_string(value)
	file.close()

func load_profile(path: String) -> CafeProfile:
	var profile := CafeProfile.new()
	profile.open(path)
	return profile

func make_session(profile: CafeProfile, immediate: bool = false) -> CafeSession:
	var s := SESSION.instantiate() as CafeSession
	s.profile = profile
	s.start_immediately = immediate
	s.cat_effects_enabled = false
	s.recipe_override = "basic_coffee"
	s.normal_arrival_interval = Vector2(1000,1000)
	s.rush_arrival_interval = Vector2(1000,1000)
	root.add_child(s)
	s.set_process(false)
	return s

func ready_drink(s: CafeSession, id: int) -> void:
	s.open_order(id)
	s.accept_order()
	s.open_station()
	s.select_station_order(id)
	for ingredient in s.get_order(id).recipe.ingredients:
		s.toggle_ingredient(ingredient)
	s.start_brewing()
	s.advance_time(s.preparation_target())
	s.stop_preparation()
	s.finish_coffee()

func run() -> void:
	defaults_and_progression()
	storage_and_recovery()
	receipts_and_shifts()
	write_failure_transactions()
	await profile_ui()
	if failures == 0:
		print("PASS: %d persistent profile assertions (isolated paths: %s)" % [checks,folder])
	quit(0 if failures == 0 else 1)

func defaults_and_progression() -> void:
	var p := CafeProfile.new()
	check(p.coins==120 and p.level==1 and p.xp==0 and p.completed_days==0 and p.team_slots==["mochi","fade","max"], "Default permanent profile")
	for pair in [[1,75],[2,95],[10,255],[25,555],[49,1035]]:
		check(CafeProfile.required_xp(pair[0])==pair[1], "XP threshold at level %d" % pair[0])
	check(p.grant_xp(74) and p.level==1 and p.xp==74, "Below first threshold")
	check(p.grant_xp(1) and p.level==2 and p.xp==0, "Exact first threshold")
	check(p.grant_xp(100) and p.level==3 and p.xp==5, "Carry excess XP")
	var before := p.snapshot()
	for invalid in [-1,1.5,"15",null,true,INF,NAN]:
		check(not p.grant_xp(invalid) and p.snapshot()==before, "Invalid XP rejected: " + str(invalid))
	var maxed := CafeProfile.new()
	check(maxed.grant_xp(27195+2500) and maxed.level==50 and maxed.xp==0 and maxed.cycles==2 and maxed.cycle_xp==500, "One grant supports all levels and multiple max-level cycles")
	check(maxed.tickets==3 and maxed.snapshot().welcome_granted and maxed.snapshot().welcome_processed, "One welcome plus two cycle ticket entitlements")
	check(maxed.grant_xp(500) and maxed.cycles==3 and maxed.cycle_xp==0 and maxed.tickets==4, "Exactly 1000 completes one repeat cycle")
	check(maxed.grant_xp(0) and maxed.tickets==4, "Zero grant cannot duplicate entitlements")
	var entitlements := maxed.pending_entitlements()
	check(entitlements.welcome_id=="" and entitlements.cycle_last==3 and entitlements.cycle_count==0 and maxed.snapshot().resolved_cycles==3, "Entitlements have stable compact identities")
	maxed.begin_shift()
	check(maxed.tickets==4 and maxed.cycles==3, "Starting a shift cannot duplicate or reset entitlements")
	for i in range(10):
		var normalized := CafeProfile.normalize(maxed.snapshot())
		check(normalized.ok and normalized.data.pending_cycle_tickets==0 and normalized.data.welcome_processed and normalized.data.lottery_tickets==4, "Repeated normalization cannot repeat welcome/cycle rewards")
	var almost := CafeProfile.new()
	almost.grant_xp(27194)
	check(almost.level==49 and almost.xp==1034, "Level 49 exact pre-cap boundary")
	almost.grant_xp(1)
	check(almost.level==50 and almost.cycle_xp==0 and almost.tickets==1, "Level 50 welcome has no premature repeat cycle")

func storage_and_recovery() -> void:
	var path := path_for("roundtrip")
	var p := load_profile(path)
	check(p.coins==120 and not FileAccess.file_exists(path), "Missing save creates valid defaults without overwriting anything")
	check(p.set_team(["odin","momo","blaze"]), "Team save succeeds")
	var shift := p.begin_shift()
	check(shift>0 and p.apply_service(shift,1,16,15), "Service transaction persists")
	var loaded := load_profile(path)
	check(loaded.snapshot()==p.snapshot() and loaded.coins==136 and loaded.team_slots==["odin","momo","blaze"], "Full save/load round trip")
	check(FileAccess.file_exists(path+".bak") and not FileAccess.file_exists(path+".tmp"), "Valid backup retained, staged file promoted")
	check(not loaded.apply_service(shift,1,16,15) and loaded.coins==136, "Reloaded receipt rejects duplicate service")
	loaded.grant_xp(27195+2100)
	var pending := loaded.tickets
	for i in range(4):
		loaded = load_profile(path)
		check(loaded.level==50 and loaded.tickets==pending and loaded.cycles==2, "Durable welcome/cycle entitlements survive reload")
	# Primary corrupted: recover last valid checkpoint and retain the bad bytes.
	var backup_text := FileAccess.get_file_as_string(path+".bak")
	write_raw(path,"{broken")
	var recovered := load_profile(path)
	check(not recovered.diagnostic.is_empty() and recovered.snapshot()==CafeProfile.normalize(JSON.parse_string(backup_text)).data, "Corrupt primary recovers validated backup")
	check(FileAccess.get_file_as_string(path)=="{broken", "Loading does not overwrite corrupt primary")
	check(recovered.set_team(["max","fade","mochi"]), "Recovered profile can save safely")
	var archives := 0
	for name in DirAccess.get_files_at(path.get_base_dir()):
		if name.begins_with("profile.json.corrupt-"):
			archives += 1
	check(archives>0 and FileAccess.get_file_as_string(path+".bak")==backup_text, "Damaged primary archived, valid backup preserved")
	var partial_backup_path := path_for("partial-with-backup")
	var rich := load_profile(partial_backup_path)
	rich.grant_xp(90)
	rich.begin_shift()
	write_raw(partial_backup_path,"{}")
	var partial_recovery := load_profile(partial_backup_path)
	check(partial_recovery.level==2 and partial_recovery.xp==15 and partial_recovery.diagnostic.contains("backup"), "Partial primary prefers complete backup over silently defaulting progress")
	check(FileAccess.get_file_as_string(partial_backup_path)=="{}", "Partial primary retained on load")
	var preserved_backup := FileAccess.get_file_as_string(partial_backup_path+".bak")
	partial_recovery.set_team(["odin","momo","blaze"])
	check(FileAccess.get_file_as_string(partial_backup_path+".bak")==preserved_backup, "Repair cannot replace a complete backup with partial data")
	# Both missing backup and corrupt primary still preserve evidence when replacing.
	var corrupt_path := path_for("corrupt-only")
	write_raw(corrupt_path,"not JSON")
	var fallback := load_profile(corrupt_path)
	check(fallback.coins==120 and not fallback.diagnostic.is_empty(), "No valid backup gives diagnosed defaults")
	check(fallback.grant_xp(5), "Defaults can establish a valid save")
	archives=0
	for name in DirAccess.get_files_at(corrupt_path.get_base_dir()):
		if name.contains(".corrupt-"):
			archives+=1
	check(archives==1, "Original corrupt save retained for recovery")
	# Missing primary and malformed/unsupported backup paths remain recoverable.
	var missing_primary := path_for("backup-only")
	write_raw(missing_primary+".bak",JSON.stringify(p.snapshot()))
	var backup_only := load_profile(missing_primary)
	check(backup_only.coins==136 and not backup_only.diagnostic.is_empty(), "Missing primary recovers backup")
	var unknown_backup := path_for("future-backup")
	write_raw(unknown_backup+".bak",JSON.stringify({"schema_version":999}))
	var preserved := load_profile(unknown_backup)
	check(not preserved.writable and not preserved.grant_xp(1), "Future-schema backup is preserved and write-blocked")
	# Schema and field recovery.
	var partial_path := path_for("legacy")
	write_raw(partial_path,JSON.stringify({"schema_version":0,"coins":230,"level":2,"xp":10,"team":["odin","odin","bad"]}))
	var migrated := load_profile(partial_path)
	check(migrated.coins==230 and migrated.level==2 and migrated.xp==10 and migrated.completed_days==0 and migrated.team_slots==["odin","mochi","fade"], "Legacy/missing fields and invalid team migrate safely")
	check(not migrated.diagnostic.is_empty() and migrated.grant_xp(1) and load_profile(partial_path).snapshot().schema_version==CafeProfile.VERSION, "Migration saved in current schema")
	for fixture in [{"coins":-1},{"level":51},{"xp":-1},{"coins":"money"},{"served_order_ids":[1,1]},{"cycle_xp":10},{"pending_welcome_ticket":true}]:
		var normalized := CafeProfile.normalize(fixture)
		check(not normalized.ok, "Invalid field rejected: " + str(fixture))
	var future_path := path_for("future")
	var future_text := JSON.stringify({"schema_version":999,"coins":999})
	write_raw(future_path,future_text)
	var future := load_profile(future_path)
	check(not future.writable and not future.grant_xp(5) and FileAccess.get_file_as_string(future_path)==future_text, "Future schema is preserved and write-blocked")
	# Never replay an uncommitted staged service after a crash.
	var stage_path := path_for("uncommitted")
	write_raw(stage_path+".tmp",JSON.stringify(p.snapshot()))
	var staged := load_profile(stage_path)
	check(staged.coins==120 and staged.xp==0, "Orphan staged write is not treated as a committed reward")
	check(staged.grant_xp(1), "Fresh transaction can recover with an orphan stage present")

func receipts_and_shifts() -> void:
	var path := path_for("session")
	var p := load_profile(path)
	var s := make_session(p)
	check(s.view==CafeSession.View.LOBBY and s.active_count()==0 and s.day==1 and s.elapsed==0, "Before Day 1, no customers or running clock")
	s.advance_time(100)
	check(s.elapsed==0 and s.active_count()==0, "Lobby does not advance shift")
	s.open_team()
	check(s.can_edit_team() and s.assign_cat(0,"odin"), "Team editable before first day")
	s.back_to_cafe()
	s.start_next_day()
	var first_shift := s.shift_id
	check(first_shift>0 and s.active_count()==1 and s.phase==CafeSession.Phase.OPENING, "Start allocates durable shift ID")
	ready_drink(s,1)
	s.open_order(1)
	s.serve()
	s.serve()
	check(s.coins==131 and s.profile.xp==15 and s.served==1 and s.earned==11, "Profile is authoritative; service pays once")
	var snapshot := p.snapshot()
	s.free() # Abrupt mid-shift scene exit; no day completed.
	var reload := load_profile(path)
	check(reload.coins==131 and reload.xp==15 and reload.completed_days==0, "Mid-shift relaunch preserves only committed rewards")
	var fresh := make_session(reload)
	check(fresh.view==CafeSession.View.LOBBY and fresh.orders.is_empty() and fresh.team.slots[0]=="odin", "No unfinished customers/drinks restored; team restored")
	fresh.start_next_day()
	check(fresh.shift_id!=first_shift and fresh.get_order(1).state==CafeSession.State.WAITING_ORDER, "Fresh shift/order state with a new durable identity")
	check(not reload.apply_service(first_shift,1,11,15), "Old-scene receipt cannot reward new session")
	fresh.advance_time(400)
	check(fresh.view==CafeSession.View.RESULTS and reload.completed_days==1 and fresh.coins==131, "Day completion commits once without re-awarding service")
	reload.complete_shift(fresh.shift_id)
	check(reload.completed_days==1, "Repeated completion idempotent")
	fresh.start_next_day()
	fresh.start_next_day()
	check(fresh.day==2 and reload.completed_days==1 and fresh.coins==131, "Next day never duplicates previous totals")
	fresh.free()
	check(load_profile(path).completed_days==1, "Completed days durable after exit")
	# Invalid currency mutations cannot change balances or receipts.
	var bad := CafeProfile.new()
	var id := bad.begin_shift()
	for amount in [-1,1.5,"10",INF]:
		check(not bad.apply_service(id,1,amount,5) and bad.coins==120, "Invalid Coin reward rejected")

func write_failure_transactions() -> void:
	var path := path_for("failure")
	var p := load_profile(path)
	var s := make_session(p)
	var obstruction := path.get_base_dir().path_join("file-not-directory")
	write_raw(obstruction,"block")
	p.store.path = obstruction.path_join("profile.json")
	s.start_next_day()
	check(s.view==CafeSession.View.LOBBY and s.active_count()==0 and s.shift_id==0, "Failed shift checkpoint cannot start a day")
	p.store.path = path
	s.start_next_day()
	ready_drink(s,1)
	p.store.path = obstruction.path_join("profile.json")
	s.open_order(1)
	s.serve()
	check(s.get_order(1).state==CafeSession.State.DRINK_READY and s.coins==120 and s.profile.xp==0 and s.served==0, "Failed service commit leaves drink ready and awards nothing")
	p.store.path = path
	s.serve()
	check(s.coins==131 and s.served==1, "Retry service commits exactly once")
	p.store.path = obstruction.path_join("profile.json")
	s.advance_time(400)
	check(s.view==CafeSession.View.RESULTS and s.completion_pending and p.completed_days==0, "Failed completion is explicitly pending")
	p.store.path = path
	s.start_next_day()
	check(s.day==2 and p.completed_days==1 and not s.completion_pending, "Retry completion counts once before next day")
	s.free()

func settle() -> void:
	for frame in range(8):
		await process_frame

func click(button: Button, touch: bool, scroll: ScrollContainer = null) -> void:
	if scroll!=null:
		scroll.ensure_control_visible(button)
		await settle()
	check(button.is_visible_in_tree() and not button.disabled,"Enabled profile input " + button.name)
	var position := button.get_global_rect().get_center()
	for pressed in [true,false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.index=0
			event.position=root.get_final_transform()*position
			event.pressed=pressed
			Input.parse_input_event(event)
		else:
			var event := InputEventMouseButton.new()
			event.button_index=MOUSE_BUTTON_LEFT
			event.position=position
			event.pressed=pressed
			root.push_input(event,true)
	await settle()

func profile_ui() -> void:
	root.content_scale_size=Vector2i(720,1280)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	for dimensions in [Vector2i(720,1280),Vector2i(320,568)]:
		root.size=dimensions
		var touch: bool = dimensions.x==320
		var path := path_for("ui")
		var p := load_profile(path)
		var main := MAIN.instantiate() as Control
		var s := main.get_node("CafeSession") as CafeSession
		s.profile=p
		s.cat_effects_enabled=false
		s.recipe_override="basic_coffee"
		s.normal_arrival_interval=Vector2(1000,1000)
		root.add_child(main)
		s.set_process(false)
		await settle()
		var view := main.get_node("GameplayView")
		var lobby := view.get_node("DayLobby/Content/Layout")
		check(s.view==CafeSession.View.LOBBY and view.get_node("DayLobby").visible,"Initial pre-day interface")
		check_panel(main,lobby)
		await click(lobby.get_node("Settings"),touch)
		await click(main.get_node("SettingsPanel/Center/Panel/Margins/Layout/Close"),touch)
		check(root.gui_get_focus_owner()==lobby.get_node("Settings"),"Lobby Settings focus restored")
		await click(lobby.get_node("CatTeam"),touch)
		var team := view.get_node("CatTeamScreen")
		await click(team.cards["odin"].get_node("Assign"),touch,team.get_node("Content/Layout/Scroll"))
		await click(team.get_node("Content/Layout/Back"),touch)
		check(s.team.slots[0]=="odin" and load_profile(path).team_slots[0]=="odin","Pre-Day 1 team change saved through input")
		await click(lobby.get_node("Action"),touch)
		p.grant_xp(74)
		ready_drink(s,1)
		await settle()
		check_cafe_interactions(main)
		s.open_order(1)
		s.serve()
		await settle()
		check(p.level==2 and p.xp==14 and main.get_node("Content/Layout/TopHUD/StatsRow/Level").text=="Level\n2","Service levels up and updates HUD")
		s._arrive()
		s._arrive()
		await settle()
		check_cafe_interactions(main)
		var xp_label := main.get_node("Content/Layout/Welcome") as Label
		check(xp_label.visible and xp_label.text.contains("14/95") and xp_label.get_theme_font_size("font_size")*main.ui_scale>=16,"Reputation progress visible/readable")
		s.advance_time(400)
		await settle()
		check_panel(main,view.get_node("DayResults/Content/Layout"))
		check(view.get_node("DayResults/Content/Layout/Description").text.contains("Gained 1"),"Results show gained level")
		var completed_snapshot := p.snapshot()
		p.grant_xp(27195+2100)
		await settle()
		check_panel(main,view.get_node("DayResults/Content/Layout"))
		check(p.level==50 and view.get_node("DayResults/Content/Layout/Description").text.contains("Cycle"), "Level 50 results show repeat-cycle progress")
		main.queue_free()
		await process_frame
		var restored := load_profile(path)
		check(restored.snapshot()==p.snapshot() and completed_snapshot.level==2 and completed_snapshot.xp==14 and restored.completed_days==1,"UI shift survives full profile reload")
		print("PASS profile UI at ",dimensions)

func check_panel(main: Control, layout: VBoxContainer) -> void:
	var bounds := Rect2(Vector2.ZERO,main.size)
	for name in ["Heading","Patience","Description","Action","CatTeam","Settings"]:
		var control := layout.get_node(name) as Control
		check(bounds.encloses(control.get_global_rect()),"Progression control in viewport " + name)
		if control is Button:
			check(control.size.y*main.ui_scale>=44 and control.size.x*main.ui_scale>=44,"Progression touch target " + name)
		else:
			check(control.get_theme_font_size("font_size")*main.ui_scale>=16,"Progression readable " + name)

func check_cafe_interactions(main: Control) -> void:
	var view := main.get_node("GameplayView")
	for name in ["Customer","CustomerRight","CoffeeEquipment"]:
		var button := view.get_node(name) as Button
		if button.is_visible_in_tree():
			check(not view.get_node("Status").get_global_rect().intersects(button.get_global_rect()),"Progression HUD leaves café interaction accessible: "+name)
