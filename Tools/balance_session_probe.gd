extends "res://Scripts/Gameplay/cafe_session.gd"
## Audit-only observer; production behavior stays in super. Not exported.
var offered := 0
var skipped := 0
var observed_arrivals: Dictionary = {}
var arrival_phases: Dictionary = {}

func _arrive() -> void:
	offered+=1
	var before := orders.size()
	super._arrive()
	if orders.size()==before:
		skipped+=1
	else:
		var id: int=_next_id-1
		observed_arrivals[id]=elapsed
		arrival_phases[id]=phase
