class_name Autonomy
extends RefCounted
## Picks what an idle Sim does on their own. Each object interaction advertises how
## much it would restore each need; low needs weigh much more than nearly full ones,
## and far-away objects score a little lower.

## Needs above this are ignored when scoring.
const SATISFIED := 90.0
## Below this score the Sim just stays idle.
const MIN_SCORE := 4.0


## How pressing a need is at value `v` (0..100). Grows sharply as it empties.
static func urgency(v: float) -> float:
	var d := clampf(1.0 - v / 100.0, 0.0, 1.0)
	return 0.2 + d * d * 4.0


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


## Returns [furniture, interaction] or an empty array if nothing is worth doing.
static func choose(sim: Sim, lot: Lot, rng: RandomNumberGenerator) -> Array:
	var options: Array = []
	for f in lot.furniture:
		if f.user != null and f.user != sim:
			continue
		var dist := sim.global_position.distance_to(f.global_position)
		for i in f.interactions:
			var s := score(sim.needs, i) / (1.0 + dist / 20.0)
			if s >= MIN_SCORE:
				options.append([s, f, i])
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
