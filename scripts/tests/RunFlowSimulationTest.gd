extends Node

const SETUPS := [
	{"mode": 0, "theme": 0, "difficulty": 0, "label": "Legacy Neutral Wanderer"},
	{"mode": 1, "theme": 1, "difficulty": 1, "label": "Themed Thunder Exile"},
	{"mode": 1, "theme": 5, "difficulty": 2, "label": "Themed Void Unranked"}
]

var _failed := false

func _ready() -> void:
	var game_state: Node = get_node("/root/GameState")
	var original_meta: Dictionary = game_state.meta_state.duplicate(true)
	for setup in SETUPS:
		await _simulate_run(setup)
	game_state.meta_state = original_meta
	game_state.save_meta_state()
	if _failed:
		push_error("RunFlowSimulationTest failed")
		get_tree().quit(1)
		return
	print("RunFlowSimulationTest passed")
	get_tree().quit()

func _simulate_run(setup: Dictionary) -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	var main := packed.instantiate() as RunController
	add_child(main)
	await _frames(2)

	_choose(main, int(setup.get("mode", 0)))
	_choose(main, int(setup.get("theme", 0)))
	_choose(main, int(setup.get("difficulty", 0)))
	await _frames(2)

	var visited := 0
	while visited < 12 and not main.end_screen.visible:
		var path_graph: Dictionary = main.game_state.run_state.get("path_graph", {})
		var available: Array = path_graph.get("available", [])
		if available.is_empty():
			break
		main._on_path_node_selected(str(available[0]))
		await _frames(2)
		await _resolve_current_node(main)
		visited += 1
		await _frames(2)

	if not main.end_screen.visible:
		_fail("%s did not reach an end screen after %d nodes" % [str(setup.get("label", "Run")), visited])
	if int(main.score_manager.get_base_score()) <= 0:
		_fail("%s ended without scoring" % str(setup.get("label", "Run")))
	main.queue_free()
	await _frames(2)

func _resolve_current_node(main: RunController) -> void:
	var node: Dictionary = main.game_state.run_state.get("current_node", {})
	var node_type: String = str(node.get("type", ""))
	match node_type:
		"combat", "elite", "ambush":
			main._complete_encounter("simulation")
			await _frames(1)
			_clear_overlay_or_draft(main)
		"boss":
			main._complete_encounter("simulation")
			await _frames(1)
			_choose(main, 1)
		"relic":
			_clear_overlay_or_draft(main)
		"rest", "story", "shrine":
			_choose(main, 0)
			await _frames(1)
			_clear_overlay_or_draft(main)
		_:
			main._complete_current_node()

func _clear_overlay_or_draft(main: RunController) -> void:
	var guard := 0
	while guard < 8:
		guard += 1
		if main.end_screen.visible:
			return
		if main.item_draft.visible:
			main._on_draft_skipped()
			await _frames(1)
			continue
		if main._choice_overlay != null and main._choice_overlay.visible:
			_choose(main, 0)
			await _frames(1)
			continue
		break

func _choose(main: RunController, index: int) -> void:
	main._on_choice_selected(index)

func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
