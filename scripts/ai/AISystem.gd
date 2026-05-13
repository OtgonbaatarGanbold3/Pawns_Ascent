extends Node
class_name AISystem


static func calculate_priority(unit: Unit) -> Dictionary:
    var weights_cfg: Dictionary = DataLoader.load_config("ai_weights")
    var base_weights: Dictionary = weights_cfg.get("piece_base_weights", {}).get(unit.piece_id, {})

    var priority := {
        "aggressive": int(base_weights.get("aggressive", 0)),
        "attack": int(base_weights.get("attack", 0)),
        "defend": int(base_weights.get("defend", 0)),
        "flee": int(base_weights.get("flee", 0))
    }

    for item in unit.items:
        var behavior: Dictionary = item.get("ai_behavior", {})
        var mode: String = behavior.get("mode", "")
        var weight: int = int(behavior.get("weight", 0))
        if priority.has(mode):
            priority[mode] += weight

    var hp_pct := 0.0
    if unit.max_hp > 0:
        hp_pct = float(unit.hp) / float(unit.max_hp)
    var hp_mod: Dictionary = weights_cfg.get("hp_modifiers", {})
    var defend_below := float(hp_mod.get("defend_below", 0.5))
    var defend_add := int(hp_mod.get("defend_add", 0))
    var flee_below := float(hp_mod.get("flee_below", 0.3))
    var flee_add := int(hp_mod.get("flee_add", 0))
    if hp_pct < defend_below:
        priority["defend"] += defend_add
    if hp_pct < flee_below:
        priority["flee"] += flee_add

    if unit.is_boss:
        var boss_mod: Dictionary = weights_cfg.get("boss_modifier", {})
        priority["aggressive"] += int(boss_mod.get("aggressive", 0))
        priority["attack"] += int(boss_mod.get("attack", 0))
        priority["defend"] += int(boss_mod.get("defend", 0))
        priority["flee"] += int(boss_mod.get("flee", 0))

    if not unit.role_id.is_empty():
        var roles: Dictionary = DataLoader.load_config("enemy_roles")
        var role: Dictionary = roles.get(unit.role_id, {})
        var role_priority: Dictionary = role.get("priority", {})
        for mode in priority.keys():
            priority[mode] += int(role_priority.get(mode, 0))

    return priority

static func choose_behavior(priority: Dictionary) -> String:
    var best := "aggressive"
    var best_score := -999999
    for mode in priority.keys():
        var score: int = int(priority.get(mode, 0))
        if score > best_score:
            best = mode
            best_score = score
    return best

static func decide_action(unit: Unit, board: BoardData, player: Unit) -> Dictionary:
    var can_attack := MovementSystem.can_attack(unit, player, board)
    var priority := calculate_priority(unit)
    var mode := choose_behavior(priority)

    if can_attack and mode != "flee":
        return {"type": "attack", "target": player.position}

    var moves := MovementSystem.get_valid_moves(unit, board)
    if moves.is_empty():
        return {"type": "wait"}

    match mode:
        "flee":
            return {"type": "move", "target": _choose_move_away(moves, player.position)}
        "defend":
            return {"type": "move", "target": _choose_defensive_tile(moves, board)}
        _:
            return {"type": "move", "target": _choose_move_toward(moves, player.position)}

static func decide_movement_target(unit: Unit, board: BoardData, focus: Vector2i) -> Vector2i:
    if unit == null or board == null:
        return Vector2i(-1, -1)
    var moves := MovementSystem.get_valid_moves(unit, board)
    if moves.is_empty():
        return unit.position
    var priority := calculate_priority(unit)
    var mode := choose_behavior(priority)
    match mode:
        "flee":
            return _choose_move_away(moves, focus)
        "defend":
            return _choose_defensive_tile(moves, board)
        _:
            return _choose_move_toward(moves, focus)

static func describe_intent(unit: Unit, board: BoardData, player: Unit) -> String:
    if unit == null or player == null:
        return "Waiting."
    if board != null and MovementSystem.can_attack(unit, player, board):
        return "Strike the Unranked."
    var priority := calculate_priority(unit)
    var mode := choose_behavior(priority)
    match mode:
        "flee":
            return "Pull away from danger."
        "defend":
            if board != null:
                var moves := MovementSystem.get_valid_moves(unit, board)
                if not moves.is_empty():
                    var tile = board.get_tile(_choose_defensive_tile(moves, board))
                    if tile != null and tile.terrain_id in ["blessed", "elevated"]:
                        return "Claim %s ground." % tile.terrain_id.capitalize()
            return "Hold a safer line."
        "attack":
            return "Close in for a killing blow."
        _:
            return "Advance with the law."

static func _choose_move_toward(moves: Array[Vector2i], target: Vector2i) -> Vector2i:
    var best: Vector2i = moves[0]
    var best_dist := _manhattan(best, target)
    for move in moves:
        var dist := _manhattan(move, target)
        if dist < best_dist:
            best = move
            best_dist = dist
    return best

static func _choose_move_away(moves: Array[Vector2i], target: Vector2i) -> Vector2i:
    var best: Vector2i = moves[0]
    var best_dist := _manhattan(best, target)
    for move in moves:
        var dist := _manhattan(move, target)
        if dist > best_dist:
            best = move
            best_dist = dist
    return best

static func _choose_defensive_tile(moves: Array[Vector2i], board: BoardData) -> Vector2i:
    var best: Vector2i = moves[0]
    var best_score := -999999
    for move in moves:
        var tile = board.get_tile(move)
        var score := 0
        if tile != null:
            var mod: Dictionary = tile.terrain_data.get("combat_mod", {})
            score += int(mod.get("damage_reduce", 0)) * 2
            score += int(mod.get("atk_bonus", 0))
        if score > best_score:
            best = move
            best_score = score
    return best

static func _manhattan(a: Vector2i, b: Vector2i) -> int:
    return abs(a.x - b.x) + abs(a.y - b.y)
