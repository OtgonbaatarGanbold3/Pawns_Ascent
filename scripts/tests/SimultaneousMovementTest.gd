extends Node


func _ready() -> void:
	var pieces: Dictionary = DataLoader.load_config("pieces")
	var board := BoardData.new()
	board.init_board(7, 7)
	for row in range(board.rows):
		for col in range(board.cols):
			var tile := Tile.new()
			tile.init_from_terrain("normal", {})
			board.set_tile(Vector2i(col, row), tile)

	var player := Unit.new()
	player.init_from_piece("pawn", pieces.get("pawn", {}))
	player.is_player = true
	board.set_unit(Vector2i(2, 4), player)

	var enemy := Unit.new()
	enemy.init_from_piece("pawn", pieces.get("pawn", {}))
	board.set_unit(Vector2i(4, 4), enemy)

	var plans: Array = [{
		"unit": player,
		"from": player.position,
		"to": Vector2i(3, 4),
		"is_player": true
	}]
	plans.append_array(SimultaneousMovementSystem.build_enemy_move_plans([enemy], board, player, Vector2i(3, 4)))
	var resolved: Dictionary = SimultaneousMovementSystem.resolve_move_plans(board, plans)
	var approved: Array = resolved.get("approved", [])
	var enemy_blocked := false
	for blocked in resolved.get("blocked", []):
		if blocked.get("unit", null) == enemy and blocked.get("reason", "") == "contested":
			enemy_blocked = true
	if not _has_plan_for(approved, player, Vector2i(3, 4)):
		push_error("SimultaneousMovementTest failed: player plan was not approved")
	if not enemy_blocked:
		push_error("SimultaneousMovementTest failed: player should win a shared target contest")

	var side_enemy := Unit.new()
	side_enemy.init_from_piece("pawn", pieces.get("pawn", {}))
	board.set_unit(Vector2i(5, 5), side_enemy)
	var chase_plans := SimultaneousMovementSystem.build_enemy_move_plans([side_enemy], board, player, Vector2i(3, 4))
	if chase_plans.is_empty():
		push_error("SimultaneousMovementTest failed: enemy did not plan a chase move")
	else:
		var target: Vector2i = chase_plans[0].get("to", side_enemy.position)
		if _manhattan(target, Vector2i(3, 4)) >= _manhattan(side_enemy.position, Vector2i(3, 4)):
			push_error("SimultaneousMovementTest failed: enemy chase did not close distance")
	print("SimultaneousMovementTest passed")

func _has_plan_for(plans: Array, unit: Unit, target: Vector2i) -> bool:
	for plan in plans:
		if plan.get("unit", null) == unit and plan.get("to", Vector2i(-1, -1)) == target:
			return true
	return false

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
