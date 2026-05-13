extends Node
class_name ItemSystem


static func apply_items(unit: Unit, items_data: Array) -> void:
    unit.apply_items(items_data)
    unit.trigger_flags["move_range_bonus"] = 0
    _event_bus().clear_owner(unit)
    for item in items_data:
        _register_trigger(unit, item)
    _event_bus().emit_event(_event_bus().EVENT_ITEMS_CHANGED, {"unit": unit})

static func _register_trigger(unit: Unit, item: Dictionary) -> void:
    var trigger_id: String = item.get("trigger_id", "")
    if trigger_id.is_empty():
        return
    match trigger_id:
        "on_hit_bleed":
            var cb = func(payload: Dictionary) -> void:
                var attacker: Unit = payload.get("attacker", null)
                var defender: Unit = payload.get("defender", null)
                if attacker != unit or defender == null:
                    return
                StatusSystem.apply_status(defender, "bleed")
            _event_bus().subscribe(_event_bus().EVENT_ATTACK_HIT, cb, unit)
        "on_kill_heal":
            var cb = func(payload: Dictionary) -> void:
                var killer: Unit = payload.get("killer", null)
                if killer != unit:
                    return
                var amount: int = int(item.get("trigger_value", 0))
                if amount <= 0:
                    return
                unit.hp = min(unit.hp + amount, unit.max_hp)
            _event_bus().subscribe(_event_bus().EVENT_UNIT_KILLED, cb, unit)
        "on_hit_knockback":
            var cb = func(payload: Dictionary) -> void:
                var attacker: Unit = payload.get("attacker", null)
                var defender: Unit = payload.get("defender", null)
                var board: BoardData = payload.get("board", null) as BoardData
                if attacker != unit or defender == null or board == null:
                    return
                _push_defender(attacker, defender, board, int(item.get("trigger_value", 1)))
            _event_bus().subscribe(_event_bus().EVENT_ATTACK_HIT, cb, unit)
        "on_move_extra":
            unit.trigger_flags["move_range_bonus"] = max(
                int(unit.trigger_flags.get("move_range_bonus", 0)),
                int(item.get("trigger_value", 2))
            )
        "on_turn_ap":
            var cb = func(payload: Dictionary) -> void:
                var turn_unit: Unit = payload.get("unit", null)
                if turn_unit != unit:
                    return
                unit.ap += max(1, int(item.get("trigger_value", 1)))
            _event_bus().subscribe(_event_bus().EVENT_TURN_START, cb, unit)
        "on_adj_defend":
            var cb = func(payload: Dictionary) -> void:
                var turn_unit: Unit = payload.get("unit", null)
                var board: BoardData = payload.get("board", null) as BoardData
                if turn_unit != unit or board == null:
                    return
                if _has_adjacent_enemy(unit, board):
                    StatusSystem.apply_status(unit, "shielded")
            _event_bus().subscribe(_event_bus().EVENT_TURN_START, cb, unit)
        "on_low_hp_buff":
            var cb = func(payload: Dictionary) -> void:
                var defender: Unit = payload.get("defender", null)
                if defender != unit or unit.max_hp <= 0:
                    return
                var flag_key := "low_hp_buff_%s" % str(item.get("id", item.get("display_name", "item")))
                if bool(unit.trigger_flags.get(flag_key, false)):
                    return
                var threshold: float = float(item.get("threshold", 0.3))
                if float(unit.hp) / float(unit.max_hp) > threshold:
                    return
                unit.trigger_stat_bonuses["atk"] = int(unit.trigger_stat_bonuses.get("atk", 0)) + max(1, int(item.get("trigger_value", 2)))
                unit.trigger_flags[flag_key] = true
                unit.apply_items(unit.items)
            _event_bus().subscribe(_event_bus().EVENT_UNIT_DAMAGED, cb, unit)
        _:
            return

static func _event_bus() -> Node:
    return Engine.get_main_loop().root.get_node("EventBus")

static func _push_defender(attacker: Unit, defender: Unit, board: BoardData, distance: int) -> void:
    var direction := defender.position - attacker.position
    direction.x = clamp(direction.x, -1, 1)
    direction.y = clamp(direction.y, -1, 1)
    if direction == Vector2i.ZERO:
        return
    var target := defender.position
    for i in range(max(1, distance)):
        var next := target + direction
        if not board.is_in_bounds(next):
            break
        var tile: Tile = board.get_tile(next)
        if tile == null or tile.piece != null or MovementSystem.is_blocked(tile):
            break
        target = next
    if target == defender.position:
        return
    board.clear_unit(defender.position)
    board.set_unit(target, defender)

static func _has_adjacent_enemy(unit: Unit, board: BoardData) -> bool:
    for pos in MovementSystem.get_adjacent_positions(unit.position):
        var tile: Tile = board.get_tile(pos)
        if tile == null or tile.piece == null:
            continue
        if not _is_friendly(unit, tile.piece):
            return true
    return false

static func _is_friendly(a: Unit, b: Unit) -> bool:
    if a.is_player and b.is_player:
        return true
    if a.is_ally and (b.is_player or b.is_ally):
        return true
    if not a.is_player and not a.is_ally and not b.is_player and not b.is_ally:
        return true
    return false
