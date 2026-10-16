class_name CafeOrder
extends RefCounted
## One customer's order; deadlines use CafeSession.elapsed, never a second clock.
var customer_id: int
var order_id: int
var seat: int
var state: int = 0
var original_patience: float
var care_crossed: bool = false
var ordinary_tip: int = 0
var premium_tip: int = 0
var deadline: float
var requested_drink: String = "Basic Coffee"
var recipe: Dictionary = {}
var quality_score: int = -1
var quality_tier: String = ""
var reward_coins: int = 0
var reward_xp: int = 0

func remaining(now: float) -> float:
	return maxf(0.0, deadline - now)
