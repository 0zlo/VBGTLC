extends CharacterBody3D
class_name EnemyAgent

signal defeated(enemy_id: int)

const PATROL_SPEED := 2.6
const CHASE_SPEED := 4.3
const GRAVITY := 18.0

var enemy_id := -1
var room_id := -1
var patrol_points: Array = []
var patrol_index := 0
var player = null
var runtime: Node = null
var home_position := Vector3.ZERO
var attack_cooldown := 0.0
var health := 52.0
var max_health := 52.0
var state := "patrol"
var lost_timer := 0.0
var is_guard := false

var mesh_instance: MeshInstance3D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_body()

func setup(data: Dictionary, theme: Dictionary) -> void:
	enemy_id = int(data.get("id", -1))
	room_id = int(data.get("room_id", -1))
	patrol_points = data.get("patrol_points", [])
	home_position = data.get("position", Vector3.ZERO)
	global_position = home_position
	is_guard = bool(data.get("is_guard", false))
	max_health = 78.0 if is_guard else 52.0
	health = max_health
	if mesh_instance == null:
		_build_body()
	_apply_theme(theme)

func bind(player_ref, runtime_ref: Node) -> void:
	player = player_ref
	runtime = runtime_ref

func _build_body() -> void:
	if mesh_instance != null:
		return
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.25
	collider.shape = capsule
	collider.position = Vector3(0.0, 0.92, 0.0)
	add_child(collider)

	mesh_instance = MeshInstance3D.new()
	var body := PrismMesh.new()
	body.size = Vector3(0.9, 1.7, 0.9)
	body.left_to_right = 0.2
	mesh_instance.mesh = body
	mesh_instance.position = Vector3(0.0, 1.0, 0.0)
	add_child(mesh_instance)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.34
	sphere.height = 0.68
	head.mesh = sphere
	head.position = Vector3(0.0, 1.95, 0.0)
	add_child(head)

func _apply_theme(theme: Dictionary) -> void:
	var material := StandardMaterial3D.new()
	var base: Color = theme.get("albedo", Color(0.8, 0.5, 0.3))
	material.albedo_color = base.lerp(Color(0.14, 0.0, 0.0), 0.2 if is_guard else 0.08)
	material.emission_enabled = true
	material.emission = theme.get("emission", base) * (0.18 if is_guard else 0.08)
	material.roughness = 0.82
	mesh_instance.material_override = material

func _physics_process(delta: float) -> void:
	if player == null:
		return
	attack_cooldown = max(attack_cooldown - delta, 0.0)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = max(velocity.y, -0.1)

	var distance_to_player := global_position.distance_to(player.global_position)
	var has_sight := distance_to_player < 16.0 and _has_sight_to_player()
	if has_sight:
		state = "chase"
		lost_timer = 0.0
	else:
		lost_timer += delta
		if state == "chase" and lost_timer > 3.0:
			state = "return"

	match state:
		"chase":
			_chase_player(distance_to_player)
		"return":
			_move_towards(home_position, PATROL_SPEED, delta)
			if global_position.distance_to(home_position) < 1.2:
				state = "patrol"
		_:
			_patrol(delta)

	move_and_slide()

func _patrol(delta: float) -> void:
	if patrol_points.is_empty():
		_move_towards(home_position, PATROL_SPEED, delta)
		return
	var target: Vector3 = patrol_points[patrol_index]
	_move_towards(target, PATROL_SPEED, delta)
	if global_position.distance_to(target) < 1.0:
		patrol_index = (patrol_index + 1) % patrol_points.size()

func _chase_player(distance_to_player: float) -> void:
	if distance_to_player < 1.55 and attack_cooldown <= 0.0:
		attack_cooldown = 1.1 if is_guard else 1.35
		player.apply_damage(18.0 if is_guard else 11.0, global_position)
	_move_towards(player.global_position, CHASE_SPEED, 0.0)

func _move_towards(target: Vector3, speed: float, _delta: float) -> void:
	var direction := target - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * get_physics_process_delta_time())
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * get_physics_process_delta_time())
		return
	direction = direction.normalized()
	look_at(global_position + direction, Vector3.UP)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

func _has_sight_to_player() -> bool:
	if runtime and runtime.has_method("has_line_of_sight"):
		return runtime.has_line_of_sight(global_position + Vector3.UP * 1.3, player.global_position + Vector3.UP * 1.3)
	return true

func apply_damage(amount: float, _from_position := Vector3.ZERO) -> void:
	health -= amount
	if health <= 0.0:
		health = 0.0
		emit_signal("defeated", enemy_id)
		queue_free()
	else:
		state = "chase"
		lost_timer = 0.0
