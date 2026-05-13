extends Node
class_name DataLoader

static var _cache: Dictionary = {}
static var _paths := {
    "pieces": "res://data/pieces.json",
    "player_pieces": "res://data/player_pieces.json",
    "enemy_pieces": "res://data/enemy_pieces.json",
    "map_generation": "res://data/map_generation.json",
    "encounter_objectives": "res://data/encounter_objectives.json",
    "items": "res://data/items.json",
    "terrain": "res://data/terrain.json",
    "ai_weights": "res://data/ai_weights.json",
    "encounters": "res://data/encounter_tiers.json",
    "combat_rules": "res://data/combat_rules.json",
    "score_rules": "res://data/score_rules.json",
    "statuses": "res://data/statuses.json",
    "evolution_rules": "res://data/evolution_rules.json",
    "action_costs": "res://data/action_costs.json",
    "synergies": "res://data/synergies.json",
    "run_nodes": "res://data/run_nodes.json",
    "run_outcomes": "res://data/run_outcomes.json",
    "perks": "res://data/perks.json",
    "encounter_templates": "res://data/encounter_templates.json",
    "enemy_roles": "res://data/enemy_roles.json",
    "run_pacing": "res://data/run_pacing.json",
    "item_pools": "res://data/item_pools.json",
    "simultaneous_movement": "res://data/simultaneous_movement.json",
}

static func load_config(config_name: String) -> Variant:
    if _cache.has(config_name):
        return _cache[config_name]
    var path: String = _paths.get(config_name, "")
    if path.is_empty():
        push_error("DataLoader: missing config path for %s" % config_name)
        return {}
    var data: Variant = _load_json(path)
    _cache[config_name] = data
    return data

static func clear_cache() -> void:
    _cache.clear()

static func _load_json(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        push_error("DataLoader: file not found %s" % path)
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("DataLoader: unable to open %s" % path)
        return {}
    var text := file.get_as_text()
    var parsed: Variant = JSON.parse_string(text)
    if parsed == null:
        push_error("DataLoader: invalid JSON in %s" % path)
        return {}
    return parsed
