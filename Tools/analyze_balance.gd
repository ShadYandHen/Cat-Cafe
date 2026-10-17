extends SceneTree
## Audit only: real CafeSession/DrinkQuality, memory-only profiles, injected clock.
const PROBE := preload("res://Tools/balance_session_probe.gd")
const SKILLS := {
	"ideal":{"tap":0.15,"read":0.15,"notice":0.15,"sigma":0.0,"bias":0.0,"miss":0.0,"distraction":0.0},
	"high":{"tap":0.45,"read":1.0,"notice":1.0,"sigma":0.15,"bias":0.10,"miss":0.01,"distraction":0.02},
	"average":{"tap":0.85,"read":2.5,"notice":2.5,"sigma":0.45,"bias":0.20,"miss":0.06,"distraction":0.10},
	"low":{"tap":1.8,"read":6.0,"notice":6.0,"sigma":1.0,"bias":0.65,"miss":0.15,"distraction":0.25}}
const TEAMS := [["mochi","fade","max"],["fade","mochi","max"],["max","mochi","fade"],["momo","blaze","max"],["blaze","momo","max"],["odin","fade","max"]]
var session: CafeSession
var rng := RandomNumberGenerator.new()
var skill: Dictionary
var waits: Array=[]
var patience: Array=[]
var prep: Array=[]
var idle := 0.0
var busy := 0.0
var rush_busy := 0.0
var occupancy := 0.0
var max_guests := 0
var max_orders := 0
var served_in_rush := 0
var output := "/tmp/paw-balance"
var player_seed := 0

func _initialize() -> void:
	call_deferred("run")

func consume(seconds: float, working: bool = true) -> void:
	var left := maxf(0.0,seconds)
	while left>0.000001 and session.phase!=CafeSession.Phase.RESULTS:
		var step := minf(0.25,left)
		var count := session.active_count()
		var before := session.elapsed
		var in_rush: float=maxf(0.0,minf(before+step,180.0)-maxf(before,120.0))
		session.advance_time(step)
		var used := session.elapsed-before
		occupancy+=count*used
		max_guests=maxi(max_guests,count)
		max_orders=maxi(max_orders,session.accepted_orders().size())
		if working:
			busy+=used
			rush_busy+=in_rush
		else:
			idle+=used
		left-=step

func tap(multiplier: float = 1.0) -> void:
	consume(float(skill.tap)*multiplier*rng.randf_range(0.85,1.15))

func valid(order: CafeOrder) -> bool:
	return session.phase!=CafeSession.Phase.RESULTS and order.state not in [CafeSession.State.SERVED,CafeSession.State.DEPARTED]

func customer(order: CafeOrder) -> void:
	# Stable per-order draws keep team comparisons paired after earlier expirations.
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
	session.select_station(order.recipe.station)
	tap()
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
	var duration := maxf(0.05,session.preparation_target()+rng.randfn(float(skill.bias),float(skill.sigma)))
	consume(duration)
	if not valid(order):
		session.back_to_cafe()
		return
	session.stop_preparation()
	prep.append(session.stopped_duration)
	tap()
	session.finish_coffee()
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
	session.serve()
	if order.state==CafeSession.State.SERVED:
		waits.append(time-float(session.observed_arrivals[order.order_id]))
		patience.append(order.remaining(time))
		if time>=120 and time<180:
			served_in_rush+=1

func average(values: Array) -> float:
	var total := 0.0
	for value in values:
		total+=float(value)
	return total/maxi(1,values.size())

func simulate(team: Array, upgrade: int, efficiency: String, seed_value: int, existing: CafeProfile = null) -> Dictionary:
	var profile := existing if existing!=null else CafeProfile.new()
	profile.clock=func() -> int: return CafeProfile.season_catalog.anchor+100
	if existing==null:
		var data := profile.snapshot()
		for entry in CafeProfile.cafe_catalog.upgrades:
			data.upgrades[entry.id]=upgrade
		# Free fixtures isolate effects; economy mode buys through real transactions.
		assert(profile._commit(data))
	assert(profile.set_team(team))
	session=PROBE.new()
	session.profile=profile
	session.schedule_seed=seed_value
	session.start_immediately=true
	player_seed=seed_value*997+41
	rng.seed=player_seed
	skill=SKILLS[efficiency]
	waits=[]; patience=[]; prep=[]
	idle=0; busy=0; rush_busy=0; occupancy=0; max_guests=0; max_orders=0; served_in_rush=0
	root.add_child(session)
	session.set_process(false)
	var guard := 0
	while session.phase!=CafeSession.Phase.RESULTS and guard<300:
		if session.active_count()==0:
			var wait := maxf(0.01,minf(session.next_arrival,session.day_seconds)-session.elapsed)
			consume(wait,false)
		else:
			customer(session.active_orders()[0])
		guard+=1
	assert(session.phase==CafeSession.Phase.RESULTS,"Simulation did not close")
	assert(profile.store==null,"Audit must never open a save file")
	var rush_arrivals := 0
	for phase in session.arrival_phases.values():
		if phase==CafeSession.Phase.RUSH:
			rush_arrivals+=1
	var record := {"team":team,"upgrade":upgrade,"skill":efficiency,"seed":seed_value,"offered":session.offered,"arrived":session.orders.size(),"skipped":session.skipped,"served":session.served,"lost":session.lost,"coins":session.earned,"xp":session.reputation_earned,"wait_mean":average(waits),"patience_mean":average(patience),"prep_mean":average(prep),"idle":idle,"busy":busy,"duration":session.elapsed,"occupancy_mean":occupancy/session.elapsed,"max_guests":max_guests,"max_accepted_orders":max_orders,"rush_arrivals":rush_arrivals,"rush_served":served_in_rush,"rush_busy_fraction":rush_busy/60.0,"quality_counts":session.quality_counts.duplicate(),"activations":session.ability_activations.size(),"wait_samples":waits.duplicate(),"patience_samples":patience.duplicate()}
	session.free()
	return record

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output=arg.trim_prefix("--out=")
	if not output.begins_with("/tmp/") or ".." in output:
		push_error("Analysis outputs must use /tmp")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	if "--economy" in OS.get_cmdline_user_args():
		var completed := economy_runs()
		quit(0 if completed else 1)
		return
	if "--replay" in OS.get_cmdline_user_args():
		var previous = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("simulations.json")))
		for index in range(0,previous.runs.size(),194):
			var row: Dictionary=previous.runs[index]
			var repeated := simulate(row.team,int(row.upgrade),row.skill,int(row.seed))
			# JSON numeric int/float normalization via canonical serialization.
			if JSON.parse_string(JSON.stringify(repeated))!=row:
				push_error("Cross-process simulation diverged")
				quit(1)
				return
		print("PASS: 20 sampled seeded runs exactly reproduced in separate process")
		quit()
		return
	var all: Array=[]
	for team in TEAMS:
		for upgrade in [0,2,3]:
			for efficiency in SKILLS:
				for i in range(20):
					all.append(simulate(team,upgrade,efficiency,417+i))
		print("Reference team complete: ",team)
		await process_frame
	# All 60 distinct active + unordered-support combinations, paired seeds.
	var ids := CatTeam.IDS
	for active in ids:
		for a in range(ids.size()):
			for b in range(a+1,ids.size()):
				if ids[a]==active or ids[b]==active:
					continue
				var team: Array=[active,ids[a],ids[b]]
				for upgrade in [0,3]:
					for efficiency in ["average","low"]:
						for i in range(10):
							all.append(simulate(team,upgrade,efficiency,417+i))
		print("All support combinations complete for: ",active)
		await process_frame
	for efficiency in ["average","low"]:
		for i in range(20):
			all.append(simulate(TEAMS[0],1,efficiency,417+i))
	# Reproducibility checks on full records, independent of process wall-clock.
	if simulate(TEAMS[0],0,"average",417)!=simulate(TEAMS[0],0,"average",417) or all.any(func(r): return not r is Dictionary or not r.has("served")):
		push_error("Incomplete or non-deterministic analysis run")
		quit(1)
		return
	var defaults := PROBE.new()
	var baseline := {"day_seconds":defaults.day_seconds,"normal_interval":[defaults.normal_arrival_interval.x,defaults.normal_arrival_interval.y],"rush_interval":[defaults.rush_arrival_interval.x,defaults.rush_arrival_interval.y],"patience":defaults.patience_seconds,"rush_start":defaults.rush_start,"rush_end":defaults.rush_end,"recipes":DrinkCatalog.new().recipes,"cats":CatTeam.new().roster,"upgrades":CafeProfile.cafe_catalog.upgrades,"decorations":CafeProfile.cafe_catalog.decorations,"season":CafeProfile.season_catalog.data,"skills":SKILLS,"reference_teams":TEAMS}
	defaults.free()
	var f := FileAccess.open(output.path_join("simulations.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"baseline":baseline,"runs":all}))
	f.close()
	print("PASS: %d seeded café simulations + exact replay equality; outputs %s" % [all.size(),output])
	quit()

func economy_runs() -> bool:
	var records: Array=[]
	for efficiency in ["low","average","high"]:
		for seed_value in range(417,437):
			var profile := CafeProfile.new()
			profile.clock=func() -> int: return CafeProfile.season_catalog.anchor+100
			var purchases: Array=[]
			var maxed_day := -1
			var decorated_day := -1
			var earnings := 0
			for day in range(61):
				# Explicit strategy: cheapest eligible next upgrade first, then decorations.
				while true:
					var options: Array=[]
					for entry in CafeProfile.cafe_catalog.upgrades:
						var offer := profile.upgrade_offer(entry.id)
						if offer.allowed:
							options.append({"id":entry.id,"cost":int(offer.cost),"level":int(offer.current)})
					if options.is_empty():
						break
					options.sort_custom(func(a,b): return a.cost<b.cost or (a.cost==b.cost and a.id<b.id))
					var chosen: Dictionary=options[0]
					assert(profile.purchase_upgrade(chosen.id,chosen.level))
					purchases.append({"day":day,"id":chosen.id,"level":chosen.level+1,"cost":chosen.cost})
				var maxed := true
				for entry in CafeProfile.cafe_catalog.upgrades:
					maxed=maxed and profile.upgrade_level(entry.id)==3
				if maxed and maxed_day<0:
					maxed_day=day
				if maxed:
					for entry in CafeProfile.cafe_catalog.decorations:
						if entry.rarity=="regular" and profile.decoration_offer(entry.id).allowed:
							assert(profile.purchase_decoration(entry.id))
					var owned := 0
					for entry in CafeProfile.cafe_catalog.decorations:
						owned+=int(entry.rarity=="regular" and profile.owns_decoration(entry.id))
					if owned==6:
						decorated_day=day
						break
				var shift := simulate(TEAMS[0],-1,efficiency,seed_value+day*101,profile)
				earnings+=int(shift.coins)
			records.append({"skill":efficiency,"seed":seed_value,"maxed_day":maxed_day,"decorated_day":decorated_day,"earnings":earnings,"remaining":profile.coins,"level":profile.level,"purchases":purchases,"censored":maxed_day<0 or decorated_day<0})
		print("Economy strategy complete: ",efficiency)
	var f := FileAccess.open(output.path_join("economy.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(records))
	f.close()
	print("PASS: 60 persistent in-memory purchase trajectories through real unlocks/prices; no files opened by profiles")

	return true
