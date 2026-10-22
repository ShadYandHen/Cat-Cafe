extends SceneTree
## Step 14 defaults, real scheduler boundaries, patience and portrait input.
const PROBE := preload("res://Tools/balance_session_probe.gd")
const MAIN := preload("res://Scenes/Main.tscn")
var checks := 0
var failures := 0
var folder := "/tmp/paw-14-regression-%d" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fixture(effects: bool = false, team: Array = ["mochi","fade","max"], seating: int = 0) -> CafeSession:
	var s := PROBE.new() as CafeSession
	s.profile = CafeProfile.new()
	var data := s.profile.snapshot()
	data.level = 4
	data.team = team
	data.upgrades.comfortable_seating = seating
	check(s.profile._commit(data), "Isolated fixture profile")
	s.cat_effects_enabled = effects
	s.start_immediately = true
	s.recipe_override = "basic_coffee"
	root.add_child(s)
	s.set_process(false)
	return s

func prepare(s: CafeSession, id: int) -> void:
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
	DirAccess.make_dir_recursive_absolute(folder)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--cold-read="):
			cold_read(argument.trim_prefix("--cold-read="))
			finish()
			return
	defaults_and_intervals()
	boundaries()
	seats_and_service()
	patience()
	reload_and_migration()
	await ui()
	finish()

func finish() -> void:
	print("%s: %d balanced pacing assertions; isolated %s" % ["PASS" if failures==0 else "FAIL",checks,folder])
	quit(0 if failures==0 else 1)

func defaults_and_intervals() -> void:
	var s := fixture()
	check(s.patience_seconds==75 and s.get_order(1).original_patience==75, "Base patience 75 before modifiers")
	check(s.normal_arrival_interval==Vector2(20,26) and s.rush_arrival_interval==Vector2(9,12), "Exact approved interval endpoints")
	check(s.day_seconds==300 and s.rush_start==120 and s.rush_end==180 and s.seats.size()==2, "Shift and seat structure unchanged")
	for phase in [CafeSession.Phase.OPENING,CafeSession.Phase.RUSH,CafeSession.Phase.LATE_SERVICE]:
		s.phase = phase
		var samples: Array = []
		var lower := 9.0 if phase==CafeSession.Phase.RUSH else 20.0
		var upper := 12.0 if phase==CafeSession.Phase.RUSH else 26.0
		for i in range(1000):
			var value := s._interval()
			check(value>=lower and value<=upper, "Independent sampled interval stays within approved bounds")
			samples.append(value)
		check(samples.min()<lower+.05 and samples.max()>upper-.05, "Seeded samples cover both interval limits")
		check(samples[0]!=samples[1] and samples[1]!=samples[2], "Arrival intervals remain randomized")
		s.normal_arrival_interval=Vector2(20,26)
		s.rush_arrival_interval=Vector2(9,12)
	# Test sampler endpoint behavior separately without replacing production randomness.
	for value in [20,26]:
		s.phase=CafeSession.Phase.OPENING
		s.normal_arrival_interval=Vector2(value,value)
		check(s._interval()==value, "Normal endpoint accepted")
	for value in [9,12]:
		s.phase=CafeSession.Phase.RUSH
		s.rush_arrival_interval=Vector2(value,value)
		check(s._interval()==value, "Rush endpoint accepted")
	s.free()
	var a := fixture()
	var b := fixture()
	a.advance_time(400)
	for i in range(4000):
		b.advance_time(.1)
	check(a.orders.size()==b.orders.size() and a.lost==b.lost and a.phase==b.phase,"Coarse and fine clock advancement agree")
	check(a.observed_arrivals.keys()==b.observed_arrivals.keys(),"Identical seeds reproduce the same arrivals")
	for id in a.orders:
		check(absf(a.observed_arrivals[id]-b.observed_arrivals[id])<CafeSession.EPSILON,"Arrival timestamps agree within clock epsilon")
		check(is_equal_approx(a.get_order(id).deadline,b.get_order(id).deadline),"Deterministic deadlines")
	a.free()
	b.free()

func boundaries() -> void:
	var s := fixture()
	var transitions: Array = []
	s.phase_changed.connect(func(value): transitions.append(value))
	s.advance_time(119.999)
	s.next_arrival=120 # An old-phase scheduled attempt exactly on boundary.
	var offers: int=s.offered
	s.advance_time(.001)
	check(s.phase==CafeSession.Phase.RUSH and s.elapsed==120,"Rush starts at exact 120s")
	check(s.offered==offers,"Phase transition replaces boundary attempt, no duplicate spawn")
	check(s.next_arrival>=129 and s.next_arrival<=132,"First Rush attempt freshly scheduled 9–12s after boundary")
	s.advance_time(59.999)
	s.next_arrival=180
	offers=s.offered
	s.advance_time(.001)
	check(s.phase==CafeSession.Phase.LATE_SERVICE and s.elapsed==180,"Rush ends at exact 180s")
	check(s.offered==offers and s.next_arrival>=200 and s.next_arrival<=206,"Normal schedule resets without boundary duplication")
	s.advance_time(119.999)
	s.next_arrival=300
	offers=s.offered
	s.advance_time(.001)
	check(s.phase==CafeSession.Phase.SOFT_CLOSING and is_inf(s.next_arrival),"Soft closing stops scheduling at 300s")
	check(s.offered==offers,"No admission on closing boundary")
	var count := s.orders.size()
	s.advance_time(200)
	check(s.phase==CafeSession.Phase.RESULTS and s.orders.size()==count,"Existing guests expire; no post-close arrivals")
	check(transitions==[CafeSession.Phase.RUSH,CafeSession.Phase.LATE_SERVICE,CafeSession.Phase.SOFT_CLOSING,CafeSession.Phase.RESULTS],"Each phase transition occurs once")
	s.free()
	var history := fixture()
	history.advance_time(400)
	var phases: Array=[]
	for id in history.orders:
		check(history.observed_arrivals[id]<300,"All arrivals precede closing")
		check(history.get_order(id).original_patience==75,"Same base patience before, during and after Rush")
		if history.arrival_phases[id] not in phases:
			phases.append(history.arrival_phases[id])
	check(phases==[CafeSession.Phase.OPENING,CafeSession.Phase.RUSH,CafeSession.Phase.LATE_SERVICE],"Customers exercise all service phases")
	history.free()

func seats_and_service() -> void:
	var s := fixture()
	s.advance_time(s.next_arrival)
	check(s.active_count()==2 and s.seats[0]!=s.seats[1],"Two customers occupy unique seats")
	var count := s.orders.size()
	s.advance_time(s.next_arrival-s.elapsed)
	check(s.orders.size()==count and s.skipped==1,"Full-seat attempt skipped without a queue or stacking")
	s.advance_time(75-s.elapsed)
	check(s.get_order(1).state==CafeSession.State.DEPARTED and s.order_at_seat(0)==-1,"Expiration releases seat without immediate replacement")
	s.advance_time(s.next_arrival-s.elapsed)
	check(s.orders.size()==count+1 and s.order_at_seat(0)>2,"Next scheduled attempt reuses the released seat")
	s.free()
	var service := fixture()
	prepare(service,1)
	var next := service.next_arrival
	service.advance_time(next-service.elapsed)
	var before := service.profile.snapshot()
	service.open_order(1)
	service.serve()
	check(service.served==1 and service.coins==int(before.coins)+11,"Exactly one Perfect Basic Coffee payout")
	check(service.next_arrival>service.elapsed,"Service does not restart or duplicate the arrival timer")
	before=service.profile.snapshot()
	service.serve()
	check(service.profile.snapshot()==before,"Repeated callback cannot pay twice")
	service.advance_time(400)
	check(service.profile.completed_days==1,"Day completion still committed once")
	var balance := service.coins
	service.start_next_day()
	check(service.day==2 and service.active_count()==1 and service.coins==balance,"Next day resets temporary state, preserves balance")
	check(service.get_order(1)==null and service.patience_seconds==75,"No stale order restored on next day")
	service.free()

func patience() -> void:
	var plain := fixture()
	var deadline := plain.get_order(1).deadline
	for i in range(10):
		plain.open_order(1)
		plain.accept_order()
		plain.back_to_cafe()
		plain.open_station()
		plain.advance_time(.1)
		plain.back_to_cafe()
	check(plain.get_order(1).deadline==deadline and is_equal_approx(plain.get_order(1).remaining(plain.elapsed),74),"Rapid screens never reset or pause patience")
	plain.advance_time(74)
	check(plain.get_order(1).remaining(plain.elapsed)==0 and plain.get_order(1).state==CafeSession.State.DEPARTED,"Patience clamps at zero on expiration")
	plain.open_order(1)
	plain.serve()
	check(plain.coins==120 and plain.reputation_earned==0,"Expired order cannot award anything")
	plain.free()
	for level in range(4):
		var s := fixture(true,["mochi","fade","max"],level)
		var original := 75*(1.05+level*.03)
		var order := s.get_order(1)
		check(is_equal_approx(order.original_patience,original),"Seating and Mochi modifiers remain additive")
		s.advance_time(original*.7)
		check(s.ability_activations.is_empty(),"Exactly 30% does not trigger care")
		s.advance_time(.001)
		check(s.ability_activations.size()==1 and is_equal_approx(order.deadline,original*1.1),"Care restores 10% of modified original patience")
		check(order.remaining(s.elapsed)<=original,"Restoration never exceeds maximum patience")
		s.advance_time(10)
		check(s.ability_activations.size()==1,"Restored customer's second crossing does not reactivate")
		s.free()

func reload_and_migration() -> void:
	var p := CafeProfile.new()
	p.open(folder.path_join("profile.json"))
	check(p.sync_season() and p.set_team(["odin","momo","blaze"]),"Persistent existing team fixture")
	var s := PROBE.new() as CafeSession
	s.profile=p
	s.start_immediately=true
	root.add_child(s)
	s.set_process(false)
	prepare(s,1)
	s.open_order(1)
	s.serve()
	var saved := p.snapshot()
	var shift := s.shift_id
	s.free()
	var loaded := CafeProfile.new()
	loaded.open(p.store.path)
	check(loaded.snapshot()==saved and not loaded.apply_service(shift,1,12,15,3),"Reload preserves permanent rewards and rejects stale service")
	var fresh := PROBE.new() as CafeSession
	fresh.profile=loaded
	root.add_child(fresh)
	fresh.set_process(false)
	check(fresh.view==CafeSession.View.LOBBY and fresh.active_count()==0,"Relaunch starts lobby, not an unfinished shift")
	fresh.start_next_day()
	check(fresh.get_order(1).original_patience==75,"Existing profile uses new defaults with its saved team")
	fresh.free()
	# Legacy schema migration remains the existing profile implementation.
	var legacy := saved.duplicate(true)
	legacy.schema_version=4
	legacy.erase("ordinary_tip_remainder")
	var normalized := CafeProfile.normalize(legacy)
	check(normalized.ok and normalized.data.coins==saved.coins and normalized.data.team==saved.team and normalized.data.ordinary_tip_remainder==0,"Schema 4 migration retains progression and initializes tip state")
	var legacy_path := folder.path_join("legacy.json")
	var legacy_file := FileAccess.open(legacy_path,FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy));legacy_file.close()
	var migrated := CafeProfile.new()
	migrated.open(legacy_path)
	var replay := PROBE.new() as CafeSession
	replay.profile=migrated
	replay.start_immediately=true
	root.add_child(replay)
	replay.set_process(false)
	var original_coins := migrated.coins
	prepare(replay,1)
	replay.open_order(1)
	replay.serve()
	check(replay.served==1 and migrated.coins>original_coins,"Migrated profile prepares and serves on approved pacing")
	replay.advance_time(400)
	check(migrated.completed_days==1 and migrated.snapshot().schema_version==5,"Migrated profile finishes and persists a day")
	replay.start_next_day()
	check(replay.day==2 and replay.active_count()==1,"Migrated profile starts another day normally")
	replay.free()
	var file := FileAccess.open(folder.path_join("expected.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(loaded.snapshot()));file.close()
	print("COLD_READ_DIR=",folder)

func cold_read(directory: String) -> void:
	check(directory.begins_with("/tmp/paw-14-regression-") and not ".." in directory,"Isolated cold-read path")
	if not directory.begins_with("/tmp/paw-14-regression-") or ".." in directory:
		return
	var expected=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("expected.json")))
	var p := CafeProfile.new()
	p.open(directory.path_join("profile.json"))
	var checkpoint := CafeProfile.normalize(expected)
	check(checkpoint.ok and p.snapshot()==checkpoint.data,"Separate process restores exact normalized service checkpoint")
	check(not p.apply_service(int(expected.open_shift_id),1,100,15,3),"Separate process rejects historical service")
	var s := PROBE.new() as CafeSession
	s.profile=p
	root.add_child(s)
	s.set_process(false)
	s.start_next_day()
	check(s.get_order(1).original_patience==75 and s.next_arrival>=20 and s.next_arrival<=26,"Separate process starts fresh approved schedule")
	s.free()

func settle() -> void:
	for i in range(8):
		await process_frame

func click(button: Button, touch: bool) -> void:
	check(button.is_visible_in_tree() and not button.disabled,"Enabled input "+button.name)
	var position := button.get_global_rect().get_center()
	for pressed in [true,false]:
		if touch:
			var e := InputEventScreenTouch.new()
			e.index=0;e.position=root.get_final_transform()*position;e.pressed=pressed
			Input.parse_input_event(e)
		else:
			var e := InputEventMouseButton.new()
			e.button_index=MOUSE_BUTTON_LEFT;e.position=position;e.pressed=pressed
			root.push_input(e,true)
	await settle()

func ui() -> void:
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	for dimensions in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size=dimensions
		var main := MAIN.instantiate() as Control
		var s := main.get_node("CafeSession") as CafeSession
		s.profile=CafeProfile.new()
		s.start_immediately=true
		root.add_child(main)
		s.set_process(false)
		s.advance_time(s.next_arrival)
		await settle()
		var view := main.get_node("GameplayView")
		var left := view.get_node("Customer") as Button
		var right := view.get_node("CustomerRight") as Button
		check(left.visible and right.visible and not left.get_global_rect().intersects(right.get_global_rect()),"Both seats visible and non-overlapping")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(folder.path_join("cafe-%d.png" % dimensions.x))==OK,"Capture two-seat portrait")
		await click(right,dimensions.x==960)
		var selected := s.get_order(s.selected_order_id)
		var deadline := selected.deadline
		var panel := view.get_node("OrderScreen/Content/Layout")
		check(panel.get_node("Patience").text.contains("patience"),"Patience label remains present")
		await click(panel.get_node("Action"),dimensions.x==960)
		await click(view.get_node("CoffeeEquipment"),dimensions.x==960)
		check(s.view==CafeSession.View.STATION and selected.deadline==deadline,"Station opens without resetting patience")
		main.get_node("SettingsPanel").open()
		s.advance_time(5)
		check(is_equal_approx(selected.remaining(s.elapsed),deadline-s.elapsed),"Settings leaves patience on the authoritative clock")
		main.get_node("SettingsPanel").close()
		check(root.gui_get_focus_owner()!=null,"Settings restores valid keyboard focus")
		var key := InputEventKey.new()
		key.keycode=KEY_ESCAPE;key.pressed=true
		root.push_input(key,true)
		await settle()
		check(s.view==CafeSession.View.CAFE,"Keyboard Back restores café")
		s.advance_time(120-s.elapsed)
		await settle()
		check(view.get_node("Status").text.contains("Rush"),"Rush notification still visible")
		main.free()
		await settle()
		print("PASS balanced portrait ",dimensions)
