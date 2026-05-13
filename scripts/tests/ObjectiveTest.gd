extends Node


func _ready() -> void:
    DataLoader.clear_cache()
    _test_objective_config()
    _test_tile_objective_reset()
    _test_mutation_skips_objective_tile()
    print("ObjectiveTest complete")

func _test_objective_config() -> void:
    var cfg: Dictionary = DataLoader.load_config("encounter_objectives")
    var types: Dictionary = cfg.get("types", {})
    for objective_id in ["cache", "seal", "escape"]:
        if not types.has(objective_id):
            push_error("ObjectiveTest failed: missing objective %s" % objective_id)
            continue
        var objective: Dictionary = types[objective_id]
        if str(objective.get("display_name", "")).is_empty():
            push_error("ObjectiveTest failed: %s needs display_name" % objective_id)
        if str(objective.get("placement", "")).is_empty():
            push_error("ObjectiveTest failed: %s needs placement" % objective_id)
        if not objective.has("reward_gold"):
            push_error("ObjectiveTest failed: %s needs reward_gold" % objective_id)

func _test_tile_objective_reset() -> void:
    var tile := Tile.new()
    tile.objective_id = "old"
    tile.objective_type = "cache"
    tile.init_from_terrain("normal", {})
    if not tile.objective_id.is_empty() or not tile.objective_type.is_empty():
        push_error("ObjectiveTest failed: terrain reset should clear objective metadata")

func _test_mutation_skips_objective_tile() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 42
    var board := BoardData.new()
    board.init_board(1, 2)
    var terrain_cfg: Dictionary = DataLoader.load_config("terrain")
    var objective_tile := Tile.new()
    objective_tile.init_from_terrain("normal", terrain_cfg.get("normal", {}))
    objective_tile.objective_id = "cache_test"
    objective_tile.objective_type = "cache"
    board.set_tile(Vector2i(0, 0), objective_tile)
    var mutable_tile := Tile.new()
    mutable_tile.init_from_terrain("normal", terrain_cfg.get("normal", {}))
    board.set_tile(Vector2i(1, 0), mutable_tile)

    var mutated: Vector2i = BoardGenerator.mutate_empty_tile(board, rng)
    if mutated != Vector2i(1, 0):
        push_error("ObjectiveTest failed: mutation should skip objective tile, got %s" % mutated)
    var tile: Tile = board.get_tile(Vector2i(0, 0))
    if tile == null or tile.objective_type != "cache":
        push_error("ObjectiveTest failed: objective tile was overwritten")
