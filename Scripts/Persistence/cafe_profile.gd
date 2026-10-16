class_name CafeProfile
extends RefCounted
## Authoritative permanent state. Candidate -> durable save -> publish memory/signals.
signal changed
const VERSION := 2
const MAX_INTEGER := 9007199254740991 # Exactly representable in JSON/browser numbers.
const CAT_IDS := ["mochi", "fade", "momo", "odin", "max", "blaze"]
# Reserved policy only: no rolls, inventory creation, or redemption in Step 8.
const DEFERRED_REWARD_POLICY := {"coins": {"weight": 50, "amount": 1000}, "cosmetic": {"weight": 25, "rarity": "regular", "exhausted_coins": 500}, "decoration": {"weight": 25, "rarity": "regular", "exhausted_coins": 500}}
static var cafe_catalog := CafeCatalog.new()
var _data: Dictionary = defaults()
var _active_shift_id: int = 0 # Runtime lock; an interrupted shift is never restored.
var _cafe_transaction: bool = false
var store: ProfileStore
var diagnostic: String = ""
var last_error: String = ""
var last_levels_gained: int = 0

var coins: int:
	get: return int(_data.coins)
var level: int:
	get: return int(_data.level)
var xp: int:
	get: return int(_data.xp)
var completed_days: int:
	get: return int(_data.completed_days)
var cycle_xp: int:
	get: return int(_data.cycle_xp)
var cycles: int:
	get: return int(_data.cycles)
var team_slots: Array:
	get: return _data.team.duplicate()
var pending_tickets: int:
	get: return int(_data.pending_cycle_tickets) + int(_data.pending_welcome_ticket)
var writable: bool:
	get: return store == null or not store.blocked

static func defaults() -> Dictionary:
	return {"schema_version": VERSION, "coins": 120, "level": 1, "xp": 0,
		"completed_days": 0, "team": ["mochi", "fade", "max"], "cycle_xp": 0,
		"cycles": 0, "welcome_granted": false, "pending_welcome_ticket": false,
		"pending_cycle_tickets": 0, "next_shift_id": 1, "open_shift_id": 0,
		"shift_completed": false, "served_order_ids": [],
		"upgrades": {}, "owned_decorations": [],
		"equipped_decorations": {"wall_display":"", "shelf_display":"", "floor_display":""}}

static func valid_integer(value: Variant, minimum: int = 0, maximum: int = MAX_INTEGER) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum and floor(float(value)) == float(value)

static func required_xp(current_level: int) -> int:
	return 1000 if current_level >= 50 else 75 + 20 * (current_level - 1)

static func normalize(value: Variant) -> Dictionary:
	if not cafe_catalog.errors.is_empty():
		return {"ok": false, "reason": "café catalog unavailable: " + str(cafe_catalog.errors)}
	if not value is Dictionary:
		return {"ok": false, "reason": "profile is not an object"}
	var version = value.get("schema_version", 0)
	if not valid_integer(version):
		return {"ok": false, "reason": "invalid schema version"}
	if version > VERSION:
		return {"ok": false, "future": true, "reason": "newer schema"}
	var data := defaults()
	var notes: Array[String] = []
	if version < VERSION:
		notes.append("Migrated legacy schema to v%d." % VERSION)
	for key in data:
		if value.has(key):
			data[key] = value[key]
		elif key != "schema_version":
			notes.append("Defaulted missing field: " + key)
	data.schema_version = VERSION
	for key in ["coins","level","xp","completed_days","cycle_xp","cycles","pending_cycle_tickets","next_shift_id","open_shift_id"]:
		if not valid_integer(data[key]):
			return {"ok": false, "reason": "invalid " + key}
		data[key] = int(data[key])
	if data.level < 1 or data.level > 50 or data.next_shift_id < 1 or data.open_shift_id >= data.next_shift_id:
		return {"ok": false, "reason": "invalid level/shift identity"}
	for key in ["welcome_granted","pending_welcome_ticket","shift_completed"]:
		if not data[key] is bool:
			return {"ok": false, "reason": "invalid " + key}
	if not data.team is Array:
		data.team = []
	var team: Array = []
	for id in data.team:
		if id is String and id in CAT_IDS and id not in team and team.size() < 3:
			team.append(id)
	for id in ["mochi","fade","max"]:
		if team.size() < 3 and id not in team:
			team.append(id)
	if team != data.team:
		notes.append("Repaired invalid/duplicate team selection.")
	data.team = team
	if not data.served_order_ids is Array:
		return {"ok": false, "reason": "invalid service receipts"}
	var receipts: Array = []
	for id in data.served_order_ids:
		if not valid_integer(id,1) or int(id) in receipts:
			return {"ok": false, "reason": "invalid/duplicate service receipt"}
		receipts.append(int(id))
	data.served_order_ids = receipts
	if data.open_shift_id == 0 and (not receipts.is_empty() or data.shift_completed):
		return {"ok": false, "reason": "receipt without a shift"}
	_normalize_cafe(data,notes)
	# Missing/new fields and old overflowing XP can be migrated deterministically.
	_advance_reputation(data,0)
	if not valid_integer(data.cycles) or not valid_integer(data.pending_cycle_tickets):
		return {"ok": false, "reason": "reward-cycle counter overflow"}
	if data.pending_cycle_tickets > data.cycles or (data.level < 50 and (data.cycles > 0 or data.cycle_xp > 0 or data.welcome_granted)):
		return {"ok": false, "reason": "inconsistent reward-cycle state"}
	if data.pending_welcome_ticket and not data.welcome_granted:
		return {"ok": false, "reason": "inconsistent welcome entitlement"}
	return {"ok": true, "data": data, "diagnostic": " ".join(notes), "repaired": not notes.is_empty()}

static func _advance_reputation(data: Dictionary, grant: int) -> void:
	data.xp += grant
	while data.level < 50 and data.xp >= required_xp(data.level):
		data.xp -= required_xp(data.level)
		data.level += 1
	if data.level == 50:
		if not data.welcome_granted:
			data.welcome_granted = true
			data.pending_welcome_ticket = true
		var total: int = data.cycle_xp + data.xp
		var added: int = total / 1000
		data.cycle_xp = total % 1000
		data.xp = 0
		data.cycles += added
		data.pending_cycle_tickets += added

func open(save_path: String) -> void:
	_active_shift_id = 0
	store = ProfileStore.new(save_path,normalize)
	var loaded := store.load_data()
	_data = loaded if not loaded.is_empty() else defaults()
	diagnostic = store.diagnostic
	last_error = ""
	changed.emit()

func snapshot() -> Dictionary:
	return _data.duplicate(true)

func _commit(candidate: Dictionary) -> bool:
	last_error = ""
	var verified := normalize(candidate)
	if not verified.ok:
		last_error = verified.reason
		return false
	if store != null and not store.write_data(verified.data):
		last_error = store.last_error
		return false
	last_levels_gained = int(verified.data.level) - level
	_data = verified.data
	changed.emit()
	return true

func grant_xp(amount: Variant) -> bool:
	if not valid_integer(amount) or int(amount) > MAX_INTEGER - xp - cycle_xp:
		last_error = "Invalid XP grant."
		return false
	var candidate := snapshot()
	_advance_reputation(candidate,int(amount))
	return _commit(candidate)

func begin_shift() -> int:
	if _active_shift_id != 0:
		last_error = "A shift is already active."
		return 0
	if int(_data.next_shift_id) >= MAX_INTEGER:
		last_error = "Shift identifier limit reached."
		return 0
	var candidate := snapshot()
	candidate.open_shift_id = candidate.next_shift_id
	candidate.next_shift_id += 1
	candidate.shift_completed = false
	candidate.served_order_ids = []
	if not _commit(candidate):
		return 0
	_active_shift_id = int(candidate.open_shift_id)
	return _active_shift_id

func apply_service(shift_id: int, order_id: int, coin_reward: Variant, xp_reward: Variant) -> bool:
	if shift_id <= 0 or shift_id != int(_data.open_shift_id) or _data.shift_completed or order_id <= 0 or order_id in _data.served_order_ids:
		last_error = "Duplicate or stale service transaction."
		return false
	if not valid_integer(coin_reward) or int(coin_reward) > MAX_INTEGER - coins or not valid_integer(xp_reward) or int(xp_reward) > MAX_INTEGER - xp - cycle_xp:
		last_error = "Invalid service reward."
		return false
	var candidate := snapshot()
	candidate.coins += int(coin_reward)
	_advance_reputation(candidate,int(xp_reward))
	candidate.served_order_ids.append(order_id)
	return _commit(candidate)

func complete_shift(shift_id: int) -> bool:
	if shift_id <= 0 or shift_id != int(_data.open_shift_id):
		last_error = "Stale shift completion."
		return false
	if _data.shift_completed:
		release_shift(shift_id)
		return true # Idempotent: already committed, do not increment again.
	var candidate := snapshot()
	candidate.completed_days += 1
	candidate.shift_completed = true
	if not _commit(candidate):
		return false
	release_shift(shift_id)
	return true

func set_team(slots: Array) -> bool:
	if slots.size() != 3:
		return false
	var seen: Array = []
	for id in slots:
		if id not in CAT_IDS or id in seen:
			return false
		seen.append(id)
	var candidate := snapshot()
	candidate.team = slots.duplicate()
	return _commit(candidate)

func progress_text() -> String:
	return "Level 50 · Cycle %d/1000 XP" % cycle_xp if level == 50 else "Level %d · %d/%d XP" % [level,xp,required_xp(level)]

func pending_entitlements() -> Dictionary:
	# Compact serial range gives every ticket a stable identity without huge arrays.
	return {"welcome_id": "level50-welcome" if _data.pending_welcome_ticket else "",
		"cycle_first": cycles - int(_data.pending_cycle_tickets) + 1,
		"cycle_last": cycles, "cycle_count": int(_data.pending_cycle_tickets)}

static func _normalize_cafe(data: Dictionary, notes: Array[String]) -> void:
	var levels: Dictionary = {}
	var repaired_levels: bool = not data.upgrades is Dictionary
	if data.upgrades is Dictionary:
		for id in data.upgrades:
			var entry := cafe_catalog.upgrade(str(id))
			if not entry.is_empty() and valid_integer(data.upgrades[id]):
				levels[id] = mini(int(data.upgrades[id]),int(entry.max_level))
				if data.upgrades[id] > entry.max_level:
					repaired_levels=true
			else:
				repaired_levels=true
	if repaired_levels:
		notes.append("Repaired invalid upgrade levels.")
	data.upgrades = levels
	var owned: Array = []
	if data.owned_decorations is Array:
		for id in data.owned_decorations:
			if id is String and not cafe_catalog.decoration(id).is_empty() and id not in owned:
				owned.append(id)
	owned.sort()
	if not data.owned_decorations is Array or owned != data.owned_decorations:
		notes.append("Repaired decoration ownership.")
	data.owned_decorations = owned
	var slots: Dictionary = {}
	for slot in CafeCatalog.SLOT_IDS:
		var id = data.equipped_decorations.get(slot,"") if data.equipped_decorations is Dictionary else ""
		var valid: bool = id is String and id in owned and cafe_catalog.decoration(id).slot == slot
		slots[slot] = id if valid else ""
	if not data.equipped_decorations is Dictionary or slots != data.equipped_decorations:
		notes.append("Repaired decoration display slots.")
	data.equipped_decorations = slots

func release_shift(id: int) -> void:
	if _active_shift_id == id:
		_active_shift_id = 0

func can_manage_cafe() -> bool:
	return _active_shift_id == 0 and writable

func upgrade_level(id: String) -> int:
	return int(_data.upgrades.get(id,0))

func owns_decoration(id: String) -> bool:
	return id in _data.owned_decorations

func equipped_decorations() -> Dictionary:
	return _data.equipped_decorations.duplicate()

func upgrade_bonuses() -> Dictionary:
	return cafe_catalog.bonuses(_data.upgrades)

func _manage_gate(offer: Dictionary) -> Dictionary:
	if not writable:
		offer.allowed=false
		offer.reason="Saving is unavailable"
	elif _active_shift_id != 0:
		offer.allowed=false
		offer.reason="View only: finish the shift and save its results"
	return offer

func upgrade_offer(id: String) -> Dictionary:
	return _manage_gate(cafe_catalog.upgrade_offer(id,_data))

func decoration_offer(id: String) -> Dictionary:
	return _manage_gate(cafe_catalog.decoration_offer(id,_data))

func purchase_upgrade(id: String, expected_level: Variant) -> bool:
	last_error=""
	if _cafe_transaction or not valid_integer(expected_level,0,10):
		last_error="Invalid or repeated purchase request"
		return false
	var offer := upgrade_offer(id)
	if not offer.allowed:
		last_error=offer.reason
		return false
	if int(expected_level) != int(offer.current):
		last_error="Purchase already applied or quote changed; review next level"
		return false
	var candidate := snapshot()
	candidate.coins -= int(offer.cost)
	candidate.upgrades[id] = int(offer.current)+1
	_cafe_transaction=true
	var success := _commit(candidate)
	_cafe_transaction=false
	return success

func purchase_decoration(id: String) -> bool:
	last_error=""
	if _cafe_transaction:
		last_error="Purchase already in progress"
		return false
	var offer := decoration_offer(id)
	if not offer.allowed:
		last_error=offer.reason
		return false
	var candidate := snapshot()
	candidate.coins -= int(offer.cost)
	candidate.owned_decorations.append(id)
	_cafe_transaction=true
	var success := _commit(candidate)
	_cafe_transaction=false
	return success

func grant_decoration(id: String) -> bool:
	# Shared future reward entry point. Ownership changes never equip or charge Coins.
	last_error=""
	if _cafe_transaction or cafe_catalog.decoration(id).is_empty():
		last_error="Invalid decoration grant"
		return false
	if owns_decoration(id):
		return true
	var candidate := snapshot()
	candidate.owned_decorations.append(id)
	_cafe_transaction=true
	var success := _commit(candidate)
	_cafe_transaction=false
	return success

func equip_decoration(slot: String, id: String) -> bool:
	last_error=""
	if _cafe_transaction or not can_manage_cafe():
		last_error="View only: finish the shift and save its results"
		return false
	if slot not in CafeCatalog.SLOT_IDS:
		last_error="Invalid display slot"
		return false
	if not id.is_empty() and (not owns_decoration(id) or cafe_catalog.decoration(id).slot != slot):
		last_error="Decoration must be owned and compatible with this slot"
		return false
	if _data.equipped_decorations[slot] == id:
		return true
	var candidate := snapshot()
	candidate.equipped_decorations[slot]=id
	_cafe_transaction=true
	var success := _commit(candidate)
	_cafe_transaction=false
	return success
