extends RefCounted
class_name RunPathGenerator

static func generate_path(rng: RandomNumberGenerator, config: Dictionary) -> Dictionary:
    var node_types: Dictionary = config.get("node_types", {})
    var floors: Array = config.get("floors", [])
    var nodes: Dictionary = {}
    var floor_ids: Array = []
    var previous_ids: Array = []

    for floor_cfg in floors:
        if typeof(floor_cfg) != TYPE_DICTIONARY:
            continue
        var floor_index: int = int(floor_cfg.get("floor", floor_ids.size() + 1))
        var slots: Array = floor_cfg.get("slots", ["combat"])
        var ids: Array = []
        for slot_index in range(slots.size()):
            var node_type: String = str(slots[slot_index])
            var type_cfg: Dictionary = node_types.get(node_type, {})
            var node_id := "f%d_%d_%s" % [floor_index, slot_index, node_type]
            nodes[node_id] = {
                "id": node_id,
                "floor": floor_index,
                "type": node_type,
                "label": str(type_cfg.get("label", node_type.capitalize())),
                "icon": str(type_cfg.get("icon", "Node")),
                "summary": str(type_cfg.get("summary", "The Plain waits.")),
                "reward": str(type_cfg.get("reward", "none")),
                "next": []
            }
            ids.append(node_id)
        if not previous_ids.is_empty():
            _connect_layers(nodes, previous_ids, ids, rng)
        floor_ids.append(ids)
        previous_ids = ids

    var available: Array = []
    if not floor_ids.is_empty():
        var first_floor: Array = floor_ids[0]
        var offered: int = int(config.get("run", {}).get("starting_available", first_floor.size()))
        available = first_floor.slice(0, min(offered, first_floor.size()))

    return {
        "zone_name": str(config.get("run", {}).get("zone_name", "The Outer Plain")),
        "nodes": nodes,
        "floors": floor_ids,
        "available": available,
        "completed": [],
        "current": ""
    }

static func complete_node(path_graph: Dictionary, node_id: String) -> Dictionary:
    var completed: Array = path_graph.get("completed", [])
    if not node_id in completed:
        completed.append(node_id)
    path_graph["completed"] = completed

    var nodes: Dictionary = path_graph.get("nodes", {})
    var node: Dictionary = nodes.get(node_id, {})
    path_graph["available"] = node.get("next", [])
    path_graph["current"] = ""
    return path_graph

static func get_node(path_graph: Dictionary, node_id: String) -> Dictionary:
    var nodes: Dictionary = path_graph.get("nodes", {})
    return nodes.get(node_id, {})

static func _connect_layers(nodes: Dictionary, previous_ids: Array, next_ids: Array, rng: RandomNumberGenerator) -> void:
    if next_ids.is_empty():
        return
    for id in previous_ids:
        var count: int = 1
        if next_ids.size() > 1:
            count = rng.randi_range(1, min(2, next_ids.size()))
        var choices: Array = next_ids.duplicate()
        choices.shuffle()
        nodes[id]["next"] = choices.slice(0, count)

    for next_id in next_ids:
        var has_incoming := false
        for id in previous_ids:
            var outgoing: Array = nodes[id].get("next", [])
            if next_id in outgoing:
                has_incoming = true
                break
        if not has_incoming:
            var source_id: String = str(previous_ids[rng.randi_range(0, previous_ids.size() - 1)])
            var outgoing: Array = nodes[source_id].get("next", [])
            outgoing.append(next_id)
            nodes[source_id]["next"] = outgoing
