extends Area3D
class_name PickupNode

signal picked_up(pickup_id: int, kind: String, amount: int)

var pickup_id := -1
var kind := "tonic"
var amount := 1
var float_phase := 0.0

var mesh_instance: MeshInstance3D

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_visuals()

func setup(data: Dictionary) -> void:
	pickup_id = int(data.get("id", -1))
	kind = str(data.get("kind", "tonic"))
	amount = int(data.get("amount", 1))
	global_position = data.get("position", Vector3.ZERO)
	if mesh_instance == null:
		_build_visuals()
	_update_visual_style()

func _build_visuals() -> void:
	if mesh_instance != null:
		return
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	shape.shape = sphere
	add_child(shape)

	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	_update_visual_style()

func _process(delta: float) -> void:
	float_phase += delta
	rotation.y += delta * 1.6
	if mesh_instance:
		mesh_instance.position.y = 0.18 + sin(float_phase * 2.2) * 0.12

func _update_visual_style() -> void:
	if mesh_instance == null:
		return
	var material := StandardMaterial3D.new()
	material.emission_enabled = true
	material.roughness = 0.3
	match kind:
		"key":
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.18
			mesh.bottom_radius = 0.12
			mesh.height = 0.95
			mesh_instance.mesh = mesh
			material.albedo_color = Color(0.97, 0.77, 0.22)
			material.emission = Color(0.52, 0.37, 0.07)
		"aether":
			var gem := PrismMesh.new()
			gem.left_to_right = 0.5
			gem.size = Vector3(0.34, 0.62, 0.34)
			mesh_instance.mesh = gem
			material.albedo_color = Color(0.36, 0.83, 1.0)
			material.emission = Color(0.13, 0.41, 0.58)
		_:
			var box := BoxMesh.new()
			box.size = Vector3(0.34, 0.5, 0.34)
			mesh_instance.mesh = box
			material.albedo_color = Color(0.86, 0.28, 0.33)
			material.emission = Color(0.34, 0.08, 0.12)
	mesh_instance.material_override = material

func interact(player) -> void:
	player.add_pickup(kind, amount)
	emit_signal("picked_up", pickup_id, kind, amount)
	queue_free()

func get_prompt() -> String:
	match kind:
		"key":
			return "Press E to collect authorization key"
		"aether":
			return "Press E to collect aether charge"
		_:
			return "Press E to collect tonic"
