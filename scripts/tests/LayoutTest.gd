extends Control

var _failed := false

func _ready() -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	var main := packed.instantiate() as RunController
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._on_choice_selected(0)
	await get_tree().process_frame
	main._on_choice_selected(0)
	await get_tree().process_frame
	main._on_choice_selected(0)
	await get_tree().process_frame
	await get_tree().process_frame

	var path_graph: Dictionary = main.game_state.run_state.get("path_graph", {})
	var available: Array = path_graph.get("available", [])
	if not main.path_map.visible:
		_fail("PathMap should be visible at run start")
	if available.is_empty():
		_fail("Path graph should offer at least one node")
	else:
		main._on_path_node_selected(str(available[0]))
		await get_tree().process_frame
		await get_tree().process_frame

	var rects: Dictionary = main.get_layout_rects()
	_assert_rect_inside(rects["board"], rects["viewport"], "BoardView")
	_assert_rect_inside(rects["hud"], rects["viewport"], "BottomBar")
	_assert_no_overlap(rects["board"], rects["hud"], "BoardView", "BottomBar")

	if _failed:
		push_error("LayoutTest failed")
		get_tree().quit(1)
		return
	print("LayoutTest passed")
	get_tree().quit()

func _assert_rect_inside(inner: Rect2, outer: Rect2, label: String) -> void:
	var inner_end := inner.position + inner.size
	var outer_end := outer.position + outer.size
	if inner.position.x < outer.position.x or inner.position.y < outer.position.y:
		_fail("%s starts outside viewport: %s" % [label, inner])
	if inner_end.x > outer_end.x or inner_end.y > outer_end.y:
		_fail("%s ends outside viewport: %s" % [label, inner])

func _assert_no_overlap(a: Rect2, b: Rect2, a_label: String, b_label: String) -> void:
	if a.intersects(b):
		_fail("%s overlaps %s: %s / %s" % [a_label, b_label, a, b])

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
