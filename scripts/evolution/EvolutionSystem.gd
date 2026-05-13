extends Node
class_name EvolutionSystem


static func check_and_evolve(player: Unit) -> bool:
    if player.next_form.is_empty():
        return false
    if player.kills < player.evolve_kills:
        return false
    return _evolve(player)

static func _evolve(player: Unit) -> bool:
    var pieces: Dictionary = DataLoader.load_config("player_pieces")
    var next_id: String = player.next_form
    if not pieces.has(next_id):
        return false

    var new_data: Dictionary = pieces[next_id]
    var current_hp := player.hp
    var items_copy := player.items.duplicate(true)
    var evo_rules: Dictionary = DataLoader.load_config("evolution_rules")
    var heal_amount: int = int(evo_rules.get("heal_on_evolve", 0))

    player.init_from_piece(next_id, new_data)
    player.apply_items(items_copy)
    player.hp = min(player.max_hp, current_hp + heal_amount)
    player.ap = player.max_ap
    return true
