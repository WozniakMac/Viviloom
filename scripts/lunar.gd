class_name Lunar
extends RefCounted
## The lunar cycle (Game Options > Environment): eight moon phases over a cycle of
## days, a brighter or darker night with the phase, and a mood on the nights of a
## full or new moon unless lunar effects are turned off.

const PHASES: Array[String] = ["New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous", "Full Moon", "Waning Gibbous", "Third Quarter", "Waning Crescent"]
const CYCLE_DAYS: Array[int] = [4, 8, 16]


## Phase index (0 new .. 4 full .. 7) on game day `day`.
static func phase(day: int) -> int:
	var fixed: int = Settings.get_value("lunar_fixed")
	if fixed > 0:
		return fixed - 1
	var cycle: int = CYCLE_DAYS[Settings.get_value("lunar_cycle")]
	return int(floor(float(posmod(day - 1, cycle)) / cycle * PHASES.size()))


## How much of the moon is lit (0 new .. 1 full).
static func illumination(p: int) -> float:
	return 0.5 - 0.5 * cos(p / float(PHASES.size()) * TAU)


## The moodlet the night gives everyone awake, or [] (no effects, or an ordinary night).
static func night_moodlet(p: int) -> Array:
	if Settings.get_value("lunar_effects_off"):
		return []
	match p:
		4:
			return ["full_moon", "energized", 1, "Full Moon", "The moon is so bright tonight!", 30.0]
		0:
			return ["new_moon", "inspired", 1, "Starry Night", "No moon, just endless stars.", 30.0]
	return []
