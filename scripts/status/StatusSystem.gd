extends Node
class_name StatusSystem


static func apply_status(unit: Unit, status_id: String) -> void:
    var config: Dictionary = DataLoader.load_config("statuses")
    if not config.has(status_id):
        return
    var entry: Dictionary = config[status_id]
    var duration: int = int(entry.get("duration", 0))
    var damage: int = int(entry.get("damage_per_tick", 0))
    if duration <= 0:
        return
    unit.status_effects[status_id] = {
        "remaining": duration,
        "damage_per_tick": damage,
        "damage_reduce": int(entry.get("damage_reduce", 0))
    }

static func tick_all(units: Array) -> void:
    for unit in units:
        if unit == null:
            continue
        var keys: Array = unit.status_effects.keys()
        for status_id in keys:
            var data: Dictionary = unit.status_effects.get(status_id, {})
            var remaining: int = int(data.get("remaining", 0))
            var damage: int = int(data.get("damage_per_tick", 0))
            if damage > 0:
                var killed: bool = unit.apply_damage(damage)
                _event_bus().emit_event(_event_bus().EVENT_UNIT_DAMAGED, {
                    "attacker": null,
                    "defender": unit,
                    "result": {"final": damage, "status": status_id}
                })
                if killed:
                    _event_bus().emit_event(_event_bus().EVENT_UNIT_KILLED, {
                        "killer": null,
                        "victim": unit
                    })
            remaining -= 1
            if remaining <= 0:
                unit.status_effects.erase(status_id)
            else:
                data["remaining"] = remaining
                unit.status_effects[status_id] = data

static func _event_bus() -> Node:
    return Engine.get_main_loop().root.get_node("EventBus")
