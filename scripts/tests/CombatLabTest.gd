extends Node


func _ready() -> void:
	var scene: PackedScene = load("res://scenes/tests/CombatLab.tscn")
	if scene == null:
		push_error("CombatLabTest failed: scene could not be loaded")
		return
	var lab: Control = scene.instantiate()
	add_child(lab)
	await get_tree().process_frame

	var board: BoardData = lab.board
	if board == null:
		push_error("CombatLabTest failed: lab board was not created")
		return
	if board.rows != 10 or board.cols != 10:
		push_error("CombatLabTest failed: board should be 10x10")
	if board.get_tile(Vector2i(4, 9)).piece != lab.player:
		push_error("CombatLabTest failed: player should start at bottom center")
	if board.get_tile(Vector2i(4, 0)).piece != lab.dummy:
		push_error("CombatLabTest failed: dummy should start at top center")
	if lab.dummy.hp != 0 or lab.dummy.max_hp != 0:
		push_error("CombatLabTest failed: dummy should be a zero-health damage sink")
	if lab.unit_grid.get_child_count() <= 0:
		push_error("CombatLabTest failed: unit menu should be populated")
	if lab.item_grid.get_child_count() <= 0:
		push_error("CombatLabTest failed: item menu should be populated")
	if lab.skill_grid.get_child_count() <= 0:
		push_error("CombatLabTest failed: skill menu should be populated")
	lab._bleed_dummy()
	lab._burn_dummy()
	lab._shield_self()
	lab._empower_self()
	lab._control_dummy()
	lab._curse_dummy()
	lab._preview_skill_vfx()
	lab._preview_aura_threat()
	lab._preview_rarity_events()
	lab._strike_dummy()
	await get_tree().process_frame
	if not lab.dummy.status_effects.has("bleed"):
		push_error("CombatLabTest failed: bleed indicator status should apply to dummy")
	if not lab.player.status_effects.has("shielded"):
		push_error("CombatLabTest failed: shield indicator status should apply to player")
	print("CombatLabTest passed")
