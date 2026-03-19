extends Node

const SAVE_PATH := "user://run_save.json"
const SAMPLE_SEEDS := [
	"GEOMETRY-INTEGRITY",
	"BENT-STAIRS-14",
	"NO-MEANINGFUL-DEVIATION",
	"ARCHIVE-WEDGE-22"
]

var session_started_unix: int = 0
var build_configuration: String = "release"
var current_seed_text: String = SAMPLE_SEEDS[0]
var current_seed_value: int = 0
var current_run_state: Dictionary = {}

func _ready() -> void:
	start_session()
	current_seed_value = seed_text_to_value(current_seed_text)

func start_session() -> void:
	session_started_unix = int(Time.get_unix_time_from_system())
	build_configuration = "debug" if OS.is_debug_build() else "release"

func seed_text_to_value(seed_text: String) -> int:
	var trimmed := seed_text.strip_edges()
	if trimmed.is_empty():
		trimmed = SAMPLE_SEEDS[0]
	if trimmed.is_valid_int():
		return abs(trimmed.to_int()) + 1
	var hash_value: int = 5381
	for byte_value in trimmed.to_utf8_buffer():
		hash_value = int((hash_value * 33 + int(byte_value)) % 2147483647)
	return max(abs(hash_value), 1)

func set_seed_text(seed_text: String) -> void:
	current_seed_text = seed_text.strip_edges()
	if current_seed_text.is_empty():
		current_seed_text = SAMPLE_SEEDS[0]
	current_seed_value = seed_text_to_value(current_seed_text)

func make_default_player_state() -> Dictionary:
	return {
		"position": [0.0, 1.75, 0.0],
		"yaw": 0.0,
		"pitch": 0.0,
		"health": 100.0,
		"max_health": 100.0,
		"stamina": 100.0,
		"max_stamina": 100.0,
		"mana": 60.0,
		"max_mana": 60.0,
		"tonics": 1,
		"aether": 1,
		"keys": 0
	}

func make_run_state(seed_text: String) -> Dictionary:
	set_seed_text(seed_text)
	current_run_state = {
		"version": 1,
		"title": "Vault of Bent Geometry That Loads Correctly",
		"seed_text": current_seed_text,
		"seed_value": current_seed_value,
		"mode": "hub",
		"player": make_default_player_state(),
		"inventory": {
			"keys": 0,
			"tonics": 1,
			"aether": 1
		},
		"discovered_rooms": [],
		"discovered_corridors": [],
		"opened_doors": [],
		"unlocked_doors": [],
		"collected_pickups": [],
		"defeated_enemies": [],
		"goal_reached": false,
		"hub_visits": 1,
		"last_status": "geometry integrity nominal"
	}
	return current_run_state

func apply_run_state(run_state: Dictionary) -> void:
	current_run_state = run_state.duplicate(true)
	current_seed_text = str(current_run_state.get("seed_text", SAMPLE_SEEDS[0]))
	current_seed_value = int(current_run_state.get("seed_value", seed_text_to_value(current_seed_text)))

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_run(run_state: Dictionary) -> bool:
	apply_run_state(run_state)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(current_run_state, "\t"))
	file.close()
	return true

func load_run() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	apply_run_state(parsed)
	return current_run_state.duplicate(true)

func clear_run_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	current_run_state = {}

func copy_array(values: Array) -> Array:
	return values.duplicate(true)

func add_unique_int(target: Array, value: int) -> void:
	if not target.has(value):
		target.append(value)
