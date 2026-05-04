
extends Node

const EVENT_ATTACK_HIT = "attack_hit"
const EVENT_UNIT_KILLED = "unit_killed"
const EVENT_TURN_START = "turn_start"
const EVENT_UNIT_DAMAGED = "unit_damaged"
const EVENT_TICK = "tick"
const EVENT_ITEMS_CHANGED = "items_changed"

var _listeners: Dictionary = {}

func subscribe(event_type: String, callback: Callable, owner_obj: Object = null) -> void:
    if event_type.is_empty():
        return
    if not _listeners.has(event_type):
        _listeners[event_type] = []
    var entry = {
        "callback": callback,
        "owner_ref": weakref(owner_obj) if owner_obj != null else null,
    }
    _listeners[event_type].append(entry)

func unsubscribe(event_type: String, callback: Callable) -> void:
    if not _listeners.has(event_type):
        return
    var list: Array = _listeners[event_type]
    for i in range(list.size() - 1, -1, -1):
        if list[i]["callback"] == callback:
            list.remove_at(i)
    if list.is_empty():
        _listeners.erase(event_type)

func clear_owner(owner_obj: Object) -> void:
    if owner_obj == null:
        return
    for event_type in _listeners.keys():
        var list: Array = _listeners[event_type]
        for i in range(list.size() - 1, -1, -1):
            var ref = list[i]["owner_ref"]
            if ref != null and ref.get_ref() == owner_obj:
                list.remove_at(i)
        if list.is_empty():
            _listeners.erase(event_type)

func emit_event(event_type: String, payload: Dictionary = {}) -> void:
    if not _listeners.has(event_type):
        return
    _prune_event(event_type)
    var snapshot: Array = _listeners[event_type].duplicate()
    for entry in snapshot:
        var callback: Callable = entry["callback"]
        var owner_ref = entry["owner_ref"]
        if owner_ref != null and owner_ref.get_ref() == null:
            continue
        if callback.is_valid():
            callback.call(payload)

func _prune_event(event_type: String) -> void:
    var list: Array = _listeners.get(event_type, [])
    for i in range(list.size() - 1, -1, -1):
        var callback: Callable = list[i]["callback"]
        var owner_ref = list[i]["owner_ref"]
        if not callback.is_valid():
            list.remove_at(i)
            continue
        if owner_ref != null and owner_ref.get_ref() == null:
            list.remove_at(i)
    if list.is_empty():
        _listeners.erase(event_type)
    else:
        _listeners[event_type] = list
