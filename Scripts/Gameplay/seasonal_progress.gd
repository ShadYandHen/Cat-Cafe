class_name SeasonalProgress
extends RefCounted
## Pure state transitions. No clocks, files, scenes or permanent Reputation writes.
static func empty_state() -> Dictionary:
	return {"current":{},"history":[],"inbox":[],"last_time":0}

static func sync(state: Dictionary, now: int, catalog: SeasonCatalog, items: Array[Dictionary], released: Array) -> void:
	now=maxi(now,int(state.last_time))
	var calendar := catalog.season_at(now)
	var current: Dictionary=state.current
	if current.is_empty() or current.id!=calendar.id:
		if not current.is_empty() and (current.xp>0 or not current.earned.is_empty()):
			state.history.append({"id":current.id,"start":current.start,"end":current.end,"xp":current.xp,"earned":current.earned.duplicate(),"claimed":current.claimed.duplicate()})
		state.current={"id":calendar.id,"start":calendar.start,"end":calendar.end,"xp":0,"earned":[],"claimed":[],"daily":{},"weekly":{}}
		current=state.current
	for cadence in ["daily","weekly"]:
		var scheduled := catalog.challenge(calendar,maxi(now,int(calendar.start)),cadence)
		if current[cadence].is_empty() or current[cadence].period!=scheduled.period:
			current[cadence]=scheduled
	for entry in items:
		var end := catalog.end_for(entry.origin_season)
		if end>0 and now>=end and entry.origin_season not in released:
			released.append(entry.origin_season)
	released.sort()

static func add_xp(state: Dictionary, amount: int, now: int, catalog: SeasonCatalog) -> void:
	var current: Dictionary=state.current
	current.xp=mini(25000,int(current.xp)+amount)
	for reward in catalog.data.milestones:
		var tier := int(reward.tier)
		if current.xp<tier*500 or tier in current.earned:
			continue
		current.earned.append(tier)
		state.inbox.append({"id":"%s:tier:%d" % [current.id,tier],"type":reward.type,"payload":{"coins":int(reward.amount),"item_id":reward.item_id},"source":"season_pass","season":current.id,"tier":tier,"created_at":now,"claimed":false,"claim_receipt":"","claimed_at":0,"outcome":{}})

static func event(state: Dictionary, metric_values: Dictionary, now: int, catalog: SeasonCatalog) -> void:
	var current: Dictionary=state.current
	if now<int(current.start) or now>=int(current.end):
		return
	for cadence in ["daily","weekly"]:
		var challenge: Dictionary=current[cadence]
		if challenge.completed or now<int(challenge.start) or now>=int(challenge.end):
			continue
		var definition := catalog.challenge_definition(cadence,challenge.id)
		challenge.progress=mini(int(definition.target),int(challenge.progress)+int(metric_values.get(definition.metric,0)))
		if challenge.progress>=definition.target:
			challenge.completed=true
			add_xp(state,int(catalog.data[cadence+"_xp"]),now,catalog)
	if int(metric_values.get("days",0))>0:
		add_xp(state,int(catalog.data.day_xp),now,catalog)

static func normalize(state: Variant, catalog: SeasonCatalog) -> String:
	if not state is Dictionary or not state.get("current") is Dictionary or not state.get("history") is Array or not state.get("inbox") is Array or not CafeCatalog.integer(state.get("last_time"),0,9007199254740991):
		return "Invalid seasonal state containers"
	state.last_time=int(state.last_time)
	var ids: Array=[]
	for entry in state.history:
		var problem := validate_season(entry,catalog,false)
		if not problem.is_empty() or entry.id in ids:
			return "Invalid season archive: "+problem
		ids.append(entry.id)
	if not state.current.is_empty():
		var problem := validate_season(state.current,catalog,true)
		if not problem.is_empty() or state.current.id in ids:
			return "Invalid current season: "+problem
		ids.append(state.current.id)
	var receipts: Array=[]
	for reward in state.inbox:
		if not reward is Dictionary or not reward.get("id") is String or reward.id in receipts or reward.get("source")!="season_pass" or reward.get("season") not in ids or not CafeCatalog.integer(reward.get("tier"),5,50) or int(reward.tier)%5!=0:
			return "Invalid Inbox identity"
		if reward.id!="%s:tier:%d" % [reward.season,int(reward.tier)] or reward.get("type") not in ["coins","cosmetic","decoration"] or not reward.get("payload") is Dictionary or not reward.payload.get("item_id") is String or not CafeCatalog.integer(reward.payload.get("coins"),0,1000000):
			return "Invalid Inbox payload"
		if (reward.type=="coins" and (reward.payload.coins<=0 or not reward.payload.item_id.is_empty())) or (reward.type!="coins" and (reward.payload.coins!=0 or reward.payload.item_id.is_empty())):
			return "Inbox type does not match payload"
		for key in ["created_at","claimed_at"]:
			if not CafeCatalog.integer(reward.get(key),0,9007199254740991):
				return "Invalid Inbox timestamp"
			reward[key]=int(reward[key])
		var season_end := catalog.end_for(reward.season)
		if reward.get("created_at",-1)<season_end-56*86400 or reward.get("created_at",0)>=season_end:
			return "Inbox reward created outside its season"
		if not reward.get("claimed") is bool or not reward.get("claim_receipt") is String or not reward.get("outcome") is Dictionary:
			return "Invalid Inbox claim"
		if reward.claimed:
			if reward.claimed_at<reward.created_at or reward.claimed_at>state.last_time or reward.claim_receipt!="claim:"+reward.id or reward.outcome.is_empty() or not CafeProfile._valid_reward(reward.outcome):
				return "Invalid claimed receipt"
			reward.outcome.coins=int(reward.outcome.coins)
		elif not reward.claim_receipt.is_empty() or not reward.outcome.is_empty() or reward.claimed_at!=0:
			return "Pending reward has a claim receipt"
		reward.tier=int(reward.tier)
		reward.payload.coins=int(reward.payload.coins)
		receipts.append(reward.id)
	# No earned milestone can disappear or be re-claimed via a second UI surface.
	var seasons: Array=state.history.duplicate()
	if not state.current.is_empty():
		seasons.append(state.current)
	for season in seasons:
		for tier in season.earned:
			var id := "%s:tier:%d" % [season.id,tier]
			if id not in receipts:
				return "Earned reward missing from Inbox"
		for reward in state.inbox:
			if reward.season==season.id and (reward.tier not in season.earned or reward.claimed!=(reward.tier in season.claimed)):
				return "Inbox and season claim state disagree"
	return ""

static func validate_season(season: Variant, catalog: SeasonCatalog, current: bool) -> String:
	if not season is Dictionary or not season.get("id") is String:
		return "Invalid season identity"
	var end := catalog.end_for(season.id)
	if end<0 or season.get("end")!=end or season.get("start")!=end-56*86400 or not CafeCatalog.integer(season.get("xp"),0,25000):
		return "Invalid season calendar/XP"
	for key in ["start","end","xp"]:
		season[key]=int(season[key])
	for key in ["earned","claimed"]:
		if not season.get(key) is Array:
			return "Invalid milestone set"
		var values: Array=[]
		for tier in season[key]:
			if not CafeCatalog.integer(tier,5,50) or int(tier)%5!=0 or int(tier) in values or tier*500>season.xp:
				return "Invalid milestone tier"
			values.append(int(tier))
		season[key]=values
	for tier in season.claimed:
		if tier not in season.earned:
			return "Claimed unearned milestone"
	if season.earned.size()!=int(season.xp/2500):
		return "Missing earned milestones"
	if current:
		for cadence in ["daily","weekly"]:
			var challenge = season.get(cadence)
			if not challenge is Dictionary or not challenge.get("id") is String or not challenge.get("period") is String or not challenge.get("completed") is bool:
				return "Invalid challenge state"
			var definition := catalog.challenge_definition(cadence,challenge.id)
			if definition.is_empty() or not CafeCatalog.integer(challenge.get("progress"),0,int(definition.target)) or challenge.completed!=(challenge.progress==definition.target):
				return "Invalid challenge progress"
			for key in ["start","end","progress"]:
				if not CafeCatalog.integer(challenge.get(key),0,9007199254740991):
					return "Invalid challenge interval"
				challenge[key]=int(challenge[key])
			var scheduled := catalog.challenge(season,challenge.start,cadence)
			if challenge.start>=challenge.end or challenge.start<season.start or challenge.end>season.end or challenge.period!=scheduled.period or challenge.id!=scheduled.id or challenge.start!=scheduled.start or challenge.end!=scheduled.end:
				return "Challenge does not match deterministic schedule"
	return ""
