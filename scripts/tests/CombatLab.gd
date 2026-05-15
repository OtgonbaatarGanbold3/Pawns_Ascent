extends Control

const BOARD_ROWS := 10
const BOARD_COLS := 10
const PLAYER_START := Vector2i(4, 9)
const DUMMY_START := Vector2i(4, 0)
const MAX_TEST_ITEMS := 6
const OUTER_MARGIN := 18
const ROOT_GAP := 18
const BOARD_COLUMN_GAP := 10
const SIDE_PANEL_WIDTH := 370
const LOG_HEIGHT := 112
const TITLE_HEIGHT := 34
const MIN_TILE_SIZE := 36
const MAX_TILE_SIZE := 112

@onready var board_view: BoardView = $Root/BoardColumn/BoardFrame/BoardView
@onready var board_frame: PanelContainer = $Root/BoardColumn/BoardFrame
@onready var stats_label: Label = $Root/SidePanel/Scroll/Controls/StatsLabel
@onready var unit_grid: GridContainer = $Root/SidePanel/Scroll/Controls/UnitGrid
@onready var item_grid: GridContainer = $Root/SidePanel/Scroll/Controls/ItemGrid
@onready var skill_grid: GridContainer = $Root/SidePanel/Scroll/Controls/SkillGrid
@onready var reset_button: Button = $Root/SidePanel/Scroll/Controls/ResetButton
@onready var clear_items_button: Button = $Root/SidePanel/Scroll/Controls/ClearItemsButton
@onready var log_label: RichTextLabel = $Root/BoardColumn/Log

var board: BoardData
var player: Unit
var dummy: Unit
var selected: Unit
var rng := RandomNumberGenerator.new()
var item_ids: Array[String] = []

func _ready() -> void:
	rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup_layout()
	_build_buttons()
	reset_button.pressed.connect(_reset_lab)
	clear_items_button.pressed.connect(_clear_items)
	board_view.tile_clicked.connect(_on_tile_clicked)
	board_view.tile_hovered.connect(_on_tile_hovered)
	resized.connect(_on_resized)
	_reset_lab()

func _setup_layout() -> void:
	$Background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Root.offset_left = OUTER_MARGIN
	$Root.offset_top = OUTER_MARGIN
	$Root.offset_right = -OUTER_MARGIN
	$Root.offset_bottom = -OUTER_MARGIN
	$Root.add_theme_constant_override("separation", 18)
	$Root/BoardColumn.add_theme_constant_override("separation", 10)
	$Root/SidePanel.custom_minimum_size = Vector2(370, 0)
	$Root/SidePanel/Scroll/Controls.add_theme_constant_override("separation", 10)
	board_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	unit_grid.columns = 2
	item_grid.columns = 1
	skill_grid.columns = 1
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.custom_minimum_size = Vector2(0, LOG_HEIGHT)

func _build_buttons() -> void:
	var pieces: Dictionary = DataLoader.load_config("player_pieces")
	for piece_id in pieces.keys():
		var button := Button.new()
		button.text = str(pieces[piece_id].get("display_name", piece_id))
		button.tooltip_text = _piece_tooltip(piece_id, pieces[piece_id])
		button.pressed.connect(_select_unit.bind(str(piece_id)))
		unit_grid.add_child(button)

	var items: Dictionary = DataLoader.load_config("items")
	for item_id in items.keys():
		item_ids.append(str(item_id))
		var item: Dictionary = items[item_id]
		var button := Button.new()
		button.text = str(item.get("display_name", item_id))
		button.tooltip_text = _item_tooltip(item_id, item)
		button.pressed.connect(_acquire_item.bind(str(item_id)))
		item_grid.add_child(button)

	_add_skill_button("Refresh AP", "Restores AP to the current max.", _refresh_ap)
	_add_skill_button("Bleed Dummy", "Applies the same bleed status used by Bleeder's Mark.", _bleed_dummy)
	_add_skill_button("Burn Dummy", "Applies burn and its orange offensive indicator.", _burn_dummy)
	_add_skill_button("Shield Self", "Applies shielded for the next incoming hit.", _shield_self)
	_add_skill_button("Empower Self", "Adds +2 ATK through trigger bonuses.", _empower_self)
	_add_skill_button("Extra Move", "Adds +2 movement range through the active move trigger.", _extra_move)
	_add_skill_button("Strike Dummy", "Attacks the dummy from any position for fast damage checks.", _strike_dummy)
	_add_skill_button("Frost / Shock", "Previews utility control indicators on the dummy.", _control_dummy)
	_add_skill_button("Curse / Weaken", "Previews corruption and debuff indicators on the dummy.", _curse_dummy)
	_add_skill_button("Skill VFX Pass", "Previews mobility, impact, aura, summon, and mutation shapes.", _preview_skill_vfx)
	_add_skill_button("Aura / Threat", "Previews radius rings and red targeting lines.", _preview_aura_threat)
	_add_skill_button("Rarity / Events", "Previews rarity, critical hit, kill, and unit-state indicators.", _preview_rarity_events)

func _add_skill_button(label: String, tooltip: String, callable: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.pressed.connect(callable)
	skill_grid.add_child(button)

func _reset_lab() -> void:
	board = BoardData.new()
	board.init_board(BOARD_ROWS, BOARD_COLS)
	var terrain: Dictionary = DataLoader.load_config("terrain")
	for row in range(BOARD_ROWS):
		for col in range(BOARD_COLS):
			var tile := Tile.new()
			tile.terrain_id = "normal"
			tile.terrain_data = terrain.get("normal", {})
			tile.revealed = true
			board.set_tile(Vector2i(col, row), tile)

	player = _make_player("pawn")
	dummy = _make_dummy()
	board.set_unit(PLAYER_START, player)
	board.set_unit(DUMMY_START, dummy)
	selected = player
	board_view.build_board(board)
	_resize_board_to_viewport()
	board_view.show_highlights(MovementSystem.get_valid_moves(player, board), MovementSystem.get_attack_positions(player, board), player.position)
	log_label.clear()
	_log("Combat lab reset: clean 10x10 board, one silent dummy.")
	_update_ui()

func _on_resized() -> void:
	_resize_board_to_viewport()

func _resize_board_to_viewport() -> void:
	if board_view == null:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return
	var available_width: float = viewport_size.x - float(OUTER_MARGIN * 2 + ROOT_GAP + SIDE_PANEL_WIDTH)
	var available_height: float = viewport_size.y - float(OUTER_MARGIN * 2 + TITLE_HEIGHT + LOG_HEIGHT + BOARD_COLUMN_GAP * 2)
	var target_tile: int = int(floor(min(available_width / float(BOARD_COLS), available_height / float(BOARD_ROWS))))
	target_tile = clamp(target_tile, MIN_TILE_SIZE, MAX_TILE_SIZE)
	while target_tile > MIN_TILE_SIZE and _board_size_for_tile(target_tile).x > available_width:
		target_tile -= 1
	while target_tile > MIN_TILE_SIZE and _board_size_for_tile(target_tile).y > available_height:
		target_tile -= 1
	board_view.set_tile_size(target_tile)
	board_frame.custom_minimum_size = board_view.get_board_pixel_size()

func _board_size_for_tile(tile_size: int) -> Vector2:
	var separation: int = max(1, int(round(tile_size * 0.04)))
	return Vector2(
		BOARD_COLS * tile_size + max(0, BOARD_COLS - 1) * separation,
		BOARD_ROWS * tile_size + max(0, BOARD_ROWS - 1) * separation
	)

func _make_player(piece_id: String) -> Unit:
	var unit := Unit.new()
	unit.init_from_piece(piece_id, DataLoader.load_config("player_pieces").get(piece_id, {}))
	unit.is_player = true
	unit.display_name = "Test %s" % unit.display_name
	return unit

func _make_dummy() -> Unit:
	var unit := Unit.new()
	unit.piece_id = "pawn"
	unit.display_name = "Silent Dummy"
	unit.base_hp = 0
	unit.base_atk = 0
	unit.base_def = 0
	unit.base_spd = 0
	unit.base_ap = 0
	unit.max_hp = 0
	unit.hp = 0
	unit.atk = 0
	unit.def = 0
	unit.spd = 0
	unit.max_ap = 0
	unit.ap = 0
	return unit

func _select_unit(piece_id: String) -> void:
	var held_items := player.items.duplicate(true)
	var old_pos := player.position
	board.clear_unit(old_pos)
	player = _make_player(piece_id)
	ItemSystem.apply_items(player, held_items)
	player.hp = player.max_hp
	player.ap = player.max_ap
	board.set_unit(old_pos, player)
	selected = player
	_log("Unit changed to %s." % player.display_name)
	_update_board_feedback()
	_update_ui()

func _acquire_item(item_id: String) -> void:
	if player.items.size() >= MAX_TEST_ITEMS:
		_log("Item slots full. Clear items to test another set.")
		return
	var item: Dictionary = DataLoader.load_config("items").get(item_id, {}).duplicate(true)
	item["id"] = item_id
	player.items.append(item)
	ItemSystem.apply_items(player, player.items)
	player.hp = player.max_hp
	player.ap = player.max_ap
	board_view.show_trigger_effect(player.position, str(item.get("trigger_id", "")), str(item.get("school", "")))
	board_view.show_item_rarity_effect(player.position, _rarity_for_item_count(player.items.size()), str(item.get("school", "")))
	_log("Acquired %s." % item.get("display_name", item_id))
	_update_board_feedback()
	_update_ui()

func _clear_items() -> void:
	ItemSystem.apply_items(player, [])
	player.hp = player.max_hp
	player.ap = player.max_ap
	_log("Relics cleared.")
	_update_board_feedback()
	_update_ui()

func _refresh_ap() -> void:
	player.ap = player.max_ap
	_event_bus().emit_event(_event_bus().EVENT_TURN_START, {"unit": player, "board": board})
	player.ap = min(player.ap, player.max_ap + 1)
	board_view.show_trigger_effect(player.position, "on_turn_ap", "holy")
	_log("AP refreshed.")
	_update_ui()

func _bleed_dummy() -> void:
	_apply_status_to_unit(dummy, "bleed")
	_log("Dummy marked with bleed.")
	_update_ui()

func _burn_dummy() -> void:
	_apply_status_to_unit(dummy, "burn")
	_log("Dummy set alight.")
	_update_ui()

func _shield_self() -> void:
	_apply_status_to_unit(player, "shielded")
	_log("Shielded self.")
	_update_ui()

func _empower_self() -> void:
	player.trigger_stat_bonuses["atk"] = int(player.trigger_stat_bonuses.get("atk", 0)) + 2
	player.apply_items(player.items)
	_apply_status_to_unit(player, "empowered")
	board_view.show_trigger_effect(player.position, "on_low_hp_buff", "holy")
	_log("Self empowered: +2 ATK.")
	_update_board_feedback()
	_update_ui()

func _extra_move() -> void:
	player.trigger_flags["move_range_bonus"] = int(player.trigger_flags.get("move_range_bonus", 0)) + 2
	board_view.show_skill_effect(player.position, "mobility")
	board_view.show_trigger_effect(player.position, "on_move_extra", "shadow")
	_log("Extra move range granted.")
	_update_board_feedback()
	_update_ui()

func _strike_dummy() -> void:
	_apply_attack_to_dummy(true)

func _control_dummy() -> void:
	_apply_status_to_unit(dummy, "frozen")
	_apply_status_to_unit(dummy, "shocked")
	board_view.show_skill_effect(dummy.position, "impact")
	_log("Control indicators applied to dummy.")
	_update_ui()

func _curse_dummy() -> void:
	_apply_status_to_unit(dummy, "cursed")
	_apply_status_to_unit(dummy, "weakened")
	board_view.show_skill_effect(dummy.position, "mutation")
	_log("Corruption indicators applied to dummy.")
	_update_ui()

func _preview_skill_vfx() -> void:
	board_view.show_skill_trail(player.position, Vector2i(4, 6), "mobility")
	board_view.show_skill_effect(player.position, "mobility")
	board_view.show_skill_effect(dummy.position, "impact")
	board_view.show_skill_effect(Vector2i(2, 5), "summon")
	board_view.show_skill_effect(Vector2i(6, 5), "aura")
	board_view.play_mutation_flash(Vector2i(4, 4))
	board_view.show_evolution_effect(player.position)
	_log("Previewed Phase 1 skill and event indicators.")

func _preview_aura_threat() -> void:
	board_view.show_aura(player.position, 2, "heal")
	board_view.show_aura(dummy.position, 2, "fear")
	board_view.show_threat_line(dummy.position, player.position)
	board_view.show_unit_state_effect(dummy.position, "threatening")
	_log("Previewed aura radius and threat line indicators.")

func _preview_rarity_events() -> void:
	board_view.show_item_rarity_effect(Vector2i(2, 7), "common", "shadow")
	board_view.show_item_rarity_effect(Vector2i(3, 7), "rare", "holy")
	board_view.show_item_rarity_effect(Vector2i(4, 7), "epic", "siege")
	board_view.show_item_rarity_effect(Vector2i(5, 7), "legendary", "void")
	board_view.play_critical_hit(dummy.position)
	board_view.play_kill_effect(Vector2i(5, 1))
	board_view.show_unit_state_effect(player.position, "ready")
	board_view.show_unit_state_effect(dummy.position, "low_hp")
	_log("Previewed rarity and event feedback indicators.")

func _on_tile_clicked(pos: Vector2i) -> void:
	var tile := board.get_tile(pos)
	if tile == null:
		return
	if tile.piece == player:
		selected = player
		_update_board_feedback()
		return
	if selected != player:
		return
	if tile.piece == dummy:
		if MovementSystem.can_attack(player, dummy, board):
			_apply_attack_to_dummy(false)
		else:
			_log("Dummy is outside attack lines. Use Strike Dummy for raw checks.")
		return
	if tile.piece == null and pos in MovementSystem.get_valid_moves(player, board):
		var from_pos := player.position
		board.clear_unit(from_pos)
		board.set_unit(pos, player)
		player.ap = max(0, player.ap - 1)
		board_view.show_skill_trail(from_pos, pos, "mobility")
		board_view.animate_unit_move(from_pos, pos, player)
		_log("Moved to %s." % _pos_text(pos))
		_update_board_feedback()
		_update_ui()

func _on_tile_hovered(pos: Vector2i) -> void:
	board_view.set_preview_tile(pos)

func _apply_attack_to_dummy(ignore_range: bool) -> void:
	if not ignore_range and not MovementSystem.can_attack(player, dummy, board):
		return
	var before_pos := dummy.position
	var result := CombatSystem.apply_attack(player, dummy, board, rng)
	var damage := int(result.get("final", 0))
	player.ap = max(0, player.ap - 1)
	board_view.play_attack_flash(before_pos)
	board_view.show_damage_number(before_pos, damage)
	_show_attack_trigger_feedback(before_pos)
	if dummy.position != DUMMY_START:
		board.clear_unit(dummy.position)
		board.set_unit(DUMMY_START, dummy)
	elif board.get_tile(DUMMY_START) == null or board.get_tile(DUMMY_START).piece != dummy:
		board.set_unit(DUMMY_START, dummy)
	_log("Dealt %d damage. Raw %d, roll %+d." % [damage, int(result.get("raw", 0)), int(result.get("roll", 0))])
	_update_board_feedback()
	_update_ui()

func _apply_status_to_unit(unit: Unit, status_id: String) -> void:
	StatusSystem.apply_status(unit, status_id)
	board_view.show_status_effect(unit.position, status_id)
	_update_board_feedback()

func _show_attack_trigger_feedback(target_pos: Vector2i) -> void:
	for item in player.items:
		var trigger_id := str(item.get("trigger_id", ""))
		if trigger_id in ["on_hit_bleed", "on_hit_knockback", "on_low_hp_buff"]:
			board_view.show_trigger_effect(target_pos, trigger_id, str(item.get("school", "")))
	if dummy.status_effects.has("bleed"):
		board_view.show_status_effect(target_pos, "bleed")

func _rarity_for_item_count(count: int) -> String:
	if count >= 6:
		return "legendary"
	if count >= 4:
		return "epic"
	if count >= 2:
		return "rare"
	return "common"

func _update_board_feedback() -> void:
	board_view.update_board(board)
	board_view.show_highlights(MovementSystem.get_valid_moves(player, board), MovementSystem.get_attack_positions(player, board), player.position)

func _update_ui() -> void:
	var preview := CombatSystem.preview_attack(player, dummy, board)
	var lines: Array[String] = []
	lines.append("%s" % player.display_name)
	lines.append("HP %d/%d  AP %d/%d" % [player.hp, player.max_hp, player.ap, player.max_ap])
	lines.append("ATK %d  DEF %d  SPD %d  Move %d" % [player.atk, player.def, player.spd, max(1, player.spd + int(player.trigger_flags.get("move_range_bonus", 0)))])
	lines.append("Damage preview: %d-%d" % [int(preview.get("min", 0)), int(preview.get("max", 0))])
	if player.active_synergies.size() > 0:
		lines.append("Synergies: %s" % ", ".join(player.active_synergies))
	else:
		lines.append("Synergies: none")
	lines.append("Items: %s" % _item_names())
	lines.append("Statuses: %s" % _status_names(player.status_effects))
	lines.append("Dummy HP: 0/0  Damage sink only")
	lines.append("Dummy statuses: %s" % _status_names(dummy.status_effects))
	stats_label.text = "\n".join(lines)

func _item_names() -> String:
	if player.items.is_empty():
		return "none"
	var names: Array[String] = []
	for item in player.items:
		names.append(str(item.get("display_name", item.get("id", "item"))))
	return ", ".join(names)

func _status_names(statuses: Dictionary) -> String:
	if statuses.is_empty():
		return "none"
	var names: Array[String] = []
	for key in statuses.keys():
		names.append(str(key))
	return ", ".join(names)

func _piece_tooltip(piece_id: String, piece: Dictionary) -> String:
	var stats: Dictionary = piece.get("base_stats", {})
	return "%s\nHP %d  ATK %d  DEF %d  SPD %d  AP %d" % [piece_id, int(stats.get("hp", 0)), int(stats.get("atk", 0)), int(stats.get("def", 0)), int(stats.get("spd", 0)), int(stats.get("ap", 0))]

func _item_tooltip(item_id: String, item: Dictionary) -> String:
	var school := str(item.get("school", "none")).capitalize()
	var trigger := str(item.get("trigger_id", ""))
	if trigger.is_empty():
		trigger = "passive stats"
	return "%s\n%s\n%s" % [school, trigger, str(item.get("flavor", item_id))]

func _log(text: String) -> void:
	log_label.append_text("[color=#d8dde3]%s[/color]\n" % text)

func _pos_text(pos: Vector2i) -> String:
	return "(%d,%d)" % [pos.x, pos.y]

func _event_bus() -> Node:
	return Engine.get_main_loop().root.get_node("EventBus")
