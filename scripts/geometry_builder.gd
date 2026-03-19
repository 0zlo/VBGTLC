extends RefCounted
class_name GeometryBuilder

static func polygon_centroid(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO
	var area := 0.0
	var centroid := Vector2.ZERO
	for index in polygon.size():
		var current: Vector2 = polygon[index]
		var next: Vector2 = polygon[(index + 1) % polygon.size()]
		var factor := current.cross(next)
		area += factor
		centroid += (current + next) * factor
	if abs(area) < 0.001:
		var fallback := Vector2.ZERO
		for point in polygon:
			fallback += point
		return fallback / float(max(polygon.size(), 1))
	return centroid / (3.0 * area)

static func ensure_ccw(polygon: PackedVector2Array) -> PackedVector2Array:
	if signed_area(polygon) >= 0.0:
		return polygon
	var reversed := PackedVector2Array()
	for index in range(polygon.size() - 1, -1, -1):
		reversed.append(polygon[index])
	return reversed

static func signed_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index in polygon.size():
		var current: Vector2 = polygon[index]
		var next: Vector2 = polygon[(index + 1) % polygon.size()]
		area += current.cross(next)
	return area * 0.5

static func scale_polygon(polygon: PackedVector2Array, factor: float, center: Vector2 = Vector2.INF) -> PackedVector2Array:
	var pivot: Vector2 = center
	if pivot == Vector2.INF:
		pivot = polygon_centroid(polygon)
	var scaled := PackedVector2Array()
	for point in polygon:
		scaled.append(pivot + (point - pivot) * factor)
	return scaled

static func make_theme_material(theme: Dictionary, brightness: float = 1.0, emission_boost: float = 0.0) -> StandardMaterial3D:
	var base_color: Color = theme.get("albedo", Color(0.55, 0.58, 0.62))
	if brightness < 1.0:
		base_color = base_color.lerp(Color(0.06, 0.07, 0.08), clamp(1.0 - brightness, 0.0, 1.0))
	else:
		base_color = base_color.lerp(Color(1.0, 1.0, 1.0), clamp(brightness - 1.0, 0.0, 0.35))
	var material := StandardMaterial3D.new()
	material.albedo_color = base_color
	material.roughness = 0.92
	material.metallic = theme.get("metallic", 0.08)
	material.vertex_color_use_as_albedo = false
	material.emission_enabled = true
	material.emission = theme.get("emission", base_color) * (0.05 + emission_boost)
	return material

static func build_area_node(area: Dictionary, theme: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.name = str(area.get("name", "Area"), "_", area.get("id", 0))
	var mesh := build_area_mesh(area)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = make_theme_material(theme, area.get("brightness", 1.0), area.get("emission_boost", 0.0))
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.add_child(mesh_instance)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	collider.shape = mesh.create_trimesh_shape()
	body.add_child(collider)
	node.add_child(body)
	return node

static func build_area_mesh(area: Dictionary) -> ArrayMesh:
	var polygon: PackedVector2Array = ensure_ccw(area.get("polygon", PackedVector2Array()))
	var mesh := ArrayMesh.new()
	if polygon.size() < 3:
		return mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_floor(st, polygon, area)
	_add_ceiling(st, polygon, area)
	_add_walls(st, polygon, area)
	return st.commit()

static func area_floor_height(area: Dictionary, point: Vector2) -> float:
	var base_y := float(area.get("base_y", 0.0))
	var mode := str(area.get("height_mode", "flat"))
	if mode == "corridor":
		var start: Vector2 = area.get("height_start", point)
		var end: Vector2 = area.get("height_end", point)
		var axis := end - start
		var length_squared := axis.length_squared()
		if length_squared > 0.001:
			var t: float = clamp((point - start).dot(axis) / length_squared, 0.0, 1.0)
			return lerp(float(area.get("start_y", base_y)), float(area.get("end_y", base_y)), t)
	var slope := float(area.get("slope", 0.0))
	if abs(slope) > 0.0001:
		var slope_axis: Vector2 = area.get("slope_axis", Vector2.RIGHT)
		var polygon: PackedVector2Array = area.get("polygon", PackedVector2Array())
		var center: Vector2 = area.get("center", polygon_centroid(polygon))
		if slope_axis.length_squared() > 0.001:
			return base_y + slope_axis.normalized().dot(point - center) * slope
	return base_y

static func _add_floor(st: SurfaceTool, polygon: PackedVector2Array, area: Dictionary) -> void:
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	for offset in range(0, indices.size(), 3):
		var a := _point3(polygon[indices[offset]], area_floor_height(area, polygon[indices[offset]]))
		var b := _point3(polygon[indices[offset + 1]], area_floor_height(area, polygon[indices[offset + 1]]))
		var c := _point3(polygon[indices[offset + 2]], area_floor_height(area, polygon[indices[offset + 2]]))
		_add_triangle(st, a, b, c)

static func _add_ceiling(st: SurfaceTool, polygon: PackedVector2Array, area: Dictionary) -> void:
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	var ceiling_height := float(area.get("ceiling_height", 4.4))
	for offset in range(0, indices.size(), 3):
		var c := _point3(polygon[indices[offset]], area_floor_height(area, polygon[indices[offset]]) + ceiling_height)
		var b := _point3(polygon[indices[offset + 1]], area_floor_height(area, polygon[indices[offset + 1]]) + ceiling_height)
		var a := _point3(polygon[indices[offset + 2]], area_floor_height(area, polygon[indices[offset + 2]]) + ceiling_height)
		_add_triangle(st, a, b, c)

static func _add_walls(st: SurfaceTool, polygon: PackedVector2Array, area: Dictionary) -> void:
	var ceiling_height := float(area.get("ceiling_height", 4.4))
	for index in polygon.size():
		var point_a: Vector2 = polygon[index]
		var point_b: Vector2 = polygon[(index + 1) % polygon.size()]
		var floor_a := area_floor_height(area, point_a)
		var floor_b := area_floor_height(area, point_b)
		var a0 := _point3(point_a, floor_a)
		var a1 := _point3(point_a, floor_a + ceiling_height)
		var b0 := _point3(point_b, floor_b)
		var b1 := _point3(point_b, floor_b + ceiling_height)
		_add_triangle(st, a0, a1, b1)
		_add_triangle(st, a0, b1, b0)

static func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var uv_a := Vector2(a.x, a.z) * 0.12
	var uv_b := Vector2(b.x, b.z) * 0.12
	var uv_c := Vector2(c.x, c.z) * 0.12
	st.set_normal(normal)
	st.set_uv(uv_a)
	st.add_vertex(a)
	st.set_normal(normal)
	st.set_uv(uv_b)
	st.add_vertex(b)
	st.set_normal(normal)
	st.set_uv(uv_c)
	st.add_vertex(c)

static func _point3(point: Vector2, y: float) -> Vector3:
	return Vector3(point.x, y, point.y)
