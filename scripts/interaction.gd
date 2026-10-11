class_name Interaction
extends RefCounted
## Something a Sim can do with an object, e.g. "Sleep" on a bed.

var name: String
## need -> points per game hour while performing (replaces normal decay for that need).
var rates: Dictionary
## Ends early once this need is full ("" = only the time limit applies).
var until_full: String
var max_minutes: float
## "stand", "sit" or "lie".
var pose: String
## Whether the Sim moves its arms while doing this (eating, typing...).
var busy_hands: bool


func _init(p_name: String, p_rates: Dictionary, p_max_minutes: float, p_until_full := "", p_pose := "stand", p_busy_hands := false) -> void:
	name = p_name
	rates = p_rates
	max_minutes = p_max_minutes
	until_full = p_until_full
	pose = p_pose
	busy_hands = p_busy_hands
