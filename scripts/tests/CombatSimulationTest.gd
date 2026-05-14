extends Node

const SETUPS := [
	{"mode": "legacy", "theme": "neutral", "difficulty": "wanderer", "with_ally": true},
	{"mode": "legacy", "theme": "thunder", "difficulty": "wanderer"},
	{"mode": "legacy", "theme": "volcanic", "difficulty": "wanderer"},
	{"mode": "legacy", "theme": "ocean", "difficulty": "wanderer"},
	{"mode": "legacy", "theme": "frost", "difficulty": "wanderer"},
	{"mode": "legacy", "theme": "void", "difficulty": "wanderer"}
]
const MAX_STEPS := 120

var _failed := false

func _ready() -> void:
	var game_state: Node = get_node("/root/GameState")
	var original_meta: Dictionary = game_state.meta_state.duplicate(true)
	var costs: Dictionary = DataLoader.load_config("action_costs")
	costs["enemy_action_delay_ms"] = 0
	costs["move_animation_seconds"] = 0.01
	for setup in SETUPS:
		await _simulate_first_combat(setup)
	game_state.meta_state = original_meta
	game_state.save_meta_state()
	if _failed:
		push_error("CombatSimulationTest failed")
		get_tree().quit(1)
		return
	print("CombatSimulationTest passed")
	get_tree().quit()

func _simulate_first_combat(setup: Dictionary) -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	var main := packed.instantiate() as RunController
	add_child(main)
	await _frames(2)
	main.start_run(setup)
	await _frames(2)
	if bool(setup.get("with_ally", false)):
		main._add_active_ally("blade_knight")

	var path_graph: Dictionary = main.game_state.run_state.get("path_graph", {})
	var available: Array = path_graph.get("available", [])
	if available.is_empty():
		_fail("No path nodes available for combat simulation")
		return
	main._on_path_node_selected(str(available[0]))
	await _frames(2)
	if bool(setup.get("with_ally", false)) and main.game_state.run_state.get("allies", []).is_empty():
		_fail("Contract ally did not spawn into combat")
		main.queue_free()
		return

	var steps := 0
	while steps < MAX_STEPS and not main.item_draft.visible and not main.end_screen.visible:
		steps += 1
		var player: Unit = main.game_state.run_state.get("player", null) as Unit
		var board: BoardData = main.game_state.run_state.get("board", null) as BoardData
		var enemies: Array = main.game_state.run_state.get("enemies", [])
		if player == null or board == null:
			_fail("Combat simulation lost player or board")
			return
		if player.is_dead():
			break
		if enemies.is_empty():
			break
		if main.turn_system.phase != TurnSystem.Phase.PLAYER:
			await _frames(4)
			continue
		await _take_player_action(main, player, board, enemies)
		await _frames(4)

	if steps >= MAX_STEPS:
		_fail("Combat simulation stalled after %d steps for %s" % [MAX_STEPS, str(setup.get("theme", "neutral"))])
	if main.game_state.run_state.get("enemies", []).size() > 0 and not main.end_screen.visible:
		_fail("Combat simulation did not clear enemies for %s" % str(setup.get("theme", "neutral")))
	main.queue_free()
	await _frames(2)

func _take_player_action(main: RunController, player: Unit, board: BoardData, enemies: Array) -> void:
	var target := _nearest_enemy(player, enemies)
	if target == null:
		return
	if MovementSystem.can_attack(player, target, board):
		main._attack(player, target)
		await main._after_player_action(false)
		return
	var moves := MovementSystem.get_valid_moves(player, board)
	if moves.is_empty():
		main._on_end_turn_pressed()
		return
	var destination := _best_move_toward(moves, target.position)
	await main._resolve_player_move(player, destination)
	await main._after_player_action(main._simultaneous_move_enabled())

func _nearest_enemy(player: Unit, enemies: Array) -> Unit:
	var best: Unit = null
	var best_dist := 999999
	for enemy_value in enemies:
		var enemy: Unit = enemy_value as Unit
		if enemy == null or enemy.is_dead():
			continue
		var dist: int = abs(player.position.x - enemy.position.x) + abs(player.position.y - enemy.position.y)
		if dist < best_dist:
			best = enemy
			best_dist = dist
	return best

func _best_move_toward(moves: Array[Vector2i], target: Vector2i) -> Vector2i:
	var best: Vector2i = moves[0]
	var best_dist := 999999
	for move in moves:
		var dist: int = abs(move.x - target.x) + abs(move.y - target.y)
		if dist < best_dist:
			best = move
			best_dist = dist
	return best

func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
