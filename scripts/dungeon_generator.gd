extends RefCounted
class_name DungeonGenerator

const GeometryBuilderClass = preload("res://scripts/geometry_builder.gd")

const THEMES := {
	"integrity": {
		"name": "Integrity Annex",
		"albedo": Color(0.44, 0.67, 0.76),
		"emission": Color(0.22, 0.44, 0.49),
		"metallic": 0.12,
		"map": Color(0.47, 0.86, 0.93)
	},
	"corrosion": {
		"name": "Corrosion Vault",
		"albedo": Color(0.76, 0.47, 0.28),
		"emission": Color(0.43, 0.18, 0.08),
		"metallic": 0.08,
		"map": Color(0.95, 0.62, 0.39)
	},
	"archive": {
		"name": "Archive Lattice",
		"albedo": Color(0.52, 0.82, 0.59),
		"emission": Color(0.14, 0.33, 0.16),
		"metallic": 0.04,
		"map": Color(0.67, 0.93, 0.73)
	}
}

func generate(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var rooms: Array = []
	var target_rooms := 8 + rng.randi_range(0, 3)
	var entry_room := _make_room(rng, 0, Vector2.ZERO, 0.0, "entry", -1)
	entry_room["theme_id"] = "integrity"
	entry_room["brightness"] = 1.08
	rooms.append(entry_room)

	var room_id := 1
	while rooms.size() < target_rooms:
		var placed := false
		for _attempt in 32:
			var parent: Dictionary = rooms[rng.randi_range(0, rooms.size() - 1)]
			var angle := rng.randf_range(0.0, TAU)
			var center: Vector2 = parent["center"] + Vector2.RIGHT.rotated(angle) * (float(parent["bound_radius"]) + rng.randf_range(13.0, 18.0))
			var base_y: float = clamp(float(parent["base_y"]) + float(rng.randi_range(-1, 1)) * 1.35, -2.6, 3.8)
			var room := _make_room(rng, room_id, center, base_y, "room", int(parent["id"]))
			if _room_fits(room, rooms):
				rooms.append(room)
				room_id += 1
				placed = true
				break
		if not placed:
			var fallback_center := Vector2(rng.randf_range(-26.0, 26.0), rng.randf_range(-26.0, 26.0))
			var fallback := _make_room(rng, room_id, fallback_center, rng.randf_range(-1.4, 2.8), "room", 0)
			if _room_fits(fallback, rooms):
				rooms.append(fallback)
				room_id += 1

	var corridors: Array = []
	var corridor_id := 0
	for room in rooms:
		if int(room.get("parent_id", -1)) >= 0:
			var parent_room := _find_room(rooms, int(room["parent_id"]))
			if parent_room.is_empty():
				continue
			corridors.append(_make_corridor(rng, corridor_id, parent_room, room))
			corridor_id += 1

	var candidate_pairs := _collect_extra_pairs(rooms, corridors)
	for pair in candidate_pairs:
		if corridors.size() >= rooms.size() + 2:
			break
		if rng.randf() > 0.45:
			continue
		var room_a := _find_room(rooms, int(pair[0]))
		var room_b := _find_room(rooms, int(pair[1]))
		if room_a.is_empty() or room_b.is_empty():
			continue
		corridors.append(_make_corridor(rng, corridor_id, room_a, room_b))
		corridor_id += 1

	_register_room_openings(rooms, corridors)
	_assign_special_rooms(rooms)
	var goal_room_id := int(rooms[-1].get("goal_room_id", 0))
	var key_room_id := int(rooms[-1].get("key_room_id", 0))
	rooms.pop_back()

	var locked_corridor_id := _choose_locked_corridor(corridors, goal_room_id)
	var doors := _make_doors(rng, corridors, locked_corridor_id)
	var pickups := _make_pickups(rng, rooms, key_room_id, goal_room_id)
	var enemies := _make_enemies(rng, rooms, goal_room_id)
	_ensure_early_enemy(rng, rooms, corridors, enemies)
	var debug_data := _build_join_debug(seed_value, rooms, corridors)

	var entry_spawn := _sample_point_in_room(rng, _find_room(rooms, 0), false, true)
	var goal_terminal := _sample_point_in_room(rng, _find_room(rooms, goal_room_id), true, false)

	return {
		"seed_value": seed_value,
		"themes": THEMES.duplicate(true),
		"rooms": rooms,
		"corridors": corridors,
		"doors": doors,
		"pickups": pickups,
		"enemies": enemies,
		"debug": debug_data,
		"entry_spawn": entry_spawn,
		"goal_room_id": goal_room_id,
		"key_room_id": key_room_id,
		"locked_corridor_id": locked_corridor_id,
		"goal_terminal": {
			"room_id": goal_room_id,
			"position": goal_terminal
		}
	}

func _make_room(rng: RandomNumberGenerator, room_id: int, center: Vector2, base_y: float, kind: String, parent_id: int) -> Dictionary:
	var local_points := _make_room_outline(rng)
	var rotation := rng.randf_range(0.0, TAU)
	var polygon := PackedVector2Array()
	for point in local_points:
		polygon.append(point.rotated(rotation) + center)
	polygon = GeometryBuilderClass.ensure_ccw(polygon)
	var bound_radius := 0.0
	for point in polygon:
		bound_radius = max(bound_radius, point.distance_to(center))
	var theme_id: String = ["integrity", "corrosion", "archive"][rng.randi_range(0, 2)]
	var room := {
		"id": room_id,
		"name": "Room",
		"kind": kind,
		"center": center,
		"polygon": polygon,
		"bound_radius": bound_radius,
		"base_y": base_y,
		"height_mode": "flat",
		"ceiling_height": rng.randf_range(4.0, 5.2),
		"slope": 0.0 if kind == "entry" else rng.randf_range(-0.1, 0.12) if rng.randf() < 0.28 else 0.0,
		"slope_axis": Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)),
		"theme_id": theme_id,
		"brightness": rng.randf_range(0.9, 1.08),
		"parent_id": parent_id,
		"platform": {},
		"ramp": {}
	}
	if kind != "entry" and rng.randf() < 0.46:
		_assign_platform_feature(rng, room)
	return room

func _make_room_outline(rng: RandomNumberGenerator) -> PackedVector2Array:
	var choice := rng.randi_range(0, 3)
	var points := PackedVector2Array()
	match choice:
		0:
			var width_a := rng.randf_range(5.5, 8.3)
			var width_b := rng.randf_range(3.4, 7.0)
			var depth := rng.randf_range(4.8, 7.4)
			points = PackedVector2Array([
				Vector2(-width_a, -depth * 0.55),
				Vector2(width_a * 0.85, -depth * 0.75),
				Vector2(width_b, depth * 0.65),
				Vector2(-width_a * 0.8, depth * 0.8)
			])
		1:
			var front := rng.randf_range(4.0, 7.0)
			var back := rng.randf_range(6.5, 9.2)
			var tall := rng.randf_range(5.2, 8.0)
			points = PackedVector2Array([
				Vector2(-back * 0.7, -tall * 0.55),
				Vector2(back, -tall * 0.2),
				Vector2(front * 0.45, tall),
				Vector2(-front, tall * 0.35)
			])
		2:
			var rx := rng.randf_range(5.6, 8.7)
			var rz := rng.randf_range(4.4, 7.7)
			var sides := rng.randi_range(5, 6)
			for index in sides:
				var angle := TAU * float(index) / float(sides) + rng.randf_range(-0.22, 0.22)
				var radius := rng.randf_range(0.72, 1.0)
				points.append(Vector2(cos(angle) * rx * radius, sin(angle) * rz * radius))
		_:
			var base := rng.randf_range(5.0, 7.5)
			var side := rng.randf_range(4.6, 7.6)
			points = PackedVector2Array([
				Vector2(-base, -side * 0.8),
				Vector2(base * 0.5, -side),
				Vector2(base, -side * 0.1),
				Vector2(base * 0.55, side),
				Vector2(-base * 0.9, side * 0.65)
			])
	return GeometryBuilderClass.ensure_ccw(points)

func _assign_platform_feature(rng: RandomNumberGenerator, room: Dictionary) -> void:
	var platform_polygon := GeometryBuilderClass.scale_polygon(room["polygon"], rng.randf_range(0.34, 0.5), room["center"])
	var platform_y := float(room["base_y"]) + rng.randf_range(0.8, 1.55)
	var ramp_direction := Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
	var outer_point := _ray_to_polygon(room["center"], ramp_direction, room["polygon"])
	var inner_point := _ray_to_polygon(room["center"], ramp_direction, platform_polygon)
	var ramp_width := rng.randf_range(1.5, 2.2)
	var perp := Vector2(-ramp_direction.y, ramp_direction.x) * ramp_width * 0.5
	room["platform"] = {
		"id": 1000 + int(room["id"]),
		"name": "Platform",
		"polygon": platform_polygon,
		"center": GeometryBuilderClass.polygon_centroid(platform_polygon),
		"base_y": platform_y,
		"height_mode": "flat",
		"ceiling_height": float(room["ceiling_height"]) - 0.4,
		"slope": 0.0,
		"slope_axis": ramp_direction,
		"brightness": float(room["brightness"]) + 0.05,
		"theme_id": room["theme_id"]
	}
	room["ramp"] = {
		"id": 2000 + int(room["id"]),
		"name": "Ramp",
		"polygon": PackedVector2Array([
			outer_point + perp,
			outer_point - perp,
			inner_point - perp,
			inner_point + perp
		]),
		"center": ((outer_point + inner_point) * 0.5),
		"base_y": float(room["base_y"]),
		"height_mode": "corridor",
		"height_start": outer_point,
		"height_end": inner_point,
		"start_y": float(room["base_y"]),
		"end_y": platform_y,
		"ceiling_height": float(room["ceiling_height"]) - 0.35,
		"brightness": float(room["brightness"]) + 0.02,
		"theme_id": room["theme_id"]
	}
	room["slope"] = 0.0

func _room_fits(candidate: Dictionary, rooms: Array) -> bool:
	for room in rooms:
		var min_distance := float(candidate["bound_radius"]) + float(room["bound_radius"]) + 3.4
		if candidate["center"].distance_to(room["center"]) < min_distance:
			return false
	return true

func _find_room(rooms: Array, room_id: int) -> Dictionary:
	for room in rooms:
		if int(room.get("id", -1)) == room_id:
			return room
	return {}

func _make_corridor(rng: RandomNumberGenerator, corridor_id: int, room_a: Dictionary, room_b: Dictionary) -> Dictionary:
	var direction: Vector2 = (room_b["center"] - room_a["center"]).normalized()
	var start_hit: Dictionary = _ray_to_polygon_hit(room_a["center"], direction, room_a["polygon"])
	var end_hit: Dictionary = _ray_to_polygon_hit(room_b["center"], -direction, room_b["polygon"])
	var start_wall_point: Vector2 = start_hit.get("point", room_a["center"])
	var end_wall_point: Vector2 = end_hit.get("point", room_b["center"])
	var width: float = rng.randf_range(2.6, 3.6)
	var inset: float = min(width * 0.28, 0.6)
	var start_point := start_wall_point - direction * inset
	var end_point := end_wall_point + direction * inset
	var perp := Vector2(-direction.y, direction.x) * width * 0.5
	var polygon := PackedVector2Array([
		start_point + perp,
		start_point - perp,
		end_point - perp,
		end_point + perp
	])
	var start_host_edge := _resolve_host_edge_for_corridor(room_a, polygon, start_hit)
	var end_host_edge := _resolve_host_edge_for_corridor(room_b, polygon, end_hit)
	var start_host_edge_index := int(start_host_edge.get("edge_index", int(start_hit.get("edge_index", -1))))
	var end_host_edge_index := int(end_host_edge.get("edge_index", int(end_hit.get("edge_index", -1))))
	var start_host_edge_from: Vector2 = start_host_edge.get("edge_from", start_hit.get("edge_from", start_wall_point))
	var start_host_edge_to: Vector2 = start_host_edge.get("edge_to", start_hit.get("edge_to", start_wall_point))
	var end_host_edge_from: Vector2 = end_host_edge.get("edge_from", end_hit.get("edge_from", end_wall_point))
	var end_host_edge_to: Vector2 = end_host_edge.get("edge_to", end_hit.get("edge_to", end_wall_point))
	var start_y := GeometryBuilderClass.area_floor_height(room_a, start_point)
	var end_y := GeometryBuilderClass.area_floor_height(room_b, end_point)
	return {
		"id": corridor_id,
		"name": "Corridor",
		"room_a": int(room_a["id"]),
		"room_b": int(room_b["id"]),
		"center": (start_point + end_point) * 0.5,
		"polygon": polygon,
		"base_y": min(start_y, end_y),
		"height_mode": "corridor",
		"height_start": start_point,
		"height_end": end_point,
		"start_y": start_y,
		"end_y": end_y,
		"ceiling_height": rng.randf_range(3.3, 4.3),
		"theme_id": room_b["theme_id"],
		"brightness": rng.randf_range(0.86, 0.98),
		"width": width,
		"wall_inset": inset,
		"start_anchor": start_point,
		"end_anchor": end_point,
		"start_wall_point": start_wall_point,
		"end_wall_point": end_wall_point,
		"start_host_edge_index": start_host_edge_index,
		"end_host_edge_index": end_host_edge_index,
		"start_host_edge_from": start_host_edge_from,
		"start_host_edge_to": start_host_edge_to,
		"end_host_edge_from": end_host_edge_from,
		"end_host_edge_to": end_host_edge_to,
		"start_edge_resolution_mode": str(start_host_edge.get("resolution_mode", "ray_hit")),
		"end_edge_resolution_mode": str(end_host_edge.get("resolution_mode", "ray_hit")),
		"wall_openings": [
			{
				"point": start_point,
				"width": width + 1.0,
				"opening_kind": "corridor_end",
				"source_corridor_id": corridor_id,
				"source_end": "start",
				"connected_room_id": int(room_a["id"]),
				"host_corridor_id": corridor_id,
				"corridor_anchor_point": start_point,
				"room_wall_point": start_wall_point
			},
			{
				"point": end_point,
				"width": width + 1.0,
				"opening_kind": "corridor_end",
				"source_corridor_id": corridor_id,
				"source_end": "end",
				"connected_room_id": int(room_b["id"]),
				"host_corridor_id": corridor_id,
				"corridor_anchor_point": end_point,
				"room_wall_point": end_wall_point
			}
		]
	}

func _collect_extra_pairs(rooms: Array, corridors: Array) -> Array:
	var existing := {}
	for corridor in corridors:
		var key := _connection_key(int(corridor["room_a"]), int(corridor["room_b"]))
		existing[key] = true
	var candidates: Array = []
	for room_a in rooms:
		for room_b in rooms:
			if int(room_a["id"]) >= int(room_b["id"]):
				continue
			var key := _connection_key(int(room_a["id"]), int(room_b["id"]))
			if existing.has(key):
				continue
			var distance: float = room_a["center"].distance_to(room_b["center"])
			if distance > 28.0:
				continue
			candidates.append([int(room_a["id"]), int(room_b["id"]), distance])
	candidates.sort_custom(func(a, b): return a[2] < b[2])
	var result: Array = []
	for item in candidates:
		result.append([item[0], item[1]])
	return result

func _assign_special_rooms(rooms: Array) -> void:
	var distances: Array = []
	for room in rooms:
		distances.append([int(room["id"]), room["center"].length()])
	distances.sort_custom(func(a, b): return a[1] > b[1])
	var goal_room_id := int(distances[0][0])
	var key_room_id := int(distances[min(1, distances.size() - 1)][0])
	for room in rooms:
		if int(room["id"]) == goal_room_id:
			room["kind"] = "goal"
			room["theme_id"] = "archive"
			room["brightness"] = 1.1
		elif int(room["id"]) == key_room_id:
			room["kind"] = "key"
			room["theme_id"] = "corrosion"
	rooms.append({"goal_room_id": goal_room_id, "key_room_id": key_room_id})

func _choose_locked_corridor(corridors: Array, goal_room_id: int) -> int:
	for corridor in corridors:
		if int(corridor["room_a"]) == goal_room_id or int(corridor["room_b"]) == goal_room_id:
			return int(corridor["id"])
	return int(corridors.back()["id"])

func _make_doors(rng: RandomNumberGenerator, corridors: Array, locked_corridor_id: int) -> Array:
	var doors: Array = []
	var door_id := 0
	for corridor in corridors:
		var direction: Vector2 = (corridor["end_anchor"] - corridor["start_anchor"]).normalized()
		var door_position: Vector2 = corridor["start_anchor"].lerp(corridor["end_anchor"], 0.5)
		var locked := int(corridor["id"]) == locked_corridor_id
		if not locked and rng.randf() > 0.38:
			continue
		if locked:
			door_position = corridor["end_anchor"].lerp(corridor["start_anchor"], 0.22)
		var door_y: float = lerp(float(corridor["start_y"]), float(corridor["end_y"]), clamp((door_position - corridor["start_anchor"]).length() / max(corridor["start_anchor"].distance_to(corridor["end_anchor"]), 0.01), 0.0, 1.0))
		doors.append({
			"id": door_id,
			"corridor_id": int(corridor["id"]),
			"position": Vector3(door_position.x, door_y, door_position.y),
			"yaw": atan2(direction.x, direction.y),
			"locked": locked,
			"open": false
		})
		door_id += 1
	return doors

func _make_pickups(rng: RandomNumberGenerator, rooms: Array, key_room_id: int, goal_room_id: int) -> Array:
	var pickups: Array = []
	var pickup_id := 0
	for room in rooms:
		if int(room["id"]) == 0:
			continue
		if int(room["id"]) == key_room_id:
			pickups.append(_pickup_entry(pickup_id, "key", room, _sample_point_in_room(rng, room, true, false), 1))
			pickup_id += 1
			continue
		if int(room["id"]) == goal_room_id:
			continue
		if rng.randf() < 0.42:
			pickups.append(_pickup_entry(pickup_id, "tonic", room, _sample_point_in_room(rng, room, false, false), 1))
			pickup_id += 1
		if rng.randf() < 0.34:
			pickups.append(_pickup_entry(pickup_id, "aether", room, _sample_point_in_room(rng, room, false, false), 1))
			pickup_id += 1
	return pickups

func _pickup_entry(pickup_id: int, kind: String, room: Dictionary, position: Vector3, amount: int) -> Dictionary:
	return {
		"id": pickup_id,
		"kind": kind,
		"room_id": int(room["id"]),
		"position": position,
		"amount": amount
	}

func _make_enemies(rng: RandomNumberGenerator, rooms: Array, goal_room_id: int) -> Array:
	var enemies: Array = []
	var enemy_id := 0
	for room in rooms:
		if int(room["id"]) == 0:
			continue
		if rng.randf() > 0.74 and int(room["id"]) != goal_room_id:
			continue
		var position := _sample_point_in_room(rng, room, false, false)
		var patrol_points: Array = []
		for _index in 3:
			patrol_points.append(_sample_point_in_room(rng, room, rng.randf() < 0.33, false))
		enemies.append({
			"id": enemy_id,
			"room_id": int(room["id"]),
			"position": position,
			"patrol_points": patrol_points,
			"theme_id": room["theme_id"],
			"is_guard": int(room["id"]) == goal_room_id
		})
		enemy_id += 1
	return enemies

func _ensure_early_enemy(rng: RandomNumberGenerator, rooms: Array, corridors: Array, enemies: Array) -> void:
	var target_room_id := -1
	for corridor in corridors:
		if int(corridor["room_a"]) == 0:
			target_room_id = int(corridor["room_b"])
			break
		if int(corridor["room_b"]) == 0:
			target_room_id = int(corridor["room_a"])
			break
	if target_room_id < 0:
		return
	for enemy in enemies:
		if int(enemy["room_id"]) == target_room_id:
			return
	var room := _find_room(rooms, target_room_id)
	if room.is_empty():
		return
	var patrol_points: Array = []
	for _index in 3:
		patrol_points.append(_sample_point_in_room(rng, room, false, false))
	enemies.append({
		"id": enemies.size(),
		"room_id": target_room_id,
		"position": _sample_point_in_room(rng, room, false, false),
		"patrol_points": patrol_points,
		"theme_id": room["theme_id"],
		"is_guard": false
	})

func _sample_point_in_room(rng: RandomNumberGenerator, room: Dictionary, prefer_platform: bool, keep_center: bool) -> Vector3:
	var polygon: PackedVector2Array = room["polygon"]
	var height_area := room
	if prefer_platform and not room.get("platform", {}).is_empty():
		polygon = room["platform"]["polygon"]
		height_area = room["platform"]
	var center: Vector2 = room["center"]
	var min_point := polygon[0]
	var max_point := polygon[0]
	for point in polygon:
		min_point.x = min(min_point.x, point.x)
		min_point.y = min(min_point.y, point.y)
		max_point.x = max(max_point.x, point.x)
		max_point.y = max(max_point.y, point.y)
	for _attempt in 32:
		var candidate: Vector2 = center if keep_center else Vector2(rng.randf_range(min_point.x, max_point.x), rng.randf_range(min_point.y, max_point.y))
		if Geometry2D.is_point_in_polygon(candidate, polygon):
			var y := GeometryBuilderClass.area_floor_height(height_area, candidate)
			return Vector3(candidate.x, y + 0.35, candidate.y)
	var fallback_y := GeometryBuilderClass.area_floor_height(height_area, center)
	return Vector3(center.x, fallback_y + 0.35, center.y)

func _register_room_openings(rooms: Array, corridors: Array) -> void:
	for room in rooms:
		room["wall_openings"] = []
	for corridor in corridors:
		_append_room_opening(
			rooms,
			int(corridor["room_a"]),
			int(corridor["id"]),
			"start",
			corridor.get("start_wall_point", corridor["start_anchor"]),
			float(corridor["width"]) + 0.9,
			int(corridor["room_b"]),
			corridor.get("start_anchor", corridor.get("start_wall_point", Vector2.ZERO)),
			int(corridor.get("start_host_edge_index", -1)),
			corridor.get("start_host_edge_from", corridor.get("start_wall_point", Vector2.ZERO)),
			corridor.get("start_host_edge_to", corridor.get("start_wall_point", Vector2.ZERO)),
			corridor.get("polygon", PackedVector2Array())
		)
		_append_room_opening(
			rooms,
			int(corridor["room_b"]),
			int(corridor["id"]),
			"end",
			corridor.get("end_wall_point", corridor["end_anchor"]),
			float(corridor["width"]) + 0.9,
			int(corridor["room_a"]),
			corridor.get("end_anchor", corridor.get("end_wall_point", Vector2.ZERO)),
			int(corridor.get("end_host_edge_index", -1)),
			corridor.get("end_host_edge_from", corridor.get("end_wall_point", Vector2.ZERO)),
			corridor.get("end_host_edge_to", corridor.get("end_wall_point", Vector2.ZERO)),
			corridor.get("polygon", PackedVector2Array())
		)

func _append_room_opening(rooms: Array, room_id: int, corridor_id: int, end_key: String, point: Vector2, width: float, connected_room_id: int, corridor_anchor_point: Vector2, target_edge_index: int, target_edge_from: Vector2, target_edge_to: Vector2, corridor_polygon: PackedVector2Array) -> void:
	var room := _find_room(rooms, room_id)
	if room.is_empty():
		return
	if not room.has("wall_openings"):
		room["wall_openings"] = []
	room["wall_openings"].append({
		"point": point,
		"width": width,
		"opening_kind": "room_join",
		"source_corridor_id": corridor_id,
		"source_end": end_key,
		"host_room_id": room_id,
		"connected_room_id": connected_room_id,
		"room_wall_point": point,
		"corridor_anchor_point": corridor_anchor_point,
		"target_edge_index": target_edge_index,
		"target_edge_from": target_edge_from,
		"target_edge_to": target_edge_to,
		"corridor_polygon": corridor_polygon.duplicate()
	})

func _build_join_debug(seed_value: int, rooms: Array, corridors: Array) -> Dictionary:
	var room_analysis_by_id: Dictionary = {}
	var corridor_analysis_by_id: Dictionary = {}
	var room_analyses: Array = []
	var corridor_analyses: Array = []
	var room_openings: Array = []
	var corridor_openings: Array = []
	var joins: Array = []
	var suspicious_joins: Array = []
	var failed_count := 0
	for room in rooms:
		var room_id := int(room["id"])
		var analysis: Dictionary = GeometryBuilderClass.inspect_wall_openings(room["polygon"], room.get("wall_openings", []))
		room_analysis_by_id[room_id] = analysis
		room_analyses.append({
			"host_type": "room",
			"host_id": room_id,
			"analysis": analysis
		})
		for opening_report_variant in analysis.get("openings", []):
			var opening_report: Dictionary = opening_report_variant.duplicate(true)
			opening_report["host_type"] = "room"
			opening_report["host_id"] = room_id
			room_openings.append(opening_report)
	for corridor in corridors:
		var corridor_id := int(corridor["id"])
		var analysis: Dictionary = GeometryBuilderClass.inspect_wall_openings(corridor["polygon"], corridor.get("wall_openings", []))
		corridor_analysis_by_id[corridor_id] = analysis
		corridor_analyses.append({
			"host_type": "corridor",
			"host_id": corridor_id,
			"analysis": analysis
		})
		for opening_report_variant in analysis.get("openings", []):
			var opening_report: Dictionary = opening_report_variant.duplicate(true)
			opening_report["host_type"] = "corridor"
			opening_report["host_id"] = corridor_id
			corridor_openings.append(opening_report)
	for corridor in corridors:
		var start_join := _build_join_report(corridor, "start", room_analysis_by_id, corridor_analysis_by_id)
		var end_join := _build_join_report(corridor, "end", room_analysis_by_id, corridor_analysis_by_id)
		joins.append(start_join)
		joins.append(end_join)
		if str(start_join.get("status", "ok")) != "ok":
			suspicious_joins.append(start_join)
		if str(end_join.get("status", "ok")) != "ok":
			suspicious_joins.append(end_join)
	for join_variant in joins:
		var join_report: Dictionary = join_variant
		if str(join_report.get("status", "ok")) == "failed":
			failed_count += 1
	var summary := {
		"seed_value": seed_value,
		"corridor_count": corridors.size(),
		"join_count": joins.size(),
		"suspicious_count": suspicious_joins.size(),
		"failed_count": failed_count
	}
	return {
		"summary": summary,
		"corridor_joins": joins,
		"suspicious_joins": suspicious_joins,
		"room_analyses": room_analyses,
		"corridor_analyses": corridor_analyses,
		"room_openings": room_openings,
		"corridor_openings": corridor_openings
	}

func _build_join_report(corridor: Dictionary, end_key: String, room_analysis_by_id: Dictionary, corridor_analysis_by_id: Dictionary) -> Dictionary:
	var is_start := end_key == "start"
	var corridor_id := int(corridor["id"])
	var room_id := int(corridor["room_a"] if is_start else corridor["room_b"])
	var corridor_anchor: Vector2 = corridor["start_anchor"] if is_start else corridor["end_anchor"]
	var room_wall_point: Vector2 = corridor.get("start_wall_point", corridor_anchor) if is_start else corridor.get("end_wall_point", corridor_anchor)
	var authoritative_room_edge_index := int(corridor.get("start_host_edge_index", -1)) if is_start else int(corridor.get("end_host_edge_index", -1))
	var intended_room_width := float(corridor["width"]) + 0.9
	var corridor_analysis: Dictionary = corridor_analysis_by_id.get(corridor_id, {})
	var room_analysis: Dictionary = room_analysis_by_id.get(room_id, {})
	var room_opening_report := _find_opening_report(room_analysis.get("openings", []), corridor_id, end_key, "room_join")
	var corridor_opening_report := _find_opening_report(corridor_analysis.get("openings", []), corridor_id, end_key, "corridor_end")
	var best_match: Dictionary = room_opening_report.get("best_match", {})
	var authoritative_room_edge: Dictionary = {
		"edge_index": authoritative_room_edge_index,
		"edge_from": corridor.get("start_host_edge_from", room_wall_point) if is_start else corridor.get("end_host_edge_from", room_wall_point),
		"edge_to": corridor.get("start_host_edge_to", room_wall_point) if is_start else corridor.get("end_host_edge_to", room_wall_point),
		"edge_length": corridor.get("start_host_edge_from", room_wall_point).distance_to(corridor.get("start_host_edge_to", room_wall_point)) if is_start else corridor.get("end_host_edge_from", room_wall_point).distance_to(corridor.get("end_host_edge_to", room_wall_point))
	}
	var used_room_edge_index := int(room_opening_report.get("used_edge_index", -1))
	var used_room_edge: Dictionary = _find_edge_report(room_analysis, used_room_edge_index)
	var nearest_room_edge: Dictionary = room_opening_report.get("nearest_match", {})
	var room_edge_matches_authoritative := authoritative_room_edge_index >= 0 and used_room_edge_index == authoritative_room_edge_index and bool(room_opening_report.get("used_authoritative_edge", false))
	var exact_portal_reasons: Array = room_opening_report.get("failure_reasons", []).duplicate(true)
	var portal_intersection_points: Array = room_opening_report.get("intersection_points", []).duplicate(true)
	var reasons: Array = []
	var room_opening_registered := not room_opening_report.is_empty()
	var corridor_end_marked := not corridor_opening_report.is_empty()
	var room_carveable := bool(room_opening_report.get("accepted", false))
	var corridor_carveable := bool(corridor_opening_report.get("accepted", false))
	if authoritative_room_edge_index < 0:
		reasons.append("no authoritative room edge")
	if not room_opening_registered:
		reasons.append("no opening registered on room side")
	if not corridor_end_marked:
		reasons.append("corridor did not mark its own end opening")
	for portal_reason in exact_portal_reasons:
		if not reasons.has(portal_reason):
			reasons.append(portal_reason)
	if not room_opening_registered and not corridor_end_marked:
		reasons.append("no opening registered on either side")
	elif not room_opening_registered or not corridor_end_marked:
		reasons.append("no opening registered on one side")
	if room_opening_registered and authoritative_room_edge_index >= 0 and used_room_edge_index != authoritative_room_edge_index:
		reasons.append("authoritative room edge not used")
	if not best_match.is_empty():
		if float(best_match.get("corner_clearance", 999.0)) < max(0.45, intended_room_width * 0.35):
			reasons.append("opening too close to a room corner")
		if intended_room_width > float(best_match.get("edge_length", 0.0)) * 0.9:
			reasons.append("corridor width too large for the host wall segment")
	var status := "ok"
	if reasons.has("no opening registered on either side") or reasons.has("no authoritative room edge") or not exact_portal_reasons.is_empty():
		status = "failed"
	elif reasons.size() > 0:
		status = "suspicious"
	var room_span := _preferred_span(room_opening_report)
	var corridor_span := _preferred_span(corridor_opening_report)
	return {
		"join_id": str("corridor_", corridor_id, "_", end_key),
		"status": status,
		"reasons": reasons,
		"corridor_id": corridor_id,
		"end_key": end_key,
		"connected_room_id": room_id,
		"anchor_point": corridor_anchor,
		"corridor_anchor_point": corridor_anchor,
		"room_wall_point": room_wall_point,
		"anchor_offset": corridor_anchor.distance_to(room_wall_point),
		"intended_opening_width": intended_room_width,
		"authoritative_room_edge_index": authoritative_room_edge_index,
		"authoritative_room_edge": authoritative_room_edge,
		"room_edge_used_index": used_room_edge_index,
		"room_edge_used": used_room_edge,
		"room_edge_matches_authoritative": room_edge_matches_authoritative,
		"room_opening_edge_source": str(room_opening_report.get("edge_source", "none")),
		"nearest_room_edge": nearest_room_edge,
		"inferred_room_edge": best_match,
		"portal_intersection_points": portal_intersection_points,
		"portal_intersection_count": int(room_opening_report.get("intersection_count", portal_intersection_points.size())),
		"portal_failure_reasons": exact_portal_reasons,
		"portal_span_length": float(room_opening_report.get("span_length", 0.0)),
		"accepted_room_edge_indices": room_opening_report.get("accepted_edge_indices", []).duplicate(true),
		"accepted_corridor_edge_indices": corridor_opening_report.get("accepted_edge_indices", []).duplicate(true),
		"room_opening_registered": room_opening_registered,
		"room_opening_carveable": room_carveable,
		"room_opening_report": room_opening_report,
		"corridor_end_marked": corridor_end_marked,
		"corridor_end_carveable": corridor_carveable,
		"corridor_opening_report": corridor_opening_report,
		"room_opening_span": room_span,
		"corridor_opening_span": corridor_span,
		"corridor_center": corridor["center"],
		"corridor_start_anchor": corridor["start_anchor"],
		"corridor_end_anchor": corridor["end_anchor"],
		"corridor_start_y": float(corridor["start_y"]),
		"corridor_end_y": float(corridor["end_y"]),
		"corridor_width": float(corridor["width"])
	}

func _find_opening_report(openings: Array, corridor_id: int, end_key: String, opening_kind: String) -> Dictionary:
	for opening_variant in openings:
		var opening_report: Dictionary = opening_variant
		if int(opening_report.get("source_corridor_id", -1)) != corridor_id:
			continue
		if str(opening_report.get("source_end", "")) != end_key:
			continue
		if str(opening_report.get("opening_kind", "")) != opening_kind:
			continue
		return opening_report
	return {}

func _preferred_span(opening_report: Dictionary) -> Dictionary:
	if opening_report.is_empty():
		return {}
	var accepted_matches: Array = opening_report.get("accepted_matches", [])
	if not accepted_matches.is_empty():
		return accepted_matches[0]
	return opening_report.get("best_match", {})

func _resolve_host_edge_for_corridor(room: Dictionary, corridor_polygon: PackedVector2Array, preferred_hit: Dictionary) -> Dictionary:
	var polygon: PackedVector2Array = room.get("polygon", PackedVector2Array())
	var preferred_point: Vector2 = preferred_hit.get("point", room.get("center", Vector2.ZERO))
	var preferred_edge_index := int(preferred_hit.get("edge_index", -1))
	var best_valid: Dictionary = {}
	var best_rejected: Dictionary = {}
	for edge_index in polygon.size():
		var opening_data := {
			"point": preferred_point,
			"target_edge_index": edge_index,
			"corridor_polygon": corridor_polygon
		}
		var analysis: Dictionary = GeometryBuilderClass.inspect_wall_openings(polygon, [opening_data])
		var openings: Array = analysis.get("openings", [])
		if openings.is_empty():
			continue
		var opening_report: Dictionary = openings[0]
		var match: Dictionary = opening_report.get("best_match", {})
		var candidate := {
			"edge_index": edge_index,
			"edge_from": polygon[edge_index],
			"edge_to": polygon[(edge_index + 1) % polygon.size()],
			"span_length": float(opening_report.get("span_length", 0.0)),
			"corner_clearance": float(match.get("corner_clearance", 0.0)),
			"accepted": bool(opening_report.get("accepted", false)),
			"intersection_count": int(opening_report.get("intersection_count", 0)),
			"resolution_mode": "exact_span"
		}
		if candidate["accepted"]:
			if _is_better_host_edge_candidate(candidate, best_valid, preferred_edge_index):
				best_valid = candidate
		elif _is_better_host_edge_candidate(candidate, best_rejected, preferred_edge_index):
			best_rejected = candidate
	if not best_valid.is_empty():
		return best_valid
	if preferred_edge_index >= 0:
		return {
			"edge_index": preferred_edge_index,
			"edge_from": preferred_hit.get("edge_from", preferred_point),
			"edge_to": preferred_hit.get("edge_to", preferred_point),
			"resolution_mode": "ray_hit"
		}
	if not best_rejected.is_empty():
		best_rejected["resolution_mode"] = "exact_span_rejected"
		return best_rejected
	return {
		"edge_index": -1,
		"edge_from": preferred_point,
		"edge_to": preferred_point,
		"resolution_mode": "missing"
	}

func _is_better_host_edge_candidate(candidate: Dictionary, current_best: Dictionary, preferred_edge_index: int) -> bool:
	if current_best.is_empty():
		return true
	var candidate_accepted := bool(candidate.get("accepted", false))
	var best_accepted := bool(current_best.get("accepted", false))
	if candidate_accepted != best_accepted:
		return candidate_accepted
	var candidate_hits := int(candidate.get("intersection_count", 0))
	var best_hits := int(current_best.get("intersection_count", 0))
	if candidate_hits != best_hits:
		return candidate_hits > best_hits
	var candidate_span := float(candidate.get("span_length", 0.0))
	var best_span := float(current_best.get("span_length", 0.0))
	if abs(candidate_span - best_span) > 0.02:
		return candidate_span > best_span
	var candidate_clearance := float(candidate.get("corner_clearance", 0.0))
	var best_clearance := float(current_best.get("corner_clearance", 0.0))
	if abs(candidate_clearance - best_clearance) > 0.02:
		return candidate_clearance > best_clearance
	if int(candidate.get("edge_index", -1)) == preferred_edge_index and int(current_best.get("edge_index", -1)) != preferred_edge_index:
		return true
	return false

func _find_edge_report(analysis: Dictionary, edge_index: int) -> Dictionary:
	if edge_index < 0:
		return {}
	for edge_variant in analysis.get("edges", []):
		var edge_report: Dictionary = edge_variant
		if int(edge_report.get("edge_index", -1)) == edge_index:
			return edge_report
	return {}

func _ray_to_polygon(origin: Vector2, direction: Vector2, polygon: PackedVector2Array) -> Vector2:
	return _ray_to_polygon_hit(origin, direction, polygon).get("point", origin)

func _ray_to_polygon_hit(origin: Vector2, direction: Vector2, polygon: PackedVector2Array) -> Dictionary:
	var best := origin
	var best_t := INF
	var best_edge_index := -1
	var best_edge_from := origin
	var best_edge_to := origin
	var ray_end := origin + direction.normalized() * 200.0
	for index in polygon.size():
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index + 1) % polygon.size()]
		var hit: Variant = Geometry2D.segment_intersects_segment(origin, ray_end, a, b)
		if hit == null:
			continue
		var t := origin.distance_to(hit)
		if t < best_t:
			best_t = t
			best = hit
			best_edge_index = index
			best_edge_from = a
			best_edge_to = b
	return {
		"point": best,
		"edge_index": best_edge_index,
		"edge_from": best_edge_from,
		"edge_to": best_edge_to,
		"distance": best_t
	}

func _connection_key(a: int, b: int) -> String:
	return str(min(a, b), ":", max(a, b))
