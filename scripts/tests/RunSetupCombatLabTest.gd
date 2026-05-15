extends Node


func _ready() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	if scene == null:
		push_error("RunSetupCombatLabTest failed: Main scene could not be loaded")
		return
	var main: Control = scene.instantiate()
	add_child(main)
	await get_tree().process_frame

	var options: Array = main._pending_choice_options
	if options.is_empty():
		push_error("RunSetupCombatLabTest failed: setup options were not shown")
		return
	var lab_index := -1
	for i in range(options.size()):
		if str(options[i].get("action", "")) == "combat_lab":
			lab_index = i
			break
	if lab_index < 0:
		push_error("RunSetupCombatLabTest failed: Combat Lab option missing from run selection")
		return

	var lab_option: Dictionary = options[lab_index]
	if str(lab_option.get("label", "")) != "Combat Lab":
		push_error("RunSetupCombatLabTest failed: Combat Lab option label is wrong")
		return
	print("RunSetupCombatLabTest passed")
