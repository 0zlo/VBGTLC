extends Node3D
class_name DungeonRuntime

const GeometryBuilderClass = preload("res://scripts/geometry_builder.gd")
const DoorNodeClass = preload("res://scripts/door_node.gd")
const PickupNodeClass = preload("res://scripts/pickup_node.gd")
const EnemyAgentClass = preload("res://scripts/enemy_agent.gd")
const InteractionTerminalClass = preload("res://scripts/interaction_terminal.gd")
const CorridorJoinDebugViewClass = preload("res://scripts/corridor_join_debug_view.gd")

signal run_state_changed
signal goal_activated
signal notification(message: String)

var layout: Dictionary = {}
var run_state: Dictionary = {}
var player = null

var geometry_root: Node3D
var entities_root: Node3D
var props_root: Node3D
var debug_root: Node3D

var doors: Dictionary = {}
var current_room_id := -1
var current_corridor_id := -1
var join_debug_visible := false
var join_debug_view = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_ensure_roots()

func setup(new_layout: Dictionary, state: Dictionary) -> void:
	layout = new_layout
	run_state = state
	_ensure_roots()
	_ensure_state_arrays()
	_rebuild()

func bind_player(player_ref) -> void:
	_ensure_roots()
	player = player_ref
	for child in entities_root.get_children():
		if child.has_method("bind"):
			child.bind(player, self)
	_discover_entry_area()

func get_spawn_position() -> Vector3:
	return layout.get("entry_spawn", Vector3(0.0, 1.8, 0.0))

func has_line_of_sight(from_position: Vector3, to_position: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from_position, to_position)
	query.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()

func update_discovery(player_position: Vector3) -> void:
	var point2 := Vector2(player_position.x, player_position.z)
	for room in layout.get("rooms", []):
		if Geometry2D.is_point_in_polygon(point2, room.get("polygon", PackedVector2Array())):
			if current_room_id != int(room["id"]):
				current_room_id = int(room["id"])
				GameState.add_unique_int(run_state["discovered_rooms"], current_room_id)
				run_state["last_status"] = "room %02d geometry integrity nominal" % current_room_id
				emit_signal("run_state_changed")
			break
	for corridor in layout.get("corridors", []):
		if Geometry2D.is_point_in_polygon(point2, corridor.get("polygon", PackedVector2Array())):
			if current_corridor_id != int(corridor["id"]):
				current_corridor_id = int(corridor["id"])
				GameState.add_unique_int(run_state["discovered_corridors"], current_corridor_id)
				emit_signal("run_state_changed")
			break

func _ensure_roots() -> void:
	if geometry_root == null:
		geometry_root = Node3D.new()
		geometry_root.name = "Geometry"
		add_child(geometry_root)
	if entities_root == null:
		entities_root = Node3D.new()
		entities_root.name = "Entities"
		add_child(entities_root)
	if props_root == null:
		props_root = Node3D.new()
		props_root.name = "Props"
		add_child(props_root)
	if debug_root == null:
		debug_root = Node3D.new()
		debug_root.name = "Debug"
		add_child(debug_root)

func _ensure_state_arrays() -> void:
	for key in ["discovered_rooms", "discovered_corridors", "opened_doors", "unlocked_doors", "collected_pickups", "defeated_enemies"]:
		if not run_state.has(key):
			run_state[key] = []

func _rebuild() -> void:
	for child in geometry_root.get_children():
		child.queue_free()
	for child in entities_root.get_children():
		child.queue_free()
	for child in props_root.get_children():
		child.queue_free()
	for child in debug_root.get_children():
		child.queue_free()
	doors.clear()
	join_debug_view = null
	_build_rooms()
	_build_corridors()
	_build_doors()
	_build_pickups()
	_build_enemies()
	_build_goal_terminal()
	_build_join_debug_view()

func _build_rooms() -> void:
	for room in layout.get("rooms", []):
		var theme := _theme(room.get("theme_id", "integrity"))
		geometry_root.add_child(GeometryBuilderClass.build_area_node(room, theme))
		if not room.get("platform", {}).is_empty():
			geometry_root.add_child(GeometryBuilderClass.build_area_node(room["platform"], theme))
		if not room.get("ramp", {}).is_empty():
			geometry_root.add_child(GeometryBuilderClass.build_area_node(room["ramp"], theme))
		_add_room_light(room, theme)

func _build_corridors() -> void:
	for corridor in layout.get("corridors", []):
		var theme := _theme(corridor.get("theme_id", "integrity"))
		geometry_root.add_child(GeometryBuilderClass.build_area_node(corridor, theme))

func _build_doors() -> void:
	for door_data in layout.get("doors", []):
		var door := DoorNodeClass.new()
		var merged_data: Dictionary = door_data.duplicate(true)
		if run_state["opened_doors"].has(int(door_data["id"])):
			merged_data["open"] = true
		if run_state["unlocked_doors"].has(int(door_data["id"])):
			merged_data["locked"] = false
		door.setup(merged_data)
		door.door_changed.connect(_on_door_changed)
		entities_root.add_child(door)
		doors[int(door_data["id"])] = door

func _build_pickups() -> void:
	for pickup_data in layout.get("pickups", []):
		if run_state["collected_pickups"].has(int(pickup_data["id"])):
			continue
		var pickup := PickupNodeClass.new()
		pickup.setup(pickup_data)
		pickup.picked_up.connect(_on_pickup_collected)
		entities_root.add_child(pickup)

func _build_enemies() -> void:
	for enemy_data in layout.get("enemies", []):
		if run_state["defeated_enemies"].has(int(enemy_data["id"])):
			continue
		var enemy := EnemyAgentClass.new()
		enemy.setup(enemy_data, _theme(enemy_data.get("theme_id", "integrity")))
		enemy.bind(player, self)
		enemy.defeated.connect(_on_enemy_defeated)
		entities_root.add_child(enemy)

func _build_goal_terminal() -> void:
	var goal_data: Dictionary = layout.get("goal_terminal", {})
	if goal_data.is_empty():
		return
	var terminal := InteractionTerminalClass.new()
	terminal.global_position = goal_data.get("position", Vector3.ZERO)
	terminal.configure(
		"goal_terminal",
		"Press E to stabilize the vault and return",
		"state continuity preserved",
		Color(0.58, 0.92, 0.67)
	)
	terminal.activated.connect(_on_terminal_activated)
	props_root.add_child(terminal)

	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 0.8
	pedestal_mesh.bottom_radius = 1.1
	pedestal_mesh.height = 0.8
	pedestal.mesh = pedestal_mesh
	pedestal.global_position = goal_data.get("position", Vector3.ZERO) - Vector3(0.0, 0.35, 0.0)
	var pedestal_material := StandardMaterial3D.new()
	pedestal_material.albedo_color = Color(0.24, 0.32, 0.26)
	pedestal_material.roughness = 0.88
	pedestal.material_override = pedestal_material
	props_root.add_child(pedestal)

func _build_join_debug_view() -> void:
	var debug_data: Dictionary = layout.get("debug", {})
	if debug_data.is_empty():
		return
	join_debug_view = CorridorJoinDebugViewClass.new()
	join_debug_view.name = "CorridorJoinDebug"
	join_debug_view.setup(layout)
	join_debug_view.visible = join_debug_visible
	debug_root.add_child(join_debug_view)

func _add_room_light(room: Dictionary, theme: Dictionary) -> void:
	var light := OmniLight3D.new()
	light.omni_range = 14.0
	light.light_energy = 1.1 if str(room.get("kind", "room")) == "goal" else 0.75
	light.light_color = theme.get("map", Color(0.7, 0.8, 0.9))
	light.position = Vector3(room["center"].x, float(room["base_y"]) + float(room.get("ceiling_height", 4.4)) - 0.6, room["center"].y)
	props_root.add_child(light)

func _theme(theme_id: String) -> Dictionary:
	return layout.get("themes", {}).get(theme_id, layout.get("themes", {}).get("integrity", {}))

func set_join_debug_visible(enabled: bool) -> void:
	join_debug_visible = enabled
	if join_debug_view:
		join_debug_view.visible = enabled

func get_join_debug_data() -> Dictionary:
	return layout.get("debug", {})

func _on_pickup_collected(pickup_id: int, _kind: String, _amount: int) -> void:
	GameState.add_unique_int(run_state["collected_pickups"], pickup_id)
	run_state["last_status"] = "resource transfer acknowledged"
	emit_signal("run_state_changed")

func _on_enemy_defeated(enemy_id: int) -> void:
	GameState.add_unique_int(run_state["defeated_enemies"], enemy_id)
	run_state["last_status"] = "hostile geometry deprecated"
	emit_signal("run_state_changed")

func _on_door_changed(door_id: int, is_open: bool, is_locked: bool) -> void:
	if is_open:
		GameState.add_unique_int(run_state["opened_doors"], door_id)
	if not is_locked:
		GameState.add_unique_int(run_state["unlocked_doors"], door_id)
	run_state["last_status"] = "access continuity preserved"
	emit_signal("run_state_changed")

func _on_terminal_activated(_terminal_id: String) -> void:
	run_state["goal_reached"] = true
	run_state["last_status"] = "vault loaded correctly"
	emit_signal("run_state_changed")
	emit_signal("goal_activated")

func _discover_entry_area() -> void:
	var entry_room := 0
	GameState.add_unique_int(run_state["discovered_rooms"], entry_room)
	emit_signal("run_state_changed")
