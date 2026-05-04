extends Node
class_name ItemSystem


static func apply_items(unit: Unit, items_data: Array) -> void:
    unit.apply_items(items_data)
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
        _:
            return

static func _event_bus() -> Node:
    return Engine.get_main_loop().root.get_node("EventBus")
