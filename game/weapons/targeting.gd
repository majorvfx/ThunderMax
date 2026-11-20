class_name Targeting
extends RefCounted
## Picks the car to aim at inside a cone, e.g. behind you for rear shots.


## Nearest-to-centre live, visible target within `cone_deg` of `dir` and `max_dist`
## metres of `from`, or null.
static func in_cone(from: ArcadeVehicle, dir: Vector3, cone_deg: float, max_dist: float) -> Node3D:
	var best: Node3D = null
	var best_angle := deg_to_rad(cone_deg)
	var origin := from.global_position
	for node in from.get_tree().get_nodes_in_group("targets"):
		if node == from or not (node is Node3D):
			continue
		if node is ArcadeVehicle and (not node.is_alive() or (node as ArcadeVehicle).status.is_cloaked()):
			continue
		var to: Vector3 = (node as Node3D).global_position - origin
		if to.length() > max_dist or to.length() < 1.0:
			continue
		var angle := dir.angle_to(to)
		if angle < best_angle:
			best_angle = angle
			best = node
	return best
