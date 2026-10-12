class_name Autonomy
extends RefCounted
## Picks what an idle Sim does on their own. Each object interaction advertises how
## much it would restore each need; low needs weigh much more than nearly full ones,
## and far-away objects score a little lower.

## Needs above this are ignored when scoring.
const SATISFIED := 90.0
## Below this score the Sim just stays idle.
const MIN_SCORE := 4.0
## How appealing cleaning up a mess is (on the same scale as need scores).
const MESS_SCORE := 16.0
const FIRE_SCORE := 1000.0


## How pressing a need is at value `v` (0..100). Grows sharply as it empties.
static func urgency(v: float) -> float:
	var d := clampf(1.0 - v / 100.0, 0.0, 1.0)
	return 0.2 + d * d * 4.0


static func urgent_needs(needs: Needs) -> Array[String]:
	var out: Array[String] = []
	for n in Needs.ORDER:
		if needs.get_value(n) < Needs.LOW:
			out.append(n)
	return out


static func restores_any(interaction: Interaction, list: Array[String]) -> bool:
	for n in list:
		if interaction.rates.get(n, 0.0) > 0.0:
			return true
	return false


static func score(needs: Needs, interaction: Interaction) -> float:
	var total := 0.0
	for need in interaction.rates:
		var rate: float = interaction.rates[need]
		var v := needs.get_value(need)
		if rate <= 0.0 or v >= SATISFIED:
			continue
		var gain := minf(100.0 - v, rate * interaction.max_minutes / 60.0)
		total += gain * urgency(v)
	return total


## Personality and mood on top of needs: traits favour some activities, and a Sim
## feeling the emotion that suits a skill is drawn to practising it.
static func preference(sim: Sim, f: Furniture, interaction: Interaction) -> float:
	var m := Traits.liking(sim.traits, f.kind, interaction)
	if interaction.skill != "" and sim.emotions.mood() == Skills.boosting_emotion(interaction.skill):
		m *= 1.5
	return m


## Returns [furniture or Sim, interaction] or an empty array if nothing is worth doing.
## Low needs come before everything else: while any need is low, only
## interactions that restore one of them are considered, purely on need.
static func choose(sim: Sim, lot: Lot, rng: RandomNumberGenerator) -> Array:
	var urgent := urgent_needs(sim.needs)
	var options: Array = []
	for f in lot.furniture:
		if f.user != null and f.user != sim:
			continue
		if Daylight.power_off and Bills.ELECTRIC.has(f.kind):
			continue
		var dist := sim.global_position.distance_to(f.global_position)
		# Fires come first for everyone except toddlers and guests.
		if f.kind == "fire":
			if not sim.is_visitor and Ages.is_adult(sim.age_stage):
				options.append([FIRE_SCORE, f, f.interactions[0]])
			continue
		# Broken things get fixed when there's time.
		if f.broken:
			if urgent.is_empty() and not sim.is_visitor and Ages.is_adult(sim.age_stage):
				options.append([MESS_SCORE * 0.8 / (1.0 + dist / 20.0), f, f.available_interactions()[0]])
			continue
		# Tidy Sims clean up messes when nothing more pressing needs doing.
		if Catalog.MESSES.has(f.kind):
			if urgent.is_empty() and not sim.is_visitor and Ages.allows(sim.age_stage, f.interactions[0]):
				options.append([MESS_SCORE / (1.0 + dist / 20.0), f, f.interactions[0]])
			continue
		for i in f.interactions:
			if not Ages.allows_for(sim, i):
				continue
			if not urgent.is_empty() and not restores_any(i, urgent):
				continue
			var s := score(sim.needs, i) / (1.0 + dist / 20.0)
			if urgent.is_empty():
				s *= preference(sim, f, i)
			if s >= MIN_SCORE:
				options.append([s, f, i])
	# Other Sims on the lot: a chat or a joke when Social or Fun need it.
	for other in lot.sims:
		if other == sim or not (other as Sim).can_socialize():
			continue
		var dist := sim.global_position.distance_to(other.global_position)
		for i in [Socials.find("Chat"), Socials.find("Tell a Joke")]:
			if not urgent.is_empty() and not restores_any(i, urgent):
				continue
			var s := score(sim.needs, i) / (1.0 + dist / 20.0)
			if s >= MIN_SCORE:
				options.append([s, other, i])
	if options.is_empty():
		return []
	options.sort_custom(func(a, b): return a[0] > b[0])
	# A little variety: pick among the best few, weighted by score.
	var top := options.slice(0, 3)
	var sum := 0.0
	for o in top:
		sum += o[0]
	var r := rng.randf() * sum
	for o in top:
		r -= o[0]
		if r <= 0.0:
			return [o[1], o[2]]
	return [top[0][1], top[0][2]]
