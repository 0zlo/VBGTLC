extends Node3D
class_name CorridorJoinDebugView

const GeometryBuilderClass = preload("res://scripts/geometry_builder.gd")

const STATUS_COLORS := {
	"ok": Color(0.34, 0.9, 0.56, 0.95),
	"suspicious": Color(1.0, 0.77, 0.25, 1.0),
	"failed": Color(1.0, 0.32, 0.3, 1.0)
}
const ROOM_SPAN_COLOR := Color(0.33, 0.9, 1.0, 0.95)
const CORRIDOR_SPAN_COLOR := Color(0.62, 1.0, 0.53, 0.95)
const EDGE_COLOR := Color(0.76, 0.49, 1.0, 0.95)
const BEST_GUESS_EDGE_COLOR := Color(0.96, 0.6, 1.0, 0.8)
const PROJECTION_COLOR := Color(1.0, 0.96, 0.55, 0.78)
const ROOM_WALL_POINT_COLOR := Color(0.64, 0.94, 1.0, 1.0)
const ANCHOR_MARKER_SIZE := 0.38

var layout: Dictionary = {}

func setup(new_layout: Dictionary) -> void:
	layout = new_layout
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	if layout.is_empty():
		return
	var debug_data: Dictionary = layout.get("debug", {})
	if debug_data.is_empty():
		return

	var line_mesh := ImmediateMesh.new()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_draw_corridor_centerlines(line_mesh, debug_data)
	_draw_join_gizmos(line_mesh, debug_data)
	line_mesh.surface_end()

	var lines := MeshInstance3D.new()
	lines.name = "JoinDebugLines"
	lines.mesh = line_mesh
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lines.material_override = _make_line_material()
	add_child(lines)

func _make_line_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	return material

func _draw_corridor_centerlines(line_mesh: ImmediateMesh, debug_data: Dictionary) -> void:
	var status_by_corridor: Dictionary = {}
	for join_variant in debug_data.get("corridor_joins", []):
		var join: Dictionary = join_variant
		var corridor_id := int(join.get("corridor_id", -1))
		var join_status := str(join.get("status", "ok"))
		if not status_by_corridor.has(corridor_id) or _status_priority(join_status) > _status_priority(str(status_by_corridor[corridor_id])):
			status_by_corridor[corridor_id] = join_status
	for corridor_variant in layout.get("corridors", []):
		var corridor: Dictionary = corridor_variant
		var corridor_id := int(corridor.get("id", -1))
		var status := str(status_by_corridor.get(corridor_id, "ok"))
		var color: Color = STATUS_COLORS.get(status, STATUS_COLORS["ok"])
		var start_anchor: Vector2 = corridor.get("start_anchor", Vector2.ZERO)
		var end_anchor: Vector2 = corridor.get("end_anchor", Vector2.ZERO)
		var start := Vector3(start_anchor.x, float(corridor.get("start_y", 0.0)) + 0.18, start_anchor.y)
		var end := Vector3(end_anchor.x, float(corridor.get("end_y", 0.0)) + 0.18, end_anchor.y)
		_add_line(line_mesh, start, end, color)

func _draw_join_gizmos(line_mesh: ImmediateMesh, debug_data: Dictionary) -> void:
	var rooms_by_id := {}
	var corridors_by_id := {}
	for room_variant in layout.get("rooms", []):
		var room: Dictionary = room_variant
		rooms_by_id[int(room.get("id", -1))] = room
	for corridor_variant in layout.get("corridors", []):
		var corridor: Dictionary = corridor_variant
		corridors_by_id[int(corridor.get("id", -1))] = corridor

	for join_variant in debug_data.get("corridor_joins", []):
		var join: Dictionary = join_variant
		var room: Dictionary = rooms_by_id.get(int(join.get("connected_room_id", -1)), {})
		var corridor: Dictionary = corridors_by_id.get(int(join.get("corridor_id", -1)), {})
		var status := str(join.get("status", "ok"))
		var status_color: Color = STATUS_COLORS.get(status, STATUS_COLORS["ok"])
		var corridor_anchor_point: Vector2 = join.get("corridor_anchor_point", join.get("anchor_point", Vector2.ZERO))
		var room_wall_point: Vector2 = join.get("room_wall_point", corridor_anchor_point)
		var corridor_anchor_height := _anchor_height(corridor_anchor_point, corridor)
		var room_wall_height := _anchor_height(room_wall_point, room)
		var corridor_anchor := Vector3(corridor_anchor_point.x, corridor_anchor_height + 0.2, corridor_anchor_point.y)
		var room_anchor := Vector3(room_wall_point.x, room_wall_height + 0.26, room_wall_point.y)
		_draw_cross(line_mesh, corridor_anchor, ANCHOR_MARKER_SIZE, status_color)
		_draw_cross(line_mesh, room_anchor, ANCHOR_MARKER_SIZE * 0.62, ROOM_WALL_POINT_COLOR)
		if corridor_anchor.distance_to(room_anchor) > 0.04:
			_add_line(line_mesh, corridor_anchor, room_anchor, ROOM_WALL_POINT_COLOR)

		if status != "ok":
			_add_line(line_mesh, corridor_anchor, corridor_anchor + Vector3.UP * 1.7, status_color)

		var room_opening_report: Dictionary = join.get("room_opening_report", {})
		var accepted_room_matches: Array = room_opening_report.get("accepted_matches", [])
		if accepted_room_matches.is_empty():
			var inferred_edge: Dictionary = join.get("inferred_room_edge", {})
			if not inferred_edge.is_empty():
				_draw_match_edge(line_mesh, room, inferred_edge, BEST_GUESS_EDGE_COLOR, 0.14)
		else:
			for match_variant in accepted_room_matches:
				var match_report: Dictionary = match_variant
				_draw_match_edge(line_mesh, room, match_report, EDGE_COLOR, 0.14)

		var room_span: Dictionary = join.get("room_opening_span", {})
		if not room_span.is_empty():
			_draw_match_span(line_mesh, room, room_span, ROOM_SPAN_COLOR, 0.26)

		var corridor_span: Dictionary = join.get("corridor_opening_span", {})
		if not corridor_span.is_empty():
			_draw_match_span(line_mesh, corridor, corridor_span, CORRIDOR_SPAN_COLOR, 0.36)

		var inferred_edge: Dictionary = join.get("inferred_room_edge", {})
		if not inferred_edge.is_empty():
			var nearest_point: Vector2 = inferred_edge.get("nearest_point", room_wall_point)
			var projection_start := Vector3(room_wall_point.x, room_wall_height + 0.3, room_wall_point.y)
			var projection_end := Vector3(nearest_point.x, _area_height(room, nearest_point) + 0.3, nearest_point.y)
			if projection_start.distance_to(projection_end) > 0.06:
				_add_line(line_mesh, projection_start, projection_end, PROJECTION_COLOR)

func _draw_match_edge(line_mesh: ImmediateMesh, area: Dictionary, match_report: Dictionary, color: Color, y_offset: float) -> void:
	if area.is_empty():
		return
	var edge_from: Vector2 = match_report.get("edge_from", Vector2.ZERO)
	var edge_to: Vector2 = match_report.get("edge_to", Vector2.ZERO)
	var from_point := Vector3(edge_from.x, _area_height(area, edge_from) + y_offset, edge_from.y)
	var to_point := Vector3(edge_to.x, _area_height(area, edge_to) + y_offset, edge_to.y)
	_add_line(line_mesh, from_point, to_point, color)

func _draw_match_span(line_mesh: ImmediateMesh, area: Dictionary, match_report: Dictionary, color: Color, y_offset: float) -> void:
	if area.is_empty():
		return
	var span_from: Vector2 = match_report.get("span_from", Vector2.ZERO)
	var span_to: Vector2 = match_report.get("span_to", Vector2.ZERO)
	var from_point := Vector3(span_from.x, _area_height(area, span_from) + y_offset, span_from.y)
	var to_point := Vector3(span_to.x, _area_height(area, span_to) + y_offset, span_to.y)
	_add_line(line_mesh, from_point, to_point, color)

func _anchor_height(anchor: Vector2, area: Dictionary) -> float:
	return _area_height(area, anchor)

func _area_height(area: Dictionary, point: Vector2) -> float:
	if area.is_empty():
		return 0.0
	return GeometryBuilderClass.area_floor_height(area, point)

func _draw_cross(line_mesh: ImmediateMesh, center: Vector3, size: float, color: Color) -> void:
	_add_line(line_mesh, center + Vector3(-size, 0.0, 0.0), center + Vector3(size, 0.0, 0.0), color)
	_add_line(line_mesh, center + Vector3(0.0, 0.0, -size), center + Vector3(0.0, 0.0, size), color)
	_add_line(line_mesh, center + Vector3(0.0, -size * 0.45, 0.0), center + Vector3(0.0, size * 0.45, 0.0), color)

func _add_line(line_mesh: ImmediateMesh, from_point: Vector3, to_point: Vector3, color: Color) -> void:
	line_mesh.surface_set_color(color)
	line_mesh.surface_add_vertex(from_point)
	line_mesh.surface_set_color(color)
	line_mesh.surface_add_vertex(to_point)

func _status_priority(status: String) -> int:
	match status:
		"failed":
			return 2
		"suspicious":
			return 1
		_:
			return 0
