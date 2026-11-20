class_name ComboBuffer
extends RefCounted
## Recognises D-pad combo sequences. Engine-agnostic: feed it directions with a
## timestamp, it answers with a move id when a sequence completes.
##
## Each press must come within `window` seconds of the one before it. A press that
## arrives late starts a new sequence. When several moves end on the same presses,
## the longest sequence wins.
##
## Moves marked "hold" only fire while the hold control is down. While it is down,
## a short move is held back if the presses so far are partway through a longer hold
## move, so a long code never sets off a short one in its middle.

var window := 0.45
var sequences := {}          ## move_id -> PackedStringArray of directions
var hold_moves := {}         ## move_id -> true for moves that need the hold control
var _presses: Array[String] = []
var _last_time := -1000.0
var _max_len := 0


func configure(moves: Dictionary, window_s: float) -> void:
	window = window_s
	sequences.clear()
	hold_moves.clear()
	_max_len = 0
	for id in moves.keys():
		var inputs: Array = moves[id].get("inputs", [])
		var seq := PackedStringArray()
		for d in inputs:
			seq.append(str(d))
		if seq.size() > 0:
			sequences[id] = seq
			_max_len = maxi(_max_len, seq.size())
			if bool(moves[id].get("hold", false)):
				hold_moves[id] = true
	reset()


func reset() -> void:
	_presses.clear()
	_last_time = -1000.0


## Adds a press ("up", "down", "left", "right"). `holding` is whether the hold control
## is down. Returns the move id it completes, or "".
func push(direction: String, now: float, holding: bool = false) -> String:
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
		if hold_moves.has(id) and not holding:
			continue
		if seq.size() > _presses.size() or seq.size() <= best_len:
			continue
		if _ends_with(seq):
			best = id
			best_len = seq.size()
	if best != "" and holding and not hold_moves.has(best) and _inside_hold_move(best_len):
		return ""
	if best != "":
		_presses.clear()
	return best


## Presses entered so far in the current sequence (for the HUD).
func pending() -> Array[String]:
	return _presses.duplicate()


func _ends_with(seq: PackedStringArray) -> bool:
	var offset := _presses.size() - seq.size()
	for i in seq.size():
		if _presses[offset + i] != seq[i]:
			return false
	return true


## True when the last presses, more than `longer_than` of them, are the start of a
## hold move that isn't finished yet.
func _inside_hold_move(longer_than: int) -> bool:
	for id in hold_moves:
		var seq: PackedStringArray = sequences[id]
		for n in range(longer_than + 1, mini(_presses.size(), seq.size() - 1) + 1):
			var match_all := true
			var offset := _presses.size() - n
			for i in n:
				if _presses[offset + i] != seq[i]:
					match_all = false
					break
			if match_all:
				return true
	return false

