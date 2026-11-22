class_name Arenas
extends RefCounted
## Every arena a match can be played in, in menu order.

const LIST := [
	["foundry_yard", "The Foundry Yard", "A dead steelworks walled in with scrap. A furnace deck in the middle, a kicker in the east lane."],
	["refinery_row", "Refinery Row", "Burning flare stacks, tank farms and a pipe bridge across the middle. The fuel tanks blow."],
	["frozen_wharf", "Frozen Wharf", "A harbour iced over. Container canyons, a beached freighter to climb, and a basin of sheet ice."],
	["blackwater_bog", "Blackwater Bog", "Swamp at night. Sucking mud, boardwalks on stilts, dead trees, and a sunken bus."],
]


static func ids() -> Array[String]:
	var out: Array[String] = []
	for a in LIST:
		out.append(a[0])
	return out


static func display_name(id: String) -> String:
	for a in LIST:
		if a[0] == id:
			return a[1]
	return id


static func blurb(id: String) -> String:
	for a in LIST:
		if a[0] == id:
			return a[2]
	return ""


static func create(id: String) -> ArenaBase:
	match id:
		"refinery_row":
			return RefineryRow.new()
		"frozen_wharf":
			return FrozenWharf.new()
		"blackwater_bog":
			return BlackwaterBog.new()
	return FoundryYard.new()
