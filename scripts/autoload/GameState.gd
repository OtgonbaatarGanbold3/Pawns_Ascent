extends Node

var run_state: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()

func reset_run() -> void:
    run_state = {
        "board": null,
        "player": null,
	        "enemies": [],
	        "encounter_index": 0,
	        "current_floor": 0,
	        "current_node": {},
	        "active_node_id": "",
	        "path_graph": {},
	        "gold": 0,
	        "phase": "player",
        "turn": 1,
        "log": []
    }

func set_phase(phase: String) -> void:
    run_state["phase"] = phase

func add_log(entry: String) -> void:
    var log_entries: Array = run_state.get("log", [])
    log_entries.append(entry)
    run_state["log"] = log_entries
