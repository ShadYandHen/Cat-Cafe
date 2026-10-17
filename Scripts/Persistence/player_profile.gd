extends Node
## One profile survives Title/Main transitions. No gameplay or UI state is saved.
var profile := CafeProfile.new()

func _ready() -> void:
	# Command-line test/capture scripts must never read or overwrite player saves.
	# Persistence suites open explicit isolated temporary paths on their own models.
	if "--script" not in OS.get_cmdline_args() and "-s" not in OS.get_cmdline_args():
		profile.open("user://player_profile.json")
		if OS.has_feature("web") and not OS.is_userfs_persistent():
			profile.diagnostic = "Browser persistent storage unavailable; progress may be lost after closing."
		if not profile.diagnostic.is_empty():
			push_warning(profile.diagnostic)

var _calendar_poll := 0.0
func _process(delta: float) -> void:
	# Tests inject and synchronize their own isolated profile clocks.
	if "--script" in OS.get_cmdline_args() or "-s" in OS.get_cmdline_args():
		return
	_calendar_poll+=delta
	if _calendar_poll<1.0 or not profile.writable or (profile.store!=null and profile.store.recovery_required):
		return
	_calendar_poll=0.0
	if not profile.sync_season():
		profile.diagnostic="Season calendar update could not save: "+profile.last_error
