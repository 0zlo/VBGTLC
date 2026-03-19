extends Node

const GAME_TITLE := "Vault of Bent Geometry That Loads Correctly"
const GeometryBuilderClass = preload("res://scripts/geometry_builder.gd")
const DungeonGeneratorClass = preload("res://scripts/dungeon_generator.gd")
const DungeonRuntimeClass = preload("res://scripts/dungeon_runtime.gd")
const PlayerControllerClass = preload("res://scripts/player_controller.gd")
const InteractionTerminalClass = preload("res://scripts/interaction_terminal.gd")
const MiniMapControlClass = preload("res://scripts/minimap_control.gd")
const MagicProjectileClass = preload("res://scripts/magic_projectile.gd")

var world_root: Node3D
var play_root: Node3D
var ui_layer: CanvasLayer

var current_mode := "menu"
var current_run_state: Dictionary = {}
var current_layout: Dictionary = {}
var player = null
var dungeon_runtime = null
var hub_terminal = null
var autosave_timer := 0.0
var notification_timer := 0.0
var map_visible := true

var menu_panel: PanelContainer
var menu_status_label: RichTextLabel
var seed_input: LineEdit
var continue_button: Button
var hud_root: Control
var prompt_label: Label
var status_label: Label
var floor_label: Label
var inventory_label: Label
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var mana_bar: ProgressBar
var notification_label: Label
var minimap = null
var pause_panel: PanelContainer
var death_panel: PanelContainer
var session_footer: Label

func _ready() -> void:
	GameState.start_session()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_input_actions()
	_setup_scene_graph()
	_setup_world_environment()
	_build_ui()
	_show_main_menu()

func _process(delta: float) -> void:
	if notification_timer > 0.0:
		notification_timer = max(notification_timer - delta, 0.0)
		notification_label.modulate.a = clamp(notification_timer, 0.0, 1.0)
	else:
		notification_label.text = ""
	if current_mode == "dungeon" and dungeon_runtime and player:
		dungeon_runtime.update_discovery(player.global_position)
		minimap.visible = map_visible
		minimap.set_player_pose(player.global_position, player.yaw)
	elif current_mode == "hub":
		minimap.visible = false
	else:
		minimap.visible = false
	if current_mode in ["hub", "dungeon"] and player:
		_update_hud()
		autosave_timer -= delta
		if autosave_timer <= 0.0 and not get_tree().paused:
			_snapshot_and_save()
			autosave_timer = 1.5

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause"):
		if current_mode in ["hub", "dungeon"]:
			_toggle_pause()
	elif Input.is_action_just_pressed("toggle_map") and current_mode == "dungeon":
		map_visible = not map_visible
	elif Input.is_action_just_pressed("toggle_godmode") and current_mode in ["hub", "dungeon"] and player:
		player.toggle_god_mode()

func _setup_scene_graph() -> void:
	world_root = get_node_or_null("WorldRoot") as Node3D
	if world_root == null:
		world_root = Node3D.new()
		world_root.name = "WorldRoot"
		add_child(world_root)
	play_root = Node3D.new()
	play_root.name = "PlayRoot"
	world_root.add_child(play_root)
	ui_layer = get_node_or_null("UiLayer") as CanvasLayer
	if ui_layer == null:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UiLayer"
		add_child(ui_layer)

func _setup_world_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.05, 0.07)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.14, 0.16, 0.19)
	environment.ambient_light_energy = 1.1
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.18, 0.24, 0.28)
	environment.fog_density = 0.018
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world_root.add_child(world_environment)

	var directional := DirectionalLight3D.new()
	directional.rotation_degrees = Vector3(-56.0, 36.0, 0.0)
	directional.light_energy = 0.45
	directional.light_color = Color(0.62, 0.71, 0.74)
	world_root.add_child(directional)

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(root)

	menu_panel = PanelContainer.new()
	menu_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu_panel.position = Vector2(180.0, 100.0)
	menu_panel.size = Vector2(920.0, 520.0)
	menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_panel_style(menu_panel, Color(0.07, 0.09, 0.11, 0.94), Color(0.31, 0.55, 0.63, 1.0))
	root.add_child(menu_panel)

	var menu_margin := MarginContainer.new()
	menu_margin.add_theme_constant_override("margin_left", 24)
	menu_margin.add_theme_constant_override("margin_top", 22)
	menu_margin.add_theme_constant_override("margin_right", 24)
	menu_margin.add_theme_constant_override("margin_bottom", 22)
	menu_panel.add_child(menu_margin)

	var menu_vbox := VBoxContainer.new()
	menu_vbox.add_theme_constant_override("separation", 14)
	menu_margin.add_child(menu_vbox)

	var title := Label.new()
	title.text = GAME_TITLE
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.93, 0.97, 0.99))
	menu_vbox.add_child(title)

	menu_status_label = RichTextLabel.new()
	menu_status_label.fit_content = true
	menu_status_label.scroll_active = false
	menu_status_label.bbcode_enabled = true
	menu_status_label.custom_minimum_size = Vector2(0.0, 110.0)
	menu_status_label.text = "[color=#a7dfee]geometry integrity nominal[/color]\nqueue a seed, enter the hub, then proceed when the system insists the vault loaded correctly.\n\nsmall print: state continuity preserved until evidence becomes inconvenient."
	menu_vbox.add_child(menu_status_label)

	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 12)
	menu_vbox.add_child(seed_row)

	var seed_label := Label.new()
	seed_label.text = "Seed"
	seed_label.custom_minimum_size = Vector2(62.0, 0.0)
	seed_row.add_child(seed_label)

	seed_input = LineEdit.new()
	seed_input.text = GameState.current_seed_text
	seed_input.placeholder_text = "Enter deterministic seed"
	seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(seed_input)

	var sample_row := HBoxContainer.new()
	sample_row.add_theme_constant_override("separation", 10)
	menu_vbox.add_child(sample_row)
	for sample_seed in GameState.SAMPLE_SEEDS:
		var sample_button := Button.new()
		sample_button.text = sample_seed
		sample_button.pressed.connect(func() -> void:
			seed_input.text = sample_seed
		)
		sample_row.add_child(sample_button)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	menu_vbox.add_child(button_row)

	var new_button := Button.new()
	new_button.text = "Initialize Vault"
	new_button.pressed.connect(_on_new_run_pressed)
	button_row.add_child(new_button)

	continue_button = Button.new()
	continue_button.text = "Continue Run"
	continue_button.disabled = not GameState.has_save()
	continue_button.pressed.connect(_on_continue_pressed)
	button_row.add_child(continue_button)

	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.pressed.connect(func() -> void:
		get_tree().quit()
	)
	button_row.add_child(quit_button)

	var controls := Label.new()
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.text = "Controls: WASD move, Shift sprint or descend in godmode, Space jump or ascend in godmode, E interact, Left Mouse melee, Right Mouse continuity pulse, Q tonic, F aether, Tab minimap, F10 godmode, Esc pause."
	controls.add_theme_color_override("font_color", Color(0.74, 0.8, 0.84))
	menu_vbox.add_child(controls)

	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.visible = false
	hud_root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(hud_root)

	var top_left := VBoxContainer.new()
	top_left.position = Vector2(18.0, 18.0)
	top_left.custom_minimum_size = Vector2(320.0, 0.0)
	top_left.add_theme_constant_override("separation", 10)
	hud_root.add_child(top_left)

	floor_label = Label.new()
	floor_label.text = ""
	top_left.add_child(floor_label)

	health_bar = _make_bar(top_left, "Health")
	stamina_bar = _make_bar(top_left, "Stamina")
	mana_bar = _make_bar(top_left, "Mana")

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text = ""
	top_left.add_child(status_label)

	inventory_label = Label.new()
	inventory_label.text = ""
	top_left.add_child(inventory_label)

	minimap = MiniMapControlClass.new()
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.anchor_top = 0.0
	minimap.anchor_bottom = 0.0
	minimap.offset_left = -264.0
	minimap.offset_top = 18.0
	minimap.offset_right = -18.0
	minimap.offset_bottom = 264.0
	minimap.visible = false
	hud_root.add_child(minimap)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 24)
	crosshair.anchor_left = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -8.0
	crosshair.offset_top = -14.0
	crosshair.offset_right = 8.0
	crosshair.offset_bottom = 14.0
	hud_root.add_child(crosshair)

	prompt_label = Label.new()
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_top = 1.0
	prompt_label.anchor_bottom = 1.0
	prompt_label.offset_left = -260.0
	prompt_label.offset_right = 260.0
	prompt_label.offset_top = -88.0
	prompt_label.offset_bottom = -48.0
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.text = ""
	hud_root.add_child(prompt_label)

	notification_label = Label.new()
	notification_label.anchor_left = 0.5
	notification_label.anchor_right = 0.5
	notification_label.anchor_top = 0.0
	notification_label.anchor_bottom = 0.0
	notification_label.offset_left = -280.0
	notification_label.offset_right = 280.0
	notification_label.offset_top = 54.0
	notification_label.offset_bottom = 84.0
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.text = ""
	hud_root.add_child(notification_label)

	pause_panel = _build_overlay_panel(root, "Pause", "state continuity held in temporary suspension")
	var pause_buttons := pause_panel.get_child(0).get_child(0) as VBoxContainer
	pause_buttons.add_child(_make_action_button("Resume", _resume_game))
	pause_buttons.add_child(_make_action_button("Save Run", _snapshot_and_save))
	pause_buttons.add_child(_make_action_button("Return To Title", _return_to_title))

	death_panel = _build_overlay_panel(root, "Integrity Lost", "deviation exceeded safe coping thresholds")
	var death_buttons := death_panel.get_child(0).get_child(0) as VBoxContainer
	death_buttons.add_child(_make_action_button("Restart Seed In Hub", _restart_seed))
	death_buttons.add_child(_make_action_button("Return To Title", _return_to_title_from_death))

	session_footer = Label.new()
	session_footer.anchor_left = 0.0
	session_footer.anchor_right = 1.0
	session_footer.anchor_top = 1.0
	session_footer.anchor_bottom = 1.0
	session_footer.offset_left = 18.0
	session_footer.offset_right = -18.0
	session_footer.offset_top = -32.0
	session_footer.offset_bottom = -10.0
	session_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	session_footer.text = "session unix %d | %s build | %s" % [GameState.session_started_unix, GameState.build_configuration, OS.get_name()]
	root.add_child(session_footer)

func _make_bar(parent: Node, label_text: String) -> ProgressBar:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(280.0, 16.0)
	parent.add_child(bar)
	return bar

func _build_overlay_panel(parent: Node, title_text: String, body_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -220.0
	panel.offset_top = -150.0
	panel.offset_right = 220.0
	panel.offset_bottom = 150.0
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_panel_style(panel, Color(0.08, 0.09, 0.1, 0.95), Color(0.43, 0.55, 0.59, 1.0))
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)

	return panel

func _make_action_button(text_value: String, callable: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.pressed.connect(callable)
	return button

func _apply_panel_style(panel: PanelContainer, fill: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)

func _show_main_menu() -> void:
	current_mode = "menu"
	menu_panel.visible = true
	hud_root.visible = false
	pause_panel.visible = false
	death_panel.visible = false
	get_tree().paused = false
	if player:
		player.set_gameplay_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	continue_button.disabled = not GameState.has_save()
	seed_input.text = GameState.current_seed_text
	_clear_play_world()

func _on_new_run_pressed() -> void:
	current_run_state = GameState.make_run_state(seed_input.text)
	current_run_state["last_status"] = "geometry integrity nominal"
	_enter_hub(false)

func _on_continue_pressed() -> void:
	var loaded := GameState.load_run()
	if loaded.is_empty():
		return
	current_run_state = loaded
	GameState.set_seed_text(str(current_run_state.get("seed_text", GameState.current_seed_text)))
	if str(current_run_state.get("mode", "hub")) == "dungeon":
		_enter_dungeon(true)
	else:
		_enter_hub(true)

func _enter_hub(from_save: bool) -> void:
	menu_panel.visible = false
	hud_root.visible = true
	pause_panel.visible = false
	death_panel.visible = false
	get_tree().paused = false
	current_mode = "hub"
	map_visible = false
	current_run_state["mode"] = "hub"
	current_run_state["last_status"] = "staging room loaded correctly"
	_clear_play_world()
	_spawn_player()
	_build_hub_world()
	if from_save:
		player.apply_player_state(current_run_state.get("player", GameState.make_default_player_state()), current_run_state.get("inventory", {}))
	else:
		player.apply_player_state(current_run_state.get("player", GameState.make_default_player_state()), current_run_state.get("inventory", {}))
		player.global_position = Vector3(-4.8, 0.3, 0.0)
		player.yaw = -1.2
		player.rotation.y = player.yaw
		player.camera.rotation.x = 0.0
	player.set_gameplay_enabled(true)
	minimap.set_layout({})
	_snapshot_and_save()
	_show_notification("Hub staging aligned. Seed queued: %s" % current_run_state.get("seed_text", ""))

func _build_hub_world() -> void:
	var hub_theme := {
		"albedo": Color(0.4, 0.63, 0.72),
		"emission": Color(0.18, 0.29, 0.36),
		"metallic": 0.08,
		"map": Color(0.62, 0.86, 0.91)
	}
	var hub_polygon := PackedVector2Array([
		Vector2(-9.0, -5.8),
		Vector2(7.6, -7.2),
		Vector2(10.4, -0.6),
		Vector2(6.1, 7.3),
		Vector2(-7.8, 5.9),
		Vector2(-10.2, 1.4)
	])
	var hub_room := {
		"id": 9000,
		"name": "Hub",
		"polygon": hub_polygon,
		"center": GeometryBuilderClass.polygon_centroid(hub_polygon),
		"base_y": 0.0,
		"height_mode": "flat",
		"ceiling_height": 5.4,
		"slope": 0.0,
		"slope_axis": Vector2(1.0, 0.0),
		"brightness": 1.04
	}
	play_root.add_child(GeometryBuilderClass.build_area_node(hub_room, hub_theme))

	var platform_poly := PackedVector2Array([
		Vector2(1.2, -1.8),
		Vector2(4.1, -2.7),
		Vector2(5.2, 0.4),
		Vector2(2.1, 1.8),
		Vector2(0.2, 0.1)
	])
	var platform := {
		"id": 9001,
		"name": "HubPlatform",
		"polygon": platform_poly,
		"center": GeometryBuilderClass.polygon_centroid(platform_poly),
		"base_y": 1.0,
		"height_mode": "flat",
		"ceiling_height": 4.4,
		"slope": 0.0,
		"slope_axis": Vector2.RIGHT,
		"brightness": 1.1
	}
	var ramp := {
		"id": 9002,
		"name": "HubRamp",
		"polygon": PackedVector2Array([
			Vector2(-1.6, -0.7),
			Vector2(-1.6, 0.9),
			Vector2(0.8, 0.6),
			Vector2(0.8, -0.4)
		]),
		"center": Vector2(-0.3, 0.0),
		"base_y": 0.0,
		"height_mode": "corridor",
		"height_start": Vector2(-1.6, 0.1),
		"height_end": Vector2(0.8, 0.1),
		"start_y": 0.0,
		"end_y": 1.0,
		"ceiling_height": 4.5,
		"brightness": 1.03
	}
	play_root.add_child(GeometryBuilderClass.build_area_node(platform, hub_theme))
	play_root.add_child(GeometryBuilderClass.build_area_node(ramp, hub_theme))

	hub_terminal = InteractionTerminalClass.new()
	hub_terminal.global_position = Vector3(2.4, 1.0, -0.1)
	hub_terminal.configure(
		"hub_start",
		"Press E to enter the monitored floor",
		"geometry queue: %s" % current_run_state.get("seed_text", GameState.current_seed_text),
		Color(0.51, 0.91, 0.98)
	)
	hub_terminal.activated.connect(_on_hub_terminal_activated)
	play_root.add_child(hub_terminal)

	var hub_light := OmniLight3D.new()
	hub_light.position = Vector3(1.8, 4.2, 0.0)
	hub_light.omni_range = 18.0
	hub_light.light_energy = 0.95
	hub_light.light_color = Color(0.54, 0.82, 0.92)
	play_root.add_child(hub_light)

func _enter_dungeon(from_save: bool) -> void:
	menu_panel.visible = false
	hud_root.visible = true
	pause_panel.visible = false
	death_panel.visible = false
	get_tree().paused = false
	current_mode = "dungeon"
	map_visible = true
	current_run_state["mode"] = "dungeon"
	_clear_play_world()
	_spawn_player()

	var generator := DungeonGeneratorClass.new()
	current_layout = generator.generate(int(current_run_state.get("seed_value", GameState.current_seed_value)))
	dungeon_runtime = DungeonRuntimeClass.new()
	play_root.add_child(dungeon_runtime)
	dungeon_runtime.bind_player(player)
	dungeon_runtime.run_state_changed.connect(_on_run_state_changed)
	dungeon_runtime.goal_activated.connect(_on_goal_activated)
	dungeon_runtime.notification.connect(_show_notification)
	dungeon_runtime.setup(current_layout, current_run_state)
	minimap.set_layout(current_layout)
	minimap.set_discovery(current_run_state.get("discovered_rooms", []), current_run_state.get("discovered_corridors", []))

	player.apply_player_state(current_run_state.get("player", GameState.make_default_player_state()), current_run_state.get("inventory", {}))
	if from_save:
		player.apply_player_state(current_run_state.get("player", GameState.make_default_player_state()), current_run_state.get("inventory", {}))
	else:
		player.global_position = dungeon_runtime.get_spawn_position()
		player.yaw = 0.0
		player.rotation.y = 0.0
		player.camera.rotation.x = 0.0
	player.set_gameplay_enabled(true)
	dungeon_runtime.update_discovery(player.global_position)
	minimap.set_discovery(current_run_state.get("discovered_rooms", []), current_run_state.get("discovered_corridors", []))
	current_run_state["last_status"] = "vault loaded correctly"
	_snapshot_and_save()
	_show_notification("Vault loaded correctly. Deviation monitoring active.")

func _spawn_player() -> void:
	player = PlayerControllerClass.new()
	play_root.add_child(player)
	player.request_projectile.connect(_spawn_projectile)
	player.stats_changed.connect(_on_player_stats_changed)
	player.died.connect(_on_player_died)
	player.notification.connect(_show_notification)

func _spawn_projectile(origin: Vector3, direction: Vector3) -> void:
	var projectile := MagicProjectileClass.new()
	projectile.configure(origin, direction, player)
	play_root.add_child(projectile)

func _update_hud() -> void:
	health_bar.max_value = player.max_health
	health_bar.value = player.health
	stamina_bar.max_value = player.max_stamina
	stamina_bar.value = player.stamina
	mana_bar.max_value = player.max_mana
	mana_bar.value = player.mana
	inventory_label.text = "Keys %d | Tonics %d | Aether %d" % [player.keys, player.tonics, player.aether]
	floor_label.text = "Mode: %s | Seed: %s%s" % [
		current_mode.capitalize(),
		current_run_state.get("seed_text", GameState.current_seed_text),
		" | GODMODE" if player.god_mode else ""
	]
	status_label.text = str(current_run_state.get("last_status", "geometry integrity nominal"))
	prompt_label.text = player.get_prompt_text()
	if dungeon_runtime:
		minimap.set_discovery(current_run_state.get("discovered_rooms", []), current_run_state.get("discovered_corridors", []))

func _toggle_pause() -> void:
	if death_panel.visible:
		return
	if pause_panel.visible:
		_resume_game()
	else:
		pause_panel.visible = true
		get_tree().paused = true
		if player:
			player.set_gameplay_enabled(false)

func _resume_game() -> void:
	pause_panel.visible = false
	get_tree().paused = false
	if player:
		player.set_gameplay_enabled(true)

func _on_run_state_changed() -> void:
	_snapshot_and_save()

func _on_player_stats_changed() -> void:
	if current_mode in ["hub", "dungeon"]:
		current_run_state["inventory"] = player.get_inventory_state()

func _on_player_died() -> void:
	current_mode = "dead"
	death_panel.visible = true
	get_tree().paused = true
	if player:
		player.set_gameplay_enabled(false)
	GameState.clear_run_save()
	_show_notification("Integrity lost. State continuity not preserved.")

func _restart_seed() -> void:
	get_tree().paused = false
	current_run_state = GameState.make_run_state(str(current_run_state.get("seed_text", GameState.current_seed_text)))
	death_panel.visible = false
	_enter_hub(false)

func _return_to_title() -> void:
	_snapshot_and_save()
	_show_main_menu()

func _return_to_title_from_death() -> void:
	get_tree().paused = false
	GameState.clear_run_save()
	death_panel.visible = false
	_show_main_menu()

func _on_goal_activated() -> void:
	_show_notification("Vault stabilized. State continuity preserved.")
	var preserved_seed := str(current_run_state.get("seed_text", GameState.current_seed_text))
	current_run_state = GameState.make_run_state(preserved_seed)
	current_run_state["last_status"] = "vault loaded correctly"
	_enter_hub(false)

func _on_hub_terminal_activated(_terminal_id: String) -> void:
	current_run_state["seed_text"] = seed_input.text if not seed_input.text.is_empty() else current_run_state.get("seed_text", GameState.current_seed_text)
	GameState.set_seed_text(str(current_run_state.get("seed_text", GameState.current_seed_text)))
	current_run_state["seed_text"] = GameState.current_seed_text
	current_run_state["seed_value"] = GameState.current_seed_value
	current_run_state["discovered_rooms"] = []
	current_run_state["discovered_corridors"] = []
	current_run_state["opened_doors"] = []
	current_run_state["unlocked_doors"] = []
	current_run_state["collected_pickups"] = []
	current_run_state["defeated_enemies"] = []
	current_run_state["goal_reached"] = false
	_enter_dungeon(false)

func _snapshot_and_save() -> void:
	if current_mode not in ["hub", "dungeon"] or player == null:
		return
	current_run_state["player"] = player.export_player_state()
	current_run_state["inventory"] = player.get_inventory_state()
	current_run_state["mode"] = current_mode
	GameState.save_run(current_run_state)
	continue_button.disabled = not GameState.has_save()

func _show_notification(message: String) -> void:
	notification_label.text = message
	notification_label.modulate = Color(0.94, 0.98, 1.0, 1.0)
	notification_timer = 1.8
	current_run_state["last_status"] = message.to_lower()

func _clear_play_world() -> void:
	for child in play_root.get_children():
		child.free()
	player = null
	dungeon_runtime = null
	hub_terminal = null
	current_layout = {}

func _ensure_input_actions() -> void:
	_add_action_key("move_forward", KEY_W)
	_add_action_key("move_forward", KEY_UP)
	_add_action_key("move_backward", KEY_S)
	_add_action_key("move_backward", KEY_DOWN)
	_add_action_key("move_left", KEY_A)
	_add_action_key("move_left", KEY_LEFT)
	_add_action_key("move_right", KEY_D)
	_add_action_key("move_right", KEY_RIGHT)
	_add_action_key("jump", KEY_SPACE)
	_add_action_key("sprint", KEY_SHIFT)
	_add_action_key("interact", KEY_E)
	_add_action_key("use_tonic", KEY_Q)
	_add_action_key("use_aether", KEY_F)
	_add_action_key("toggle_map", KEY_TAB)
	_add_action_key("toggle_godmode", KEY_F10)
	_add_action_key("pause", KEY_ESCAPE)
	_add_action_mouse("attack_melee", MOUSE_BUTTON_LEFT)
	_add_action_mouse("attack_magic", MOUSE_BUTTON_RIGHT)

func _add_action_key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.keycode == keycode:
			return
	var key_event := InputEventKey.new()
	key_event.keycode = keycode
	InputMap.action_add_event(action, key_event)

func _add_action_mouse(action: StringName, button_index: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button_index:
			return
	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = button_index
	InputMap.action_add_event(action, mouse_event)
