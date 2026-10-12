class_name Bills
extends Node
## Household bills: every few days a bill arrives in the mailbox, sized by what the
## home is worth. Pay it at the mailbox; if it's still unpaid a few days later the
## power is cut (lamps go dark, electronics stop working) until it's paid.

signal notice(text: String, title: String)
signal changed

## Days between bills, and grace days before the power goes out.
const PERIOD_DAYS := 3
const GRACE_DAYS := 2
const BILL_HOUR := 9
const ELECTRIC: Array[String] = ["tv", "desk", "stove", "fridge", "lamp"]

var lot: Lot
var build: BuildMode
## Amount owed now (0 when paid up), and the day it became due.
var due := 0
var due_day := 0
var power_off := false
## Bills only come and the power only goes while the household is at home.
var active := true
var _last_bill_day := 1


## The bill for the home: a base charge plus a share of what the objects are worth.
static func amount_for(objects_value: int) -> int:
	return 60 + int(objects_value * 0.06)


func home_value() -> int:
	var v := 0
	for f in lot.furniture:
		v += f.price
	return v


func _process(_delta: float) -> void:
	if lot == null or not active:
		return
	var day := Clock.day()
	if day - _last_bill_day >= PERIOD_DAYS and Clock.hour() >= BILL_HOUR:
		_last_bill_day = day
		var amount := amount_for(home_value())
		if due == 0:
			due_day = day
		due += amount
		notice.emit("New bills have arrived: %s. Pay them at the mailbox within %d days." % [Hud.money(due), GRACE_DAYS], "Bills")
		changed.emit()
	if due > 0 and not power_off and day - due_day >= GRACE_DAYS and Clock.hour() >= BILL_HOUR:
		_set_power(false)
		notice.emit("The bills went unpaid, so the power has been cut off. Pay %s at the mailbox." % Hud.money(due), "Bills")


## Pays everything owed, if the household can afford it.
func pay() -> void:
	if due == 0:
		notice.emit("There are no bills to pay.", "Bills")
		return
	if build.funds < due:
		notice.emit("Not enough Simoleons to pay %s in bills." % Hud.money(due), "Bills")
		return
	build.funds -= due
	build.funds_changed.emit(build.funds)
	Sfx.play("cash", -4.0)
	notice.emit("Bills of %s paid. Thank you!" % Hud.money(due), "Bills")
	due = 0
	if power_off:
		_set_power(true)
	changed.emit()


func _set_power(on: bool) -> void:
	power_off = not on
	Daylight.power_off = not on
	get_tree().call_group("lamps", "set_lit", on and Daylight.lit_now)
	if not on:
		notice.emit("Without power, lamps, the TV, computer, stove and fridge won't work.", "Bills")
	changed.emit()


## Whether an object can be used right now (electronics need power).
func can_use(f: Furniture) -> bool:
	return not (power_off and ELECTRIC.has(f.kind))


func to_dict() -> Dictionary:
	return {"due": due, "due_day": due_day, "power_off": power_off, "last": _last_bill_day}


func from_dict(d: Dictionary) -> void:
	due = int(d.get("due", 0))
	due_day = int(d.get("due_day", 0))
	_last_bill_day = int(d.get("last", Clock.day()))
	_set_power(not d.get("power_off", false))
