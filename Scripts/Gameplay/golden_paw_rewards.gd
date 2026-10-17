class_name GoldenPawRewards
extends RefCounted
## Pure candidate-state operations. Caller commits the complete candidate once.
static func category(bucket: int, cycle: bool = false) -> String:
	assert(bucket>=0 and bucket<100)
	if bucket<50:
		return "coins"
	if cycle:
		return "regular_cosmetics" if bucket<75 else "regular_decorations"
	return "regular_cosmetics" if bucket<74 else "regular_decorations" if bucket<98 else "exclusive"

static func outcome(data: Dictionary, catalog: RewardCatalog, decorations: Array[Dictionary], rng: RandomNumberGenerator, cycle: bool = false) -> Dictionary:
	var group := category(rng.randi_range(0,99),cycle)
	var result := {"category":group,"item_id":"","coins":0,"duplicate_fallback":false,"fallback":""}
	if group=="coins":
		result.coins=1000 if cycle else 500
		return result
	var pool := catalog.pool(group,decorations,data.released_seasons)
	var eligible: Array[Dictionary] = []
	for entry in pool:
		var owned: bool = entry.id in data.owned_cosmetics or entry.id in data.owned_decorations
		# Regular lottery draws include owned items. Cycle and exclusive draws do not.
		if not owned or (not cycle and group!="exclusive"):
			eligible.append(entry)
	if eligible.is_empty():
		result.coins=1000 if group=="exclusive" else 500
		result.fallback="exhausted_pool"
		return result
	var selected: Dictionary=eligible[rng.randi_range(0,eligible.size()-1)]
	result.item_id=selected.id
	if selected.id in data.owned_cosmetics or selected.id in data.owned_decorations:
		result.coins=500
		result.duplicate_fallback=true
		result.fallback="duplicate_regular"
	return result

static func apply(data: Dictionary, reward: Dictionary, catalog: RewardCatalog) -> bool:
	if int(reward.coins)>CafeProfile.MAX_INTEGER-int(data.coins):
		return false
	data.coins+=int(reward.coins)
	if reward.coins==0 and not reward.item_id.is_empty():
		var field := "owned_cosmetics" if not catalog.cosmetic(reward.item_id).is_empty() else "owned_decorations"
		if reward.item_id not in data[field]:
			data[field].append(reward.item_id)
	return true
