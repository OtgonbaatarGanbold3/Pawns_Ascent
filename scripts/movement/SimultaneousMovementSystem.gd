extends Node
class_name SimultaneousMovementSystem


static func build_enemy_move_plans(enemies: Array, board: BoardData, player: Unit, player_target: Vector2i) -> Array:
	var plans: Array = []
	if board == null or player == null:
		return plans
	for enemy in enemies:
		var unit: Unit = enemy as Unit
		if unit == null or unit.is_dead():
			continue
		var target := AISystem.decide_movement_target(unit, board, player_target)
		if target == Vector2i(-1, -1):
			target = unit.position
		plans.append({
			"unit": unit,
			"from": unit.position,
			"to": target,
			"is_player": false
		})
	return plans

static func resolve_move_plans(board: BoardData, plans: Array) -> Dictionary:
	var result := {
		"approved": [],
		"blocked": []
	}
	if board == null:
		return result

	var from_keys := {}
	for plan in plans:
		var unit: Unit = plan.get("unit", null) as Unit
		if unit == null:
			continue
		from_keys[_key(unit.position)] = unit

	var candidates_by_target := {}
	for plan in plans:
		var unit: Unit = plan.get("unit", null) as Unit
		var target: Vector2i = plan.get("to", Vector2i(-1, -1))
		if unit == null or unit.is_dead():
			continue
		if target == unit.position:
			result["blocked"].append(_blocked(plan, "held"))
			continue
		if not board.is_in_bounds(target):
			result["blocked"].append(_blocked(plan, "out_of_bounds"))
			continue
		var tile: Tile = board.get_tile(target)
		if tile == null or MovementSystem.is_blocked(tile):
			result["blocked"].append(_blocked(plan, "blocked_tile"))
			continue
		if tile.piece != null and not from_keys.has(_key(target)):
			result["blocked"].append(_blocked(plan, "occupied"))
			continue
		var target_key := _key(target)
		if not candidates_by_target.has(target_key):
			candidates_by_target[target_key] = []
		candidates_by_target[target_key].append(plan)

	for target_key in candidates_by_target.keys():
		var candidates: Array = candidates_by_target[target_key]
		if candidates.size() == 1:
			result["approved"].append(candidates[0])
			continue
		var winner: Dictionary = _pick_contest_winner(candidates)
		if winner.is_empty():
			for plan in candidates:
				result["blocked"].append(_blocked(plan, "contested"))
			continue
		result["approved"].append(winner)
		for plan in candidates:
			if plan != winner:
				result["blocked"].append(_blocked(plan, "contested"))

	return result

static func _pick_contest_winner(candidates: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -999999
	var tied := false
	for plan in candidates:
		var unit: Unit = plan.get("unit", null) as Unit
		if unit == null:
			continue
		var score := unit.spd
		if bool(plan.get("is_player", false)):
			score += 1000
		if score > best_score:
			best = plan
			best_score = score
			tied = false
		elif score == best_score:
			tied = true
	if tied and not bool(best.get("is_player", false)):
		return {}
	return best

static func _blocked(plan: Dictionary, reason: String) -> Dictionary:
	var copy := plan.duplicate(true)
	copy["reason"] = reason
	return copy

static func _key(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]
