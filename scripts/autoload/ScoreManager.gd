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

func get_final_score() -> int:
    return base_score
