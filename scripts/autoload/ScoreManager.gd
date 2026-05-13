extends Node


var base_score: int = 0
var events: Array = []

func reset() -> void:
    base_score = 0
    events = []

func add_score(event_id: String) -> void:
    var rules: Dictionary = DataLoader.load_config("score_rules")
    var points: int = int(rules.get(event_id, 0))
    if points == 0:
        return
    base_score += points
    events.append({"event": event_id, "points": points})

func get_base_score() -> int:
    return base_score

func get_events() -> Array:
    return events.duplicate(true)

func get_final_score(run_state: Dictionary = {}) -> int:
    var rules: Dictionary = DataLoader.load_config("score_rules")
    var multiplier_cfg: Dictionary = rules.get("multipliers", {})
    var floor_index: int = int(run_state.get("current_floor", 1))
    var base_multiplier: float = float(multiplier_cfg.get("death_floor_base", 1.0))
    var floor_step: float = float(multiplier_cfg.get("death_floor_step", 0.0))
    var floor_cap: float = float(multiplier_cfg.get("death_floor_cap", base_multiplier))
    var floor_multiplier: float = min(floor_cap, base_multiplier + max(0, floor_index - 1) * floor_step)
    return int(round(float(base_score) * floor_multiplier))
