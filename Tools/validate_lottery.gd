extends SceneTree
## Deterministic reward accounting and native-input UI, always isolated saves.
const MAIN := preload("res://Scenes/Main.tscn")
var folder := "/tmp/paw-lottery-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
var checks := 0
var failures := 0
var serial := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func write_raw(path: String, data: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path,FileAccess.WRITE)
	assert(f!=null)
	f.store_string(JSON.stringify(data))
	f.close()

func fixture(cycles: int = 0) -> CafeProfile:
	serial+=1
	var p := CafeProfile.new()
	p.open(folder.path_join("%d/profile.json" % serial))
	p.reward_rng.seed=1234
	if cycles>=0:
		check(p.grant_xp(27195+cycles*1000),"Earn Level 50 tickets through real progression")
	return p

func reload(p: CafeProfile) -> CafeProfile:
	var other := CafeProfile.new()
	other.open(p.store.path)
	return other

func seed_for(group: String, cycle: bool = false) -> int:
	var rng := RandomNumberGenerator.new()
	for seed_value in range(10000):
		rng.seed=seed_value
		if GoldenPawRewards.category(rng.randi_range(0,99),cycle)==group:
			return seed_value
	assert(false,"No matching seed")
	return 0

func roll(p: CafeProfile, count: int) -> bool:
	return p.roll_lottery(count,int(p.snapshot().next_roll_sequence))

func run() -> void:
	catalog_and_probabilities()
	tickets_and_rolls()
	duplicates_and_cycles()
	migration_and_failures()
	await ui()
	if failures==0:
		print("PASS: %d lottery and collection assertions (isolated: %s)" % [checks,folder])
	quit(0 if failures==0 else 1)

func catalog_and_probabilities() -> void:
	check(CafeProfile.reward_catalog.errors.is_empty() and CafeProfile.cafe_catalog.errors.is_empty(),"Valid reward catalogs")
	var ids: Array=[]
	for entry in CafeProfile.reward_catalog.all_items(CafeProfile.cafe_catalog.decorations):
		check(entry.id not in ids,"Unique combined reward ID: "+entry.id)
		ids.append(entry.id)
		var cosmetic := not CafeProfile.reward_catalog.cosmetic(entry.id).is_empty()
		check(RewardCatalog.validate_item(entry,cosmetic).is_empty(),"Valid metadata and compatibility: "+entry.id)
		if not entry.origin_season.is_empty():
			check(not RewardCatalog.eligible(entry,[]) and RewardCatalog.eligible(entry,[entry.origin_season]),"Seasonal items require their explicit release condition")
	var counts := {"coins":0,"regular_cosmetics":0,"regular_decorations":0,"exclusive":0}
	var cycles := {"coins":0,"regular_cosmetics":0,"regular_decorations":0}
	for i in range(100):
		var expected := "coins" if i<50 else "regular_cosmetics" if i<74 else "regular_decorations" if i<98 else "exclusive"
		check(GoldenPawRewards.category(i)==expected,"Exact lottery bucket boundary %d" % i)
		counts[GoldenPawRewards.category(i)]+=1
		var cycle_expected := "coins" if i<50 else "regular_cosmetics" if i<75 else "regular_decorations"
		check(GoldenPawRewards.category(i,true)==cycle_expected,"Exact cycle bucket boundary %d" % i)
		cycles[GoldenPawRewards.category(i,true)]+=1
	check(counts=={"coins":50,"regular_cosmetics":24,"regular_decorations":24,"exclusive":2},"Exact lottery weights, no pity")
	check(cycles=={"coins":50,"regular_cosmetics":25,"regular_decorations":25},"Separate cycle weights")
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed=456
	b.seed=456
	for i in range(50):
		var one := GoldenPawRewards.outcome(CafeProfile.defaults(),CafeProfile.reward_catalog,CafeProfile.cafe_catalog.decorations,a)
		var two := GoldenPawRewards.outcome(CafeProfile.defaults(),CafeProfile.reward_catalog,CafeProfile.cafe_catalog.decorations,b)
		check(one==two,"Injected seeded RNG reproduces outcome %d" % i)
	for change in [{"collection":"wrong"},{"exclusive":false},{"eligibility_start":"unknown"},{"asset":"res://absent.png"},{"slot":"hat"}]:
		var bad := CafeProfile.reward_catalog.cosmetics[3].duplicate(true)
		bad.merge(change,true)
		check(not RewardCatalog.validate_item(bad,true).is_empty(),"Invalid reward metadata rejected")

func tickets_and_rolls() -> void:
	var locked := fixture(-1)
	var original := locked.snapshot()
	check(not roll(locked,1) and locked.snapshot()==original,"Lottery visible but locked below Level 50")
	var p := fixture(11)
	check(p.level==50 and p.tickets==12 and p.pending_tickets==0 and p.snapshot().welcome_processed,"Welcome and cycle tickets resolved exactly once")
	check(p.snapshot().cycle_rewards.size()==11 and p.snapshot().resolved_cycles==11,"Every cycle stores durable outcome and ID")
	var prior := p.snapshot()
	check(p.resolve_level50_rewards() and p.snapshot()==prior,"Resolving again never duplicates grants")
	check(reload(p).snapshot()==prior,"Reload does not reroll committed cycles")
	var seq: int=prior.next_roll_sequence
	check(p.roll_lottery(1,seq) and p.tickets==11 and p.last_roll_results.size()==1,"Roll 1 spends one ticket and records reward")
	var after := p.snapshot()
	check(not p.roll_lottery(1,seq) and p.snapshot()==after,"Repeated input with same sequence cannot spend twice")
	check(roll(p,10) and p.tickets==1 and p.last_roll_results.size()==10,"Roll 10 independent outcomes in one transaction")
	check(p.snapshot().lottery_history.size()==11,"Batch stores ten receipts in persistent history")
	check(not roll(p,10) and p.tickets==1,"Insufficient tickets rejects full batch")
	for invalid in [0,2,-1,11]:
		check(not roll(p,invalid) and p.tickets==1,"Unsupported roll count rejected")
	check(reload(p).snapshot()==p.snapshot(),"Lottery balance inventory and receipts round trip")
	var active := p.begin_shift()
	var in_shift := p.snapshot()
	check(not roll(p,1) and not p.equip_cosmetic("") and p.snapshot()==in_shift,"Shift locks spending and equipment in authoritative profile")
	p.release_shift(active)
	check(roll(p,1) and p.tickets==0,"Spending available between shifts")
	check(not roll(p,1),"No tickets cannot roll")
	var history := fixture(65)
	for i in range(6):
		check(roll(history,10),"History batch %d" % i)
	var recent: Array=history.snapshot().lottery_history
	check(recent.size()==50 and recent[0].sequence==11 and recent[-1].sequence==60,"History retains only last 50 in sequence")
	check(reload(history).snapshot()==history.snapshot(),"Truncated history survives load without granting again")

func duplicates_and_cycles() -> void:
	var p := fixture(15)
	for entry in CafeProfile.reward_catalog.cosmetics:
		if entry.rarity=="regular":
			check(p.grant_cosmetic(entry.id),"Grant regular cosmetic through shared ownership API")
	for entry in CafeProfile.cafe_catalog.decorations:
		if entry.rarity=="regular":
			check(p.grant_decoration(entry.id),"Reuse existing decoration inventory")
	for category in ["regular_cosmetics","regular_decorations"]:
		p.reward_rng.seed=seed_for(category)
		var balance := p.coins
		check(roll(p,1) and p.coins==balance+500 and p.last_roll_results[0].duplicate_fallback,"Regular duplicate pays exactly 500 Coins: "+category)
	var exclusive_ids: Array=[]
	for i in range(4):
		p.reward_rng.seed=seed_for("exclusive")
		check(roll(p,1),"Exclusive draw succeeds")
		var reward: Dictionary=p.last_roll_results[0]
		check(reward.coins==0 and reward.item_id not in exclusive_ids,"Exclusives always choose an unowned item")
		exclusive_ids.append(reward.item_id)
	p.reward_rng.seed=seed_for("exclusive")
	var balance := p.coins
	check(roll(p,1) and p.coins==balance+1000 and p.last_roll_results[0].fallback=="exhausted_pool","Exhausted exclusive pool pays 1000, not unreleased seasonal items")
	for entry in CafeProfile.reward_catalog.all_items(CafeProfile.cafe_catalog.decorations):
		if not entry.origin_season.is_empty():
			check(not p.owns_cosmetic(entry.id) and not p.owns_decoration(entry.id),"Unreleased seasonal item never awarded")
	var counts := p.collections()
	for group in RewardCatalog.GROUPS:
		check(counts[group].owned==counts[group].total and counts[group].percent==100,"Complete collection calculated from single inventory: "+group)
	var before := p.snapshot()
	check(p.grant_cosmetic("strawberry_badge") and p.snapshot()==before,"Cosmetic grant is unique and idempotent")
	check(not p.grant_cosmetic("unknown") and not p.equip_cosmetic("unknown"),"Invalid cosmetic identifier rejected")
	check(p.equip_cosmetic("strawberry_badge") and p.snapshot().equipped_cosmetics.cafe_badge=="strawberry_badge","Equip owned cosmetic without editing artwork")
	check(reload(p).snapshot().equipped_cosmetics.cafe_badge=="strawberry_badge","Cosmetic equipment persists")
	check(p.equip_cosmetic("") and p.owns_cosmetic("strawberry_badge"),"Unequip preserves cosmetic ownership")
	for category in ["coins","regular_cosmetics","regular_decorations"]:
		p.reward_rng.seed=seed_for(category,true)
		var prior_coins := p.coins
		var tickets := p.tickets
		var cycle := p.cycles
		check(p.grant_xp(1000) and p.tickets==tickets+1 and p.cycles==cycle+1,"Cycle grants ticket in addition to reward")
		check(p.coins==prior_coins+(1000 if category=="coins" else 500),"Cycle regular exhaustion substitute: "+category)
		check(p.snapshot().cycle_rewards[-1].category==category and p.snapshot().cycle_rewards[-1].cycle_id==cycle+1,"Cycle outcome has stable receipt, no ticket consumption")
	# Same seed twice must select the same regular candidate; cycle skips owned items.
	var candidate := CafeProfile.defaults()
	for category in ["regular_cosmetics","regular_decorations"]:
		var rng := RandomNumberGenerator.new()
		rng.seed=seed_for(category,true)
		var first := GoldenPawRewards.outcome(candidate,CafeProfile.reward_catalog,CafeProfile.cafe_catalog.decorations,rng,true)
		GoldenPawRewards.apply(candidate,first,CafeProfile.reward_catalog)
		rng.seed=seed_for(category,true)
		var second := GoldenPawRewards.outcome(candidate,CafeProfile.reward_catalog,CafeProfile.cafe_catalog.decorations,rng,true)
		check(first.coins==0 and second.coins==0 and first.item_id!=second.item_id,"Cycle rewards choose unowned regular items uniformly")

func migration_and_failures() -> void:
	serial+=1
	var path := folder.path_join("legacy%d/profile.json" % serial)
	var old := CafeProfile.defaults()
	old.schema_version=2
	old.level=50
	old.welcome_granted=true
	old.pending_welcome_ticket=true
	old.cycles=3
	old.pending_cycle_tickets=3
	old.cycle_xp=40
	old.coins=2345
	old.upgrades={"brewing_equipment":2}
	old.owned_decorations=["pink_paw_plaque"]
	old.equipped_decorations.wall_display="pink_paw_plaque"
	old.completed_days=12
	old.team=["odin","momo","blaze"]
	for key in ["lottery_tickets","welcome_processed","resolved_cycles","cycle_rewards","owned_cosmetics","equipped_cosmetics","lottery_history","next_roll_sequence","released_seasons"]:
		old.erase(key)
	write_raw(path,old)
	var p := CafeProfile.new()
	p.open(path)
	check(p.tickets==4 and p.pending_tickets==0 and p.snapshot().schema_version==CafeProfile.VERSION,"Schema 2 pending entitlements migrate and resolve")
	check(p.completed_days==12 and p.cycle_xp==40 and p.upgrade_level("brewing_equipment")==2 and p.equipped_decorations().wall_display=="pink_paw_plaque" and p.team_slots==old.team,"Migration preserves old permanent progression and slots")
	var resolved := p.snapshot()
	for i in range(3):
		check(reload(p).snapshot()==resolved,"Legacy entitlements cannot replay after reload")
	var bad := resolved.duplicate(true)
	bad.lottery_tickets+=1
	check(not CafeProfile.normalize(bad).ok,"Invalid ticket accounting is rejected")
	bad=resolved.duplicate(true)
	bad.equipped_cosmetics={"cafe_badge":"unknown"}
	bad.owned_cosmetics=["unknown",4]
	var repaired := CafeProfile.normalize(bad)
	check(repaired.ok and repaired.data.owned_cosmetics.is_empty() and repaired.data.equipped_cosmetics.cafe_badge=="","Invalid cosmetic ownership/equipment safely repairs")
	var failure := fixture(11)
	var durable := failure.snapshot()
	var saved_path := failure.store.path
	var obstruction := saved_path.get_base_dir().path_join("obstruction")
	write_raw(obstruction,"block")
	failure.store.path=obstruction.path_join("save.json")
	failure.reward_rng.seed=123
	var rng_state := failure.reward_rng.state
	check(not roll(failure,10) and failure.snapshot()==durable and failure.reward_rng.state==rng_state,"Failed batch write spends nothing, grants nothing, restores RNG")
	failure.store.path=saved_path
	check(roll(failure,10) and reload(failure).snapshot()==failure.snapshot(),"Failed roll can retry and persists atomically")
	var deferred := CafeProfile.defaults()
	deferred.level=50
	deferred.welcome_granted=true
	deferred.pending_welcome_ticket=true
	deferred.cycles=2
	deferred.pending_cycle_tickets=2
	failure._data=deferred
	failure.store.path=obstruction.path_join("save.json")
	check(not failure.resolve_level50_rewards() and failure.snapshot()==deferred,"Failed entitlement resolution retains every pending reward")
	failure.store.path=saved_path
	check(failure.resolve_level50_rewards() and failure.tickets==3 and failure.pending_tickets==0,"Resolution retry grants exactly once")
	var many := fixture(140)
	check(many.snapshot().resolved_cycles==128 and many.pending_tickets==12,"Huge legacy backlog uses bounded transactional batches")
	check(many.resolve_level50_rewards() and many.tickets==141 and many.pending_tickets==0,"Further resolution preserves unprocessed remainder")
	# Simulate an orphan staged roll. Loading ignores it and preserves committed balance.
	var orphan := failure.snapshot()
	write_raw(saved_path+".tmp",orphan)
	check(reload(failure).snapshot()==orphan,"Staged file cannot replay a lottery reward")

func settle() -> void:
	for i in range(10):
		await process_frame

func click(control: Button, touch: bool, scroll: ScrollContainer = null) -> void:
	if scroll!=null:
		scroll.ensure_control_visible(control)
		await settle()
	check(control.is_visible_in_tree() and not control.disabled,"UI enabled: "+control.text)
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
	root.content_scale_size=Vector2i(720,1280)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	for dimensions in [Vector2i(720,1280),Vector2i(320,568)]:
		root.size=dimensions
		var touch: bool = dimensions.x==320
		var p := fixture(-1)
		var main := MAIN.instantiate() as Control
		var session := main.get_node("CafeSession") as CafeSession
		session.profile=p
		root.add_child(main)
		session.set_process(false)
		await settle()
		var view := main.get_node("GameplayView")
		await click(view.get_node("DayLobby/Content/Layout/Shop"),touch)
		var shop := view.get_node("CafeShopScreen")
		await click(shop.get_node("Content/Layout/Scroll/Body/GoldenPaw"),touch,shop.get_node("Content/Layout/Scroll"))
		var panel := view.get_node("RewardsScreen")
		check(panel.visible and session.view==CafeSession.View.REWARDS and panel.roll_one.disabled,"Visible locked booth before first shift")
		await click(panel.get_node("Content/Layout/Settings"),touch)
		await click(main.get_node("SettingsPanel/Center/Panel/Margins/Layout/Close"),touch)
		check(root.gui_get_focus_owner()==panel.get_node("Content/Layout/Settings"),"Reward Settings restores keyboard focus")
		p.grant_xp(27195+12000)
		await settle()
		var scroll := panel.get_node("Content/Layout/Scroll") as ScrollContainer
		await click(panel.roll_ten,touch,scroll)
		check(p.tickets==3 and panel.results.size()==10 and panel.outcome_text.text.count("#")==10,"Roll 10 input displays all outcomes")
		check(panel.roll_ten.disabled and panel.roll_one.disabled,"Post-roll quote prevents double-tap spending")
		await click(panel.review,touch,scroll)
		await click(panel.roll_one,touch,scroll)
		check(p.tickets==2,"Reviewed Roll 1 input spends exactly one")
		await click(panel.get_node("Content/Layout/Tabs/Collections"),touch)
		p.grant_cosmetic("strawberry_badge")
		p.grant_decoration("golden_paw_lantern")
		await settle()
		await click(panel.cards.strawberry_badge.button,touch,scroll)
		check(p.snapshot().equipped_cosmetics.cafe_badge=="strawberry_badge","Input equips owned cosmetic")
		await click(panel.cards.golden_paw_lantern.button,touch,scroll)
		check(p.equipped_decorations().wall_display=="golden_paw_lantern","Collection uses existing decoration display inventory")
		for name in ["Heading","Status","Tabs","Scroll","Settings","Back"]:
			var control := panel.get_node("Content/Layout/"+name) as Control
			check(Rect2(Vector2.ZERO,main.size).encloses(control.get_global_rect()),"Reward layout bounds %s at %s" % [name,dimensions])
		for control in panel.find_children("*","Control",true,false):
			if control is Button:
				check(control.size.y*main.ui_scale>=44 and control.size.x*main.ui_scale>=44,"48px reward touch target")
			if control is Label:
				check(control.get_theme_font_size("font_size")*main.ui_scale>=16,"Readable reward label")
		await click(panel.get_node("Content/Layout/Back"),touch)
		check(session.view==CafeSession.View.LOBBY,"Back returns to opening through shop route")
		session.start_next_day()
		await settle()
		await click(main.get_node("Content/Layout/BottomNavigation/Map"),touch)
		panel.show_tab(false)
		check(panel.visible and panel.roll_one.disabled,"Map opens view-only rewards during shift")
		var before := session.elapsed
		session.advance_time(2)
		check(session.elapsed==before+2,"Shift clock keeps running in rewards")
		panel.show_tab(true)
		check(panel.cards.strawberry_badge.button.disabled,"Collection equip disabled during shift")
		panel.get_node("Content/Layout/Back").grab_focus()
		var key := InputEventKey.new()
		key.keycode=KEY_ENTER
		key.pressed=true
		root.push_input(key,true)
		await settle()
		key=InputEventKey.new()
		key.keycode=KEY_ENTER
		key.pressed=false
		root.push_input(key,true)
		check(session.view==CafeSession.View.CAFE,"Keyboard Back preserves navigation")
		session.advance_time(400)
		session.open_rewards()
		await settle()
		check(session.can_edit_cafe() and not panel.roll_one.disabled,"Rewards editable after results")
		if DisplayServer.get_name()!="headless":
			panel.show_tab(false)
			await settle()
			await process_frame
			root.get_texture().get_image().save_png(folder.path_join("lottery-%d.png" % dimensions.x))
			panel.show_tab(true)
			await settle()
			await process_frame
			root.get_texture().get_image().save_png(folder.path_join("collections-%d.png" % dimensions.x))
		for resized in [Vector2i(1280,720),Vector2i(1920,1080),dimensions]:
			root.size=resized
			await settle()
			var bounds: Control=panel.get_node("Content")
			check(absf(bounds.get_global_rect().get_center().x-main.size.x/2)<1,"Rewards stay centered after resize: "+str(resized))
			check(Rect2(Vector2.ZERO,main.size).encloses(panel.get_node("Content/Layout/Back").get_global_rect()),"Reward Back accessible after resize: "+str(resized))
		main.queue_free()
		await process_frame
		print("PASS lottery UI at ",dimensions)
