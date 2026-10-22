class_name CafeSession
extends Node
## Scene-owned shift. One clock drives day phases, arrivals, patience and brewing.
signal changed
signal clock_changed
signal customer_departed(order_id: int)
signal customer_served(order_id: int)
signal phase_changed(phase: int)
signal day_finished

enum State { WAITING_ORDER, ORDER_ACCEPTED, DRINK_READY, SERVED, DEPARTED }
enum View { CAFE, ORDER, STATION, RESULTS, TEAM, LOBBY, UPGRADES, DECORATE, REWARDS, SEASON }
enum Phase { OPENING, RUSH, LATE_SERVICE, SOFT_CLOSING, RESULTS, PRE_DAY }
const EPSILON := 0.000001

@export var cat_effects_enabled: bool = true # Legacy tests disable effects to isolate baseline rules.
@export var start_immediately: bool = false # Isolated legacy fixtures may start directly.
var profile: CafeProfile
var shift_id: int = 0
var starting_level: int = 1
var completion_pending: bool = false
var _serving: bool = false
@export var recipe_override: String = "" # Optional deterministic fixture; empty uses seeded variety.
@export_range(0.1, 600.0) var patience_seconds: float = 75.0
@export var day_seconds: float = 300.0
@export var rush_start: float = 120.0
@export var rush_end: float = 180.0
@export var normal_arrival_interval := Vector2(20, 26)
@export var rush_arrival_interval := Vector2(9, 12)
@export var schedule_seed: int = 417

var catalog := DrinkCatalog.new()
var team := CatTeam.new()
var ability_ready_at: float = 0.0
var ability_activations: Array[Dictionary] = []
var ability_feedback: String = ""
var draft_target_seconds: float = 0.0
var draft_forgiveness: float = 0.0
var _team_return_view: View = View.CAFE
var _season_return_view: View = View.LOBBY
var _shop_return_view: View = View.LOBBY
var shop_feedback: String = ""
var _shift_upgrade_bonuses: Dictionary = {}
var reputation_earned: int = 0
var quality_counts: Array[int] = [0, 0, 0, 0]
var station_category: String = "Coffee"
var selected_ingredients: Array[String] = []
var stopped_duration: float = 0.0
var coins: int:
	get: return profile.coins if profile != null else 120
var day: int = 0
var served: int = 0
var lost: int = 0
var earned: int = 0
var elapsed: float = 0.0
var phase: Phase = Phase.PRE_DAY
var view: View = View.LOBBY
var orders: Dictionary[int, CafeOrder] = {}
var seats: Array[int] = [-1, -1]
var selected_order_id: int = -1
var brew_order_id: int = -1
var brew_started_at: float = 0.0
var brew_ready: bool = false
var next_arrival: float = INF
var feedback: String = "Tap an order ticket to prepare."
var _next_id: int = 1 # Never reset: stale actions cannot target a new day's orders.
var _last_second: int = -1
var _rng := RandomNumberGenerator.new()

var brewing: bool:
	get: return brew_order_id >= 0 and not brew_ready
var brew_elapsed: float:
	get: return (stopped_duration if brew_ready else maxf(0, elapsed - brew_started_at)) if brew_order_id >= 0 else 0.0

func _ready() -> void:
	assert(catalog.errors.is_empty(), str(catalog.errors))
	assert(team.errors.is_empty(), str(team.errors))
	assert(CafeProfile.cafe_catalog.errors.is_empty(), str(CafeProfile.cafe_catalog.errors))
	if profile == null:
		profile = get_node("/root/PlayerProfile").profile
	team.slots.assign(profile.team_slots)
	day = profile.completed_days + 1
	profile.changed.connect(_profile_changed)
	if start_immediately:
		_begin_day()
	else:
		feedback = "Choose your team, then start the day."

func _profile_changed() -> void:
	changed.emit()
	clock_changed.emit()

func _process(delta: float) -> void:
	advance_time(delta)

func active_count() -> int:
	return active_orders().size()

func active_orders() -> Array[CafeOrder]:
	var result: Array[CafeOrder] = []
	for order: CafeOrder in orders.values():
		if order.state not in [State.SERVED, State.DEPARTED]:
			result.append(order)
	return result

func accepted_orders() -> Array[CafeOrder]:
	var result: Array[CafeOrder] = []
	for order in active_orders():
		if order.state in [State.ORDER_ACCEPTED, State.DRINK_READY]:
			result.append(order)
	return result

func get_order(id: int) -> CafeOrder:
	return orders.get(id)

func order_at_seat(seat: int) -> int:
	return seats[seat] if seat >= 0 and seat < seats.size() else -1

func remaining_day() -> float:
	return maxf(0.0, day_seconds - elapsed)

func phase_label() -> String:
	return ["Opening", "Rush Hour!", "Late service", "Closing", "Day complete", "Before opening"][phase]

func countdown() -> String:
	var seconds := ceili(remaining_day())
	return "%d:%02d" % [seconds / 60, seconds % 60]

func _begin_day() -> void:
	var new_shift := profile.begin_shift()
	if new_shift == 0:
		feedback = "Save failed. Day not started; retry."
		changed.emit()
		return
	shift_id = new_shift
	day = profile.completed_days + 1
	starting_level = profile.level
	completion_pending = false
	served = 0
	lost = 0
	earned = 0
	reputation_earned = 0
	quality_counts.assign([0, 0, 0, 0])
	elapsed = 0.0
	ability_ready_at = 0.0
	ability_activations.clear()
	ability_feedback = ""
	_last_second = -1
	orders.clear()
	seats.assign([-1, -1])
	selected_order_id = -1
	_cancel_brew()
	_shift_upgrade_bonuses = profile.upgrade_bonuses().duplicate()
	phase = Phase.OPENING
	view = View.CAFE
	feedback = "Tap an order ticket to prepare."
	_rng.seed = schedule_seed + day
	_arrive()
	next_arrival = _interval()
	phase_changed.emit(phase)
	changed.emit()
	clock_changed.emit()

func start_next_day() -> void:
	if phase == Phase.PRE_DAY and view == View.LOBBY:
		_begin_day()
	elif phase == Phase.RESULTS and view == View.RESULTS:
		if completion_pending:
			if not profile.complete_shift(shift_id):
				feedback = "Save failed. Day completion pending; retry."
				changed.emit()
				return
			completion_pending = false
		_begin_day()

func _interval() -> float:
	var interval := rush_arrival_interval if phase == Phase.RUSH else normal_arrival_interval
	return maxf(0.1, _rng.randf_range(minf(interval.x, interval.y), maxf(interval.x, interval.y)))

func _arrive() -> void:
	if elapsed >= day_seconds or phase in [Phase.RESULTS, Phase.PRE_DAY]:
		return
	var seat := seats.find(-1)
	if seat < 0:
		return # Full café: skip this arrival without queuing or stacking guests.
	var order := CafeOrder.new()
	order.order_id = _next_id
	order.customer_id = _next_id
	_next_id += 1
	order.recipe = (catalog.find(recipe_override) if not recipe_override.is_empty() else catalog.recipes[(order.order_id - 1 + schedule_seed) % catalog.recipes.size()]).duplicate(true)
	assert(not order.recipe.is_empty(), "Unknown recipe override")
	order.requested_drink = order.recipe.name
	order.seat = seat
	order.original_patience = patience_seconds * (1.0 + gameplay_bonuses().patience)
	order.deadline = elapsed + order.original_patience
	orders[order.order_id] = order
	seats[seat] = order.order_id

func advance_time(delta: float) -> void:
	if delta <= 0.0 or phase in [Phase.RESULTS, Phase.PRE_DAY]:
		return
	var target := elapsed + delta
	var dirty := false
	# Resolve events chronologically, even in a long frame/accelerated test. No arrivals
	# are retroactively granted patience or admitted at/after the closing boundary.
	while elapsed < target and phase not in [Phase.RESULTS, Phase.PRE_DAY]:
		var event_at := minf(target, day_seconds) if elapsed < day_seconds else target
		if phase == Phase.OPENING:
			event_at = minf(event_at, rush_start)
		elif phase == Phase.RUSH:
			event_at = minf(event_at, rush_end)
		elif phase == Phase.LATE_SERVICE:
			event_at = minf(event_at, day_seconds)
		event_at = minf(event_at, next_arrival)
		for order in active_orders():
			event_at = minf(event_at, order.deadline)
			if _active_kind("care") and not order.care_crossed:
				var threshold: float = team.active_cat().active.parameters.threshold
				event_at = minf(event_at, order.deadline - order.original_patience * threshold + EPSILON * 2)
		elapsed = maxf(elapsed, event_at)
		for order in active_orders():
			if order.deadline <= elapsed + EPSILON:
				_depart(order)
				dirty = true
		if _check_customer_care():
			dirty = true
		var new_phase := Phase.SOFT_CLOSING if elapsed + EPSILON >= day_seconds else Phase.LATE_SERVICE if elapsed + EPSILON >= rush_end else Phase.RUSH if elapsed + EPSILON >= rush_start else Phase.OPENING
		if phase != new_phase:
			phase = new_phase
			next_arrival = INF if phase == Phase.SOFT_CLOSING else elapsed + _interval()
			if phase == Phase.SOFT_CLOSING:
				feedback = "Closing: finish remaining orders."
			phase_changed.emit(phase)
			dirty = true
		if next_arrival <= elapsed + EPSILON and elapsed < day_seconds:
			_arrive()
			next_arrival = elapsed + _interval()
			dirty = true
		if _check_day_finished():
			dirty = true
	if dirty:
		changed.emit()
	var second := floori(elapsed)
	if second != _last_second:
		_last_second = second
		clock_changed.emit()

func _available(id: int) -> bool:
	var order := get_order(id)
	if order == null or order.state in [State.SERVED, State.DEPARTED]:
		return false
	if order.remaining(elapsed) <= EPSILON:
		_depart(order)
		_check_day_finished()
		changed.emit()
		return false
	return true

func open_order(id: int) -> void:
	if view != View.CAFE or not _available(id):
		return
	selected_order_id = id
	view = View.ORDER
	changed.emit()

func accept_order() -> void:
	if view != View.ORDER or not _available(selected_order_id):
		return
	var order := get_order(selected_order_id)
	if order.state != State.WAITING_ORDER:
		return
	order.state = State.ORDER_ACCEPTED
	feedback = "Order #%d accepted. Tap its ticket to prepare." % order.order_id
	view = View.CAFE
	changed.emit()

func prepare_order(id: int) -> void:
	# Ticket navigation only. Unique IDs + _available reject departed/stale orders.
	if view != View.CAFE or phase in [Phase.RESULTS, Phase.PRE_DAY] or not _available(id):
		return
	var order := get_order(id)
	if order.state == State.WAITING_ORDER:
		open_order(id)
		accept_order()
	elif order.state == State.ORDER_ACCEPTED:
		selected_order_id = id
	else:
		return # Ready drinks use explicit manual serving, never another draft.
	if view == View.CAFE and _available(id) and selected_order_id == id:
		open_station()

func open_station() -> void:
	if view != View.CAFE or phase in [Phase.RESULTS, Phase.PRE_DAY]:
		return
	var selected_available := _available(selected_order_id)
	if phase in [Phase.RESULTS, Phase.PRE_DAY]:
		return
	var choices := accepted_orders()
	if not selected_available or get_order(selected_order_id).state == State.WAITING_ORDER:
		selected_order_id = choices[0].order_id if not choices.is_empty() else -1
	var chosen := get_order(selected_order_id)
	if chosen != null:
		station_category = chosen.recipe.category
	view = View.STATION
	changed.emit()

func select_station_order(id: int) -> void:
	if view != View.STATION or not _available(id):
		return
	if get_order(id).state not in [State.ORDER_ACCEPTED, State.DRINK_READY]:
		return
	if id != selected_order_id:
		_cancel_brew()
	selected_order_id = id
	station_category = get_order(id).recipe.category
	changed.emit()

func select_station(category: String) -> void:
	if view != View.STATION or category not in DrinkCatalog.CATEGORIES:
		return
	if station_category != category:
		_cancel_brew()
	station_category = category
	changed.emit()

func toggle_ingredient(ingredient: String) -> void:
	if view != View.STATION or brew_order_id >= 0 or ingredient not in DrinkCatalog.INGREDIENTS or not _available(selected_order_id):
		return
	var order := get_order(selected_order_id)
	if order.state != State.ORDER_ACCEPTED or order.recipe.station != station_category:
		return
	if ingredient in selected_ingredients:
		selected_ingredients.erase(ingredient)
	else:
		selected_ingredients.append(ingredient)
	changed.emit()

func stop_preparation() -> void:
	if view != View.STATION or not brewing or brew_order_id != selected_order_id or not _available(selected_order_id):
		return
	stopped_duration = elapsed - brew_started_at
	brew_ready = true
	changed.emit()

func start_brewing() -> void:
	if view != View.STATION or not _available(selected_order_id) or brew_order_id >= 0:
		return
	if get_order(selected_order_id).state != State.ORDER_ACCEPTED or get_order(selected_order_id).recipe.station != station_category:
		return
	var speed: float = gameplay_bonuses().speed
	draft_forgiveness = 0.0
	if ability_remaining() <= EPSILON and (_active_kind("speed") or _active_kind("precision")):
		var parameters: Dictionary = team.active_cat().active.parameters
		if _active_kind("speed"):
			speed += parameters.speed
		else:
			draft_forgiveness = parameters.forgiveness
		_activate_ability(selected_order_id)
	draft_target_seconds = get_order(selected_order_id).recipe.target_seconds / (1.0 + speed)
	brew_order_id = selected_order_id
	brew_started_at = elapsed
	brew_ready = false
	changed.emit()

func finish_coffee() -> void:
	if view != View.STATION or not _available(selected_order_id):
		return
	if not brew_ready or brew_order_id != selected_order_id or get_order(selected_order_id).state != State.ORDER_ACCEPTED:
		return
	var order := get_order(selected_order_id)
	var steps := 2 if selected_ingredients.is_empty() else 3
	order.quality_score = DrinkQuality.score(order.recipe.ingredients, selected_ingredients, stopped_duration, draft_target_seconds, steps, draft_forgiveness)
	var complete := DrinkQuality.ingredients_complete(order.recipe.ingredients, selected_ingredients)
	order.quality_score = DrinkQuality.final_score(order.quality_score, roundi(gameplay_bonuses().quality), complete)
	if complete and _active_kind("finish") and ability_remaining() <= EPSILON:
		var parameters: Dictionary = team.active_cat().active.parameters
		if order.quality_score >= parameters.minimum and order.quality_score <= parameters.maximum:
			order.quality_score = int(parameters.score)
			_activate_ability(order.order_id)
	# Final guard also protects against any ability tier override.
	order.quality_score = DrinkQuality.final_score(order.quality_score, 0, complete)
	var reward := DrinkQuality.reward(int(order.recipe.base_coins), order.quality_score, gameplay_bonuses().tip)
	order.quality_tier = reward.tier
	order.ordinary_tip = reward.tip
	order.ordinary_bonus_units = reward.bonus_units
	order.reward_coins = reward.coins
	order.reward_xp = reward.xp
	order.state = State.DRINK_READY
	feedback = "#%d ready: %s (%d)." % [selected_order_id, order.quality_tier, order.quality_score]
	_cancel_brew()
	view = View.CAFE
	changed.emit()

func back_to_cafe() -> void:
	if view==View.SEASON:
		view=_season_return_view
		changed.emit()
		return
	if view in [View.UPGRADES, View.DECORATE, View.REWARDS]:
		view = _shop_return_view
		changed.emit()
		return
	if view == View.TEAM:
		view = _team_return_view
		changed.emit()
		return
	if view == View.RESULTS:
		return
	_cancel_brew()
	view = View.CAFE
	changed.emit()

func service_preview(order: CafeOrder) -> Dictionary:
	var premium := 0
	if _active_kind("premium") and ability_remaining() <= EPSILON and DrinkQuality.tier(order.quality_score) >= 2:
		premium = floori(order.recipe.base_coins * team.active_cat().active.parameters.tip)
	var carry: int = profile.tip_settlement(order.ordinary_bonus_units).coins
	return {"premium": premium, "carry": carry, "coins": order.reward_coins + premium + carry}

func serve() -> void:
	if _serving or view != View.ORDER or not _available(selected_order_id):
		return
	var order := get_order(selected_order_id)
	if order.state != State.DRINK_READY:
		return
	_serving = true
	var preview := service_preview(order)
	var premium: int = preview.premium
	var service_coins: int = preview.coins
	var previous_level := profile.level
	if not profile.apply_service(shift_id, order.order_id, service_coins - int(preview.carry), order.reward_xp, DrinkQuality.tier(order.quality_score), order.ordinary_bonus_units):
		_serving = false
		feedback = "Save failed; retry service."
		changed.emit()
		return
	# Save and receipt are durable before resolving the temporary customer.
	order.state = State.SERVED
	order.premium_tip = premium
	order.reward_coins = service_coins
	if premium > 0:
		_activate_ability(order.order_id)
	seats[order.seat] = -1
	_serving = false
	earned += order.reward_coins
	reputation_earned += order.reward_xp
	quality_counts[DrinkQuality.tier(order.quality_score)] += 1
	served += 1
	feedback = "#%d served: +%d Coins · +%d XP." % [order.customer_id, order.reward_coins, order.reward_xp]
	if profile.level > previous_level:
		feedback = "Level %d! +%d Coins · +%d XP." % [profile.level, order.reward_coins, order.reward_xp]
	view = View.CAFE
	customer_served.emit(order.order_id)
	_check_day_finished()
	changed.emit()

func _cancel_brew() -> void:
	brew_order_id = -1
	brew_started_at = 0.0
	brew_ready = false
	stopped_duration = 0.0
	draft_target_seconds = 0.0
	draft_forgiveness = 0.0
	selected_ingredients.clear()

func _depart(order: CafeOrder) -> void:
	if order.state in [State.SERVED, State.DEPARTED]:
		return
	order.state = State.DEPARTED
	seats[order.seat] = -1
	if brew_order_id == order.order_id or selected_order_id == order.order_id:
		_cancel_brew()
	feedback = "Guest #%d left without service." % order.customer_id
	customer_departed.emit(order.order_id)
	lost += 1

func _check_day_finished() -> bool:
	if phase != Phase.SOFT_CLOSING or active_count() > 0:
		return false
	completion_pending = not profile.complete_shift(shift_id)
	if completion_pending:
		feedback = "Save failed. Day completion pending; retry."
	phase = Phase.RESULTS
	view = View.RESULTS
	_cancel_brew()
	phase_changed.emit(phase)
	day_finished.emit()
	return true

func cat_bonuses() -> Dictionary:
	return team.bonuses() if cat_effects_enabled else {"patience": 0.0, "tip": 0.0, "quality": 0.0, "speed": 0.0}

func _active_kind(kind: String) -> bool:
	return cat_effects_enabled and team.active_cat().active.kind == kind

func ability_remaining() -> float:
	return maxf(0.0, ability_ready_at - elapsed)

func ability_status() -> String:
	var cat: Dictionary = team.active_cat()
	return "%s · %s" % [cat.name, "Ready" if ability_remaining() <= EPSILON else "%ds cooldown" % ceili(ability_remaining())]

func preparation_target() -> float:
	if brew_order_id >= 0:
		return draft_target_seconds
	var order := get_order(selected_order_id)
	if order == null:
		return 3.0
	var speed: float = gameplay_bonuses().speed
	if _active_kind("speed") and ability_remaining() <= EPSILON:
		speed += team.active_cat().active.parameters.speed
	return order.recipe.target_seconds / (1.0 + speed)

func _activate_ability(order_id: int) -> void:
	var cat: Dictionary = team.active_cat()
	ability_ready_at = elapsed + cat.cooldown
	ability_feedback = "%s: %s (#%d)" % [cat.name, cat.active.kind, order_id]
	ability_activations.append({"cat": cat.id, "order_id": order_id, "at": elapsed})

func _check_customer_care() -> bool:
	if not _active_kind("care"):
		return false
	var changed_patience := false
	var parameters: Dictionary = team.active_cat().active.parameters
	# Stable creation order breaks simultaneous crossings by customer ID.
	for order in active_orders():
		if not order.care_crossed and order.remaining(elapsed) < order.original_patience * parameters.threshold - EPSILON:
			order.care_crossed = true # A crossing missed during cooldown is not retried.
			if ability_remaining() <= EPSILON:
				order.deadline = minf(elapsed + order.original_patience, order.deadline + order.original_patience * parameters.restore)
				_activate_ability(order.order_id)
				changed_patience = true
	return changed_patience

func can_edit_team() -> bool:
	return can_edit_cafe()

func open_team() -> void:
	if view not in [View.CAFE, View.RESULTS, View.LOBBY]:
		return
	_team_return_view = view
	view = View.TEAM
	changed.emit()

func assign_cat(slot: int, id: String) -> bool:
	if view != View.TEAM or not can_edit_team():
		return false
	var old_slots := team.slots.duplicate()
	if not team.assign(slot,id):
		return false
	if not profile.set_team(team.slots):
		team.slots.assign(old_slots)
		feedback = "Save failed. Team unchanged."
		changed.emit()
		return false
	feedback = "Team saved."
	changed.emit()
	return true

func _exit_tree() -> void:
	if profile != null:
		profile.release_shift(shift_id)

func gameplay_bonuses() -> Dictionary:
	var combined := cat_bonuses()
	var permanent := profile.upgrade_bonuses() if phase in [Phase.PRE_DAY,Phase.RESULTS] else _shift_upgrade_bonuses
	for effect in permanent:
		combined[effect] += permanent[effect]
	return combined

func can_edit_cafe() -> bool:
	return phase in [Phase.PRE_DAY,Phase.RESULTS] and not completion_pending and profile.can_manage_cafe()

func open_shop(decorate: bool = false) -> void:
	if view not in [View.CAFE,View.LOBBY,View.RESULTS,View.UPGRADES,View.DECORATE]:
		return
	if view not in [View.UPGRADES,View.DECORATE]:
		_shop_return_view = view
	shop_feedback=""
	view = View.DECORATE if decorate else View.UPGRADES
	changed.emit()

func _cafe_result(success: bool, message: String) -> bool:
	shop_feedback = message if success else profile.last_error
	if shop_feedback.is_empty():
		shop_feedback="Unavailable during a shift; finish and save its results first"
	# Shop feedback owns these diagnostics; do not leave a price/unlock rejection
	# masquerading as a failed customer-service save in the existing order UI.
	profile.last_error=""
	changed.emit()
	return success

func buy_upgrade(id: String, expected_level: Variant) -> bool:
	if view != View.UPGRADES or not can_edit_cafe():
		shop_feedback="View only: finish the shift and save its results"
		changed.emit()
		return false
	return _cafe_result(profile.purchase_upgrade(id,expected_level),"Upgrade purchased and saved")

func buy_decoration(id: String) -> bool:
	if view != View.DECORATE or not can_edit_cafe():
		shop_feedback="View only: finish the shift and save its results"
		changed.emit()
		return false
	return _cafe_result(profile.purchase_decoration(id),"Decoration owned and saved")

func equip_decoration(slot: String, id: String) -> bool:
	if view != View.DECORATE or not can_edit_cafe():
		shop_feedback="View only: finish the shift and save its results"
		changed.emit()
		return false
	return _cafe_result(profile.equip_decoration(slot,id),"Display saved")

func open_rewards() -> void:
	if view not in [View.CAFE,View.LOBBY,View.RESULTS,View.UPGRADES,View.DECORATE,View.REWARDS]:
		return
	if view not in [View.UPGRADES,View.DECORATE,View.REWARDS]:
		_shop_return_view=view
	view=View.REWARDS
	changed.emit()

func open_season() -> void:
	if view not in [View.CAFE,View.LOBBY,View.RESULTS,View.UPGRADES,View.DECORATE,View.REWARDS]:
		return
	_season_return_view=view
	profile.sync_season()
	view=View.SEASON
	changed.emit()
