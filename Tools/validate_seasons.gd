extends SceneTree
## UTC clock injection, durable receipts, migration, rollover and real UI input.
const MAIN := preload("res://Scenes/Main.tscn")
var folder := "/tmp/paw-seasons-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
var checks := 0
var failures := 0
var serial := 0
var times: Dictionary={}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func raw(path: String, data: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	assert(file!=null)
	file.store_string(JSON.stringify(data))
	file.close()

func fixture(now: int = -1) -> CafeProfile:
	serial+=1
	var p := CafeProfile.new()
	var key := serial
	times[key]=CafeProfile.season_catalog.anchor+100 if now<0 else now
	p.clock=func() -> int: return int(times[key])
	p.open(folder.path_join("%d/profile.json" % serial))
	check(p.sync_season(),"Initialize isolated seasonal profile")
	p.set_meta("clock_key",key)
	return p

func set_time(p: CafeProfile, now: int) -> void:
	times[p.get_meta("clock_key")]=now

func reload(p: CafeProfile) -> CafeProfile:
	var other := CafeProfile.new()
	other.clock=p.clock
	other.open(p.store.path)
	return other

func earn(p: CafeProfile, xp: int) -> bool:
	# Isolated test fixture acceleration; production has no arbitrary Seasonal XP API.
	var candidate := p.snapshot()
	var now := p.seasonal_now()
	p._sync_season_candidate(candidate,now)
	SeasonalProgress.add_xp(candidate.seasonal,xp,now,CafeProfile.season_catalog)
	return p._commit(candidate,now)

func current(p: CafeProfile) -> Dictionary:
	return p.seasonal_state().current

func service(p: CafeProfile, count: int, quality: int = 3, coins: int = 10) -> int:
	var shift := p.begin_shift()
	check(shift>0,"Begin test shift")
	for id in range(1,count+1):
		check(p.apply_service(shift,id,coins,15,quality),"Committed eligible service %d" % id)
	return shift

func run() -> void:
	calendar()
	progression_and_events()
	claims_and_rollover()
	migration_and_failures()
	await ui()
	if failures==0:
		print("PASS: %d seasonal/challenge/Inbox assertions (isolated: %s)" % [checks,folder])
	quit(0 if failures==0 else 1)

func calendar() -> void:
	var catalog := CafeProfile.season_catalog
	var anchor := catalog.anchor
	check(catalog.errors.is_empty(),"Valid free pass/challenge catalog")
	check(catalog.data.duration_days==56 and catalog.data.maximum_tier==50 and catalog.data.xp_per_tier==500,"Established season duration and tier rules")
	check(catalog.season_at(anchor).id=="paw-season-0001" and catalog.season_at(anchor+56*86400-1).id=="paw-season-0001","First season exact inclusive/exclusive boundaries")
	check(catalog.season_at(anchor+56*86400).id=="paw-season-0002","Second season begins exactly at end")
	check(catalog.end_for("spring_preview")==-1 and catalog.end_for("paw-season-0001")==anchor+56*86400,"Stable season IDs and end lookup")
	var monday := int(Time.get_unix_time_from_datetime_string("2026-10-19T00:00:00"))
	check(SeasonCatalog.week_start(monday)==monday and SeasonCatalog.week_start(monday-1)==monday-7*86400,"Monday UTC boundary")
	check(SeasonCatalog.day_start(monday-1)==monday-86400,"Midnight UTC boundary")
	for cadence in ["daily","weekly"]:
		var first := catalog.challenge(catalog.season_at(anchor),anchor+100,cadence)
		check(first==catalog.challenge(catalog.season_at(anchor),anchor+100,cadence),"Deterministic challenge selection: "+cadence)
		var next := catalog.challenge(catalog.season_at(first.end),first.end,cadence)
		check(next.period!=first.period and first.start>=anchor and first.end<=anchor+56*86400,"Clipped challenge period: "+cadence)
	var p := fixture(anchor-100)
	check(CafeProfile.normalize(p.snapshot()).ok,"Pre-anchor season has valid future schedule")
	var shift := service(p,5)
	p.complete_shift(shift)
	check(current(p).xp==0,"No XP before configured season starts")
	set_time(p,anchor+10)
	check(p.sync_season() and current(p).xp==0,"Entering first season does not replay old events")
	for reward in catalog.data.milestones:
		check(int(reward.tier)%5==0 and reward.exclusive==(reward.tier>=40),"All ten explicit milestones and exclusivity")
	for cadence in ["daily","weekly"]:
		for definition in catalog.data[cadence]:
			check(not catalog.challenge_definition(cadence,definition.id).is_empty(),"Data-driven objective: "+definition.id)

func progression_and_events() -> void:
	var p := fixture()
	var rep := p.xp
	for tier in range(1,51):
		check(earn(p,499),"Grant isolated Seasonal XP below tier boundary")
		check(int(current(p).xp/500)==tier-1,"500 XP tier boundary %d" % tier)
		check(earn(p,1) and int(current(p).xp/500)==tier,"Exact tier threshold %d" % tier)
	check(current(p).earned==[5,10,15,20,25,30,35,40,45,50] and p.seasonal_state().inbox.size()==10,"Only earned milestone entitlements created")
	check(earn(p,100000) and current(p).xp==25000 and p.seasonal_state().inbox.size()==10,"Tier 50 cap cannot create extra tiers or rewards")
	check(p.xp==rep and p.coins==120 and p.level==1,"Seasonal XP never changes permanent Reputation or Coins")
	var day := fixture()
	var shift := day.begin_shift()
	check(day.complete_shift(shift) and current(day).xp==200,"Finalized café day awards exactly 200 Seasonal XP")
	var before := day.snapshot()
	check(day.complete_shift(shift) and day.snapshot()==before,"Repeated complete-day receipt gives no extra XP")
	check(reload(day).snapshot()==before,"Day XP and receipt round trip")
	var abandoned := fixture()
	var abandoned_shift := service(abandoned,1)
	abandoned.release_shift(abandoned_shift)
	check(abandoned.completed_days==0 and current(abandoned).xp==0,"Abandoned shift earns no completed-day XP")
	# Exercise every daily and weekly objective through the authoritative service/day API.
	for cadence in ["daily","weekly"]:
		for definition in CafeProfile.season_catalog.data[cadence]:
			var found := -1
			for i in range(56):
				var now: int=CafeProfile.season_catalog.anchor+i*86400+100
				if CafeProfile.season_catalog.challenge(CafeProfile.season_catalog.season_at(now),now,cadence).id==definition.id:
					found=now
					break
			check(found>=0,"Challenge pool entry appears in deterministic schedule")
			var q := fixture(found)
			var id := q.begin_shift()
			var target := int(definition.target)
			if definition.metric=="days":
				for i in range(target):
					if i>0:
						id=q.begin_shift()
					check(q.complete_shift(id),"Day challenge valid completion")
			else:
				for i in range(1,target+1):
					check(q.apply_service(id,i,1,5,3),"Challenge tracks eligible receipt")
			var state: Dictionary=current(q)[cadence]
			check(state.completed and state.progress==target,"Objective completes persistently: "+definition.id)
			var previous := q.snapshot()
			check(not q.apply_service(id,1,1,5,3) and q.snapshot()==previous,"Duplicate service never repeats progress or challenge XP")
			check(reload(q).snapshot()==previous,"Completed challenge survives relaunch: "+definition.id)
			# Expected XP consists only of completed day and the currently completed challenges.
			var expected := q.completed_days*200+int(current(q).daily.completed)*150+int(current(q).weekly.completed)*500
			check(current(q).xp==expected,"Exact Seasonal XP from completed challenge + day events")
	var reset := fixture()
	var id := reset.begin_shift()
	reset.apply_service(id,1,10,5,0)
	var old: Dictionary = current(reset).daily.duplicate(true)
	set_time(reset,int(old.end))
	check(reset.sync_season() and current(reset).daily.progress==0 and not current(reset).daily.completed,"Daily rollover resets only new objective progress")
	var later := reset.snapshot()
	set_time(reset,int(old.start)+1)
	check(reset.sync_season() and reset.snapshot()==later,"Clock rollback cannot revisit an old challenge period")
	reset.release_shift(id)
	var week: Dictionary=current(reset).weekly.duplicate(true)
	set_time(reset,int(week.end))
	check(reset.sync_season() and current(reset).weekly.progress==0,"UTC weekly reset")

func claims_and_rollover() -> void:
	var p := fixture()
	earn(p,25000)
	check(not p.claim_inbox("missing"),"Unearned/invalid reward cannot be claimed")
	var first_id := "paw-season-0001:tier:5"
	var coins := p.coins
	check(p.claim_inbox(first_id) and p.coins==coins+250,"Manual Coin milestone claim")
	var after := p.snapshot()
	check(not p.claim_inbox(first_id) and p.snapshot()==after,"Repeated manual claim cannot pay twice")
	p.grant_cosmetic("spring_blossom_badge")
	coins=p.coins
	check(p.claim_inbox("paw-season-0001:tier:40") and p.coins==coins+500,"Duplicate seasonal exclusive substitutes 500 Coins deterministically")
	var shift := p.begin_shift()
	var in_shift := p.snapshot()
	check(not p.claim_inbox("paw-season-0001:tier:45") and p.snapshot()==in_shift,"Authoritative profile forbids in-shift claims")
	p.release_shift(shift)
	var before := p.snapshot()
	set_time(p,CafeProfile.season_catalog.anchor+56*86400)
	check(p.sync_season(),"Automatic season rollover saves")
	check(current(p).id=="paw-season-0002" and current(p).xp==0 and current(p).earned.is_empty(),"New season resets only Seasonal XP/rewards/challenges")
	check(p.seasonal_state().inbox.size()==10 and p.seasonal_state().history.size()==1,"All earned rewards retained, no unearned rewards invented")
	for key in ["coins","level","xp","completed_days","team","upgrades","owned_cosmetics","owned_decorations","lottery_tickets","lottery_history"]:
		check(p.snapshot()[key]==before[key],"Rollover preserves permanent "+key)
	check("paw-season-0001" in p.snapshot().released_seasons,"Ended season releases originating exclusives to existing lottery")
	for item in CafeProfile.reward_catalog.all_items(CafeProfile.cafe_catalog.decorations):
		if item.origin_season=="paw-season-0001":
			check(not RewardCatalog.eligible(item,[]) and RewardCatalog.eligible(item,p.snapshot().released_seasons),"Exclusive release eligibility: "+item.id)
	check(not p.claim_inbox(first_id),"Historical claims stay protected after rollover")
	check(p.claim_inbox("paw-season-0001:tier:45") and p.owns_decoration("spring_heart_mat"),"Expired-season reward claims through permanent Inbox")
	check(p.claim_inbox("paw-season-0001:tier:50") and p.owns_cosmetic("season_dream_badge"),"Third exclusive uses existing cosmetic inventory")
	var saved := p.snapshot()
	check(reload(p).snapshot()==saved,"Archived claims and pending rewards persist")
	set_time(p,CafeProfile.season_catalog.anchor+56*86400*10)
	check(p.sync_season() and current(p).id=="paw-season-0011" and p.seasonal_state().history.size()==1 and p.seasonal_state().inbox.size()==10,"Multiple missed seasons do not fabricate rewards/history")
	check(p.claim_inbox("paw-season-0001:tier:10"),"Pending reward never expires across multiple missed seasons")
	# Sample the existing lottery exactly at release, without an earlier sync call.
	var lottery := fixture()
	lottery.grant_xp(27195+2000)
	for item in CafeProfile.reward_catalog.all_items(CafeProfile.cafe_catalog.decorations):
		if item.exclusive and item.origin_season.is_empty():
			if not CafeProfile.reward_catalog.cosmetic(item.id).is_empty():
				lottery.grant_cosmetic(item.id)
			else:
				lottery.grant_decoration(item.id)
	var rng := RandomNumberGenerator.new()
	var exclusive_seed := 0
	for seed_value in range(10000):
		rng.seed=seed_value
		if GoldenPawRewards.category(rng.randi_range(0,99))=="exclusive":
			exclusive_seed=seed_value
			break
	lottery.reward_rng.seed=exclusive_seed
	check(lottery.roll_lottery(1,int(lottery.snapshot().next_roll_sequence)) and lottery.last_roll_results[0].coins==1000,"Active-season exclusives remain outside exhausted lottery pool")
	set_time(lottery,CafeProfile.season_catalog.anchor+56*86400)
	lottery.reward_rng.seed=exclusive_seed
	check(lottery.roll_lottery(1,int(lottery.snapshot().next_roll_sequence)) and lottery.last_roll_results[0].coins==0,"Existing lottery samples newly released season items at boundary")
	var instant := fixture()
	earn(instant,2500)
	set_time(instant,CafeProfile.season_catalog.anchor+56*86400+100)
	check(instant.claim_inbox("paw-season-0001:tier:5") and current(instant).id=="paw-season-0002","Claim itself handles rollover atomically without prior polling")
	var earned_again := fixture()
	earn(earned_again,2499)
	set_time(earned_again,CafeProfile.season_catalog.anchor+56*86400)
	earned_again.sync_season()
	check(earned_again.seasonal_state().inbox.is_empty(),"Unreached milestones are never transferred")

func migration_and_failures() -> void:
	var old := fixture()
	old.grant_xp(27195+11000)
	old.roll_lottery(10,int(old.snapshot().next_roll_sequence))
	old.grant_cosmetic("coffee_pin")
	old.equip_cosmetic("coffee_pin")
	old.grant_decoration("pink_paw_plaque")
	old.equip_decoration("wall_display","pink_paw_plaque")
	var legacy := old.snapshot()
	legacy.schema_version=3
	legacy.erase("seasonal")
	var path := folder.path_join("legacy/profile.json")
	raw(path,legacy)
	var migrated := CafeProfile.new()
	migrated.clock=old.clock
	migrated.open(path)
	for key in legacy:
		if key!="schema_version":
			check(migrated.snapshot()[key]==legacy[key],"Schema 3 migration preserves "+key)
	check(migrated.sync_season() and migrated.snapshot().schema_version==CafeProfile.VERSION and current(migrated).xp==0,"Schema 4 initializes no retroactive Seasonal XP")
	check(reload(migrated).snapshot()==migrated.snapshot(),"Migrated seasonal profile saves/loads")
	var p := fixture()
	earn(p,2500)
	var saved_path := p.store.path
	var obstruction := saved_path.get_base_dir().path_join("obstruction")
	raw(obstruction,"block")
	p.store.path=obstruction.path_join("profile.json")
	var before := p.snapshot()
	check(not p.claim_inbox("paw-season-0001:tier:5") and p.snapshot()==before,"Failed claim write retains entitlement and changes no Coins")
	p.store.path=saved_path
	check(p.claim_inbox("paw-season-0001:tier:5") and not p.claim_inbox("paw-season-0001:tier:5"),"Claim retry commits once")
	var shift := p.begin_shift()
	p.store.path=obstruction.path_join("profile.json")
	before=p.snapshot()
	check(not p.apply_service(shift,1,50,15,3) and p.snapshot()==before,"Failed service cannot count challenge progress")
	check(not p.complete_shift(shift) and p.snapshot()==before,"Failed day commit cannot grant Seasonal XP")
	p.store.path=saved_path
	check(p.complete_shift(shift),"Day transaction can retry after save recovery")
	before=p.snapshot()
	set_time(p,CafeProfile.season_catalog.anchor+56*86400)
	p.store.path=obstruction.path_join("profile.json")
	check(not p.sync_season() and p.snapshot()==before,"Failed rollover leaves original season and Inbox intact")
	p.store.path=saved_path
	check(p.sync_season() and reload(p).snapshot()==p.snapshot(),"Rollover retry commits without losing pending rewards")
	var invalid_quality := p.begin_shift()
	var unchanged := p.snapshot()
	check(not p.apply_service(invalid_quality,1,10,5,99) and p.snapshot()==unchanged,"Invalid final quality cannot generate challenge progress")
	p.release_shift(invalid_quality)
	var broken := p.snapshot()
	broken.seasonal.inbox[0].claimed=false
	check(not CafeProfile.normalize(broken).ok,"Corrupt claim receipt state rejected for backup recovery")
	broken=p.snapshot()
	broken.seasonal.current.xp=-1
	check(not CafeProfile.normalize(broken).ok,"Invalid Seasonal XP rejected")
	broken=p.snapshot()
	broken.seasonal.current.daily.progress=999999
	check(not CafeProfile.normalize(broken).ok,"Invalid challenge progress rejected")
	broken=p.snapshot()
	broken.seasonal.inbox[0].created_at="invalid"
	check(not CafeProfile.normalize(broken).ok,"Malformed Inbox timestamp is rejected without script errors")

func settle() -> void:
	for i in range(10):
		await process_frame

func click(control: Button, touch: bool, scroll: ScrollContainer = null) -> void:
	if scroll!=null:
		scroll.ensure_control_visible(control)
		await settle()
	check(control.is_visible_in_tree() and not control.disabled,"Enabled seasonal input: "+control.text)
	var position := control.get_global_rect().get_center()
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

func ui() -> void:
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	for dimensions in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size=dimensions
		var touch: bool=dimensions.x==960
		var p := fixture()
		earn(p,25000)
		var main := MAIN.instantiate() as Control
		var session := main.get_node("CafeSession") as CafeSession
		session.profile=p
		root.add_child(main)
		session.set_process(false)
		await settle()
		session.open_season()
		await settle()
		var panel := main.get_node("GameplayView/SeasonScreen")
		var scroll := panel.get_node("Content/Layout/Scroll") as ScrollContainer
		check(panel.visible and panel.pass_cards.size()==10,"All ten seasonal milestone controls present")
		await click(panel.pass_cards[5].claim,touch,scroll)
		check(5 in current(p).claimed and panel.pass_cards[5].claim.disabled,"Pass claim via mouse/touch pays once")
		await click(panel.get_node("Content/Layout/Settings"),touch)
		set_time(p,CafeProfile.season_catalog.anchor+56*86400)
		p.sync_season()
		await settle()
		check(main.get_node("SettingsPanel").visible,"Season rollover keeps Settings modal open")
		await click(main.get_node("SettingsPanel/Center/Panel/Margins/Layout/Close"),touch)
		check(root.gui_get_focus_owner()==panel.get_node("Content/Layout/Settings"),"Season Settings restores focus")
		set_time(p,CafeProfile.season_catalog.anchor+56*86400)
		p.sync_season()
		await settle()
		await click(panel.get_node("Content/Layout/Tabs/Inbox"),touch)
		var id := "paw-season-0001:tier:10"
		await click(panel.inbox_cards[id].claim,touch,scroll)
		check(p.owns_cosmetic("strawberry_badge") and panel.inbox_cards[id].claim.disabled,"Archived Inbox claim via input")
		for name in ["Heading","Status","Tabs","Scroll","Settings","Back"]:
			var control := panel.get_node("Content/Layout/"+name) as Control
			check(Rect2(Vector2.ZERO,main.size).encloses(control.get_global_rect()),"Season fixed control in viewport: "+name)
		for control in panel.find_children("*","Control",true,false):
			if control is Button:
				check(control.size.y*main.ui_scale>=44 and control.size.x*main.ui_scale>=44,"Season touch target >=44px")
			if control is Label:
				check(control.get_theme_font_size("font_size")*main.ui_scale>=16,"Season label >=16px")
		await click(panel.get_node("Content/Layout/Back"),touch)
		check(session.view==CafeSession.View.LOBBY,"Season Back restores entry view")
		session.start_next_day()
		session.open_season()
		await settle()
		check(panel.inbox_cards["paw-season-0001:tier:15"].claim.disabled,"UI view only during shift")
		var elapsed := session.elapsed
		session.advance_time(1)
		check(session.elapsed==elapsed+1,"Café clock continues in Season screen")
		panel.get_node("Content/Layout/Back").grab_focus()
		for pressed in [true,false]:
			var key := InputEventKey.new()
			key.keycode=KEY_ENTER
			key.pressed=pressed
			root.push_input(key,true)
			await settle()
		check(session.view==CafeSession.View.CAFE,"Season keyboard Back works")
		session.advance_time(400)
		session.open_season()
		await settle()
		check(not panel.inbox_cards["paw-season-0001:tier:15"].claim.disabled,"Results permit reward claims")
		if DisplayServer.get_name()!="headless":
			panel.show_tab(false)
			await settle()
			root.get_texture().get_image().save_png(folder.path_join("season-%d.png" % dimensions.x))
			panel.show_tab(true)
			await settle()
			root.get_texture().get_image().save_png(folder.path_join("inbox-%d.png" % dimensions.x))
		for resized in [Vector2i(1280,720),Vector2i(1920,1080),dimensions]:
			root.size=resized
			await settle()
			check(absf(panel.get_node("Content").get_global_rect().get_center().x-main.size.x/2)<1,"Season stays centered on resize")
			check(Rect2(Vector2.ZERO,main.size).encloses(panel.get_node("Content/Layout/Back").get_global_rect()),"Season Back stays accessible on resize")
		main.queue_free()
		await process_frame
		print("PASS seasonal UI at ",dimensions)
