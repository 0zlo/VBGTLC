extends Area3D
class_name InteractionTerminal

signal activated(terminal_id: String)

var terminal_id := "terminal"
var prompt_text := "Press E to interact"
var display_text := "geometry integrity nominal"
var accent := Color(0.4, 0.86, 0.96)

var indicator: MeshInstance3D
var label: Label3D
var phase := 0.0

func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_terminal()
	_apply_style()

func configure(new_id: String, prompt: String, text: String, color: Color) -> void:
	terminal_id = new_id
	prompt_text = prompt
	display_text = text
	accent = color
	if indicator == null:
		_build_terminal()
	_apply_style()

func _build_terminal() -> void:
	if indicator != null:
		return
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 2.2, 1.1)
	shape.shape = box
	shape.position = Vector3(0.0, 1.1, 0.0)
	add_child(shape)

	var chassis := MeshInstance3D.new()
	var chassis_mesh := BoxMesh.new()
	chassis_mesh.size = Vector3(1.4, 2.1, 0.9)
	chassis.mesh = chassis_mesh
	chassis.position = Vector3(0.0, 1.05, 0.0)
	var chassis_material := StandardMaterial3D.new()
	chassis_material.albedo_color = Color(0.15, 0.17, 0.2)
	chassis_material.roughness = 0.72
	chassis.material_override = chassis_material
	add_child(chassis)

	indicator = MeshInstance3D.new()
	var indicator_mesh := BoxMesh.new()
	indicator_mesh.size = Vector3(0.88, 0.56, 0.08)
	indicator.mesh = indicator_mesh
	indicator.position = Vector3(0.0, 1.45, 0.5)
	add_child(indicator)

	label = Label3D.new()
	label.position = Vector3(0.0, 2.4, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.modulate = Color(0.92, 0.95, 1.0)
	add_child(label)

func _apply_style() -> void:
	if indicator:
		var material := StandardMaterial3D.new()
		material.albedo_color = accent
		material.emission_enabled = true
		material.emission = accent * 0.45
		material.roughness = 0.2
		indicator.material_override = material
	if label:
		label.text = display_text

func _process(delta: float) -> void:
	phase += delta
	if indicator:
		indicator.position.y = 1.45 + sin(phase * 2.4) * 0.05

func interact(_player) -> void:
	emit_signal("activated", terminal_id)

func get_prompt() -> String:
	return prompt_text
