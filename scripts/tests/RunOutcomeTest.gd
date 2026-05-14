extends Node

var _failed := false

func _ready() -> void:
	var outcomes: Dictionary = DataLoader.load_config("run_outcomes")
	var node_rewards: Dictionary = outcomes.get("node_rewards", {})
	_assert(node_rewards.has("combat"), "combat reward should exist")
	_assert(node_rewards.has("elite"), "elite reward should exist")
	_assert(node_rewards.has("boss"), "boss reward should exist")

	var combat: Dictionary = node_rewards.get("combat", {})
	var combat_effects: Dictionary = combat.get("effects", {})
	var combat_gold_range: Array = combat_effects.get("gold_range", [])
	var combat_score_events: Array = combat_effects.get("score_events", [])
	_assert(combat.get("draft_reward_type", "") == "draft", "combat should award a normal draft")
	_assert(combat_gold_range.size() == 2, "combat should award a gold range")
	_assert("floor_clear" in combat_score_events, "combat should score floor clear")

	var rest_options: Array = outcomes.get("rest_options", [])
	_assert(rest_options.size() >= 2, "rest should offer at least two choices")

	var story_events: Array = outcomes.get("story_events", [])
	_assert(not story_events.is_empty(), "story events should exist")
	for event in story_events:
		var story: Dictionary = event
		var choices: Array = story.get("choices", [])
		_assert(choices.size() >= 2, "story events should offer choices")

	var score_manager: Node = Engine.get_main_loop().root.get_node("ScoreManager")
	score_manager.reset()
	score_manager.add_score("floor_clear")
	var final_score: int = score_manager.get_final_score({"current_floor": 3})
	_assert(final_score > score_manager.get_base_score(), "final score should include floor multiplier")

	var run_themes: Dictionary = DataLoader.load_config("run_themes")
	_assert(run_themes.get("modes", {}).has("legacy"), "legacy mode should exist")
	_assert(run_themes.get("themes", {}).has("neutral"), "neutral theme should exist")
	_assert(run_themes.get("themes", {}).has("void"), "void theme should exist")
	_assert(run_themes.get("difficulties", {}).has("unranked"), "unranked difficulty should exist")
	for theme_id in ["thunder", "volcanic", "ocean", "frost", "void"]:
		var theme: Dictionary = run_themes.get("themes", {}).get(theme_id, {})
		_assert(theme.has("theme_mechanic"), "theme %s should define theme_mechanic" % theme_id)
	var neutral_score: int = score_manager.get_final_score({
		"current_floor": 1,
		"setup": {"theme": "neutral", "difficulty": "wanderer"}
	})
	var hard_score: int = score_manager.get_final_score({
		"current_floor": 1,
		"setup": {"theme": "void", "difficulty": "unranked"}
	})
	_assert(hard_score > neutral_score, "theme and difficulty should increase score")
	var multipliers: Array = score_manager.get_multiplier_breakdown({
		"current_floor": 1,
		"setup": {"theme": "void", "difficulty": "unranked"}
	})
	_assert(multipliers.size() >= 3, "score breakdown should include floor, theme, and difficulty")

	var run_nodes: Dictionary = DataLoader.load_config("run_nodes")
	var node_types: Dictionary = run_nodes.get("node_types", {})
	_assert(node_types.has("shrine"), "shrine node type should exist")
	_assert(node_types.has("shop"), "shop node type should exist")
	_assert(node_types.has("ally_hire"), "ally hire node type should exist")

	var perks: Dictionary = DataLoader.load_config("perks")
	_assert(perks.size() >= 3, "perk pool should have at least three options")
	for perk_id in perks.keys():
		var perk: Dictionary = perks[perk_id]
		var effects: Dictionary = perk.get("effects", {})
		_assert(not effects.is_empty(), "perk %s should define effects" % perk_id)

	var items: Dictionary = DataLoader.load_config("items")
	for trigger_id in ["on_hit_knockback", "on_move_extra", "on_turn_ap", "on_adj_defend", "on_low_hp_buff"]:
		_assert(_has_item_trigger(items, trigger_id), "item trigger %s should be represented" % trigger_id)

	var roles: Dictionary = DataLoader.load_config("enemy_roles")
	for role_id in ["pursuer", "keeper", "coward", "warden", "zealot"]:
		_assert(roles.has(role_id), "enemy role %s should exist" % role_id)

	var ally_units: Dictionary = DataLoader.load_config("ally_units")
	_assert(ally_units.size() >= 3, "ally unit pool should have at least three contracts")
	for ally_id in ally_units.keys():
		var ally: Dictionary = ally_units[ally_id]
		_assert(not str(ally.get("piece", "")).is_empty(), "ally %s should define a piece" % ally_id)
		_assert(int(ally.get("duration", 0)) > 0, "ally %s should define a duration" % ally_id)
		_assert(roles.has(str(ally.get("role", ""))), "ally %s role should exist" % ally_id)
	var hire_options: Array = outcomes.get("ally_hire_options", [])
	for option in hire_options:
		var hire: Dictionary = option
		var effects: Dictionary = hire.get("effects", {})
		var ally_id: String = str(effects.get("ally_id", ""))
		_assert(ally_id.is_empty() or ally_units.has(ally_id), "hire option should reference an ally")

	var templates_cfg: Dictionary = DataLoader.load_config("encounter_templates")
	var templates: Array = templates_cfg.get("templates", [])
	_assert(templates.size() >= 4, "encounter template pool should have authored patterns")
	for template in templates:
		var entry: Dictionary = template
		_assert(not str(entry.get("id", "")).is_empty(), "encounter template should have an id")
		_assert(not entry.get("enemies", []).is_empty(), "encounter template should define enemies")
		for enemy in entry.get("enemies", []):
			var enemy_spec: Dictionary = enemy
			var role_id: String = str(enemy_spec.get("role", ""))
			_assert(role_id.is_empty() or roles.has(role_id), "template enemy role should exist")

	if _failed:
		push_error("RunOutcomeTest failed")
		get_tree().quit(1)
		return
	print("RunOutcomeTest passed")
	get_tree().quit()

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)

func _has_item_trigger(items: Dictionary, trigger_id: String) -> bool:
	for item_id in items.keys():
		var item: Dictionary = items[item_id]
		if str(item.get("trigger_id", "")) == trigger_id:
			return true
	return false
