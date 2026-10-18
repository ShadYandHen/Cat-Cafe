extends SceneTree
## Actual production session clock, real reward ledger, and input-driven team UI.
const SESSION := preload("res://Scenes/Gameplay/CafeSession.tscn")
const MAIN := preload("res://Scenes/Main.tscn")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func make_session(active: String, a: String, b: String, recipe_id: String = "basic_coffee") -> CafeSession:
	var s := SESSION.instantiate() as CafeSession
	s.profile = CafeProfile.new()
	s.start_immediately = true
	s.team.slots.assign([active, a, b])
	s.profile.set_team([active,a,b])
	s.recipe_override = recipe_id
	s.normal_arrival_interval = Vector2(1000,1000)
	s.rush_arrival_interval = Vector2(1000,1000)
	root.add_child(s)
	s.set_process(false)
	return s

func accept(s: CafeSession, id: int) -> void:
	s.open_order(id)
	s.accept_order()

func begin(s: CafeSession, id: int) -> void:
	if s.get_order(id).state == CafeSession.State.WAITING_ORDER:
		accept(s,id)
	s.open_station()
	s.select_station_order(id)
	for ingredient in s.get_order(id).recipe.ingredients:
		s.toggle_ingredient(ingredient)
	s.start_brewing()

func finish(s: CafeSession, duration: float) -> void:
	s.advance_time(duration)
	s.stop_preparation()
	s.finish_coffee()

func run() -> void:
	roster_and_team()
	patience_care()
	preparation_abilities()
	quality_and_premium()
	clock_equivalence()
	await team_inputs()
	if failures == 0:
		print("PASS: %d cat team/ability assertions" % checks)
	quit(0 if failures == 0 else 1)

func roster_and_team() -> void:
	var team := CatTeam.new()
	check(team.errors.is_empty() and team.roster.size() == 6, "All six definitions/artwork load")
	for id in CatTeam.IDS:
		var cat := team.find(id)
		check(cat.id == id and cat.cooldown == 30 and ResourceLoader.exists(cat.artwork), "Valid cat " + id)
	check(team.slots == ["mochi","fade","max"], "Default Mochi active, Fade/Max support")
	check(team.assign(0,"fade") and team.slots == ["fade","mochi","max"], "Equipped assignment swaps slots without duplicates")
	check(not team.assign(0,"fade") and not team.assign(3,"momo") and not team.assign(1,"unknown"), "Duplicate/no-op/invalid inputs rejected")
	for id in CatTeam.IDS:
		for slot in range(3):
			team.assign(slot,id)
			check(team.slots[slot]==id and team.slots[0]!=team.slots[1] and team.slots[1]!=team.slots[2] and team.slots[0]!=team.slots[2], "Unique assignment %s/%d" % [id,slot])
	team.slots.assign(["mochi","momo","blaze"])
	check(is_equal_approx(team.bonuses().patience,0.05) and team.bonuses().quality == 10, "All three equipped cats contribute once")
	for i in range(10):
		team.bonuses()
	check(team.bonuses().quality == 10, "Repeated reads cannot stack passives")
	team.slots.assign(["odin","fade","max"])
	check(is_equal_approx(team.bonuses().tip,0.10) and is_equal_approx(team.bonuses().speed,0.05), "Tip passives add to 10%, Max speed adds 5%")
	var s := make_session("mochi","fade","max")
	s.open_team()
	var before := s.team.slots.duplicate()
	check(not s.can_edit_team() and not s.assign_cat(0,"odin") and s.team.slots == before, "In-shift team assignments are blocked by model")
	s.back_to_cafe()
	s.advance_time(400)
	s.open_team()
	check(s.can_edit_team() and s.assign_cat(0,"odin") and s.team.slots[0] == "odin", "Results permit team edits")
	s.back_to_cafe()
	s.start_next_day()
	check(s.day == 2 and s.team.slots[0] == "odin" and s.ability_remaining() == 0, "Team persists and new-day cooldown is ready")
	s.free()

func patience_care() -> void:
	var s := make_session("mochi","fade","odin")
	var first := s.get_order(1)
	check(is_equal_approx(first.original_patience,78.75) and is_equal_approx(first.deadline,78.75), "Mochi adds starting patience once")
	s.advance_time(55.125)
	check(s.ability_activations.is_empty(), "Exactly 30% is not below threshold")
	s.advance_time(0.001)
	check(s.ability_activations.size() == 1 and first.care_crossed and is_equal_approx(first.deadline,86.625), "Crossing restores 10% of original 78.75s")
	check(first.remaining(s.elapsed) <= first.original_patience and s.ability_remaining() > 29.99, "Restoration capped; 30s cooldown begins")
	s.open_team()
	s.back_to_cafe()
	s.advance_time(20)
	check(s.ability_activations.size() == 1, "No repeated activation on restored customer's second crossing")
	s.advance_time(12)
	check(first.state == CafeSession.State.DEPARTED and s.coins == 120 and s.reputation_earned == 0, "Care does not prevent eventual expiry or grant rewards")
	s.free()
	var two := make_session("mochi","fade","odin")
	two.advance_time(10)
	two._arrive()
	two.advance_time(56.125)
	check(two.ability_activations.size() == 1 and two.get_order(2).care_crossed and is_equal_approx(two.get_order(2).deadline,88.75), "Second crossing during cooldown is skipped, not queued")
	two.free()
	var support := make_session("fade","mochi","odin")
	support.advance_time(50)
	check(is_equal_approx(support.get_order(1).original_patience,78.75) and support.ability_activations.is_empty(), "Support Mochi passive works without active care")
	support.free()
	var capped := make_session("mochi","fade","odin")
	capped.team.find("mochi").active.parameters.restore = 2.0
	capped.advance_time(55.126)
	check(is_equal_approx(capped.get_order(1).remaining(capped.ability_activations[0].at),78.75), "Large configured restoration cannot exceed original maximum")
	capped.free()

func preparation_abilities() -> void:
	for fixture in [["fade","max","momo",1.25],["max","fade","odin",1.20]]:
		var s := make_session(fixture[0],fixture[1],fixture[2])
		s.open_station()
		s.start_brewing()
		check(s.ability_activations.is_empty(), "No preparation activation without accepted order")
		s.back_to_cafe()
		begin(s,1)
		var target := 3.0 / float(fixture[3])
		check(is_equal_approx(s.preparation_target(),target) and s.ability_activations.size() == 1, "Actual active + passive speed for " + fixture[0])
		s.start_brewing()
		s.select_station_order(1)
		check(s.ability_activations.size() == 1 and is_equal_approx(s.preparation_target(),target), "Repeated events do not stack draft bonuses")
		finish(s,target)
		check(s.get_order(1).quality_score == 100, "Accelerated target gives perfect real timing")
		s.free()
	for active in ["fade","momo","max"]:
		for category in DrinkCatalog.CATEGORIES:
			var recipe: Dictionary = {}
			for candidate in DrinkCatalog.new().recipes:
				if candidate.category == category:
					recipe = candidate
					break
			var supporting: Array = ["fade","odin"] if active=="max" else ["max","odin"]
			var cross := make_session(active,supporting[0],supporting[1],recipe.id)
			begin(cross,1)
			check(cross.ability_activations.size()==1, "Preparation ability qualifies across categories: %s/%s" % [active,category])
			finish(cross,cross.preparation_target())
			check(cross.get_order(1).quality_score==100, "Modified target scores correctly: %s/%s" % [active,category])
			cross.free()
	var cancel := make_session("fade","max","momo")
	begin(cancel,1)
	cancel.advance_time(1)
	cancel.back_to_cafe()
	begin(cancel,1)
	check(cancel.ability_activations.size() == 1 and is_equal_approx(cancel.preparation_target(),3.0/1.05), "Canceled ability is not refunded; next draft retains passive only")
	cancel.advance_time(29)
	check(cancel.ability_remaining() == 0, "Cooldown ends exactly at 30 session seconds")
	check(is_equal_approx(cancel.preparation_target(),3.0/1.05), "Cooldown completion does not change an in-flight target")
	cancel.back_to_cafe()
	begin(cancel,1)
	check(cancel.ability_activations.size() == 2 and is_equal_approx(cancel.preparation_target(),2.4), "Next qualifying draft reactivates after cooldown")
	cancel.free()
	var precision := make_session("momo","max","blaze")
	begin(precision,1)
	var target := precision.preparation_target()
	check(is_equal_approx(precision.draft_forgiveness,0.15) and precision.ability_activations.size() == 1, "Momo applies 15% forgiveness to one valid draft")
	finish(precision,target * 1.5)
	var expected := mini(100,DrinkQuality.score(["Coffee","Water"],["Coffee","Water"],target*1.5,target,3,0.15)+10)
	check(precision.get_order(1).quality_score == expected and expected > DrinkQuality.score(["Coffee","Water"],["Coffee","Water"],target*1.5,target,3)+10, "Forgiveness affects scoring plus both quality passives")
	check(precision.get_order(1).quality_score <= 100, "Final quality clamped")
	precision.free()
	var passive_only := make_session("odin","momo","blaze")
	begin(passive_only,1)
	finish(passive_only,5)
	check(passive_only.draft_forgiveness == 0, "Support Momo cannot grant active timing forgiveness")
	check(passive_only.get_order(1).quality_score == 87 and passive_only.ability_activations.is_empty(), "Support quality passives apply, support Blaze cannot convert")
	passive_only.free()
	var support_max := make_session("mochi","max","odin")
	begin(support_max,1)
	check(is_equal_approx(support_max.preparation_target(),3.0/1.05) and support_max.ability_activations.is_empty(), "Support Max grants passive speed only")
	support_max.free()
	var departed := make_session("fade","momo","odin")
	departed.get_order(1).deadline = 1
	begin(departed,1)
	finish(departed,2)
	departed.start_brewing()
	check(departed.ability_activations.size()==1 and departed.get_order(1).state==CafeSession.State.DEPARTED and departed.coins==120 and departed.reputation_earned==0, "Expired preparation cannot reactivate or earn rewards")
	departed.free()

func quality_and_premium() -> void:
	for final_before in [74,75,94,95,100]:
		var s := make_session("blaze","fade","odin")
		begin(s,1)
		# Correct ingredients yield raw scores 65–100; Blaze passive adds 5.
		var duration := 3.0 * (1.0 + maxf(0,100.0-(final_before-5))/35.0) if final_before < 100 else 3.0
		finish(s,duration)
		var converted: bool = final_before >= 75 and final_before <= 94
		check(s.get_order(1).quality_score == (95 if converted else final_before), "Blaze conversion boundary %d" % final_before)
		check(s.ability_activations.size() == (1 if converted else 0), "Blaze consumes cooldown only for Excellent")
		s.free()
	var repeated := make_session("blaze","fade","odin")
	repeated._arrive()
	for id in [1,2]:
		begin(repeated,id)
		finish(repeated,3.0*(1.0+20.0/35.0))
		repeated.open_order(id)
		repeated.serve()
	check(repeated.get_order(1).quality_score==95 and repeated.get_order(2).quality_score==85 and repeated.ability_activations.size()==1, "Blaze does not convert second drink during cooldown")
	check(repeated.reputation_earned==27 and repeated.get_order(1).premium_tip==0, "Blaze uses final tier XP; support Odin cannot add premium")
	repeated.free()
	var odin := make_session("odin","fade","max")
	odin._arrive()
	for id in [1,2]:
		odin.get_order(id).recipe.base_coins = 100
		begin(odin,id)
		finish(odin,odin.preparation_target())
		check(odin.ability_activations.is_empty() if id == 1 else odin.ability_activations.size() == 1, "Odin waits until actual service")
		odin.open_order(id)
		odin.serve()
		odin.serve()
	check(odin.get_order(1).ordinary_tip == 16 and odin.get_order(1).premium_tip == 15 and odin.get_order(1).reward_coins == 131, "Ordinary tips enhanced by 10%, premium separate and rounded down")
	check(odin.get_order(2).premium_tip == 0 and odin.coins == 120+131+116+1 and odin.profile.snapshot().ordinary_tip_remainder == 0 and odin.reputation_earned == 30 and odin.served == 2, "Second service respects cooldown; exact Coins/XP once per order")
	check(odin.ability_activations.size() == 1, "No duplicate Odin activation")
	odin._arrive()
	var third_id := odin.order_at_seat(0)
	odin.get_order(third_id).recipe.base_coins = 100
	begin(odin,third_id)
	finish(odin,odin.preparation_target())
	odin.advance_time(odin.ability_remaining())
	odin.open_order(third_id)
	odin.serve()
	check(odin.ability_activations.size()==2 and odin.get_order(third_id).premium_tip==15 and odin.coins==499 and odin.profile.snapshot().ordinary_tip_remainder==5000 and odin.reputation_earned==45, "Odin reactivates only on qualifying service after 30 seconds")
	odin.advance_time(400)
	odin.open_team()
	odin.assign_cat(0,"blaze")
	odin.back_to_cafe()
	odin.start_next_day()
	check(odin.ability_ready_at == 0 and odin.ability_activations.is_empty() and odin.team.slots[0] == "blaze", "New day clears cooldown/history after changing active")
	odin.free()
	var expired := make_session("odin","fade","momo")
	begin(expired,1)
	finish(expired,3)
	expired.advance_time(75)
	expired.open_order(1)
	expired.serve()
	check(expired.coins == 120 and expired.reputation_earned == 0 and expired.ability_activations.is_empty(), "Expired ready order cannot trigger premium or rewards")
	expired.free()
	var low := make_session("odin","fade","max")
	accept(low,1)
	low.open_station()
	low.start_brewing()
	finish(low,0.01)
	low.open_order(1)
	low.serve()
	check(low.ability_activations.is_empty() and low.get_order(1).premium_tip == 0 and low.reputation_earned == 5, "Odin does not consume cooldown for Okay service")
	low.free()
	var tiny := make_session("odin","fade","max")
	tiny.get_order(1).recipe.base_coins = 1
	begin(tiny,1)
	finish(tiny,tiny.preparation_target())
	tiny.open_order(1)
	tiny.serve()
	check(tiny.ability_activations.is_empty() and tiny.coins==121 and tiny.reputation_earned==15, "Zero-valued rounded premium does not consume cooldown")
	tiny.free()

func clock_equivalence() -> void:
	var a := make_session("mochi","fade","max")
	var b := make_session("mochi","fade","max")
	for s in [a,b]:
		s.normal_arrival_interval = Vector2(10,10)
		s.rush_arrival_interval = Vector2(10,10)
		s.next_arrival = 10
	a.advance_time(400)
	for i in range(4000):
		b.advance_time(0.1)
	check(a.phase == CafeSession.Phase.RESULTS and a.orders.size() == b.orders.size() and a.ability_activations.size() == b.ability_activations.size(), "Care events preserve coarse/fine clock equivalence through closing")
	for id in a.orders:
		check(is_equal_approx(a.get_order(id).deadline,b.get_order(id).deadline) and a.get_order(id).state == b.get_order(id).state, "Stable patience chronology #%d" % id)
	a.free()
	b.free()

func settle() -> void:
	for frame in range(8):
		await process_frame

func click(button: Button, touch: bool, scroll: ScrollContainer = null) -> void:
	if scroll != null:
		scroll.ensure_control_visible(button)
		await settle()
	check(button.is_visible_in_tree() and not button.disabled, "Enabled team input " + button.name)
	var position := button.get_global_rect().get_center()
	for pressed in [true,false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.position = root.get_final_transform() * position
			event.pressed = pressed
			Input.parse_input_event(event)
		else:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = position
			event.pressed = pressed
			root.push_input(event,true)
	await settle()

func team_inputs() -> void:
	root.content_scale_size = Vector2i(720,1280)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	for dimensions in [Vector2i(720,1280),Vector2i(320,568)]:
		root.size = dimensions
		var touch: bool = dimensions.x == 320
		var main := MAIN.instantiate() as Control
		main.get_node("CafeSession").profile = CafeProfile.new()
		main.get_node("CafeSession").start_immediately = true
		root.add_child(main)
		var s := main.get_node("CafeSession") as CafeSession
		s.set_process(false)
		await settle()
		var view := main.get_node("GameplayView")
		var team_screen := view.get_node("CatTeamScreen")
		var layout := team_screen.get_node("Content/Layout")
		var scroll := layout.get_node("Scroll") as ScrollContainer
		await click(main.get_node("Content/Layout/BottomNavigation/CatTeam"),touch)
		check(s.view == CafeSession.View.TEAM and team_screen.visible, "Existing navigation opens team")
		for card in team_screen.cards.values():
			check(card.get_node("Assign").disabled, "Shift locks every cat assignment")
		var before := s.elapsed
		s.advance_time(10)
		check(s.elapsed == before+10 and not s.assign_cat(0,"odin"), "Team inspection does not pause clock or unlock edits")
		await click(layout.get_node("Settings"),touch)
		s.advance_time(5)
		await click(main.get_node("SettingsPanel/Center/Panel/Margins/Layout/Close"),touch)
		check(root.gui_get_focus_owner() == layout.get_node("Settings"), "Team Settings restores focus")
		await click(layout.get_node("Back"),touch)
		s.advance_time(400)
		await settle()
		await click(view.get_node("DayResults/Content/Layout/CatTeam"),touch)
		check(s.can_edit_team() and team_screen.visible, "Results open editable team")
		await click(team_screen.slot_buttons[0],touch,scroll)
		await click(team_screen.cards["max"].get_node("Assign"),touch,scroll)
		check(s.team.slots == ["max","fade","mochi"], "Input swaps Max active, Mochi support")
		await click(team_screen.slot_buttons[2],touch,scroll)
		await click(team_screen.cards["blaze"].get_node("Assign"),touch,scroll)
		check(s.team.slots == ["max","fade","blaze"], "Input assigns unequipped cat to support")
		var keyboard_assign := team_screen.cards["momo"].get_node("Assign") as Button
		keyboard_assign.grab_focus()
		await settle()
		await key_press(KEY_ENTER)
		check(s.team.slots[2]=="momo", "Keyboard assigns a focused roster cat")
		await click(team_screen.cards["blaze"].get_node("Assign"),touch,scroll)
		await key_press(KEY_ESCAPE)
		check(s.view==CafeSession.View.RESULTS, "Escape returns team to results")
		await click(view.get_node("DayResults/Content/Layout/CatTeam"),touch)
		var scale_factor: float = main.ui_scale
		for card in team_screen.cards.values():
			var assign := card.get_node("Assign") as Button
			scroll.ensure_control_visible(assign)
			await settle()
			check(scroll.get_global_rect().encloses(assign.get_global_rect()), "Roster assignment scrolls fully into view " + card.name)
			check(assign.size.y*scale_factor>=44 and assign.get_theme_font_size("font_size")*scale_factor>=16, "Readable touch roster target " + card.name)
			check(card.get_node("Row/Description").get_theme_font_size("font_size")*scale_factor>=16, "Readable ability description " + card.name)
		for button in [layout.get_node("Settings"),layout.get_node("Back")] + team_screen.slot_buttons:
			check(button.size.x*scale_factor >=44 and button.size.y*scale_factor>=44, "44px team target " + button.name)
			check(button.get_theme_font_size("font_size")*scale_factor>=16, "Readable team control " + button.name)
		for name in ["Heading","Status","Settings","Back"]:
			check(Rect2(Vector2.ZERO,main.size).encloses(layout.get_node(name).get_global_rect()), "Team control in viewport " + name)
		for resized in [Vector2i(1280,720),Vector2i(1920,1080),dimensions]:
			root.size = resized
			await settle()
			var column := team_screen.get_node("Content") as Control
			check(absf(column.get_global_rect().get_center().x-main.size.x/2)<1, "Team remains centered after resize " + str(resized))
			check(Rect2(Vector2.ZERO,main.size).encloses(layout.get_node("Back").get_global_rect()), "Team Back remains accessible after resize " + str(resized))
		await click(layout.get_node("Back"),touch)
		await click(view.get_node("DayResults/Content/Layout/Action"),touch)
		check(s.day==2 and s.team.slots[0]=="max" and s.ability_remaining()==0, "Edited team applies next day")
		# Prep active cooldown uses the live clock even behind station Settings.
		accept(s,s.order_at_seat(0))
		s.open_station()
		s.start_brewing()
		var remaining := s.ability_remaining()
		main.get_node("SettingsPanel").open()
		s.advance_time(5)
		check(s.ability_remaining()==remaining-5 and s.brewing, "Cooldown advances inside station Settings")
		# Exercise production _process while Settings remains open, not only accelerated time.
		var live_remaining := s.ability_remaining()
		s.set_process(true)
		await create_timer(0.06).timeout
		s.set_process(false)
		check(s.ability_remaining()<live_remaining, "Live cooldown continues through modal Settings")
		main.get_node("SettingsPanel").close()
		await settle()
		check(root.gui_get_focus_owner()!=null and root.gui_get_focus_owner().is_visible_in_tree(), "Station recovers visible focus")
		s.back_to_cafe()
		s.open_team()
		var team_remaining := s.ability_remaining()
		s.advance_time(5)
		check(is_equal_approx(s.ability_remaining(),team_remaining-5), "Cooldown continues in read-only team screen")
		main.queue_free()
		await process_frame
		print("PASS cat team input at ",dimensions)

func key_press(key: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
	await settle()
