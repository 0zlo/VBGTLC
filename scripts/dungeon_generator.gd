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
	var start_point := _ray_to_polygon(room_a["center"], direction, room_a["polygon"])
	var end_point := _ray_to_polygon(room_b["center"], -direction, room_b["polygon"])
	var width: float = rng.randf_range(2.6, 3.6)
	var inset: float = min(width * 0.28, 0.6)
	start_point -= direction * inset
	end_point += direction * inset
	var perp := Vector2(-direction.y, direction.x) * width * 0.5
	var polygon := PackedVector2Array([
		start_point + perp,
		start_point - perp,
		end_point - perp,
		end_point + perp
	])
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
		"start_anchor": start_point,
		"end_anchor": end_point,
		"wall_openings": [
			{
				"point": start_point,
				"width": width + 1.0
			},
			{
				"point": end_point,
				"width": width + 1.0
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
		_append_room_opening(rooms, int(corridor["room_a"]), corridor["start_anchor"], float(corridor["width"]) + 0.9)
		_append_room_opening(rooms, int(corridor["room_b"]), corridor["end_anchor"], float(corridor["width"]) + 0.9)

func _append_room_opening(rooms: Array, room_id: int, point: Vector2, width: float) -> void:
	var room := _find_room(rooms, room_id)
	if room.is_empty():
		return
	if not room.has("wall_openings"):
		room["wall_openings"] = []
	room["wall_openings"].append({
		"point": point,
		"width": width
	})

func _ray_to_polygon(origin: Vector2, direction: Vector2, polygon: PackedVector2Array) -> Vector2:
	var best := origin
	var best_t := INF
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
	return best

func _connection_key(a: int, b: int) -> String:
	return str(min(a, b), ":", max(a, b))
