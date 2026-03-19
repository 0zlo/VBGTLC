extends Node3D
class_name DoorNode

signal door_changed(door_id: int, is_open: bool, is_locked: bool)

var door_id := -1
var is_locked := false
var is_open := false
var target_angle := 0.0
var swing_sign := 1.0

var pivot: Node3D
var collision_shape: CollisionShape3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_door()

func setup(data: Dictionary) -> void:
	door_id = int(data.get("id", -1))
	global_position = data.get("position", Vector3.ZERO)
	rotation.y = float(data.get("yaw", 0.0))
	is_locked = bool(data.get("locked", false))
	is_open = bool(data.get("open", false))
	target_angle = deg_to_rad(88.0) if is_open else 0.0
	swing_sign = -1.0 if door_id % 2 == 0 else 1.0
	if pivot == null:
		_build_door()
	pivot.rotation.y = target_angle * swing_sign
	_update_collision_state()

func _build_door() -> void:
	if pivot != null:
		return
	pivot = Node3D.new()
	pivot.position = Vector3(-0.7, 0.0, 0.0)
	add_child(pivot)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	pivot.add_child(body)

	collision_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 2.5, 0.18)
	collision_shape.shape = box
	collision_shape.position = Vector3(0.7, 1.25, 0.0)
	body.add_child(collision_shape)

	var slab := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.4, 2.5, 0.16)
	slab.mesh = mesh
	slab.position = Vector3(0.7, 1.25, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.22, 0.25)
	material.emission_enabled = true
	material.emission = Color(0.07, 0.1, 0.14)
	material.roughness = 0.7
	slab.material_override = material
	pivot.add_child(slab)

	var strip := MeshInstance3D.new()
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(0.18, 0.18, 0.18)
	strip.mesh = strip_mesh
	strip.position = Vector3(1.16, 1.3, 0.0)
	var strip_material := StandardMaterial3D.new()
	strip_material.albedo_color = Color(0.89, 0.72, 0.25)
	strip_material.emission_enabled = true
	strip_material.emission = Color(0.4, 0.28, 0.06)
	strip.material_override = strip_material
	pivot.add_child(strip)

func _process(delta: float) -> void:
	if pivot == null:
		return
	pivot.rotation.y = lerp_angle(pivot.rotation.y, target_angle * swing_sign, delta * 7.5)
	_update_collision_state()

func interact(player) -> void:
	if is_open:
		return
	if is_locked:
		if not player.spend_key():
			return
		is_locked = false
		_open()
		player.emit_signal("notification", "Lock continuity reconciled.")
	else:
		_open()

func _open() -> void:
	is_open = true
	target_angle = deg_to_rad(88.0)
	emit_signal("door_changed", door_id, is_open, is_locked)

func _update_collision_state() -> void:
	if collision_shape == null:
		return
	collision_shape.disabled = abs(pivot.rotation.y) > deg_to_rad(52.0)

func get_prompt() -> String:
	if is_open:
		return "Door already reconciled"
	if is_locked:
		return "Press E to unlock door"
	return "Press E to open door"

func force_state(open_state: bool, locked_state: bool) -> void:
	is_open = open_state
	is_locked = locked_state
	target_angle = deg_to_rad(88.0) if is_open else 0.0
	if pivot:
		pivot.rotation.y = target_angle * swing_sign
	_update_collision_state()
