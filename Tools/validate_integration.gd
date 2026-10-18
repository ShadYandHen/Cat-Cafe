extends SceneTree
## End-to-end scenes/input, lifecycle regressions and isolated cold-reload artifacts.
const DEV := preload("res://Tools/development_profile.gd")
var folder := "/tmp/paw-integration-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
var checks := 0
var failures := 0
var touch := false
var model: RefCounted
var p: CafeProfile
var main: Control
var s: CafeSession
var view: Control
var captures := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func settle() -> void:
	for i in range(8):
		await process_frame

func raw(path: String, value: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path,FileAccess.WRITE)
	assert(f!=null)
	f.store_string(JSON.stringify(value))
	f.close()

func click(control: Button, scroll: ScrollContainer = null) -> void:
	if scroll!=null:
		scroll.ensure_control_visible(control)
		await settle()
	check(control.is_visible_in_tree() and not control.disabled,"Enabled journey input: "+control.name+" "+control.text)
	var pos := control.get_global_rect().get_center()
	for pressed in [true,false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.index=0
			event.position=root.get_final_transform()*pos
			event.pressed=pressed
			Input.parse_input_event(event)
		else:
			var event := InputEventMouseButton.new()
			event.position=pos
			event.button_index=MOUSE_BUTTON_LEFT
			event.pressed=pressed
			root.push_input(event,true)
	await settle()

func shot(name: String) -> void:
	if not captures:
		return
	await settle()
	check(root.get_texture().get_image().save_png(folder.path_join(name+"-%d.png" % root.size.x))==OK,"Capture "+name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for argument in OS.get_cmdline_user_args():
		if argument=="--capture":
			captures=DisplayServer.get_name()!="headless"
		if argument.begins_with("--cold-read="):
			await cold_read(argument.trim_prefix("--cold-read="))
			finish()
			return
	lifecycle_regressions()
	save_recovery_and_migration()
	development_safety()
	root.content_scale_size=Vector2i(720,1280)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	for size in [Vector2i(720,1280),Vector2i(320,568)]:
		root.size=size
		touch=size.x==320
		await journey()
		print("PASS integrated player journey at ",size)
	finish()

func finish() -> void:
	if failures==0:
		print("PASS: %d full integration assertions (artifacts: %s)" % [checks,folder])
	quit(0 if failures==0 else 1)

func lifecycle_regressions() -> void:
	var q := CafeProfile.new()
	var shift := q.begin_shift()
	var before := q.snapshot()
	check(not q.set_team(["odin","momo","blaze"]) and q.snapshot()==before,"Profile blocks team edit during active shift")
	q.release_shift(shift)
	check(not q.apply_service(shift,77,10,5,3) and q.snapshot()==before,"Released shift cannot reward an unserved order")
	check(not q.complete_shift(shift) and q.snapshot()==before,"Abandoned shift cannot later count as a completed day")
	var path := folder.path_join("stale/profile.json")
	q=CafeProfile.new()
	q.open(path)
	shift=q.begin_shift()
	var reloaded := CafeProfile.new()
	reloaded.open(path)
	before=reloaded.snapshot()
	check(not reloaded.apply_service(shift,99,10,5,3) and reloaded.snapshot()==before,"Reloaded unfinished shift rejects stale unserved callbacks")
	check(not reloaded.complete_shift(shift) and reloaded.snapshot()==before,"Reloaded unfinished shift cannot grant completed-day Seasonal XP")
	var session := load("res://Scenes/Gameplay/CafeSession.tscn").instantiate() as CafeSession
	session.profile=q
	root.add_child(session)
	session.set_process(false)
	session.phase=CafeSession.Phase.RESULTS
	session.completion_pending=true
	session.open_team()
	check(not session.can_edit_team() and not session.assign_cat(0,"odin"),"Pending day save keeps team view-only")
	session.free()

func save_recovery_and_migration() -> void:
	var q := CafeProfile.new()
	var path := folder.path_join("recovery/profile.json")
	q.open(path)
	check(q.grant_xp(20) and q.set_team(["odin","momo","blaze"]),"Establish primary and valid backup")
	var backup := FileAccess.get_file_as_string(path+".bak")
	var broken := FileAccess.open(path,FileAccess.WRITE)
	broken.store_string("{broken")
	broken.close()
	var loaded := CafeProfile.new()
	loaded.open(path)
	check(loaded.store.recovery_required and FileAccess.get_file_as_string(path)=="{broken","Recovery load retains damaged primary")
	check(loaded.set_team(["max","momo","blaze"]) and not loaded.store.recovery_required,"Successful repair clears recovery lock so calendar polling can resume")
	check(FileAccess.get_file_as_string(path+".bak")==backup,"Recovery preserves backup checkpoint")
	var retained := false
	for file in DirAccess.get_files_at(path.get_base_dir()):
		retained=retained or file.contains(".corrupt-")
	check(retained,"Damaged recovery bytes archived")
	for version in [1,2,3,4,5]:
		var data := CafeProfile.defaults()
		data.schema_version=version
		data.coins=789
		data.level=2
		data.xp=25
		data.completed_days=3
		data.team=["odin","momo","blaze"]
		if version<2:
			for key in ["upgrades","owned_decorations","equipped_decorations"]:
				data.erase(key)
		if version<3:
			for key in ["lottery_tickets","welcome_processed","resolved_cycles","cycle_rewards","owned_cosmetics","equipped_cosmetics","lottery_history","next_roll_sequence","released_seasons"]:
				data.erase(key)
		if version<5:
			data.erase("ordinary_tip_remainder")
		if version<4:
			data.erase("seasonal")
		var legacy_path := folder.path_join("v%d/profile.json" % version)
		raw(legacy_path,data)
		loaded=CafeProfile.new()
		loaded.open(legacy_path)
		check(loaded.coins==789 and loaded.level==2 and loaded.xp==25 and loaded.completed_days==3 and loaded.team_slots==data.team,"Save migration retains permanent baseline v%d" % version)
		check(loaded.sync_season() and loaded.snapshot().schema_version==CafeProfile.VERSION,"Save migration writes current schema v%d" % version)

func development_safety() -> void:
	var invalid := DEV.new("../player_profile")
	check(invalid.profile==null,"Development slot traversal rejected")
	invalid=DEV.new("/workspace/Cat-Cafe")
	check(invalid.profile==null,"Absolute development slot rejected")
	var tool := DEV.new("regression-%d" % OS.get_process_id())
	check(tool.reset() and tool.set_coins(5000),"Development reset and Coins use isolated storage")
	check(tool.set_reputation(50,0) and tool.grant_tickets(11) and tool.profile.tickets==12,"Test tickets use durable real entitlement accounting")
	check(tool.set_seasonal_xp(2500) and tool.profile.seasonal_state().inbox.size()==1,"Development XP creates valid milestone entitlement")
	check(tool.boundary("day") and tool.boundary("week") and tool.boundary("season"),"Development day/week/season clock controls")
	check(tool.profile.seasonal_state().inbox.size()==1,"Development time controls retain earned Inbox rewards")
	var correct_path: String=tool.profile.store.path
	tool.profile.store.path="user://player_profile.json"
	check(not tool.set_coins(1),"Development action refuses redirected player-save destination without reading/writing it")
	tool.profile.store.path=correct_path
	check(not tool.set_seasonal_xp(-1) and not tool.advance(-1),"Invalid development actions rejected")
	check(tool.reset() and tool.profile.coins==120 and tool.profile.level==1 and tool.profile.tickets==0,"Reset creates a fresh scratch profile")
	check(FileAccess.get_file_as_string("res://export_presets.cfg").contains('exclude_filter="Tools/*,ArtReferences/*"'),"Development scripts excluded from configured export")

func open_title(profile: CafeProfile) -> void:
	root.get_node("PlayerProfile").profile=profile
	change_scene_to_file("res://Scenes/Title.tscn")
	await scene_changed
	await settle()

func enter_cafe() -> void:
	await click(current_scene.get_node("Content/Layout/Play"))
	main=current_scene as Control
	s=main.get_node("CafeSession") as CafeSession
	s.set_process(false)
	view=main.get_node("GameplayView")
	check(s.view==CafeSession.View.LOBBY and s.active_count()==0,"Title Play enters pre-day café")

func journey() -> void:
	model=DEV.new("journey-%d-%d" % [OS.get_process_id(),root.size.x])
	check(model.reset(),"Fresh isolated journey profile")
	p=model.profile
	await open_title(p)
	await shot("title")
	await enter_cafe()
	check(p.coins==120 and p.level==1 and p.xp==0 and p.completed_days==0 and p.team_slots==["mochi","fade","max"],"Fresh player baseline")
	var lobby := view.get_node("DayLobby/Content/Layout")
	await click(lobby.get_node("CatTeam"))
	var team := view.get_node("CatTeamScreen")
	await click(team.cards.fade.get_node("Assign"),team.get_node("Content/Layout/Scroll"))
	check(p.team_slots==["fade","mochi","max"],"Input selects active cat and swaps unique support slots")
	await click(team.get_node("Content/Layout/Back"))
	await nested_navigation()
	await click(lobby.get_node("Action"))
	s.set_process(false)
	check(s.day_seconds==300 and s.rush_start==120 and s.rush_end==180 and s.active_count()==1,"Production shift timing and initial seat")
	await shot("cafe")
	await serve_one(s.order_at_seat(0))
	check(s.served==1 and s.ability_activations.size()==1,"Actual preparation triggers only the active cat's ability")
	# Use the production clock API in accelerated deterministic slices, never shorten a day.
	var loops := 0
	while s.phase!=CafeSession.Phase.RESULTS and loops<30:
		for order in s.active_orders():
			await serve_one(order.order_id)
		if s.phase!=CafeSession.Phase.RESULTS:
			s.advance_time(20)
			await settle()
		loops+=1
	check(s.phase==CafeSession.Phase.RESULTS and p.completed_days==1,"Full five-minute café day reaches results")
	check(s.served>=5 and s.earned==p.coins-120 and s.reputation_earned>0,"Results match committed service earnings")
	var season: Dictionary = p.seasonal_state().current
	var expected_xp := 200+150*int(season.daily.completed)+500*int(season.weekly.completed)
	check(season.xp==expected_xp,"Day and completed challenges grant exact Seasonal XP")
	check(season.daily.progress>0 and season.weekly.progress>0,"Daily and weekly objectives track integrated gameplay")
	var journey_summary := {"served":s.served,"lost":s.lost,"coins_earned":s.earned,"reputation_earned":s.reputation_earned,"seasonal_xp":season.xp,"elapsed":s.elapsed}
	print("SHIFT RESULTS ",root.size," ",journey_summary)
	await shot("results")
	await click(view.get_node("DayResults/Content/Layout/Shop"))
	var shop := view.get_node("CafeShopScreen")
	var scroll := shop.get_node("Content/Layout/Scroll") as ScrollContainer
	await click(shop.upgrade_cards.brewing_equipment.get_node("Buy"),scroll)
	check(p.upgrade_level("brewing_equipment")==1,"Post-shift upgrade purchase")
	await click(shop.get_node("Content/Layout/Tabs/Decorate"))
	await click(shop.decoration_cards.pink_paw_plaque.get_node("Buy"),scroll)
	await click(shop.decoration_cards.pink_paw_plaque.get_node("Equip"),scroll)
	check(p.owns_decoration("pink_paw_plaque") and p.equipped_decorations().wall_display=="pink_paw_plaque","Purchased decoration owns and equips persistently")
	await click(shop.get_node("Content/Layout/Back"))
	await click(view.get_node("DayResults/Content/Layout/Action"))
	s.set_process(false)
	check(s.day==2 and s.ability_activations.is_empty() and s.ability_remaining()==0,"Next day resets ability cooldown and day-specific state")
	check(is_equal_approx(float(s._shift_upgrade_bonuses.speed),0.03),"Purchased preparation upgrade captured by next shift")
	var before := p.snapshot()
	check(not p.purchase_upgrade("brewing_equipment",1) and not p.equip_decoration("wall_display",""),"Purchases and equipment locked during new shift")
	check(p.snapshot()==before,"Rejected in-shift edits change nothing")
	await upgraded_preparation()
	await menu_during_shift()
	# Close the unfinished second shift and re-enter via Title/Play with disk state.
	await open_title(p)
	var loaded := CafeProfile.new()
	loaded.clock=p.clock
	loaded.open(p.store.path)
	check(loaded.snapshot()==p.snapshot(),"Restart during shift retains only permanent state")
	p=loaded
	await open_title(p)
	await enter_cafe()
	check(p.completed_days==1 and s.orders.is_empty() and s.team.slots==["fade","mochi","max"],"Relaunch restores team/inventory without unfinished customers")
	# Separate progression tools now operate while no shift is active.
	model.profile=p
	check(model.set_coins(5000) and model.set_reputation(50,0) and model.grant_tickets(11) and model.set_seasonal_xp(25000),"Isolated long-term reward setup")
	await long_term_rewards()
	var artifact := {"path":p.store.path,"expected":p.snapshot(),"summary":journey_summary}
	raw(folder.path_join("journey-%d.json" % root.size.x),artifact)
	await open_title(p)

func serve_one(id: int) -> void:
	var order := s.get_order(id)
	if order==null or order.state in [CafeSession.State.SERVED,CafeSession.State.DEPARTED]:
		return
	var actor := view.get_node("Customer" if order.seat==0 else "CustomerRight") as Button
	await click(actor)
	await click(view.get_node("OrderScreen/Content/Layout/Action"))
	await click(view.get_node("CoffeeEquipment"))
	var station := view.get_node("CoffeeStation/Content/Layout")
	var body := station.get_node("Workspace/Body")
	await click(body.get_node("Stations").get_child(DrinkCatalog.CATEGORIES.find(order.recipe.station)),station.get_node("Workspace"))
	for ingredient in order.recipe.ingredients:
		await click(body.get_node("Ingredients").get_child(DrinkCatalog.INGREDIENTS.find(ingredient)),station.get_node("Workspace"))
	check(s.selected_ingredients.size()==order.recipe.ingredients.size(),"Scrolled station ingredient input matches requested recipe")
	if s.served==0:
		await shot("station")
	await click(station.get_node("Action"))
	check(s.brewing and s.preparation_target()<float(order.recipe.target_seconds),"Cat/upgrade bonuses affect actual timing")
	s.advance_time(s.preparation_target())
	await settle()
	await click(station.get_node("Action"))
	await click(station.get_node("Action"))
	check(order.state==CafeSession.State.DRINK_READY and order.quality_score>=95,"Requested recipe prepares a Perfect drink")
	var coins := p.coins
	var rep := p.xp
	var reward: int = s.service_preview(order).coins
	await click(actor)
	await click(view.get_node("OrderScreen/Content/Layout/Action"))
	check(order.state==CafeSession.State.SERVED and p.coins==coins+reward,"Manual serving pays recipe/quality/cat reward once")
	var saved := p.snapshot()
	s.serve()
	check(p.snapshot()==saved,"Repeated service action cannot pay or progress challenges twice")
	check(p.xp>rep or p.level>1,"Permanent Reputation reward advances separately")

func upgraded_preparation() -> void:
	var order := s.get_order(s.order_at_seat(0))
	var coins := p.coins
	await click(view.get_node("Customer"))
	await click(view.get_node("OrderScreen/Content/Layout/Action"))
	await click(view.get_node(view.EQUIPMENT[DrinkCatalog.CATEGORIES.find(order.recipe.category)]))
	var station := view.get_node("CoffeeStation/Content/Layout")
	var body := station.get_node("Workspace/Body")
	var scroll := station.get_node("Workspace") as ScrollContainer
	for ingredient in order.recipe.ingredients:
		await click(body.get_node("Ingredients").get_child(DrinkCatalog.INGREDIENTS.find(ingredient)),scroll)
	await click(station.get_node("Action"))
	var expected: float=order.recipe.target_seconds/(1.0+float(s.cat_bonuses().speed)+0.03+0.20)
	check(s.brewing and is_equal_approx(s.preparation_target(),expected),"Purchased upgrade stacks with restored cat team in actual next-day preparation")
	await click(station.get_node("Back"))
	check(not s.brewing and p.coins==coins and order.state==CafeSession.State.ORDER_ACCEPTED,"Cancelled next-day preparation grants nothing")

func nested_navigation() -> void:
	for iteration in range(2):
		await click(view.get_node("DayLobby/Content/Layout/Shop"))
		var shop := view.get_node("CafeShopScreen")
		var scroll := shop.get_node("Content/Layout/Scroll") as ScrollContainer
		await click(shop.get_node("Content/Layout/Scroll/Body/SeasonPass"),scroll)
		check(s.view==CafeSession.View.SEASON,"Shop opens Seasonal Pass")
		await click(view.get_node("SeasonScreen/Content/Layout/Back"))
		check(s.view==CafeSession.View.UPGRADES,"Season Back returns to originating shop")
		await click(shop.get_node("Content/Layout/Scroll/Body/GoldenPaw"),scroll)
		var rewards := view.get_node("RewardsScreen")
		await click(rewards.lottery_body.get_child(0),rewards.get_node("Content/Layout/Scroll"))
		await click(view.get_node("SeasonScreen/Content/Layout/Back"))
		check(s.view==CafeSession.View.REWARDS,"Season Back returns to rewards")
		await click(rewards.get_node("Content/Layout/Back"))
		check(s.view==CafeSession.View.LOBBY,"Rewards Back returns to opening without trap")
	check(view.find_children("SeasonScreen","Control",false,false).size()==1,"Repeated navigation keeps one Season screen instance")

func menu_during_shift() -> void:
	await click(main.get_node("Content/Layout/BottomNavigation/Map"))
	var rewards := view.get_node("RewardsScreen")
	check(rewards.roll_one.disabled,"Lottery view only during shift")
	await click(rewards.lottery_body.get_child(0),rewards.get_node("Content/Layout/Scroll"))
	var season := view.get_node("SeasonScreen")
	await click(season.get_node("Content/Layout/Settings"))
	var elapsed := s.elapsed
	var order := s.get_order(s.order_at_seat(0))
	var patience := order.remaining(s.elapsed)
	s.advance_time(5)
	await settle()
	check(s.elapsed==elapsed+5 and order.remaining(s.elapsed)==patience-5,"Settings over nested menu keeps shift and patience running")
	await shot("settings")
	await click(main.get_node("SettingsPanel/Center/Panel/Margins/Layout/Close"))
	check(root.gui_get_focus_owner()==season.get_node("Content/Layout/Settings"),"Nested Settings restores keyboard focus")
	await click(season.get_node("Content/Layout/Back"))
	await click(rewards.get_node("Content/Layout/Back"))
	check(s.view==CafeSession.View.CAFE,"Nested in-shift menus return to café")

func long_term_rewards() -> void:
	await click(view.get_node("DayLobby/Content/Layout/Shop"))
	var shop := view.get_node("CafeShopScreen")
	await click(shop.get_node("Content/Layout/Scroll/Body/SeasonPass"),shop.get_node("Content/Layout/Scroll"))
	var season := view.get_node("SeasonScreen")
	var scroll := season.get_node("Content/Layout/Scroll") as ScrollContainer
	await click(season.pass_cards[5].claim,scroll)
	check(season.pass_cards[5].claim.disabled,"Pass claim is not repeatable")
	await click(season.get_node("Content/Layout/Tabs/Inbox"))
	await click(season.inbox_cards["paw-season-0001:tier:10"].claim,scroll)
	check(p.owns_cosmetic("strawberry_badge"),"Inbox uses shared cosmetic ownership")
	await shot("inbox")
	await click(season.get_node("Content/Layout/Back"))
	await click(shop.get_node("Content/Layout/Scroll/Body/GoldenPaw"),shop.get_node("Content/Layout/Scroll"))
	var rewards := view.get_node("RewardsScreen")
	scroll=rewards.get_node("Content/Layout/Scroll")
	var tickets := p.tickets
	await click(rewards.roll_ten,scroll)
	check(p.tickets==tickets-10 and rewards.results.size()==10,"Roll 10 atomically records ten outcomes")
	await click(rewards.review,scroll)
	await click(rewards.roll_one,scroll)
	check(p.tickets==tickets-11 and p.snapshot().lottery_history.size()==11,"Roll 1 recorded with exact ticket balance")
	await click(rewards.get_node("Content/Layout/Tabs/Collections"))
	await click(rewards.cards.strawberry_badge.button,scroll)
	check(p.snapshot().equipped_cosmetics.cafe_badge=="strawberry_badge","Collections equips owned cosmetic")
	check(model.boundary("season"),"Isolated time crosses season boundary")
	await click(rewards.get_node("Content/Layout/Tabs/Lottery"))
	await click(rewards.lottery_body.get_child(0),scroll)
	await click(season.get_node("Content/Layout/Tabs/Inbox"))
	await click(season.inbox_cards["paw-season-0001:tier:40"].claim,season.get_node("Content/Layout/Scroll"))
	check(p.owns_cosmetic("spring_blossom_badge") and p.seasonal_state().current.id=="paw-season-0002","Old-season claim and lottery release coexist")
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(320,568) if touch else Vector2i(720,1280)]:
		root.size=dimensions
		await settle()
		check(absf(season.get_node("Content").get_global_rect().get_center().x-main.size.x/2)<1,"Integrated reward UI remains centered")
		check(Rect2(Vector2.ZERO,main.size).encloses(season.get_node("Content/Layout/Back").get_global_rect()),"Reward Back accessible after resize")

func cold_read(directory: String) -> void:
	if not directory.begins_with("/tmp/paw-integration-") or ".." in directory:
		check(false,"Cold verification restricted to integration artifacts")
		return
	var verified := 0
	root.content_scale_size=Vector2i(720,1280)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	for file in DirAccess.get_files_at(directory):
		if not file.begins_with("journey-") or not file.ends_with(".json"):
			continue
		var artifact = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(file)))
		var safe_path: bool=artifact is Dictionary and artifact.get("path") is String and artifact.path.begins_with(DEV.ROOT+"/") and artifact.path==artifact.path.simplify_path() and artifact.path.get_file()=="profile.json"
		check(safe_path,"Cold reload uses isolated development profile")
		if not safe_path:
			continue
		verified+=1
		root.size=Vector2i(320,568) if file.contains("320") else Vector2i(720,1280)
		var data := CafeProfile.normalize(artifact.expected)
		check(data.ok,"Cold expected checkpoint valid")
		var profile := CafeProfile.new()
		var fixed_time: int=data.data.seasonal.last_time
		profile.clock=func() -> int: return fixed_time
		profile.open(artifact.path)
		check(profile.snapshot()==data.data,"Separate process restores whole journey checkpoint "+file)
		check(not profile.claim_inbox("paw-season-0001:tier:5"),"Separate process cannot repeat previous claim")
		await open_title(profile)
		await enter_cafe()
		check(s.view==CafeSession.View.LOBBY and s.orders.is_empty() and profile.completed_days==1,"Cold UI returns to opening with no unfinished shift")
		check(profile.equipped_decorations().wall_display=="pink_paw_plaque" and profile.snapshot().equipped_cosmetics.cafe_badge=="strawberry_badge" and profile.upgrade_level("brewing_equipment")==1,"Cold UI restored upgrade, decoration and cosmetic")

	check(verified==2,"Both portrait journey checkpoints verified in the second process")
