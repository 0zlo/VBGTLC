extends Control
class_name MiniMapControl

var layout: Dictionary = {}
var discovered_rooms: Array = []
var discovered_corridors: Array = []
var player_position := Vector3.ZERO
var player_yaw := 0.0
var show_full_map := true

func _ready() -> void:
	custom_minimum_size = Vector2(240.0, 240.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_layout(new_layout: Dictionary) -> void:
	layout = new_layout
	queue_redraw()

func set_discovery(room_ids: Array, corridor_ids: Array) -> void:
	discovered_rooms = room_ids.duplicate(true)
	discovered_corridors = corridor_ids.duplicate(true)
	queue_redraw()

func set_player_pose(position: Vector3, yaw: float) -> void:
	player_position = position
	player_yaw = yaw
	queue_redraw()

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.07, 0.78), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.29, 0.44, 0.52, 0.95), false, 2.0)
	if layout.is_empty():
		return
	var bounds := _calculate_bounds()
	var pad := 18.0
	var available := size - Vector2.ONE * pad * 2.0
	var layout_size := Vector2(max(bounds.size.x, 1.0), max(bounds.size.y, 1.0))
	var scale_factor: float = min(available.x / layout_size.x, available.y / layout_size.y)
	var offset: Vector2 = Vector2(pad, pad) - bounds.position * scale_factor + (available - layout_size * scale_factor) * 0.5

	for corridor in layout.get("corridors", []):
		var polygon := _transform_polygon(corridor.get("polygon", PackedVector2Array()), scale_factor, offset)
		var discovered := discovered_corridors.has(int(corridor.get("id", -1)))
		var color := _map_color(corridor.get("theme_id", "integrity"), discovered, 0.52)
		if show_full_map or discovered:
			draw_colored_polygon(polygon, color)

	for room in layout.get("rooms", []):
		var polygon := _transform_polygon(room.get("polygon", PackedVector2Array()), scale_factor, offset)
		var discovered := discovered_rooms.has(int(room.get("id", -1)))
		var color := _map_color(room.get("theme_id", "integrity"), discovered, 0.68)
		if show_full_map or discovered:
			draw_colored_polygon(polygon, color)
			draw_polyline(_closed_polyline(polygon), color.lightened(0.16), 1.8)

	var player_map: Vector2 = Vector2(player_position.x, player_position.z) * scale_factor + offset
	var forward := Vector2(sin(player_yaw), cos(player_yaw))
	var right := Vector2(forward.y, -forward.x)
	var arrow := PackedVector2Array([
		player_map + forward * 8.0,
		player_map - forward * 6.0 + right * 5.0,
		player_map - forward * 6.0 - right * 5.0
	])
	draw_colored_polygon(arrow, Color(1.0, 0.95, 0.87, 1.0))

func _calculate_bounds() -> Rect2:
	var first := true
	var min_point := Vector2.ZERO
	var max_point := Vector2.ZERO
	for room in layout.get("rooms", []):
		for point in room.get("polygon", PackedVector2Array()):
			if first:
				min_point = point
				max_point = point
				first = false
			else:
				min_point.x = min(min_point.x, point.x)
				min_point.y = min(min_point.y, point.y)
				max_point.x = max(max_point.x, point.x)
				max_point.y = max(max_point.y, point.y)
	for corridor in layout.get("corridors", []):
		for point in corridor.get("polygon", PackedVector2Array()):
			if first:
				min_point = point
				max_point = point
				first = false
			else:
				min_point.x = min(min_point.x, point.x)
				min_point.y = min(min_point.y, point.y)
				max_point.x = max(max_point.x, point.x)
				max_point.y = max(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)

func _transform_polygon(source: PackedVector2Array, scale_factor: float, offset: Vector2) -> PackedVector2Array:
	var transformed := PackedVector2Array()
	for point in source:
		transformed.append(point * scale_factor + offset)
	return transformed

func _closed_polyline(source: PackedVector2Array) -> PackedVector2Array:
	var line := PackedVector2Array(source)
	if not source.is_empty():
		line.append(source[0])
	return line

func _map_color(theme_id: String, discovered: bool, alpha: float) -> Color:
	var theme: Dictionary = layout.get("themes", {}).get(theme_id, {"map": Color(0.7, 0.8, 0.9)})
	var color: Color = theme.get("map", Color(0.7, 0.8, 0.9))
	if not discovered:
		color = color.darkened(0.64)
		alpha *= 0.46
	color.a = alpha
	return color
