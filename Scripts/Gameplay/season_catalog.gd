class_name SeasonCatalog
extends RefCounted
## Configurable UTC calendar and original prototype reward/challenge definitions.
var data: Dictionary = {}
var errors: PackedStringArray = []
var anchor: int = 0

func _init() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://Data/Seasons/pass.json"))
	if not parsed is Dictionary:
		errors.append("Season catalog must be an object")
		return
	data=parsed
	if not data.get("anchor_utc") is String:
		errors.append("Missing UTC anchor")
		return
	anchor=int(Time.get_unix_time_from_datetime_string(data.anchor_utc))
	if anchor<=0 or Time.get_datetime_string_from_unix_time(anchor)!=data.anchor_utc:
		errors.append("Anchor must be a canonical UTC datetime")
	for pair in [["duration_days",56],["xp_per_tier",500],["maximum_tier",50]]:
		if data.get(pair[0])!=pair[1]:
			errors.append("Invalid established seasonal rule: "+pair[0])
	for key in ["day_xp", "daily_xp", "weekly_xp"]:
		if not CafeCatalog.integer(data.get(key), 1):
			errors.append("Invalid seasonal XP reward: " + key)
	if not data.get("milestones") is Array or data.milestones.size()!=10:
		errors.append("Ten milestones required")
		return
	for i in range(10):
		var reward = data.milestones[i]
		if not reward is Dictionary or reward.get("tier")!=(i+1)*5 or reward.get("type") not in ["coins","cosmetic","decoration"] or not reward.get("exclusive") is bool or reward.exclusive!=(i>=7):
			errors.append("Invalid milestone")
		if reward is Dictionary:
			if not CafeCatalog.integer(reward.get("amount"),0) or not reward.get("item_id") is String:
				errors.append("Invalid milestone payload")
			elif reward.type=="coins" and (reward.amount<=0 or not reward.item_id.is_empty()):
				errors.append("Coin milestone requires an amount, not an item")
			elif reward.type!="coins" and (reward.amount!=0 or reward.item_id.is_empty()):
				errors.append("Item milestone requires a unique item")
	for cadence in ["daily","weekly"]:
		if not data.get(cadence) is Array or data[cadence].is_empty():
			errors.append("Missing challenge pool")
			continue
		var seen: Array=[]
		for entry in data[cadence]:
			if not entry is Dictionary or not entry.get("id") is String or entry.id in seen or not entry.get("label") is String or entry.get("metric") not in ["served","good","excellent","coins","days"] or not CafeCatalog.integer(entry.get("target"),1):
				errors.append("Invalid challenge definition")
			else:
				seen.append(entry.id)

func season_at(now: int) -> Dictionary:
	var index := maxi(0,int(floor(float(now-anchor)/(56*86400))))
	var start := anchor+index*56*86400
	return {"id":"paw-season-%04d" % (index+1),"start":start,"end":start+56*86400,"index":index}

func end_for(id: String) -> int:
	if not id.begins_with("paw-season-"):
		return -1
	var number := id.trim_prefix("paw-season-")
	if not number.is_valid_int() or int(number)<1 or id!="paw-season-%04d" % int(number):
		return -1
	return anchor+int(number)*56*86400

static func day_start(now: int) -> int:
	return int(floor(float(now)/86400))*86400

static func week_start(now: int) -> int:
	# Unix epoch was Thursday; Monday 1970-01-05 is day 4.
	return int(floor(float(day_start(now)/86400-4)/7))*7*86400+4*86400

func challenge(season: Dictionary, now: int, cadence: String) -> Dictionary:
	var start := day_start(now) if cadence=="daily" else week_start(now)
	var period := "%s:%s:%d" % [season.id,cadence,start]
	# Explicit FNV-1a, not engine-dependent hash(), for stable cross-platform selection.
	var hash_value: int=2166136261
	for byte in period.to_utf8_buffer():
		hash_value=((hash_value^byte)*16777619)&0xffffffff
	var entry: Dictionary=data[cadence][hash_value%data[cadence].size()]
	return {"period":period,"id":entry.id,"start":maxi(start,int(season.start)),"end":mini(start+(86400 if cadence=="daily" else 7*86400),int(season.end)),"progress":0,"completed":false}

func challenge_definition(cadence: String, id: String) -> Dictionary:
	for entry in data[cadence]:
		if entry.id==id:
			return entry
	return {}

func milestone(tier: int) -> Dictionary:
	for reward in data.milestones:
		if int(reward.tier)==tier:
			return reward
	return {}

func validate_reward_items(rewards: RewardCatalog, cafe: CafeCatalog) -> String:
	for reward in data.milestones:
		if reward.type=="coins":
			continue
		var item := rewards.cosmetic(reward.item_id) if reward.type=="cosmetic" else cafe.decoration(reward.item_id)
		if item.is_empty() or item.exclusive!=reward.exclusive:
			return "Milestone item missing or incorrectly classified"
	return ""
