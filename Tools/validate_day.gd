extends SceneTree
## Deterministic accelerated checks exercise the same clock used by runtime _process.
const SESSION := preload("res://Scenes/Gameplay/CafeSession.tscn")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func make_session(patience_seconds: float = 60.0, default_schedule: bool = false) -> CafeSession:
	var session := SESSION.instantiate() as CafeSession
	session.profile = CafeProfile.new()
	session.start_immediately = true
	session.cat_effects_enabled = false
	session.recipe_override = "basic_coffee"
	session.patience_seconds = patience_seconds
	if not default_schedule:
		session.normal_arrival_interval = Vector2(30, 30)
		session.rush_arrival_interval = Vector2(12, 12)
	root.add_child(session)
	session.set_process(false)
	return session

func accept(session: CafeSession, id: int) -> void:
	session.open_order(id)
	session.accept_order()

func coffee(session: CafeSession, id: int) -> void:
	session.open_station()
	session.select_station_order(id)
	session.start_brewing()
	session.advance_time(session.get_order(id).recipe.target_seconds)
	session.stop_preparation()
	session.finish_coffee()

func run() -> void:
	phase_and_schedule()
	independent_orders()
	selected_expiry()
	closing_and_next_day()
	chunk_equivalence()
	if failures == 0:
		print("PASS: %d accelerated day/order assertions" % checks)
	quit(0 if failures == 0 else 1)

func phase_and_schedule() -> void:
	var s := make_session()
	var history: Array[int] = []
	s.phase_changed.connect(func(phase: int): history.append(phase))
	check(s.day == 1 and s.countdown() == "5:00" and s.coins == 120, "Day starts at 5:00 and 120 coins")
	check(s.active_count() == 1, "Initial guest appears immediately")
	s.advance_time(30)
	check(s.active_count() == 2 and s.seats[0] != s.seats[1], "Second guest has a different seat/ID")
	check(s.get_order(1).deadline == 60 and s.get_order(2).deadline == 90, "Independent patience deadlines")
	s.advance_time(29)
	check(s.active_count() == 2 and s.orders.size() == 2, "Occupied seats never stack arrivals")
	s.advance_time(1)
	check(s.get_order(1).state == CafeSession.State.DEPARTED and s.order_at_seat(0) == 3, "Expired seat reused by later arrival")
	s.advance_time(59.9)
	check(s.phase == CafeSession.Phase.OPENING, "Opening until 120 elapsed")
	s.advance_time(0.1)
	check(s.phase == CafeSession.Phase.RUSH and s.countdown() == "3:00", "Rush starts at exactly 120")
	check(is_equal_approx(s.next_arrival - s.elapsed, 12), "Rush uses faster arrival interval")
	s.advance_time(59.9)
	check(s.phase == CafeSession.Phase.RUSH, "Rush lasts through 179.9")
	s.advance_time(0.1)
	check(s.phase == CafeSession.Phase.LATE_SERVICE and s.countdown() == "2:00", "Late service starts at exactly 180")
	check(is_equal_approx(s.next_arrival - s.elapsed, 30), "Normal arrivals resume")
	s.advance_time(120)
	check(s.phase == CafeSession.Phase.SOFT_CLOSING and s.countdown() == "0:00", "Soft close at exactly 300")
	var admitted := s.orders.size()
	s.advance_time(100)
	check(s.phase == CafeSession.Phase.RESULTS and s.orders.size() == admitted, "No arrivals after closing; final patience resolves day")
	check(history == [CafeSession.Phase.RUSH, CafeSession.Phase.LATE_SERVICE, CafeSession.Phase.SOFT_CLOSING, CafeSession.Phase.RESULTS], "One transition per phase")
	check(s.served == 0 and s.lost == admitted and s.earned == 0 and s.coins == 120, "Lost-day summary exact")
	for order: CafeOrder in s.orders.values():
		check(order.deadline - s.patience_seconds < 300, "No customer admitted at/after 300")
	s.free()
	# Default interval ranges and seeded repeatability.
	var a := make_session(60, true)
	check(a.next_arrival >= 20 and a.next_arrival <= 26, "Default normal schedule range")
	a.advance_time(120)
	check(a.next_arrival - a.elapsed >= 9 and a.next_arrival - a.elapsed <= 12, "Default rush schedule range")
	a.free()

func independent_orders() -> void:
	var s := make_session()
	s.advance_time(30)
	accept(s, 1)
	accept(s, 2)
	coffee(s, 1)
	check(s.get_order(1).state == CafeSession.State.DRINK_READY and s.get_order(2).state == CafeSession.State.ORDER_ACCEPTED, "Drink belongs only to selected order")
	s.open_order(2)
	s.serve()
	check(s.coins == 120 and s.served == 0, "Cannot serve another customer's drink")
	s.back_to_cafe()
	s.open_order(1)
	s.serve()
	s.serve()
	check(s.coins == 130 and s.served == 1 and s.earned == 10, "One service gives exactly one reward")
	check(s.order_at_seat(0) == -1 and s.order_at_seat(1) == 2, "Serving releases only its own seat")
	s.open_order(1)
	check(s.view == CafeSession.View.CAFE, "Departed actor/order cannot reopen")
	s.open_station()
	s.select_station_order(2)
	s.start_brewing()
	s.start_brewing()
	s.advance_time(1)
	s.back_to_cafe()
	check(s.brew_order_id == -1 and s.get_order(2).state == CafeSession.State.ORDER_ACCEPTED, "Back cancels unfinished brew without a drink")
	s.advance_time(26)
	check(s.order_at_seat(0) == 3 and s.order_at_seat(1) == 2, "Served seat available for new unique customer")
	accept(s, 3)
	s.open_station()
	s.select_station_order(2)
	s.start_brewing()
	s.advance_time(1)
	s.select_station_order(3)
	check(s.brew_order_id == -1 and s.get_order(2).state == CafeSession.State.ORDER_ACCEPTED, "Selection switch cancels previous unfinished brew")
	s.stop_preparation()
	s.finish_coffee()
	check(s.get_order(3).state == CafeSession.State.ORDER_ACCEPTED, "Old brew cannot complete a newly selected order")
	s.free()

func selected_expiry() -> void:
	var s := make_session()
	s.advance_time(30)
	accept(s, 1)
	accept(s, 2)
	s.open_station()
	s.select_station_order(1)
	s.start_brewing()
	s.advance_time(30)
	check(s.get_order(1).state == CafeSession.State.DEPARTED and s.brew_order_id == -1, "Selected expiry safely cancels in-progress brewing")
	check(s.get_order(2).state == CafeSession.State.ORDER_ACCEPTED and s.get_order(2).remaining(s.elapsed) == 30, "Another customer's patience/order unaffected")
	s.stop_preparation()
	s.finish_coffee()
	s.serve()
	check(s.coins == 120 and s.served == 0 and s.lost == 1, "Expired drink cannot earn coins")
	s.select_station_order(2)
	s.start_brewing()
	s.advance_time(3)
	s.stop_preparation()
	s.finish_coffee()
	s.open_order(2)
	s.serve()
	check(s.coins == 130 and s.served == 1, "Other order remains serviceable after expiry")
	s.free()
	var other := make_session()
	other.advance_time(30)
	accept(other, 1)
	accept(other, 2)
	other.open_station()
	other.select_station_order(2)
	other.start_brewing()
	other.advance_time(30)
	check(other.get_order(1).state == CafeSession.State.DEPARTED and other.brewing and other.brew_order_id == 2, "Unselected expiry does not cancel selected customer's brew")
	other.advance_time(10)
	other.stop_preparation()
	other.finish_coffee()
	check(other.get_order(2).state == CafeSession.State.DRINK_READY, "Selected brew completes after other customer expires")
	other.free()
	var ready := make_session()
	accept(ready, 1)
	coffee(ready, 1)
	ready.advance_time(57)
	ready.open_order(1)
	ready.serve()
	check(ready.get_order(1).state == CafeSession.State.DEPARTED and ready.coins == 120, "Ready drink invalidated by patience expiry")
	ready.free()

func closing_and_next_day() -> void:
	var s := make_session(1000)
	var finishes: Array[int] = []
	s.day_finished.connect(func(): finishes.append(s.day))
	s.advance_time(300)
	check(s.phase == CafeSession.Phase.SOFT_CLOSING and s.active_count() == 2, "Closing retains existing customers")
	for id in [1, 2]:
		accept(s, id)
		coffee(s, id)
		s.open_order(id)
		s.serve()
	check(s.phase == CafeSession.Phase.RESULTS and s.view == CafeSession.View.RESULTS, "Last closing service opens results")
	check(s.coins == 140 and s.earned == 20 and s.served == 2 and s.lost == 0 and finishes == [1], "Successful day summary exact and one-shot")
	s.advance_time(1000)
	s.serve()
	check(finishes == [1] and s.coins == 140, "Completed day frozen and reward guarded")
	s.start_next_day()
	s.start_next_day()
	check(s.day == 2 and s.elapsed == 0 and s.countdown() == "5:00" and s.phase == CafeSession.Phase.OPENING, "Next day starts once with clock reset")
	check(s.coins == 140 and s.earned == 0 and s.served == 0 and s.lost == 0, "Only accumulated coins persist")
	check(s.orders.size() == 1 and s.get_order(1) == null and s.selected_order_id == -1 and s.brew_order_id == -1, "Previous orders and drink state cleared")
	check(s.seats[0] > 2 and s.seats[1] == -1, "Order IDs never reused across days")
	s.open_order(1)
	s.serve()
	check(s.view == CafeSession.View.CAFE and s.coins == 140, "Stale prior-day action harmless")
	s.free()

func chunk_equivalence() -> void:
	var a := make_session(60, true)
	var b := make_session(60, true)
	a.advance_time(360)
	for i in range(3600):
		b.advance_time(0.1)
	check(a.orders.size() == b.orders.size() and a.lost == b.lost and a.phase == b.phase, "Large tick matches fine-step scheduling")
	for id in a.orders:
		check(a.get_order(id).state == b.get_order(id).state and is_equal_approx(a.get_order(id).deadline, b.get_order(id).deadline), "Deterministic order history #%d" % id)
	a.free()
	b.free()
