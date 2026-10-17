extends RefCounted
## DEVELOPMENT ONLY. Never loaded by game scenes. Tools/* is excluded from Web export.
const ROOT := "/tmp/paw-pads-development"
var profile: CafeProfile
var slot: String
var _clock_value: Array = [0]
var simulated_time: int:
	get: return int(_clock_value[0])
	set(value): _clock_value[0]=value
var error := ""

static func permitted() -> bool:
	# Exported debug builds also lack the editor feature. CLI -s is mandatory.
	return OS.has_feature("editor") and OS.is_debug_build() and ("--script" in OS.get_cmdline_args() or "-s" in OS.get_cmdline_args())

func _init(slot_name: String = "scratch") -> void:
	if not permitted() or slot_name.is_empty() or slot_name.length()>64:
		error="Editor-only script execution and a safe slot name are required"
		return
	for character in slot_name:
		if character not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-":
			error="Slot names allow only letters, digits, underscores and hyphens"
			return
	slot=slot_name
	simulated_time=CafeProfile.season_catalog.anchor+100
	profile=CafeProfile.new()
	_attach_clock()
	profile.open(path())
	simulated_time=maxi(simulated_time,int(profile.seasonal_state().last_time))

func _attach_clock() -> void:
	var value := _clock_value
	profile.clock=func() -> int: return int(value[0])

func path() -> String:
	return ROOT.path_join(slot).path_join("profile.json")

func safe() -> bool:
	if not permitted() or profile==null or profile.store==null or profile.store.path!=path() or not profile.can_manage_cafe():
		error="Refusing operation: inactive isolated editor test profile required"
		return false
	return true

func commit(data: Dictionary) -> bool:
	if not safe():
		return false
	var result := profile._commit(data)
	error="" if result else profile.last_error
	return result

func reset() -> bool:
	if not safe():
		return false
	var directory := path().get_base_dir()
	if DirAccess.dir_exists_absolute(directory):
		var archived := directory+"-reset-%d-%d" % [Time.get_ticks_usec(),OS.get_process_id()]
		var result := DirAccess.rename_absolute(directory,archived)
		if result!=OK:
			error="Cannot retain previous test slot: "+error_string(result)
			return false
	simulated_time=CafeProfile.season_catalog.anchor+100
	profile=CafeProfile.new()
	_attach_clock()
	profile.open(path())
	return commit(profile.snapshot())

func set_coins(amount: int) -> bool:
	if not safe() or not CafeProfile.valid_integer(amount):
		return false
	var data := profile.snapshot()
	data.coins=amount
	return commit(data)

func set_reputation(level: int, xp: int) -> bool:
	if not safe() or level<1 or level>50 or xp<0 or xp>=CafeProfile.required_xp(level):
		error="Use Level 1–50 and XP below the next threshold"
		return false
	if level<50 and profile.snapshot().welcome_granted:
		error="Reset the scratch slot to move below an already reached Level 50"
		return false
	var data := profile.snapshot()
	data.level=level
	data.xp=xp if level<50 else 0
	data.cycle_xp=xp if level==50 else 0
	if not commit(data):
		return false
	var result := profile.resolve_level50_rewards()
	error="" if result else profile.last_error
	return result

func set_seasonal_xp(amount: int) -> bool:
	if not safe() or amount<0 or amount>25000:
		error="Seasonal XP must be 0–25000"
		return false
	var data := profile.snapshot()
	profile._sync_season_candidate(data,simulated_time)
	if amount<int(data.seasonal.current.xp):
		error="Seasonal XP is raise-only; reset a scratch slot to test lower progress"
		return false
	SeasonalProgress.add_xp(data.seasonal,amount-int(data.seasonal.current.xp),simulated_time,CafeProfile.season_catalog)
	return commit(data)

func grant_tickets(count: int) -> bool:
	# Maintain production ticket/receipt invariants: tickets use real Level 50 cycles
	# and therefore also give those cycles' normal prototype prizes.
	return simulate_cycles(count)

func simulate_cycles(count: int) -> bool:
	if not safe() or profile.level!=50 or count<1 or count>100:
		error="Set Level 50 first; request 1–100 cycles/tickets at a time"
		return false
	var result := profile.grant_xp(count*1000)
	error="" if result else profile.last_error
	return result

func advance(seconds: int) -> bool:
	if not safe() or seconds<0 or seconds>56*86400*100:
		error="Advance 0–100 seasons at a time"
		return false
	var before := simulated_time
	simulated_time+=seconds
	if not commit(profile.snapshot()):
		simulated_time=before
		return false
	return true

func boundary(kind: String) -> bool:
	var target: int
	match kind:
		"day": target=SeasonCatalog.day_start(simulated_time)+86400
		"week": target=SeasonCatalog.week_start(simulated_time)+7*86400
		"season": target=int(CafeProfile.season_catalog.season_at(simulated_time).end)
		_:
			error="Boundary must be day, week or season"
			return false
	return advance(target-simulated_time)

func inspect() -> Dictionary:
	if not safe():
		return {}
	return {"development_only":true,"isolated_path":path(),"utc":Time.get_datetime_string_from_unix_time(simulated_time),"save":profile.snapshot()}
