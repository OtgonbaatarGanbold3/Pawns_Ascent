extends Node

const META_SAVE_PATH := "user://pawn_ascent_meta.json"

var run_state: Dictionary = {}
var meta_state: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()
    load_meta_state()

func reset_run(setup: Dictionary = {}) -> void:
    var themes: Dictionary = DataLoader.load_config("run_themes")
    var default_setup: Dictionary = themes.get("default_setup", {})
    var run_setup := default_setup.duplicate(true)
    for key in setup.keys():
        run_setup[key] = setup[key]
    run_state = {
        "setup": run_setup,
        "board": null,
        "player": null,
        "enemies": [],
        "allies": [],
        "encounter_index": 0,
        "current_floor": 0,
        "current_node": {},
        "active_node_id": "",
        "path_graph": {},
        "gold": 0,
        "perks": [],
        "run_stat_bonuses": {},
        "active_contracts": [],
        "active_allies": [],
        "active_consequences": [],
        "pending_board_mutations": 0,
        "ally_serial": 0,
        "phase": "player",
        "turn": 1,
        "log": []
    }

func load_meta_state() -> void:
    meta_state = _default_meta_state()
    if not FileAccess.file_exists(META_SAVE_PATH):
        return
    var file := FileAccess.open(META_SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var loaded: Dictionary = parsed
    for key in loaded.keys():
        meta_state[key] = loaded[key]

func save_meta_state() -> void:
    var file := FileAccess.open(META_SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_error("GameState: unable to save meta state")
        return
    file.store_string(JSON.stringify(meta_state, "\t"))

func record_run_result(victory: bool, score: int, summary: Dictionary = {}) -> void:
    meta_state["run_count"] = int(meta_state.get("run_count", 0)) + 1
    var history: Array = meta_state.get("run_history", [])
    var setup: Dictionary = run_state.get("setup", {})
    var entry := {
        "run": int(meta_state.get("run_count", 0)),
        "victory": victory,
        "score": score,
        "floor": int(run_state.get("current_floor", 0)),
        "mode": str(setup.get("mode", "legacy")),
        "theme": str(setup.get("theme", "neutral")),
        "difficulty": str(setup.get("difficulty", "wanderer")),
        "piece": str(summary.get("piece", "")),
        "kills": int(summary.get("kills", 0))
    }
    history.push_front(entry)
    while history.size() > 10:
        history.pop_back()
    meta_state["run_history"] = history
    _update_best_scores(entry)
    save_meta_state()

func set_legacy_boss(record: Dictionary) -> void:
    meta_state["legacy_boss"] = record.duplicate(true)
    save_meta_state()

func clear_legacy_boss() -> void:
    meta_state["legacy_boss"] = {}
    save_meta_state()

func get_legacy_boss() -> Dictionary:
    return (meta_state.get("legacy_boss", {}) as Dictionary).duplicate(true)

func _default_meta_state() -> Dictionary:
    return {
        "run_count": 0,
        "tutorial_complete": false,
        "legacy_tokens": 0,
        "legacy_boss": {},
        "run_history": [],
        "best_scores": {}
    }

func _update_best_scores(entry: Dictionary) -> void:
    var best_scores: Dictionary = meta_state.get("best_scores", {})
    var key := "%s:%s:%s" % [str(entry.get("mode", "legacy")), str(entry.get("theme", "neutral")), str(entry.get("difficulty", "wanderer"))]
    var score: int = int(entry.get("score", 0))
    if score > int(best_scores.get(key, 0)):
        best_scores[key] = score
    meta_state["best_scores"] = best_scores

func set_phase(phase: String) -> void:
    run_state["phase"] = phase

func add_log(entry: String) -> void:
    var log_entries: Array = run_state.get("log", [])
    log_entries.append(entry)
    run_state["log"] = log_entries
