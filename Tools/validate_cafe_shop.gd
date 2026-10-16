extends SceneTree
## Isolated catalog, transaction, migration, stacking and native UI integration checks.
const SESSION := preload("res://Scenes/Gameplay/CafeSession.tscn")
const MAIN := preload("res://Scenes/Main.tscn")
var folder := "/tmp/paw-shop-tests-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
var serial := 0
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func write_raw(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	assert(file!=null)
	file.store_string(text)
	file.close()

func fixture(coins: int = 10000, reputation: int = 10) -> CafeProfile:
	serial+=1
	var path := folder.path_join("%d/profile.json" % serial)
	var data := CafeProfile.defaults()
	data.coins=coins
	data.level=reputation
	write_raw(path,JSON.stringify(data))
	var p := CafeProfile.new()
	p.open(path)
	return p

func reload(p: CafeProfile) -> CafeProfile:
	var restored := CafeProfile.new()
	restored.open(p.store.path)
	return restored

func make_session(p: CafeProfile, active: String = "mochi", a: String = "fade", b: String = "max") -> CafeSession:
	p.set_team([active,a,b])
	var s := SESSION.instantiate() as CafeSession
	s.profile=p
	s.recipe_override="basic_coffee"
	s.normal_arrival_interval=Vector2(1000,1000)
	s.rush_arrival_interval=Vector2(1000,1000)
	root.add_child(s)
	s.set_process(false)
	return s

func upgrade_all(p: CafeProfile) -> void:
	for entry in CafeProfile.cafe_catalog.upgrades:
		check(p.purchase_upgrade(entry.id,0),"Purchase one level: "+entry.id)

func begin(s: CafeSession) -> void:
	s.open_order(s.order_at_seat(0))
	s.accept_order()
	s.open_station()
	for ingredient in s.get_order(s.selected_order_id).recipe.ingredients:
		s.toggle_ingredient(ingredient)
	s.start_brewing()

func finish(s: CafeSession, duration: float) -> void:
	s.advance_time(duration)
	s.stop_preparation()
	s.finish_coffee()

func run() -> void:
	catalogs()
	upgrade_transactions()
	decorations_and_slots()
	migration_and_failures()
	gameplay_stacking()
	await shop_inputs()
	if failures==0:
		print("PASS: %d café shop assertions (isolated saves: %s)" % [checks,folder])
	quit(0 if failures==0 else 1)

func catalogs() -> void:
	var catalog := CafeCatalog.new()
	check(catalog.errors.is_empty() and catalog.upgrades.size()==4 and catalog.decorations.size()>=6,"Four upgrades and six valid original decorations")
	var ids: Array=[]
	for entry in catalog.upgrades:
		check(entry.id not in ids and CafeCatalog.validate_upgrade(entry).is_empty(),"Unique valid upgrade "+entry.id)
		ids.append(entry.id)
	for entry in catalog.decorations:
		check(entry.id not in ids and CafeCatalog.validate_decoration(entry).is_empty(),"Unique valid decoration "+entry.id)
		ids.append(entry.id)
	for change in [{"max_level":0},{"effect":"unknown"},{"costs":[60,30,10]},{"costs":[1.5,2,3]},{"minimum_reputation":[1,2,51]},{"value_per_level":-0.1}]:
		var bad := catalog.upgrades[0].duplicate(true)
		bad.merge(change,true)
		check(not CafeCatalog.validate_upgrade(bad).is_empty(),"Invalid upgrade definition rejected: "+str(change))
	for change in [{"price":-1},{"slot":"unknown"},{"minimum_reputation":51},{"asset":"res://missing.png"},{"symbol":"unknown"}]:
		var bad := catalog.decorations[0].duplicate(true)
		bad.merge(change,true)
		check(not CafeCatalog.validate_decoration(bad).is_empty(),"Invalid decoration definition rejected: "+str(change))
	check(not CafeCatalog.purchase_gate(2,1,999,10).allowed and not CafeCatalog.purchase_gate(1,1,0,10).allowed and not CafeCatalog.purchase_gate(1,1,999,10,true).allowed,"Reusable Reputation, affordability and ownership gates")

func upgrade_transactions() -> void:
	var p := fixture()
	var balance := p.coins
	for entry in CafeProfile.cafe_catalog.upgrades:
		for level in range(int(entry.max_level)):
			check(p.purchase_upgrade(entry.id,level),"Purchase valid next level")
			balance-=int(entry.costs[level])
			check(p.coins==balance and p.upgrade_level(entry.id)==level+1,"Coin deduction and upgrade increment are atomic")
			var committed := p.snapshot()
			check(not p.purchase_upgrade(entry.id,level) and p.snapshot()==committed,"Repeated/stale quote cannot buy next level")
			p=reload(p)
			check(p.snapshot()==committed and not p.purchase_upgrade(entry.id,level),"Purchase and replay protection survive reload")
		check(not p.purchase_upgrade(entry.id,3),"Upgrade cap cannot be exceeded")
	var bonuses := p.upgrade_bonuses()
	check(is_equal_approx(bonuses.speed,0.09) and is_equal_approx(bonuses.patience,0.09) and bonuses.quality==6 and is_equal_approx(bonuses.tip,0.15),"Prototype caps apply once per level")
	for invalid in [-1,1.5,"1",true,null]:
		check(not p.purchase_upgrade("brewing_equipment",invalid),"Invalid quote level rejected")
	check(not p.purchase_upgrade("missing",0),"Unknown upgrade rejected")
	var poor := fixture(40,10)
	check(not poor.purchase_upgrade("brewing_equipment",0) and poor.coins==40 and poor.upgrade_level("brewing_equipment")==0,"Insufficient Coins cannot mutate upgrade state")
	var locked := fixture(10000,1)
	check(not locked.purchase_upgrade("better_ingredients",0),"Minimum Reputation unlock enforced")
	check(locked.purchase_upgrade("brewing_equipment",0) and not locked.purchase_upgrade("brewing_equipment",1),"Next-level Reputation unlock is independent of first level")
	var reentrant := fixture()
	var nested: Array=[]
	reentrant.changed.connect(func(): nested.append(reentrant.purchase_upgrade("brewing_equipment",1)),CONNECT_ONE_SHOT)
	check(reentrant.purchase_upgrade("brewing_equipment",0) and nested==[false] and reentrant.upgrade_level("brewing_equipment")==1,"Reentrant signals cannot chain purchases")

func decorations_and_slots() -> void:
	var p := fixture()
	var balance := p.coins
	for entry in CafeProfile.cafe_catalog.decorations:
		check(p.purchase_decoration(entry.id),"Decoration purchase "+entry.id)
		balance-=int(entry.price)
		var committed := p.snapshot()
		check(p.owns_decoration(entry.id) and p.coins==balance and not p.purchase_decoration(entry.id) and p.snapshot()==committed,"Unique ownership prevents duplicate deduction")
		check(p.grant_decoration(entry.id) and p.snapshot()==committed,"Repeated future grant is idempotent and free")
	check(reload(p).snapshot()==p.snapshot(),"All decoration ownership survives reload")
	check(not p.purchase_decoration("missing") and not p.grant_decoration("missing"),"Invalid item IDs rejected")
	check(p.equip_decoration("wall_display","pink_paw_plaque"),"Equip owned compatible item")
	check(not p.equip_decoration("shelf_display","pink_paw_plaque") and not p.equip_decoration("unknown","pink_paw_plaque"),"Wrong slot and invalid slot rejected")
	check(p.equip_decoration("wall_display","morning_mug_sign") and p.owns_decoration("pink_paw_plaque"),"Replacement preserves former ownership")
	check(p.equip_decoration("shelf_display","mint_leaf_jar") and p.equip_decoration("floor_display","cozy_star_mat"),"All three display slots support items")
	check(reload(p).equipped_decorations()==p.equipped_decorations(),"Slot assignments persist")
	var before := p.snapshot()
	check(p.equip_decoration("wall_display","morning_mug_sign") and p.snapshot()==before,"Repeated equip is idempotent")
	check(p.equip_decoration("wall_display","") and p.owns_decoration("morning_mug_sign"),"Unequip never deletes ownership")
	var free := fixture(0,1)
	check(not free.purchase_decoration("pink_paw_plaque") and not free.equip_decoration("wall_display","pink_paw_plaque"),"Cannot buy without Coins or equip without ownership")
	check(free.grant_decoration("strawberry_heart_cushion") and free.coins==0 and free.owns_decoration("strawberry_heart_cushion"),"Future rewards use same inventory and bypass shop unlock without charge")
	check(not free.purchase_decoration("morning_mug_sign"),"Locked decoration rejected")
	var free_shift := free.begin_shift()
	var empty_slots := free.equipped_decorations()
	check(free.grant_decoration("mint_leaf_jar") and free.coins==0 and free.equipped_decorations()==empty_slots,"New reward during shift grants only ownership, never a display")
	check(not free.equip_decoration("shelf_display","mint_leaf_jar"),"Reward inventory cannot bypass active-shift display lock")
	free.complete_shift(free_shift)
	check(free.equip_decoration("shelf_display","mint_leaf_jar"),"Granted item can be displayed after the shift")
	var shift := p.begin_shift()
	check(not p.purchase_upgrade("brewing_equipment",0) and not p.purchase_decoration("pink_paw_plaque") and not p.equip_decoration("wall_display","pink_paw_plaque"),"Profile enforces active-shift purchase/equip lock")
	check(p.grant_decoration("pink_paw_plaque"),"Reward ownership API remains safe during active shifts")
	check(p.complete_shift(shift) and p.can_manage_cafe(),"Completed shift unlocks editing")

func migration_and_failures() -> void:
	var p := fixture(2000,50)
	p.grant_xp(2500)
	var old := p.snapshot()
	old.schema_version=1
	old.completed_days=7
	old.team=["odin","momo","blaze"]
	for key in ["upgrades","owned_decorations","equipped_decorations"]:
		old.erase(key)
	serial+=1
	var legacy_path := folder.path_join("legacy-%d/profile.json" % serial)
	write_raw(legacy_path,JSON.stringify(old))
	var migrated := CafeProfile.new()
	migrated.open(legacy_path)
	for key in old:
		if key!="schema_version":
			check(migrated.snapshot()[key]==old[key],"Version 1 migration preserves "+key)
	check(migrated.snapshot().schema_version==2 and migrated.upgrade_level("brewing_equipment")==0 and migrated.snapshot().owned_decorations.is_empty(),"Version 1 adds empty upgrade/inventory fields")
	check(migrated.pending_tickets==3 and migrated.purchase_upgrade("brewing_equipment",0),"Migration preserves Level 50 entitlements and permits purchase")
	check(reload(migrated).pending_tickets==3 and reload(migrated).completed_days==7,"Migration and purchase remain durable")
	var malformed := migrated.snapshot()
	malformed.upgrades={"brewing_equipment":999,"comfortable_seating":-1,"better_ingredients":1.5,"unknown":3}
	malformed.owned_decorations=["pink_paw_plaque","pink_paw_plaque","unknown",7]
	malformed.equipped_decorations={"wall_display":"pink_paw_plaque","shelf_display":"pink_paw_plaque","floor_display":"cozy_star_mat","unknown":"pink_paw_plaque"}
	var repaired := CafeProfile.normalize(malformed)
	check(repaired.ok and repaired.repaired and repaired.data.coins==malformed.coins and repaired.data.pending_cycle_tickets==malformed.pending_cycle_tickets,"Malformed shop fields repair without resetting economy or entitlements")
	check(repaired.data.upgrades=={"brewing_equipment":3} and repaired.data.owned_decorations==["pink_paw_plaque"] and repaired.data.equipped_decorations=={"wall_display":"pink_paw_plaque","shelf_display":"","floor_display":""},"Invalid levels, ownership, unknown and incompatible slots repaired")
	var broken := migrated.snapshot()
	broken.upgrades=[]
	broken.owned_decorations={}
	broken.equipped_decorations=[]
	var normalized_broken := CafeProfile.normalize(broken)
	check(normalized_broken.ok and normalized_broken.data.upgrades is Dictionary and normalized_broken.data.owned_decorations is Array and normalized_broken.data.equipped_decorations is Dictionary,"Missing/malformed inventory container types recover")
	var failed := fixture()
	var good_path := failed.store.path
	var obstruction := good_path.get_base_dir().path_join("not-a-directory")
	write_raw(obstruction,"block")
	failed.store.path=obstruction.path_join("profile.json")
	var before := failed.snapshot()
	check(not failed.purchase_upgrade("brewing_equipment",0) and failed.snapshot()==before,"Failed save cannot spend Coins or add upgrade")
	check(not failed.purchase_decoration("pink_paw_plaque") and not failed.grant_decoration("mint_leaf_jar") and failed.snapshot()==before,"Failed save cannot add paid or granted ownership")
	failed.store.path=good_path
	check(failed.purchase_upgrade("brewing_equipment",0) and failed.coins==before.coins-60,"Safe retry charges once")
	check(failed.grant_decoration("pink_paw_plaque"),"Establish owned decoration")
	before=failed.snapshot()
	failed.store.path=obstruction.path_join("profile.json")
	check(not failed.equip_decoration("wall_display","pink_paw_plaque") and failed.snapshot()==before,"Failed equip save leaves display unchanged")
	failed.store.path=good_path
	check(reload(failed).snapshot()==before,"Disk retains pre-failure ownership and Coins")

func gameplay_stacking() -> void:
	var p := fixture()
	upgrade_all(p)
	var s := make_session(p,"mochi","momo","max")
	s.start_next_day()
	check(is_equal_approx(s.get_order(1).original_patience,64.8),"Patience upgrade adds to Mochi passive before customer creation")
	begin(s)
	check(is_equal_approx(s.preparation_target(),3.0/1.08),"Real target combines Max passive and upgrade speed")
	finish(s,s.preparation_target())
	check(s.get_order(1).quality_score==100,"Final quality bonuses clamp at 100")
	s.advance_time(45.361-s.elapsed)
	check(is_equal_approx(s.get_order(1).deadline,71.28),"Mochi restoration uses upgraded original patience")
	s.open_shop()
	var stable := s.gameplay_bonuses()
	check(not s.buy_upgrade("comfortable_seating",1) and stable==s.gameplay_bonuses(),"Read-only shop cannot change shift stats")
	s.free()
	for fixture_data in [["fade","max","momo",1.28],["max","momo","blaze",1.23]]:
		var fast := fixture()
		upgrade_all(fast)
		var run_session := make_session(fast,fixture_data[0],fixture_data[1],fixture_data[2])
		run_session.start_next_day()
		begin(run_session)
		check(is_equal_approx(run_session.preparation_target(),3.0/float(fixture_data[3])),"Preparation active/passive/upgrade additive speed: "+fixture_data[0])
		finish(run_session,run_session.preparation_target())
		check(run_session.get_order(1).quality_score==100,"Adjusted target scores perfectly")
		run_session.free()
	for score in [74,75,94,95,100]:
		var quality := fixture()
		upgrade_all(quality)
		var blaze := make_session(quality,"blaze","fade","odin")
		blaze.start_next_day()
		begin(blaze)
		var target := blaze.preparation_target()
		var duration: float = target*(1.0+(100.0-(score-7))/35.0) if score<100 else target
		finish(blaze,duration)
		var converted: bool=score>=75 and score<=94
		check(blaze.get_order(1).quality_score==(95 if converted else score),"Upgrade quality applied before Blaze tier boundary %d" % score)
		blaze.free()
	var premium := fixture()
	upgrade_all(premium)
	var odin := make_session(premium,"odin","fade","max")
	odin.start_next_day()
	odin.get_order(1).recipe.base_coins=100
	begin(odin)
	finish(odin,odin.preparation_target())
	odin.open_order(1)
	var balance := odin.coins
	odin.serve()
	odin.serve()
	check(odin.get_order(1).ordinary_tip==17 and odin.get_order(1).premium_tip==15 and odin.coins==balance+132 and odin.reputation_earned==15,"Upgrade ordinary tip stacks with Fade/Odin; separate premium remains 15; rewards once")
	odin.free()

func settle() -> void:
	for frame in range(8):
		await process_frame

func click(button: Button, touch: bool, scroll: ScrollContainer = null, allow_disabled: bool = false) -> void:
	if scroll!=null:
		scroll.ensure_control_visible(button)
		await settle()
	if not allow_disabled:
		check(button.is_visible_in_tree() and not button.disabled,"Enabled shop input: "+button.name)
	var position := button.get_global_rect().get_center()
	for pressed in [true,false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.position=root.get_final_transform()*position
			event.index=0
			event.pressed=pressed
			Input.parse_input_event(event)
		else:
			var event := InputEventMouseButton.new()
			event.position=position
			event.button_index=MOUSE_BUTTON_LEFT
			event.pressed=pressed
			root.push_input(event,true)
	await settle()

func key_press(key: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=key
		event.pressed=pressed
		Input.parse_input_event(event)
	await settle()

func shop_inputs() -> void:
	root.content_scale_size=Vector2i(720,1280)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	for dimensions in [Vector2i(720,1280),Vector2i(320,568)]:
		root.size=dimensions
		var touch: bool=dimensions.x==320
		var p := fixture(600,10)
		var main := MAIN.instantiate() as Control
		var s := main.get_node("CafeSession") as CafeSession
		s.profile=p
		root.add_child(main)
		s.set_process(false)
		await settle()
		var view := main.get_node("GameplayView")
		var shop := view.get_node("CafeShopScreen")
		var layout := shop.get_node("Content/Layout")
		var scroll := layout.get_node("Scroll") as ScrollContainer
		await click(view.get_node("DayLobby/Content/Layout/Shop"),touch)
		check(shop.visible and s.view==CafeSession.View.UPGRADES,"Pre-day shop opens")
		var card: VBoxContainer=shop.upgrade_cards["brewing_equipment"]
		await click(card.get_node("Buy"),touch,scroll)
		await click(card.get_node("Buy"),touch,scroll,true)
		check(p.upgrade_level("brewing_equipment")==1 and p.coins==540 and card.get_node("Buy").disabled,"Double input cannot buy successive upgrade levels")
		await click(card.get_node("Review"),touch,scroll)
		card.get_node("Buy").grab_focus()
		await key_press(KEY_ENTER)
		check(p.upgrade_level("brewing_equipment")==2 and p.coins==420,"Explicit review + keyboard purchase buys next level")
		await check_shop_layout(main,shop)
		await click(layout.get_node("Tabs/Decorate"),touch)
		for id in ["pink_paw_plaque","mint_leaf_jar","cozy_star_mat"]:
			var item: VBoxContainer=shop.decoration_cards[id]
			await click(item.get_node("Buy"),touch,scroll)
			await click(item.get_node("Equip"),touch,scroll)
			check(p.owns_decoration(id),"Input purchases and equips "+id)
		check(p.coins==345 and reload(p).equipped_decorations()==p.equipped_decorations(),"UI purchases deduct and persist exact Coins/slots")
		await check_shop_layout(main,shop)
		await click(layout.get_node("Settings"),touch)
		await click(main.get_node("SettingsPanel/Center/Panel/Margins/Layout/Close"),touch)
		check(root.gui_get_focus_owner()==layout.get_node("Settings"),"Shop Settings restores focus")
		await key_press(KEY_ESCAPE)
		check(s.view==CafeSession.View.LOBBY,"Escape returns to pre-day")
		await click(view.get_node("DayLobby/Content/Layout/Action"),touch)
		await settle()
		var display := main.get_node("Content/Layout/Cafe/Stage/DecorationDisplay") as DecorationDisplay
		for slot in CafeCatalog.SLOT_IDS:
			var rect: Rect2=display.global_transform*display.marker_rect(slot)
			check(main.get_node("Content/Layout/Cafe").get_global_rect().encloses(rect),"Decoration stays inside café: "+slot)
			for name in ["Customer","CustomerRight","CoffeeEquipment"]:
				var button := view.get_node(name) as Button
				if button.visible:
					check(not rect.intersects(button.get_global_rect()),"Decoration does not cover interaction: "+slot+"/"+name)
		await click(main.get_node("Content/Layout/BottomNavigation/Upgrade"),touch)
		check(not s.can_edit_cafe() and shop.upgrade_cards["comfortable_seating"].get_node("Buy").disabled,"In-shift Upgrade navigation is view-only")
		var elapsed := s.elapsed
		s.advance_time(5)
		check(s.elapsed==elapsed+5,"Clock continues in shop")
		await click(layout.get_node("Tabs/Decorate"),touch)
		check(shop.slot_cards["wall_display"].get_node("Clear").disabled and not s.equip_decoration("wall_display",""),"In-shift decoration editing blocked")
		await click(layout.get_node("Back"),touch)
		s.advance_time(400)
		await settle()
		await click(view.get_node("DayResults/Content/Layout/Shop"),touch)
		await click(layout.get_node("Tabs/Decorate"),touch)
		await click(shop.slot_cards["wall_display"].get_node("Clear"),touch,scroll)
		check(p.equipped_decorations().wall_display=="" and p.owns_decoration("pink_paw_plaque"),"Results allow unequip without losing ownership")
		shop.decoration_cards["pink_paw_plaque"].get_node("Equip").grab_focus()
		await settle()
		await key_press(KEY_ENTER)
		check(p.equipped_decorations().wall_display=="pink_paw_plaque","Keyboard equips an owned decoration")
		for resized in [Vector2i(1280,720),Vector2i(1920,1080),dimensions]:
			root.size=resized
			await settle()
			var column := shop.get_node("Content") as Control
			check(absf(column.get_global_rect().get_center().x-main.size.x/2)<1,"Shop remains centered after resize "+str(resized))
			check(Rect2(Vector2.ZERO,main.size).encloses(layout.get_node("Back").get_global_rect()),"Shop Back accessible after resize "+str(resized))
		main.queue_free()
		await process_frame
		print("PASS café shop input at ",dimensions)

func check_shop_layout(main: Control, shop: Control) -> void:
	var layout := shop.get_node("Content/Layout")
	var bounds := Rect2(Vector2.ZERO,main.size)
	for path in ["Heading","Status","Tabs/Upgrades","Tabs/Decorate","Settings","Back"]:
		var control := layout.get_node(path) as Control
		check(bounds.encloses(control.get_global_rect()),"Shop fixed control in viewport: "+path)
		check(control.get_theme_font_size("font_size")*main.ui_scale>=16,"Readable shop fixed control: "+path)
		if control is Button:
			check(control.size.x*main.ui_scale>=44 and control.size.y*main.ui_scale>=44,"44px fixed shop target: "+path)
	var scroll := layout.get_node("Scroll") as ScrollContainer
	for button in shop.find_children("*","Button",true,false):
		if button.is_visible_in_tree() and scroll.is_ancestor_of(button):
			scroll.ensure_control_visible(button)
			await settle()
			check(scroll.get_global_rect().encloses(button.get_global_rect()),"Scrollable purchase control accessible: "+button.name)
			check(button.size.x*main.ui_scale>=44 and button.size.y*main.ui_scale>=44,"44px purchase/equip target: "+button.name)
