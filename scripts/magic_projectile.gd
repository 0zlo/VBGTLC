extends Area3D
class_name MagicProjectile

signal expired

var direction := Vector3.FORWARD
var speed := 17.0
var damage := 22.0
var lifetime := 2.8
var source: Node = null

var mesh_instance: MeshInstance3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 4
	monitoring = true
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_visuals()

func configure(origin: Vector3, fire_direction: Vector3, owner: Node) -> void:
	global_position = origin
	direction = fire_direction.normalized()
	source = owner
	look_at(origin + direction, Vector3.UP)
	if mesh_instance == null:
		_build_visuals()

func _build_visuals() -> void:
	if mesh_instance != null:
		return
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.22
	shape.shape = sphere
	add_child(shape)

	mesh_instance = MeshInstance3D.new()
	var orb := SphereMesh.new()
	orb.radius = 0.22
	orb.height = 0.44
	mesh_instance.mesh = orb
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.56, 0.92, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.21, 0.46, 0.62)
	material.roughness = 0.05
	mesh_instance.material_override = material
	add_child(mesh_instance)

func _physics_process(delta: float) -> void:
	var next_position := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next_position)
	query.exclude = [get_rid()]
	query.collision_mask = 1 | 4
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_apply_hit(hit.get("collider"), hit.get("position", next_position))
		return
	global_position = next_position
	lifetime -= delta
	if lifetime <= 0.0:
		emit_signal("expired")
		queue_free()

func _on_body_entered(body: Node) -> void:
	_apply_hit(body, global_position)

func _on_area_entered(area: Area3D) -> void:
	_apply_hit(area, global_position)

func _apply_hit(target: Variant, impact_position: Vector3) -> void:
	if target == source:
		return
	if target and target.has_method("apply_damage"):
		target.apply_damage(damage, source.global_position if source else impact_position)
	emit_signal("expired")
	queue_free()
