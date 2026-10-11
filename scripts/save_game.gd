class_name SaveGame
extends RefCounted
## One save slot stored as JSON in the user data folder.

const PATH := "user://opensims_save.json"


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func write(data: Dictionary) -> bool:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	return true


static func read() -> Dictionary:
	if not exists():
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}
