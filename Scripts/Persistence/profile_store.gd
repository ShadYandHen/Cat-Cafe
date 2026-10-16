class_name ProfileStore
extends RefCounted
## File operations only. The profile supplies schema validation.
var path: String
var diagnostic: String = ""
var last_error: String = ""
var blocked: bool = false
var validator: Callable

func _init(save_path: String, validate: Callable) -> void:
	path = ProjectSettings.globalize_path(save_path)
	validator = validate

func _read(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {"ok": false, "reason": "missing"}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "reason": "cannot read"}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return {"ok": false, "reason": "malformed JSON"}
	return validator.call(json.data)

func load_data() -> Dictionary:
	var primary := _read(path)
	if primary.get("future", false):
		blocked = true
		diagnostic = "Save uses a newer schema. File preserved; saving is disabled."
		return {}
	if primary.ok:
		if primary.get("repaired", false):
			var complete_backup := _read(path + ".bak")
			if complete_backup.ok and not complete_backup.get("repaired", false):
				diagnostic = "Profile fields required repair; recovered complete backup. Original retained."
				return complete_backup.data
		diagnostic = primary.get("diagnostic", "")
		if FileAccess.file_exists(path + ".tmp"):
			diagnostic += " Uncommitted staged save retained and ignored."
		return primary.data
	var backup := _read(path + ".bak")
	if backup.get("future", false):
		blocked = true
		diagnostic = "Backup uses a newer schema. Files preserved; saving is disabled."
		return {}
	if backup.ok:
		diagnostic = "Recovered backup: primary save is %s. Original retained until archived on next save." % primary.reason
		return backup.data
	if primary.reason != "missing" or backup.reason != "missing":
		diagnostic = "Save recovery required (%s; backup %s). Defaults loaded; damaged files retained." % [primary.reason, backup.reason]
	if FileAccess.file_exists(path + ".tmp"):
		diagnostic += " Uncommitted staged save retained and ignored."
	return {}

func _archive(file_path: String, kind: String) -> bool:
	var archive := "%s.%s-%d-%d" % [file_path, kind, Time.get_ticks_usec(), OS.get_process_id()]
	var error := DirAccess.copy_absolute(file_path, archive)
	if error != OK:
		last_error = "Cannot retain recovery file: " + error_string(error)
		return false
	return true

func write_data(data: Dictionary) -> bool:
	last_error = ""
	if blocked:
		last_error = "Newer save schema cannot be overwritten."
		return false
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		last_error = "Cannot create save directory: " + error_string(error)
		return false
	var primary := _read(path)
	if primary.get("future", false):
		blocked = true
		last_error = "Newer save appeared; it has been preserved."
		return false
	if FileAccess.file_exists(path) and (not primary.ok or primary.get("repaired", false)) and not _archive(path, "repair" if primary.ok else "corrupt"):
		return false
	var staged := path + ".tmp"
	if FileAccess.file_exists(staged) and not _archive(staged, "uncommitted"):
		return false
	var file := FileAccess.open(staged, FileAccess.WRITE)
	if file == null:
		last_error = "Cannot stage save: " + error_string(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		last_error = "Cannot flush staged save: " + error_string(error)
		return false
	var verified := _read(staged)
	if not verified.ok or verified.data != data:
		last_error = "Staged save validation failed."
		return false
	if primary.ok and (not primary.get("repaired", false) or not _read(path + ".bak").ok):
		var old_backup := _read(path + ".bak")
		if FileAccess.file_exists(path + ".bak") and not old_backup.ok and not _archive(path + ".bak", "unreadable"):
			return false
		# Only a validated primary may replace the recoverable backup.
		error = DirAccess.copy_absolute(path, path + ".bak.tmp")
		if error == OK:
			error = DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak")
		if error != OK:
			last_error = "Cannot preserve backup: " + error_string(error)
			return false
	error = DirAccess.rename_absolute(staged, path)
	if error != OK:
		last_error = "Cannot promote staged save: " + error_string(error)
		return false
	return true
