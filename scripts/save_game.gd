class_name SaveGame
extends RefCounted
## Save slots stored as JSON files in the user data folder, like the reference's
## save files: Save writes the current slot, Save As starts a new one, and Load
## Game lists them all (newest first).

## Older versions kept a single save here; it becomes "Save 1".
const LEGACY_PATH := "user://opensims_save.json"
static var dir := "user://saves"
## The slot being played (file name without .json); "" picks the newest.
static var current := ""


static func _path(slot: String) -> String:
	return "%s/%s.json" % [dir, slot]


static func _migrate() -> void:
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	if dir == "user://saves" and FileAccess.file_exists(LEGACY_PATH) and slots().is_empty():
		DirAccess.copy_absolute(LEGACY_PATH, _path("Save 1"))


## Slot names, most recently saved first.
static func slots() -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			out.append(f.trim_suffix(".json"))
	out.sort_custom(func(a, b): return FileAccess.get_modified_time(_path(a)) > FileAccess.get_modified_time(_path(b)))
	return out


static func current_slot() -> String:
	_migrate()
	if current != "" and FileAccess.file_exists(_path(current)):
		return current
	var all := slots()
	return all[0] if not all.is_empty() else ""


static func exists() -> bool:
	return current_slot() != ""


## Writes the current slot (or a new "Save N" if there is none yet).
static func write(data: Dictionary) -> bool:
	_migrate()
	var slot := current_slot()
	if slot == "":
		slot = next_free_name()
	current = slot
	var f := FileAccess.open(_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	return true


## Save As: writes `data` to a new slot called `slot_name` and keeps playing it.
static func write_as(slot_name: String, data: Dictionary) -> bool:
	var clean := slot_name.strip_edges().validate_filename()
	if clean == "":
		clean = next_free_name()
	current = clean
	_migrate()
	var f := FileAccess.open(_path(clean), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	return true


static func next_free_name() -> String:
	var n := 1
	while FileAccess.file_exists(_path("Save %d" % n)):
		n += 1
	return "Save %d" % n


static func read(slot := "") -> Dictionary:
	var s := slot if slot != "" else current_slot()
	if s == "" or not FileAccess.file_exists(_path(s)):
		return {}
	var f := FileAccess.open(_path(s), FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


## "12 Oct 2026, 14:05" for the Load Game list.
static func modified_text(slot: String) -> String:
	var local := FileAccess.get_modified_time(_path(slot)) + int(Time.get_time_zone_from_system()["bias"]) * 60
	var t := Time.get_datetime_dict_from_unix_time(local)
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%d %s %d, %02d:%02d" % [t["day"], months[t["month"] - 1], t["year"], t["hour"], t["minute"]]
