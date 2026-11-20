class_name ComboBuffer
extends RefCounted
## Recognises D-pad combo sequences. Engine-agnostic: feed it directions with a
## timestamp, it answers with a move id when a sequence completes.
##
## Each press must come within `window` seconds of the one before it. A press that
## arrives late starts a new sequence. When several moves end on the same presses,
## the longest sequence wins.

var window := 0.45
var sequences := {}          ## move_id -> PackedStringArray of directions
var _presses: Array[String] = []
var _last_time := -1000.0
var _max_len := 0


func configure(moves: Dictionary, window_s: float) -> void:
	window = window_s
	sequences.clear()
	_max_len = 0
	for id in moves.keys():
		var inputs: Array = moves[id].get("inputs", [])
		var seq := PackedStringArray()
		for d in inputs:
			seq.append(str(d))
		if seq.size() > 0:
			sequences[id] = seq
			_max_len = maxi(_max_len, seq.size())
	reset()


func reset() -> void:
	_presses.clear()
	_last_time = -1000.0


## Adds a press ("up", "down", "left", "right"). Returns the move id it completes, or "".
func push(direction: String, now: float) -> String:
	if now - _last_time > window:
		_presses.clear()
	_last_time = now
	_presses.append(direction)
	if _presses.size() > _max_len:
		_presses.pop_front()
	var best := ""
	var best_len := 0
	for id in sequences.keys():
		var seq: PackedStringArray = sequences[id]
		if seq.size() > _presses.size() or seq.size() <= best_len:
			continue
		var match_all := true
		var offset := _presses.size() - seq.size()
		for i in seq.size():
			if _presses[offset + i] != seq[i]:
				match_all = false
				break
		if match_all:
			best = id
			best_len = seq.size()
	if best != "":
		_presses.clear()
	return best


## Presses entered so far in the current sequence (for the HUD).
func pending() -> Array[String]:
	return _presses.duplicate()
