extends SceneTree
## Step 13A: production scoring/session/ledger, isolated durable saves and cold read.
const SESSION := preload("res://Scenes/Gameplay/CafeSession.tscn")
var checks := 0
var failures := 0
var serial := 0
var folder := "/tmp/paw-13a-regression-%d" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fixture() -> CafeProfile:
	serial += 1
	var p := CafeProfile.new()
	p.clock = func() -> int: return CafeProfile.season_catalog.anchor + 100
	p.open(folder.path_join("%d/profile.json" % serial))
	check(p.sync_season(), "Initialize isolated profile")
	return p

func reload_profile(p: CafeProfile) -> CafeProfile:
	var loaded := CafeProfile.new()
	loaded.clock = p.clock
	loaded.open(p.store.path)
	return loaded

func raw(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cold-read="):
			cold_read(arg.trim_prefix("--cold-read="))
			finish()
			return
	seasonal()
	quality()
	fractional()
	migration()
	await ui()
	cold_write()
	finish()

func finish() -> void:
	print("%s: %d Step 13A assertions; isolated files: %s" % ["PASS" if failures == 0 else "FAIL", checks, folder])
	quit(0 if failures == 0 else 1)

func seasonal() -> void:
	var catalog := CafeProfile.season_catalog
	check(catalog.data.day_xp == 200 and catalog.data.daily_xp == 150 and catalog.data.weekly_xp == 500, "Approved authoritative rates")
	var regular := 56 * int(catalog.data.day_xp) + 56 * int(catalog.data.daily_xp) + 8 * int(catalog.data.weekly_xp)
	check(regular == 23600 and int(regular / 500) == 47, "Regular model reaches Tier 47")
	var p := fixture()
	var state := p.snapshot()
	SeasonalProgress.add_xp(state.seasonal, regular, p.seasonal_now(), catalog)
	check(p._commit(state) and p.seasonal_state().current.earned.size() == 9, "Tier 47 earns first nine milestones")
	for i in range(7):
		var shift := p.begin_shift()
		check(p.complete_shift(shift), "Additional shift commits 200 XP")
		var saved := p.snapshot()
		check(p.complete_shift(shift) and p.snapshot() == saved, "Completed day remains exactly once")
	check(p.seasonal_state().current.xp == 25000 and p.seasonal_state().current.earned.size() == 10, "Seven additional shifts reach Tier 50")
	check(p.claim_inbox("paw-season-0001:tier:50"), "Final milestone is claimable")
	var claimed := p.snapshot()
	claimed.schema_version = 4
	claimed.erase("ordinary_tip_remainder")
	raw(folder.path_join("claimed/profile.json"), claimed)
	var claims_reload := CafeProfile.new()
	claims_reload.clock = p.clock
	claims_reload.open(folder.path_join("claimed/profile.json"))
	check(claims_reload.sync_season() and claims_reload.seasonal_state() == p.seasonal_state(), "Schema 4 retains earned rewards, Inbox and historical claim receipts")
	var claimed_before := claims_reload.snapshot()
	check(not claims_reload.claim_inbox("paw-season-0001:tier:50") and claims_reload.snapshot() == claimed_before, "Already claimed milestone cannot replay after migration")
	# An authentic old receipt/completed challenge retains its original payout.
	var old := fixture()
	var id := old.begin_shift()
	old.complete_shift(id)
	state = old.snapshot()
	state.schema_version = 4
	state.erase("ordinary_tip_remainder")
	state.seasonal.current.xp = 100
	for cadence in ["daily", "weekly"]:
		state.seasonal.current[cadence].completed = true
		state.seasonal.current[cadence].progress = int(catalog.challenge_definition(cadence, state.seasonal.current[cadence].id).target)
	raw(folder.path_join("old/profile.json"), state)
	var migrated := CafeProfile.new()
	migrated.clock = old.clock
	migrated.open(folder.path_join("old/profile.json"))
	check(migrated.sync_season() and migrated.seasonal_state().current.xp == 100, "Old seasonal XP not multiplied on schema migration")
	check(migrated.complete_shift(id) and migrated.seasonal_state().current.xp == 100, "Historical day receipt not replayed")
	id = migrated.begin_shift()
	check(migrated.apply_service(id, 1, 20, 15, 3) and migrated.seasonal_state().current.xp == 100, "Historical completed challenge not repaid")
	check(reload_profile(migrated).seasonal_state().current.xp == 100, "Preserved old progress survives reload")

func make_session(active: String, recipe: String, maximum_quality: bool = true) -> CafeSession:
	var s := SESSION.instantiate() as CafeSession
	s.profile = fixture()
	s.profile.set_team([active, "momo", "blaze"] if active != "blaze" else ["blaze", "momo", "mochi"])
	if maximum_quality:
		var data := s.profile.snapshot()
		data.upgrades.better_ingredients = 3
		check(s.profile._commit(data), "Fixture quality upgrades")
	s.recipe_override = recipe
	s.start_immediately = true
	s.normal_arrival_interval = Vector2(1000, 1000)
	s.rush_arrival_interval = Vector2(1000, 1000)
	root.add_child(s)
	s.set_process(false)
	return s

func prepare(s: CafeSession, selected: Array, duration_ratio: float = 1.0, id: int = 1) -> void:
	s.open_order(id)
	s.accept_order()
	s.open_station()
	s.select_station_order(id)
	for ingredient in selected:
		s.toggle_ingredient(ingredient)
	s.start_brewing()
	s.advance_time(s.preparation_target() * duration_ratio)
	s.stop_preparation()
	s.finish_coffee()

func quality() -> void:
	for recipe in DrinkCatalog.new().recipes:
		for missing in range(recipe.ingredients.size() + 1):
			var s := make_session("blaze", recipe.id)
			var selected: Array = recipe.ingredients.slice(missing)
			prepare(s, selected)
			var order := s.get_order(1)
			check(DrinkQuality.ingredients_complete(recipe.ingredients, selected) == (missing == 0), "Authoritative ingredient membership")
			if missing > 0:
				check(order.quality_score <= 74 and DrinkQuality.tier(order.quality_score) <= 1, "Missing %d %s capped despite maximum bonuses" % [missing, recipe.id])
				check(s.ability_activations.is_empty() and s.ability_remaining() == 0, "Ineligible Blaze never consumes or queues cooldown")
			else:
				check(order.quality_score == 100 and order.quality_tier == "Perfect", "Complete drink still Perfect")
			var raw_score := DrinkQuality.score(recipe.ingredients, selected, recipe.target_seconds, recipe.target_seconds, 2 if selected.is_empty() else 3)
			check(order.quality_score == DrinkQuality.final_score(raw_score, 16, missing == 0), "Raw scoring weights preserved before final completeness guard")
			s.free()
	for pair in [[74,1],[75,2],[94,2],[95,3]]:
		check(DrinkQuality.tier(pair[0]) == pair[1], "Tier boundaries unchanged")
	var converted := make_session("blaze", "basic_coffee", false)
	prepare(converted, converted.get_order(1).recipe.ingredients, 1.6)
	check(converted.get_order(1).quality_score == 95 and converted.ability_activations.size() == 1, "Complete Excellent converts to 95 Perfect")
	check(is_equal_approx(converted.ability_remaining(), 30), "Valid conversion starts existing 30 second cooldown")
	converted.free()
	var timing_only := make_session("odin", "basic_coffee", false)
	prepare(timing_only, timing_only.get_order(1).recipe.ingredients, 1.4)
	check(timing_only.get_order(1).quality_score > 74, "Timing error alone does not impose ingredient cap")
	timing_only.free()
	# Incomplete first drink must not queue a conversion onto an unrelated drink.
	var mixed := make_session("blaze", "honey_tea", false)
	prepare(mixed, ["Tea", "Water"])
	check(mixed.get_order(1).quality_score == 74 and mixed.ability_activations.is_empty(), "Old incomplete Excellent exploit capped")
	mixed.open_order(1)
	mixed.serve()
	mixed._arrive()
	var next := mixed.order_at_seat(0)
	prepare(mixed, mixed.get_order(next).recipe.ingredients, 1.6, next)
	check(mixed.get_order(next).quality_score == 95 and mixed.ability_activations.size() == 1, "Next complete Excellent can use unspent Blaze ability")
	mixed.free()

func fractional() -> void:
	# Fixed-point precision, plus old whole payouts, across catalog prices/tiers/bonuses.
	for base in [10,12,14]:
		for score in [0,50,75,95]:
			for percent in [0,5,10,15,20,25]:
				var result := DrinkQuality.reward(base, score, percent / 100.0)
				var tip_percent: int = DrinkQuality.TIP_PERCENT[DrinkQuality.tier(score)]
				var expected_whole: int = base * tip_percent * (100 + percent) / 10000
				var ordinary_whole: int = base * tip_percent / 100
				var unpaid := maxi(0, base * tip_percent * percent - (expected_whole - ordinary_whole) * 10000)
				check(result.tip == expected_whole and result.bonus_units == unpaid and unpaid < 10000, "Whole payout and unpaid bonus fixed-point exact")
	check(DrinkQuality.reward(14,95,0.05).bonus_units == 1050, "5% of raw 2.1 tip is .105 Coins, not 5% of floored 2")
	check(DrinkQuality.reward(12,95,0.15).tip == 2 and DrinkQuality.reward(12,95,0.15).bonus_units == 0, "Training whole threshold already covers bonus; no double-counted fraction")
	var p := fixture()
	var shift := p.begin_shift()
	var reward := DrinkQuality.reward(10,95,0.05)
	for i in range(1,41):
		var before := p.snapshot()
		check(p.apply_service(shift,i,reward.coins,reward.xp,3,reward.bonus_units), "Successful fractional service")
		var total_units := i * 750
		check(p.coins == 120 + i*11 + int(total_units/10000) and p.snapshot().ordinary_tip_remainder == total_units%10000, "Fractions accumulate and settle exactly at whole Coin thresholds")
		var saved := p.snapshot()
		check(not p.apply_service(shift,i,reward.coins,reward.xp,3,reward.bonus_units) and p.snapshot()==saved, "Duplicate service cannot move fractional balance")
		check(p.coins >= int(before.coins), "Nonnegative service payout")
	check(p.snapshot().ordinary_tip_remainder == 0 and p.coins == 563, "40 × .075 gives exactly three bonus Coins")
	var loaded := reload_profile(p)
	check(loaded.snapshot() == p.snapshot(), "Coin and remainder durable together")
	check(not loaded.apply_service(shift,41,11,15,3,750), "Reload rejects stale service instead of replaying fraction")
	# Failed staged save cannot consume a threshold crossing; retry settles once.
	shift = loaded.begin_shift()
	var data := loaded.snapshot()
	data.ordinary_tip_remainder = 9750
	check(loaded._commit(data), "Fixture fractional threshold")
	var before := loaded.snapshot()
	var original := loaded.store.path
	var block := original.get_base_dir().path_join("block")
	var file := FileAccess.open(block,FileAccess.WRITE)
	file.store_string("obstruction")
	file.close()
	loaded.store.path = block.path_join("profile.json")
	check(not loaded.apply_service(shift,1,11,15,3,750) and loaded.snapshot()==before, "Failed persistence retains Coins, XP, challenge progress, receipt and remainder")
	loaded.store.path = original
	check(loaded.apply_service(shift,1,11,15,3,750) and loaded.coins == int(before.coins)+12 and loaded.snapshot().ordinary_tip_remainder==500, "Retry commits threshold Coin exactly once")
	check(reload_profile(loaded).snapshot()==loaded.snapshot(), "Threshold Coin and remainder reload consistently")
	for invalid in [-1,10000,0.5,"750"]:
		before = loaded.snapshot()
		check(not loaded.apply_service(shift,2,11,15,3,invalid) and loaded.snapshot()==before, "Invalid fixed-point grant rejected")
	# Challenge Coin progress uses the actual settlement, including carried whole Coins.
	var coin_challenge := fixture()
	for day in range(56):
		var when := CafeProfile.season_catalog.anchor + day*86400 + 100
		if CafeProfile.season_catalog.challenge(CafeProfile.season_catalog.season_at(when),when,"daily").id == "daily_coins":
			coin_challenge.clock = func() -> int: return when
			break
	check(coin_challenge.sync_season(), "Select a deterministic service-Coin challenge period")
	data = coin_challenge.snapshot()
	data.seasonal.current.daily.progress = 88
	data.ordinary_tip_remainder = 9750
	check(coin_challenge._commit(data), "Fixture Coin progress just below threshold")
	var coin_shift := coin_challenge.begin_shift()
	check(coin_challenge.apply_service(coin_shift,1,11,15,3,750), "Service plus carried Coin commits together")
	check(coin_challenge.seasonal_state().current.daily.completed and coin_challenge.seasonal_state().current.daily.progress==100 and coin_challenge.seasonal_state().current.xp==150, "Challenge sees actual twelve Coins, grants 150 XP exactly once")
	# Real CafeSession end-to-end Fade/Odin passives, additive Training and premium.
	for active in ["fade", "odin"]:
		var s := SESSION.instantiate() as CafeSession
		s.profile = fixture()
		s.profile.set_team([active,"mochi","max"])
		data = s.profile.snapshot()
		data.upgrades.service_training = 2
		data.ordinary_tip_remainder = 9750
		s.profile._commit(data)
		s.recipe_override = "basic_coffee"
		s.start_immediately = true
		root.add_child(s)
		s.set_process(false)
		prepare(s, s.get_order(1).recipe.ingredients)
		var ready := s.get_order(1)
		check(ready.ordinary_bonus_units == 2250, "Cat 5% plus Training 10% add to actual 15% bonus")
		check(s.profile.snapshot().ordinary_tip_remainder == 9750, "Preparation alone never grants fractions")
		var quote := s.service_preview(ready)
		check(quote.carry==1 and quote.premium==(1 if active=="odin" else 0), "Odin premium remains independent of fractional carry")
		s.open_order(1)
		s.serve()
		check(s.earned==int(quote.coins) and s.coins==120+s.earned and s.profile.snapshot().ordinary_tip_remainder==2000, "Actual HUD/day payout includes settled Coin and separate premium")
		before = s.profile.snapshot()
		s.serve()
		check(s.profile.snapshot()==before, "Repeated serving cannot settle twice")
		s.free()
	var canceled := make_session("odin", "basic_coffee", false)
	prepare(canceled, canceled.get_order(1).recipe.ingredients)
	before = canceled.profile.snapshot()
	canceled.advance_time(100)
	canceled.open_order(1)
	canceled.serve()
	check(canceled.profile.snapshot()==before and canceled.served==0, "Expired prepared order grants neither Coins nor fractions")
	canceled.free()
	var back := make_session("fade", "basic_coffee", false)
	back.open_order(1)
	back.accept_order()
	back.open_station()
	back.start_brewing()
	back.advance_time(1)
	before = back.profile.snapshot()
	back.back_to_cafe()
	check(back.profile.snapshot()==before, "Canceled preparation cannot add fractions")
	back.free()

func migration() -> void:
	var p := fixture()
	var legacy := p.snapshot()
	legacy.schema_version = 4
	legacy.erase("ordinary_tip_remainder")
	legacy.coins = 456
	legacy.xp = 25
	legacy.owned_decorations = ["mint_leaf_jar"]
	var normalized := CafeProfile.normalize(legacy)
	check(normalized.ok and normalized.data.ordinary_tip_remainder==0 and normalized.data.schema_version==5, "Schema 4 defaults new field to zero")
	for key in legacy:
		if key != "schema_version":
			check(normalized.data[key]==legacy[key], "Migration retains " + key)
	for invalid in [-1,10000,0.25,"25",null]:
		var bad := p.snapshot()
		bad.ordinary_tip_remainder = invalid
		check(not CafeProfile.normalize(bad).ok, "Malformed/out-of-range saved fraction rejected for backup recovery")
	var data := p.snapshot()
	data.ordinary_tip_remainder = 9750
	check(p._commit(data), "Valid fractional checkpoint")
	var path := p.store.path
	var bad := p.snapshot()
	bad.ordinary_tip_remainder = -1
	raw(path, bad)
	var loaded := reload_profile(p)
	check(loaded.store.recovery_required and loaded.snapshot().ordinary_tip_remainder==0, "Invalid fraction recovers valid backup checkpoint")
	check(JSON.parse_string(FileAccess.get_file_as_string(path)).ordinary_tip_remainder == -1, "Corrupted source retained for recovery")

func cold_write() -> void:
	var p := fixture()
	var id := p.begin_shift()
	check(p.apply_service(id,1,11,15,3,750), "Separate-process writer commits fractional progress")
	var location := "/tmp/paw-13a-cold-path"
	var file := FileAccess.open(location,FileAccess.WRITE)
	file.store_string(p.store.path)
	file.close()
	print("COLD_READ_PATH=",p.store.path)

func cold_read(path: String) -> void:
	var p := CafeProfile.new()
	p.clock = func() -> int: return CafeProfile.season_catalog.anchor+100
	p.open(path)
	check(p.coins==131 and p.snapshot().ordinary_tip_remainder==750 and p.level==1 and p.xp==15, "Separate process restores awarded Coin balance and unpaid bonus")
	var before := p.snapshot()
	check(not p.apply_service(int(before.open_shift_id),1,11,15,3,750) and p.snapshot()==before, "Separate process rejects historical service")
	var id := p.begin_shift()
	for i in range(1,14):
		check(p.apply_service(id,i,11,15,3,750), "New process continues accumulating fractions")
	check(p.coins==275 and p.snapshot().ordinary_tip_remainder==500, "Cross-process fractional threshold awards exactly once")

func settle() -> void:
	for i in range(8):
		await process_frame

func click(button: Button, touch: bool) -> void:
	check(button.is_visible_in_tree() and not button.disabled, "Visible enabled input " + button.name)
	var point := button.get_global_rect().get_center()
	for pressed in [true, false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.position = root.get_final_transform() * point
			event.pressed = pressed
			Input.parse_input_event(event)
		else:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = point
			event.pressed = pressed
			root.push_input(event, true)
	await settle()

func ui() -> void:
	root.content_scale_size = Vector2i(720,1280)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	for dimensions in [Vector2i(720,1280), Vector2i(320,568)]:
		root.size = dimensions
		var touch: bool = dimensions.x == 320
		var main := load("res://Scenes/Main.tscn").instantiate() as Control
		var s := main.get_node("CafeSession") as CafeSession
		s.profile = fixture()
		s.profile.set_team(["blaze","momo","mochi"])
		s.recipe_override = "honey_tea"
		root.add_child(main)
		s.set_process(false)
		await settle()
		var view := main.get_node("GameplayView")
		s.open_season()
		await settle()
		var pass_screen := view.get_node("SeasonScreen")
		check(pass_screen.pass_body.get_child(0).text.contains("200 XP per café day"), "Pass shows authoritative day XP")
		check(pass_screen.daily.text.contains("150 Seasonal XP") and pass_screen.weekly.text.contains("500 Seasonal XP"), "Challenge UI shows approved rewards")
		s.back_to_cafe()
		await settle()
		await click(view.get_node("DayLobby/Content/Layout/Action"), touch)
		prepare(s, ["Tea", "Water"])
		s.open_order(1)
		await settle()
		var description := view.get_node("OrderScreen/Content/Layout/Description") as Label
		check(description.text.contains("Good · 74/100") and not description.text.contains("Perfect"), "Incomplete drink UI uses final capped tier")
		await click(view.get_node("OrderScreen/Content/Layout/Action"), touch)
		check(s.served == 1 and s.quality_counts[1] == 1, "Mouse/touch serves capped Good drink")
		s.advance_time(400)
		await settle()
		description = view.get_node("DayResults/Content/Layout/Description")
		check(description.text.contains("+200 Seasonal XP"), "Day results disclose new completed-day rate")
		var action := view.get_node("DayResults/Content/Layout/Action") as Button
		check(description.get_global_rect().end.y <= action.get_global_rect().position.y and action.get_global_rect().end.y <= main.size.y, "Results text and next-day action fit portrait viewport")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(folder.path_join("results-%d.png" % dimensions.x)) == OK, "Capture native results layout")
		await click(action, touch)
		check(s.day == 2, "Next-day action remains reachable")
		# Preserve keyboard Back while viewing the updated pass in shift.
		s.open_season()
		await settle()
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = true
		root.push_input(event, true)
		await settle()
		check(s.view == CafeSession.View.CAFE, "Keyboard returns from pass during shift")
		main.free()
		await settle()
		print("PASS Step 13A UI ", dimensions)
