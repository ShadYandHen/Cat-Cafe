class_name DrinkQuality
extends RefCounted
## Ingredient exactness 50%, timing 35%, completed recipe steps 15%.
const TIERS := ["Okay", "Good", "Excellent", "Perfect"]
const TIP_PERCENT := [0, 5, 10, 15]
const XP := [5, 8, 12, 15]

static func score(required: Array, selected: Array, duration: float, target: float, completed_steps: int, timing_forgiveness: float = 0.0) -> int:
	var hits := 0
	var extras := 0
	var unique: Array = []
	for ingredient in selected:
		if ingredient in unique:
			continue
		unique.append(ingredient)
		if ingredient in required:
			hits += 1
		else:
			extras += 1
	var ingredients := clampf(float(hits - extras) / maxi(1, required.size()), 0, 1)
	var timing := clampf(1.0 - absf(duration - target) / maxf(0.1, target * (1.0 + timing_forgiveness)), 0, 1)
	return clampi(roundi(50 * ingredients + 35 * timing + 15 * clampf(completed_steps / 3.0, 0, 1)), 0, 100)

static func tier(score_value: int) -> int:
	return 3 if score_value >= 95 else 2 if score_value >= 75 else 1 if score_value >= 50 else 0

static func reward(base: int, score_value: int, ordinary_tip_bonus: float = 0.0) -> Dictionary:
	var index := tier(score_value)
	# Floor the ordinary tip after passives. Premium tips are separate at service.
	var tip := floori(base * TIP_PERCENT[index] / 100.0 * (1.0 + ordinary_tip_bonus))
	return {"tip": tip, "coins": base + tip, "xp": XP[index], "tier": TIERS[index]}
