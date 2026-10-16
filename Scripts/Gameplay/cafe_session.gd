class_name CafeSession
extends Node
## One scene-owned test cycle. Patience has exactly one authoritative Timer.
signal changed
signal patience_changed(seconds: float)
signal customer_departed
signal customer_served

enum State { WAITING_ORDER, ORDER_ACCEPTED, DRINK_READY, SERVED, DEPARTED }
enum View { CAFE, ORDER, STATION }

@export var starting_coins: int = 120
@export_range(0.1, 600.0, 0.1) var patience_seconds: float = 60.0
@export var coffee_reward: int = 10
@export_range(0.1, 30.0, 0.1) var brew_seconds: float = 3.0

var state: State = State.WAITING_ORDER
var view: View = View.CAFE
var coins: int = 120
var brewing: bool = false
var brew_elapsed: float = 0.0
var feedback: String = "Tap the guest to take their order."
var _last_second: int = -1
@onready var patience: Timer = $Patience

func _ready() -> void:
	coins = starting_coins
	patience.timeout.connect(_depart)
	patience.start(patience_seconds)
	changed.emit()

func _process(delta: float) -> void:
	if brewing:
		brew_elapsed = minf(brew_elapsed + delta, brew_seconds)
		if brew_elapsed >= brew_seconds:
			brewing = false
			changed.emit()
	var second := ceili(patience.time_left)
	if second != _last_second:
		_last_second = second
		patience_changed.emit(patience.time_left)

func active() -> bool:
	return state not in [State.SERVED, State.DEPARTED]

func _available() -> bool:
	# Also check time_left: an input can arrive before the timeout signal is dispatched.
	if active() and patience.time_left <= 0.0:
		_depart()
	return active()

func open_order() -> void:
	if not _available() or view != View.CAFE:
		return
	view = View.ORDER
	changed.emit()

func accept_order() -> void:
	if not _available() or view != View.ORDER or state != State.WAITING_ORDER:
		return
	state = State.ORDER_ACCEPTED
	feedback = "Order accepted. Tap the coffee machine."
	view = View.CAFE
	changed.emit()

func open_station() -> void:
	if view != View.CAFE:
		return
	_available()
	view = View.STATION
	changed.emit()

func start_brewing() -> void:
	if not _available() or view != View.STATION or state != State.ORDER_ACCEPTED or brewing or brew_elapsed > 0.0:
		return
	brewing = true
	brew_elapsed = 0.0
	changed.emit()

func finish_coffee() -> void:
	if not _available() or view != View.STATION or state != State.ORDER_ACCEPTED or brewing or brew_elapsed < brew_seconds:
		return
	state = State.DRINK_READY
	brew_elapsed = 0.0
	feedback = "Basic Coffee ready! Tap the guest to serve."
	view = View.CAFE
	changed.emit()

func back_to_cafe() -> void:
	_available()
	# Leaving the station always cancels unfinished preparation, even after brewing.
	brewing = false
	brew_elapsed = 0.0
	view = View.CAFE
	changed.emit()

func serve() -> void:
	if not _available() or view != View.ORDER or state != State.DRINK_READY:
		return
	state = State.SERVED # Commit terminal state before publishing a reward or signal.
	patience.stop()
	coins += coffee_reward
	feedback = "Served! +%d Coins. Test cycle complete." % coffee_reward
	view = View.CAFE
	customer_served.emit()
	changed.emit()

func _depart() -> void:
	if not active():
		return
	state = State.DEPARTED
	patience.stop()
	brewing = false
	brew_elapsed = 0.0
	feedback = "The guest ran out of patience and left. No Coins earned."
	# Keep an open station/order visible so its explanation and Back remain available.
	customer_departed.emit()
	changed.emit()
