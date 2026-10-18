extends "res://Tools/analyze_balance.gd"
## REVIEW ONLY. Fixture overrides on memory-only sessions; no production writes.
## All raw data is restricted to /tmp. Tools/* is already excluded from Web export.
const MODELS := {
	"current":{"normal":[25,35],"rush":[10,15],"patience":60},
	"A":{"normal":[26,34],"rush":[12,16],"patience":75},
	"B":{"normal":[20,26],"rush":[9,12],"patience":75},
	"C":{"normal":[16,22],"rush":[7,10],"patience":60}}
const STAGES := {"new":0,"early":1,"mid":2,"max":3}
var selected_model := "current"
var ability_candidate := ""
var interval_scale := 1.0
var overlap := 0.0
var rush_overlap := 0.0
var fractional_coins := 0
var premium_coins := 0
var ordinary_coins := 0
var prepared := 0
var incomplete := 0
var model_runs: Array = []
var team_runs: Array = []
var comparisons: Array = []
var economies: Array = []
var report_dir := "/tmp/paw-13b"
var assertions := 0

func ensure(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)

func consume(seconds: float, working: bool = true) -> void:
	var left := maxf(0.0,seconds)
	while left>0.000001 and session.phase!=CafeSession.Phase.RESULTS:
		var step := minf(1.0,left)
		var count := session.active_count()
		var before := session.elapsed
		session.advance_time(step)
		var used := session.elapsed-before
		var in_rush: float=maxf(0.0,minf(before+used,session.rush_end)-maxf(before,session.rush_start))
		occupancy+=count*used
		max_guests=maxi(max_guests,count)
		max_orders=maxi(max_orders,session.accepted_orders().size())
		if count>=2:
			overlap+=used
			rush_overlap+=in_rush
		if working:
			busy+=used
			rush_busy+=in_rush
		else:
			idle+=used
		left-=step

func customer(order: CafeOrder) -> void:
	# Return explicitly after an expired station/order interaction, as a player must.
	if session.view != CafeSession.View.CAFE:
		session.back_to_cafe()
		tap()
	# Same reaction/error draws per guest across teams and candidate models.
	rng.seed=player_seed+order.order_id*10007
	consume(float(skill.notice))
	if rng.randf()<float(skill.distraction):
		consume(rng.randf_range(15,30) if skill.tap>1.0 else rng.randf_range(8,18))
	if not valid(order):
		return
	session.open_order(order.order_id)
	tap()
	consume(float(skill.read))
	if not valid(order):
		session.back_to_cafe()
		return
	session.accept_order()
	tap()
	session.open_station()
	tap()
	if not valid(order):
		session.back_to_cafe()
		return
	# Production already selected the matching category. No fictitious tab tap.
	ensure(session.station_category==order.recipe.station,"Matching station auto-selects")
	for ingredient in order.recipe.ingredients:
		if not valid(order):
			break
		if rng.randf()>=float(skill.miss):
			session.toggle_ingredient(ingredient)
		tap()
	if not valid(order):
		session.back_to_cafe()
		return
	tap()
	session.start_brewing()
	if not session.brewing:
		session.back_to_cafe()
		return
	var complete := DrinkQuality.ingredients_complete(order.recipe.ingredients,session.selected_ingredients)
	var duration := maxf(0.05,session.preparation_target()+rng.randfn(float(skill.bias),float(skill.sigma)))
	consume(duration)
	if not valid(order):
		session.back_to_cafe()
		return
	session.stop_preparation()
	prep.append(session.stopped_duration)
	tap()
	session.finish_coffee()
	if order.state==CafeSession.State.DRINK_READY:
		prepared+=1
		incomplete+=int(not complete)
		ensure(complete or order.quality_score<=74,"Step 13A ingredient cap preserved")
	tap()
	if not valid(order):
		return
	session.open_order(order.order_id)
	tap()
	tap()
	if not valid(order):
		session.back_to_cafe()
		return
	var time := session.elapsed
	var quote := session.service_preview(order)
	var base := int(order.recipe.base_coins)
	var ordinary := order.ordinary_tip
	session.serve()
	if order.state==CafeSession.State.SERVED:
		fractional_coins+=int(quote.carry)
		premium_coins+=order.premium_tip
		ordinary_coins+=ordinary
		ensure(order.reward_coins==base+ordinary+int(quote.carry)+order.premium_tip,"Whole service accounting")
		waits.append(time-float(session.observed_arrivals[order.order_id]))
		patience.append(order.remaining(time))
		if time>=session.rush_start and time<session.rush_end:
			served_in_rush+=1

func simulate(team: Array, upgrade: int, efficiency: String, seed_value: int, existing: CafeProfile = null) -> Dictionary:
	var profile := existing if existing!=null else CafeProfile.new()
	profile.clock=func() -> int: return CafeProfile.season_catalog.anchor+100
	profile.reward_rng.seed=seed_value*37+19
	if existing==null:
		var data := profile.snapshot()
		data.level=maxi(1,upgrade+1) # Legal effect endowment, not a purchase simulation.
		for entry in CafeProfile.cafe_catalog.upgrades:
			data.upgrades[entry.id]=upgrade
		ensure(profile._commit(data),"Valid stage fixture")
	ensure(profile.store==null and profile.set_team(team),"Isolated team fixture")
	session=PROBE.new()
	session.profile=profile
	session.schedule_seed=seed_value
	session.start_immediately=true
	var model: Dictionary=MODELS[selected_model]
	session.normal_arrival_interval=Vector2(model.normal[0],model.normal[1])*interval_scale
	session.rush_arrival_interval=Vector2(model.rush[0],model.rush[1])*interval_scale
	session.patience_seconds=model.patience
	# Optional sensitivity fixtures edit only this session's private roster object.
	if ability_candidate=="fade25":
		session.team.find("fade").active.parameters.speed=0.25
	elif ability_candidate=="max20":
		session.team.find("max").active.parameters.speed=0.20
	elif ability_candidate=="mochi15":
		session.team.find("mochi").active.parameters.restore=0.15
	elif ability_candidate=="odin20":
		session.team.find("odin").active.parameters.tip=0.20

	player_seed=seed_value*997+41
	rng.seed=player_seed
	skill=SKILLS[efficiency].duplicate()
	waits=[]; patience=[]; prep=[]
	idle=0; busy=0; rush_busy=0; occupancy=0; max_guests=0; max_orders=0; served_in_rush=0
	overlap=0; rush_overlap=0; fractional_coins=0; premium_coins=0; ordinary_coins=0; prepared=0; incomplete=0
	root.add_child(session)
	session.set_process(false)
	var guard := 0
	while session.phase!=CafeSession.Phase.RESULTS and guard<300:
		if session.active_count()==0:
			consume(maxf(0.01,minf(session.next_arrival,session.day_seconds)-session.elapsed),false)
		else:
			customer(session.active_orders()[0])
		guard+=1
	ensure(session.phase==CafeSession.Phase.RESULTS and profile.store==null,"Full shift closes without player storage")
	ensure(session.served+session.lost==session.orders.size() and max_guests<=2,"No lost/orphaned orders or seat overflow")
	var rush_arrivals := 0
	for phase in session.arrival_phases.values():
		rush_arrivals+=int(phase==CafeSession.Phase.RUSH)
	var record := {"model":selected_model,"team":team,"upgrade":upgrade,"skill":efficiency,"seed":seed_value,"candidate":ability_candidate,
		"offered":session.offered,"arrived":session.orders.size(),"skipped":session.skipped,"served":session.served,"lost":session.lost,
		"loss_percent":100.0*session.lost/maxi(1,session.orders.size()),"coins":session.earned,"xp":session.reputation_earned,
		"wait_mean":average(waits),"patience_mean":average(patience),"prep_mean":average(prep),"prep_seconds":prep.reduce(func(a,b):return a+b,0.0),
		"idle":idle,"idle_percent":100*idle/session.elapsed,"busy":busy,"duration":session.elapsed,"occupancy_mean":occupancy/session.elapsed,
		"max_guests":max_guests,"max_accepted_orders":max_orders,"overlap_percent":100*overlap/session.elapsed,"rush_overlap_percent":100*rush_overlap/60,
		"rush_arrivals":rush_arrivals,"rush_served":served_in_rush,"rush_busy_fraction":rush_busy/60.0,"quality_counts":session.quality_counts.duplicate(),
		"activations":session.ability_activations.size(),"wait_samples":waits.duplicate(),"patience_samples":patience.duplicate(),
		"activation_times":session.ability_activations.duplicate(true),"fractional_coins":fractional_coins,"premium_coins":premium_coins,"ordinary_coins":ordinary_coins,
		"prepared":prepared,"incomplete":incomplete,"remainder":profile.snapshot().ordinary_tip_remainder}
	session.free()
	return record

func save_json(name: String, data: Variant) -> void:
	var file := FileAccess.open(report_dir.path_join(name),FileAccess.WRITE)
	ensure(file!=null,"Open isolated report output")
	file.store_string(JSON.stringify(data))
	file.close()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			report_dir=arg.trim_prefix("--out=")
		if arg.begins_with("--economy-model="):
			selected_model=arg.trim_prefix("--economy-model=")
	if selected_model not in MODELS:
		push_error("Unknown economy fixture model")
		quit(1)
		return
	if not report_dir.begins_with("/tmp/") or ".." in report_dir:
		push_error("Output must stay under /tmp")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(report_dir)
	if "--scaling" in OS.get_cmdline_user_args():
		selected_model="B"
		var runs: Array=[]
		for upgrade in [0,3]:
			for efficiency in ["low","average","high"]:
				for seed_value in range(417,457):
					interval_scale=1.0
					var control := simulate(TEAMS[0],upgrade,efficiency,seed_value)
					interval_scale=0.94
					runs.append({"control":control,"scaled":simulate(TEAMS[0],upgrade,efficiency,seed_value)})
		interval_scale=1.0
		save_json("scaling.json",runs)
		print("PASS 480 paired scaling shifts; ",assertions," assertions")
		quit()
		return
	if "--smoke" in OS.get_cmdline_user_args():
		for model in MODELS:
			selected_model=model
			for stage in STAGES:
				for efficiency in ["low","average","high"]:
					simulate(TEAMS[0],STAGES[stage],efficiency,417)
		print("PASS 48 complete smoke shifts; ",assertions," assertions")
		quit()
		return
	if "--economy" in OS.get_cmdline_user_args():
		await economy()
		quit()
		return
	if "--replay" in OS.get_cmdline_user_args():
		var original=JSON.parse_string(FileAccess.get_file_as_string(report_dir.path_join("pacing.json")))
		for i in range(0,original.size(),80):
			var row: Dictionary=original[i]
			selected_model=row.model
			var repeated := simulate(row.team,int(row.upgrade),row.skill,int(row.seed))
			ensure(JSON.parse_string(JSON.stringify(repeated))==row,"Separate-process exact record replay")
		print("PASS 24 sampled cross-process records and ",assertions," assertions")
		quit()
		return
	for model in MODELS:
		selected_model=model
		for stage in STAGES:
			for efficiency in ["low","average","high"]:
				for seed_value in range(417,457):
					model_runs.append(simulate(TEAMS[0],STAGES[stage],efficiency,seed_value))
			print("Pacing complete ",model," / ",stage)
			await process_frame
	save_json("pacing.json",model_runs)
	# All 60 active+unordered support teams. Support order has no gameplay effect.
	for model in ["current","B"]:
		selected_model=model
		for active in CatTeam.IDS:
			for a in range(CatTeam.IDS.size()):
				for b in range(a+1,CatTeam.IDS.size()):
					if active in [CatTeam.IDS[a],CatTeam.IDS[b]]:
						continue
					for upgrade in [0,2,3]:
						for efficiency in ["low","average","high"]:
							for seed_value in range(417,429):
								team_runs.append(simulate([active,CatTeam.IDS[a],CatTeam.IDS[b]],upgrade,efficiency,seed_value))
			print("All team combinations ",model," / ",active)
			await process_frame
	save_json("teams.json",team_runs)
	# Paired, fixture-only small ability changes. No approved production change.
	selected_model="B"
	for item in [["fade","fade25"],["max","max20"],["mochi","mochi15"],["odin","odin20"]]:
		for upgrade in [0,3]:
			for efficiency in ["low","average","high"]:
				for seed_value in range(417,437):
					var supports: Array=["momo","blaze"] if item[0]!="mochi" else ["momo","max"]
					ability_candidate=""
					var control := simulate([item[0],supports[0],supports[1]],upgrade,efficiency,seed_value)
					ability_candidate=item[1]
					comparisons.append({"control":control,"candidate":simulate([item[0],supports[0],supports[1]],upgrade,efficiency,seed_value)})
		ability_candidate=""
		print("Candidate sensitivity complete ",item[1])
		await process_frame
	save_json("ability_candidates.json",comparisons)
	ensure(simulate(TEAMS[0],0,"average",417)==simulate(TEAMS[0],0,"average",417),"Exact same-process replay")
	save_json("baseline.json",{"models":MODELS,"stages":STAGES,"skills":SKILLS,"cats":CatTeam.new().roster,"upgrades":CafeProfile.cafe_catalog.upgrades,"recipes":DrinkCatalog.new().recipes,"decorations":CafeProfile.cafe_catalog.decorations,"season":CafeProfile.season_catalog.data})
	print("PASS ",model_runs.size()," pacing + ",team_runs.size()," team + ",comparisons.size()*2," sensitivity shifts; ",assertions," accounting/isolation assertions")
	quit()

func economy() -> void:
	for efficiency in ["low","average","high"]:
		for seed_value in range(417,427):
			var profile := CafeProfile.new()
			profile.clock=func() -> int: return CafeProfile.season_catalog.anchor+100
			var purchases: Array=[]
			var checkpoints: Array=[]
			var maxed_day := -1
			var decorated_day := -1
			var level50_day := -1
			var lifetime_coins := 0
			var carried_coins := 0
			var limit := 600
			for day in range(limit):
				while true:
					var options: Array=[]
					for entry in CafeProfile.cafe_catalog.upgrades:
						var offer := profile.upgrade_offer(entry.id)
						if offer.allowed:
							options.append({"id":entry.id,"cost":int(offer.cost),"level":int(offer.current)})
					if options.is_empty():
						break
					options.sort_custom(func(a,b):return a.cost<b.cost or (a.cost==b.cost and a.id<b.id))
					var chosen: Dictionary=options[0]
					ensure(profile.purchase_upgrade(chosen.id,chosen.level),"Real upgrade transaction")
					purchases.append({"day":day,"id":chosen.id,"level":chosen.level+1,"cost":chosen.cost})
				var maxed := true
				for entry in CafeProfile.cafe_catalog.upgrades:
					maxed=maxed and profile.upgrade_level(entry.id)==3
				if maxed and maxed_day<0:
					maxed_day=day
				if maxed:
					var owned := 0
					for entry in CafeProfile.cafe_catalog.decorations:
						if entry.rarity=="regular":
							if profile.decoration_offer(entry.id).allowed:
								ensure(profile.purchase_decoration(entry.id),"Real regular decoration purchase")
							owned+=int(profile.owns_decoration(entry.id))
					if owned==6 and decorated_day<0:
						decorated_day=day
				var row := simulate(TEAMS[0],-1,efficiency,seed_value+day*101,profile)
				lifetime_coins+=int(row.coins)
				carried_coins+=int(row.fractional_coins)
				if profile.level==50 and level50_day<0:
					level50_day=day+1
				if day+1 in [10,25,50,100,200,400] or day+1==level50_day:
					checkpoints.append({"shift":day+1,"coins":profile.coins,"level":profile.level,"xp":profile.xp,"earned":lifetime_coins,"fractional":carried_coins})
				if level50_day>0:
					break
			economies.append({"skill":efficiency,"seed":seed_value,"maxed_day":maxed_day,"decorated_day":decorated_day,"level50_day":level50_day,"earned":lifetime_coins,"remaining":profile.coins,"fractional":carried_coins,"purchases":purchases,"checkpoints":checkpoints,"censored":level50_day<0})
			print("Economy trajectory ",efficiency," / ",seed_value," L50 shift ",level50_day)
			await process_frame
	save_json("economy.json" if selected_model=="current" else "economy-"+selected_model+".json",economies)
	print("PASS ",economies.size()," real purchase trajectories; ",assertions," assertions; no stored player profiles")
