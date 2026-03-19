extends CharacterBody3D
class_name PlayerController

signal request_projectile(origin: Vector3, direction: Vector3)
signal stats_changed
signal died
signal notification(message: String)

const WALK_SPEED := 5.4
const SPRINT_SPEED := 8.2
const JUMP_VELOCITY := 5.2
const LOOK_SENSITIVITY := 0.0026
const MELEE_RANGE := 2.0
const MELEE_COST := 18.0
const MAGIC_COST := 15.0
const GRAVITY := 18.0
const GOD_SPEED := 15.5

var max_health := 100.0
var health := 100.0
var max_stamina := 100.0
var stamina := 100.0
var max_mana := 60.0
var mana := 60.0
var tonics := 1
var aether := 1
var keys := 0
var god_mode := false

var yaw := 0.0
var pitch := 0.0
var input_enabled := true
var melee_cooldown := 0.0
var magic_cooldown := 0.0
var status_clock := 0.0
var damage_flash := 0.0
var current_focus_target: Node = null

var camera: Camera3D
var interaction_ray: RayCast3D
var body_mesh: MeshInstance3D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.42
	safe_margin = 0.02
	_process_mode_setup()
	_build_body()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	emit_signal("stats_changed")

func _process_mode_setup() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _build_body() -> void:
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.35
	collider.shape = capsule
	collider.position = Vector3(0.0, 0.95, 0.0)
	add_child(collider)

	body_mesh = MeshInstance3D.new()
	var body_shape := CapsuleMesh.new()
	body_shape.radius = 0.38
	body_shape.mid_height = 0.95
	body_mesh.mesh = body_shape
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.17, 0.19, 0.21, 0.0)
	body_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body_mesh.material_override = body_material
	body_mesh.visible = false
	body_mesh.position = Vector3(0.0, 0.95, 0.0)
	add_child(body_mesh)

	camera = Camera3D.new()
	camera.current = true
	camera.position = Vector3(0.0, 1.62, 0.0)
	camera.fov = 82.0
	add_child(camera)

	interaction_ray = RayCast3D.new()
	interaction_ray.target_position = Vector3(0.0, 0.0, -4.0)
	interaction_ray.collide_with_areas = true
	interaction_ray.collide_with_bodies = true
	interaction_ray.collision_mask = 1 | 4 | 8 | 16
	camera.add_child(interaction_ray)

func _input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * LOOK_SENSITIVITY
		pitch = clamp(pitch - event.relative.y * LOOK_SENSITIVITY, -1.35, 1.35)
		rotation.y = yaw
		camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
	if not input_enabled:
		velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
		move_and_slide()
		return

	melee_cooldown = max(melee_cooldown - delta, 0.0)
	magic_cooldown = max(magic_cooldown - delta, 0.0)
	status_clock += delta
	damage_flash = max(damage_flash - delta * 1.6, 0.0)
	if god_mode:
		health = max_health
		stamina = max_stamina
		mana = max_mana
		_process_god_mode_movement(delta)
		if Input.is_action_just_pressed("attack_melee"):
			_perform_melee()
		if Input.is_action_just_pressed("attack_magic"):
			_cast_magic()
		if Input.is_action_just_pressed("interact"):
			var god_target := get_focus_target()
			if god_target and god_target.has_method("interact"):
				god_target.interact(self)
		if Input.is_action_just_pressed("use_tonic"):
			use_tonic()
		if Input.is_action_just_pressed("use_aether"):
			use_aether_charge()
		emit_signal("stats_changed")
		return

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var is_sprinting := Input.is_action_pressed("sprint") and input_vector.length() > 0.2 and stamina > 6.0 and is_on_floor()
	var target_speed := SPRINT_SPEED if is_sprinting else WALK_SPEED
	if is_sprinting:
		stamina = max(stamina - 26.0 * delta, 0.0)
	else:
		stamina = min(stamina + 22.0 * delta, max_stamina)
	mana = min(mana + 8.0 * delta, max_mana)

	if direction != Vector3.ZERO:
		velocity.x = direction.x * target_speed
		velocity.z = direction.z * target_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = max(velocity.y, -0.1)
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY

	if Input.is_action_just_pressed("attack_melee"):
		_perform_melee()
	if Input.is_action_just_pressed("attack_magic"):
		_cast_magic()
	if Input.is_action_just_pressed("interact"):
		var target := get_focus_target()
		if target and target.has_method("interact"):
			target.interact(self)
	if Input.is_action_just_pressed("use_tonic"):
		use_tonic()
	if Input.is_action_just_pressed("use_aether"):
		use_aether_charge()

	move_and_slide()
	emit_signal("stats_changed")

func _process(_delta: float) -> void:
	current_focus_target = get_focus_target()

func _perform_melee() -> void:
	if melee_cooldown > 0.0:
		return
	if not god_mode and stamina < MELEE_COST:
		return
	if not god_mode:
		stamina -= MELEE_COST
	melee_cooldown = 0.48
	var shape := SphereShape3D.new()
	shape.radius = 0.9
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 4
	query.exclude = [get_rid()]
	var origin := camera.global_transform.origin + (-camera.global_basis.z * 1.45)
	query.transform = Transform3D(Basis.IDENTITY, origin)
	var hits := get_world_3d().direct_space_state.intersect_shape(query, 8)
	var dealt := false
	for hit in hits:
		var collider = hit.get("collider")
		if collider and collider.has_method("apply_damage"):
			collider.apply_damage(28.0, global_transform.origin)
			dealt = true
	if dealt:
		emit_signal("notification", "Structural correction applied.")
	else:
		emit_signal("notification", "No meaningful deviation detected.")

func _cast_magic() -> void:
	if magic_cooldown > 0.0:
		return
	if not god_mode and mana < MAGIC_COST:
		return
	if not god_mode:
		mana -= MAGIC_COST
	magic_cooldown = 0.36
	var direction := -camera.global_basis.z.normalized()
	var origin := camera.global_transform.origin + direction * 0.7
	emit_signal("request_projectile", origin, direction)
	emit_signal("notification", "Continuity pulse released.")

func get_focus_target() -> Node:
	if interaction_ray == null:
		return null
	interaction_ray.force_raycast_update()
	if not interaction_ray.is_colliding():
		return null
	var node: Node = interaction_ray.get_collider()
	while node != null:
		if node.has_method("interact") or node.has_method("get_prompt"):
			return node
		node = node.get_parent()
	return null

func get_prompt_text() -> String:
	if current_focus_target and current_focus_target.has_method("get_prompt"):
		return str(current_focus_target.get_prompt())
	return ""

func apply_player_state(state: Dictionary, inventory: Dictionary) -> void:
	global_position = _vec3_from_array(state.get("position", [0.0, 1.75, 0.0]))
	yaw = float(state.get("yaw", 0.0))
	pitch = float(state.get("pitch", 0.0))
	rotation.y = yaw
	camera.rotation.x = pitch
	max_health = float(state.get("max_health", 100.0))
	health = float(state.get("health", max_health))
	max_stamina = float(state.get("max_stamina", 100.0))
	stamina = float(state.get("stamina", max_stamina))
	max_mana = float(state.get("max_mana", 60.0))
	mana = float(state.get("mana", max_mana))
	keys = int(inventory.get("keys", int(state.get("keys", 0))))
	tonics = int(inventory.get("tonics", int(state.get("tonics", 1))))
	aether = int(inventory.get("aether", int(state.get("aether", 1))))
	emit_signal("stats_changed")

func export_player_state() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"yaw": yaw,
		"pitch": pitch,
		"health": health,
		"max_health": max_health,
		"stamina": stamina,
		"max_stamina": max_stamina,
		"mana": mana,
		"max_mana": max_mana,
		"keys": keys,
		"tonics": tonics,
		"aether": aether
	}

func get_inventory_state() -> Dictionary:
	return {
		"keys": keys,
		"tonics": tonics,
		"aether": aether
	}

func add_pickup(kind: String, amount: int) -> void:
	match kind:
		"key":
			keys += amount
			_emit_pickup_notice("Key authorization appended.")
		"tonic":
			tonics += amount
			_emit_pickup_notice("Tonic reserve increased.")
		"aether":
			aether += amount
			_emit_pickup_notice("Aether charge acquired.")
	emit_signal("stats_changed")

func spend_key() -> bool:
	if keys <= 0:
		emit_signal("notification", "Authorization key required.")
		return false
	keys -= 1
	emit_signal("stats_changed")
	return true

func use_tonic() -> void:
	if tonics <= 0:
		emit_signal("notification", "No tonic reserve available.")
		return
	if health >= max_health - 1.0:
		emit_signal("notification", "Health buffer already nominal.")
		return
	tonics -= 1
	health = min(health + 46.0, max_health)
	emit_signal("stats_changed")
	emit_signal("notification", "Integrity restored.")

func use_aether_charge() -> void:
	if aether <= 0:
		emit_signal("notification", "Aether reserve exhausted.")
		return
	if mana >= max_mana - 1.0:
		emit_signal("notification", "Mana lattice already stable.")
		return
	aether -= 1
	mana = min(mana + 34.0, max_mana)
	emit_signal("stats_changed")
	emit_signal("notification", "Mana lattice replenished.")

func apply_damage(amount: float, from_position := Vector3.ZERO) -> void:
	if god_mode:
		return
	health -= amount
	damage_flash = 1.0
	if from_position != Vector3.ZERO:
		var push := (global_position - from_position).normalized()
		velocity += push * 1.8
	if health <= 0.0:
		health = 0.0
		emit_signal("stats_changed")
		emit_signal("died")
	else:
		emit_signal("stats_changed")
		emit_signal("notification", "Integrity compromised.")

func set_gameplay_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func toggle_god_mode() -> void:
	god_mode = not god_mode
	if god_mode:
		collision_layer = 0
		collision_mask = 0
		velocity = Vector3.ZERO
		health = max_health
		stamina = max_stamina
		mana = max_mana
		emit_signal("notification", "Godmode enabled. No meaningful damage detected.")
	else:
		collision_layer = 2
		collision_mask = 1 | 4
		velocity = Vector3.ZERO
		emit_signal("notification", "Godmode disabled. Structural liability restored.")
	emit_signal("stats_changed")

func _process_god_mode_movement(delta: float) -> void:
	var planar_input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var camera_basis := camera.global_basis
	var flat_forward := -camera_basis.z
	var flat_right := camera_basis.x
	var vertical_axis := 0.0
	if Input.is_action_pressed("jump"):
		vertical_axis += 1.0
	if Input.is_action_pressed("sprint"):
		vertical_axis -= 1.0
	var move_direction := flat_right * planar_input.x + flat_forward * planar_input.y + Vector3.UP * vertical_axis
	if move_direction.length_squared() > 0.001:
		global_position += move_direction.normalized() * GOD_SPEED * delta

func _vec3_from_array(raw: Variant) -> Vector3:
	if raw is Array and raw.size() >= 3:
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3.ZERO

func _emit_pickup_notice(message: String) -> void:
	emit_signal("notification", message)
