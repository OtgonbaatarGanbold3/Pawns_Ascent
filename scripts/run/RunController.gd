extends Control
class_name RunController

@onready var board_view: BoardView = $BoardView
@onready var bottom_bar: Control = $BottomBar
@onready var bar_row: HBoxContainer = $BottomBar/BarRow
@onready var left_column: VBoxContainer = $BottomBar/BarRow/LeftColumn
@onready var center_column: VBoxContainer = $BottomBar/BarRow/CenterColumn
@onready var right_column: VBoxContainer = $BottomBar/BarRow/RightColumn
@onready var divider_1: VSeparator = $BottomBar/BarRow/Divider1
@onready var divider_2: VSeparator = $BottomBar/BarRow/Divider2
@onready var stats_panel: StatsPanel = $BottomBar/BarRow/LeftColumn/StatsPanel
@onready var combat_log: CombatLog = $BottomBar/BarRow/CombatLog
@onready var end_turn_button: Button = $BottomBar/BarRow/RightColumn/EndTurnButton
@onready var enemy_header: Label = $BottomBar/BarRow/CenterColumn/EnemyHeader
@onready var enemy_info_label: Label = $BottomBar/BarRow/CenterColumn/EnemyInfoLabel
@onready var turn_order_label: Label = $BottomBar/BarRow/CenterColumn/TurnOrderLabel
@onready var tile_info_label: Label = $BottomBar/BarRow/CenterColumn/TileInfoLabel
@onready var items_header: Label = $BottomBar/BarRow/RightColumn/ItemsHeader
@onready var items_list_label: Label = $BottomBar/BarRow/RightColumn/ItemsListLabel
@onready var item_draft: ItemDraftOverlay = $ItemDraftOverlay
@onready var end_screen: EndScreen = $EndScreen
@onready var path_map: PathMap = $PathMap
@onready var game_state: Node = get_node("/root/GameState")
@onready var score_manager: Node = get_node("/root/ScoreManager")
@onready var background: ColorRect = $Background
@onready var board_backdrop: Panel = $BoardBackdrop
@onready var ui_backdrop: Panel = $UIBackdrop
@onready var title_label: Label = $BottomBar/BarRow/LeftColumn/TitleLabel
@onready var hint_label: Label = $BottomBar/BarRow/RightColumn/HintLabel

const BASE_VIEWPORT_HEIGHT := 1080.0
const MIN_TILE_SIZE := 48
const MAX_TILE_SIZE := 120
const SIDE_HUD_MIN_WIDTH := 1500.0
const SIDE_HUD_ASPECT := 1.45

var rng := RandomNumberGenerator.new()
var turn_system := TurnSystem.new()

var selected: Unit = null
var player_items: Array = []
var _pending_reward_node_id := ""
var _resolving_action := false

func _ready() -> void:
    rng.randomize()
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    board_view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    bottom_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    board_backdrop.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    ui_backdrop.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    item_draft.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    end_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    path_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bar_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    game_state.reset_run()
    board_view.tile_clicked.connect(_on_tile_clicked)
    board_view.tile_hovered.connect(_on_tile_hovered)
    end_turn_button.pressed.connect(_on_end_turn_pressed)
    item_draft.item_selected.connect(_on_item_selected)
    item_draft.draft_skipped.connect(_on_draft_skipped)
    end_screen.restart_requested.connect(_on_restart_requested)
    path_map.node_selected.connect(_on_path_node_selected)
    hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    enemy_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    turn_order_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    tile_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    items_list_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _apply_panel_styles()
    resized.connect(_on_root_resized)
    _apply_layout()
    item_draft.hide_draft()
    end_screen.hide_screen()
    path_map.hide_path()
    start_run()

func _apply_layout() -> void:
    var viewport_size := get_viewport_rect().size
    if viewport_size == Vector2.ZERO:
        return

    var ui_scale: float = _ui_scale(viewport_size)
    var outer_margin := int(round(20 * ui_scale))
    var gap := int(round(12 * ui_scale))
    var pad := int(round(10 * ui_scale))
    var use_side_hud: bool = _uses_side_hud(viewport_size)

    _apply_ui_scale(ui_scale, use_side_hud)

    var bar_min: Vector2 = bar_row.get_combined_minimum_size()
    var board_area: Rect2 = Rect2()
    if use_side_hud:
        var target_side_width: float = max(bar_min.x + pad * 2, viewport_size.x * 0.4)
        var side_width: float = clamp(target_side_width, 620.0 * ui_scale, min(760.0 * ui_scale, viewport_size.x * 0.45))
        side_width = min(side_width, max(0.0, viewport_size.x - outer_margin * 2 - gap - MIN_TILE_SIZE * 9))
        bottom_bar.position = Vector2(viewport_size.x - outer_margin - side_width, outer_margin)
        bottom_bar.size = Vector2(side_width, max(0.0, viewport_size.y - outer_margin * 2))
        board_area = Rect2(
            Vector2(outer_margin, outer_margin),
            Vector2(max(0.0, bottom_bar.position.x - outer_margin - gap), max(0.0, viewport_size.y - outer_margin * 2))
        )
    else:
        var target_bar_height: int = int(round(max(bar_min.y + pad * 2, 240 * ui_scale)))
        var max_bar_height: int = int(viewport_size.y * 0.42)
        var bar_height: int = target_bar_height
        if bar_height > max_bar_height:
            bar_height = max_bar_height
        var bar_width: float = max(0.0, viewport_size.x - outer_margin * 2)
        bottom_bar.position = Vector2(outer_margin, viewport_size.y - outer_margin - bar_height)
        bottom_bar.size = Vector2(bar_width, bar_height)
        board_area = Rect2(
            Vector2(outer_margin, outer_margin),
            Vector2(max(0.0, viewport_size.x - outer_margin * 2), max(0.0, bottom_bar.position.y - outer_margin - gap))
        )

    bar_row.offset_left = 0
    bar_row.offset_top = 0
    bar_row.offset_right = 0
    bar_row.offset_bottom = 0

    ui_backdrop.position = bottom_bar.position - Vector2(pad, pad)
    ui_backdrop.size = bottom_bar.size + Vector2(pad * 2, pad * 2)

    var board_dims: Vector2i = board_view.get_board_dims()
    if board_dims == Vector2i.ZERO:
        board_dims = Vector2i(9, 8)

    var tile_from_width := int(floor(board_area.size.x / float(board_dims.x)))
    var tile_from_height := int(floor(board_area.size.y / float(board_dims.y)))
    var target_tile: int = int(min(tile_from_width, tile_from_height))
    target_tile = clamp(target_tile, 24, MAX_TILE_SIZE)
    while target_tile > 24 and _board_size_for_tile(board_dims, target_tile).y > board_area.size.y:
        target_tile -= 1
    while target_tile > 24 and _board_size_for_tile(board_dims, target_tile).x > board_area.size.x:
        target_tile -= 1
    board_view.set_tile_size(target_tile)

    var board_size: Vector2 = board_view.get_board_pixel_size()
    var board_x: float = board_area.position.x + max(0.0, (board_area.size.x - board_size.x) * 0.5)
    var board_y: float = board_area.position.y + max(0.0, (board_area.size.y - board_size.y) * 0.5)
    board_view.position = Vector2(board_x, board_y)

    board_backdrop.position = board_view.position - Vector2(pad, pad)
    board_backdrop.size = board_size + Vector2(pad * 2, pad * 2)

func _on_root_resized() -> void:
    _apply_layout()

func get_layout_rects() -> Dictionary:
    return {
        "viewport": Rect2(Vector2.ZERO, get_viewport_rect().size),
        "board": Rect2(board_view.position, board_view.size),
        "hud": Rect2(bottom_bar.position, bottom_bar.size)
    }

func _ui_scale(viewport_size: Vector2) -> float:
    return clamp(viewport_size.y / BASE_VIEWPORT_HEIGHT, 0.8, 1.4)

func _uses_side_hud(viewport_size: Vector2) -> bool:
    if viewport_size.y <= 0.0:
        return false
    return viewport_size.x >= SIDE_HUD_MIN_WIDTH and viewport_size.x / viewport_size.y >= SIDE_HUD_ASPECT

func _board_size_for_tile(board_dims: Vector2i, tile_size: int) -> Vector2:
    var separation: int = max(1, int(round(tile_size * 0.04)))
    return Vector2(
        board_dims.x * tile_size + max(0, board_dims.x - 1) * separation,
        board_dims.y * tile_size + max(0, board_dims.y - 1) * separation
    )

func _apply_ui_scale(ui_scale: float, use_side_hud: bool) -> void:
    var viewport_width: float = get_viewport_rect().size.x
    var usable_width: float = max(640.0, viewport_width - 72.0)
    var title_size: int = int(round(22 * ui_scale))
    var hint_size: int = int(round(16 * ui_scale))
    var button_font: int = int(round(20 * ui_scale))
    var button_width: int = int(round(200 * ui_scale))
    var button_height: int = int(round(56 * ui_scale))

    divider_1.visible = true
    divider_2.visible = true

    title_label.add_theme_font_size_override("font_size", title_size)
    hint_label.add_theme_font_size_override("font_size", hint_size)
    hint_label.custom_minimum_size = Vector2(int(round(300 * ui_scale)), int(round(54 * ui_scale)))
    enemy_header.add_theme_font_size_override("font_size", int(round(16 * ui_scale)))
    enemy_info_label.add_theme_font_size_override("font_size", int(round(15 * ui_scale)))
    enemy_info_label.custom_minimum_size = Vector2(int(round(390 * ui_scale)), int(round(86 * ui_scale)))
    turn_order_label.add_theme_font_size_override("font_size", int(round(14 * ui_scale)))
    turn_order_label.custom_minimum_size = Vector2(int(round(390 * ui_scale)), int(round(48 * ui_scale)))
    tile_info_label.add_theme_font_size_override("font_size", int(round(14 * ui_scale)))
    tile_info_label.custom_minimum_size = Vector2(int(round(390 * ui_scale)), int(round(78 * ui_scale)))
    items_header.add_theme_font_size_override("font_size", int(round(16 * ui_scale)))
    items_list_label.add_theme_font_size_override("font_size", int(round(14 * ui_scale)))
    items_list_label.custom_minimum_size = Vector2(int(round(460 * ui_scale)), int(round(120 * ui_scale)))

    stats_panel.set_font_scale(ui_scale)
    var left_width: int = int(round(clamp(usable_width * 0.22, 180.0, 300.0 * ui_scale)))
    var center_width: int = int(round(clamp(usable_width * 0.32, 220.0, 430.0 * ui_scale)))
    var right_width: int = int(round(clamp(usable_width * 0.38, 260.0, 520.0 * ui_scale)))
    if use_side_hud:
        var hud_width: float = clamp(viewport_width * 0.4, 620.0 * ui_scale, 760.0 * ui_scale)
        var column_space: float = max(540.0, hud_width - 92.0 * ui_scale)
        left_width = int(round(column_space * 0.27))
        center_width = int(round(column_space * 0.33))
        right_width = int(round(column_space * 0.4))
        hint_label.custom_minimum_size = Vector2(right_width, int(round(70 * ui_scale)))
        enemy_info_label.custom_minimum_size = Vector2(center_width, int(round(108 * ui_scale)))
        turn_order_label.custom_minimum_size = Vector2(center_width, int(round(58 * ui_scale)))
        tile_info_label.custom_minimum_size = Vector2(center_width, int(round(100 * ui_scale)))
        items_list_label.custom_minimum_size = Vector2(right_width, int(round(150 * ui_scale)))
    left_column.custom_minimum_size = Vector2(left_width, 0)
    center_column.custom_minimum_size = Vector2(center_width, 0)
    right_column.custom_minimum_size = Vector2(right_width, 0)

    stats_panel.custom_minimum_size = Vector2(int(round(260 * ui_scale)), 0)

    combat_log.set_font_scale(ui_scale)
    combat_log.custom_minimum_size = Vector2(int(round(360 * ui_scale)), int(round(160 * ui_scale)))
    combat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    combat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL

    end_turn_button.custom_minimum_size = Vector2(button_width, button_height)
    end_turn_button.add_theme_font_size_override("font_size", button_font)

    bar_row.add_theme_constant_override("separation", int(round(16 * ui_scale)))
    left_column.add_theme_constant_override("separation", int(round(6 * ui_scale)))
    center_column.add_theme_constant_override("separation", int(round(8 * ui_scale)))
    right_column.add_theme_constant_override("separation", int(round(8 * ui_scale)))

func _apply_panel_styles() -> void:
    var board_style := PawnUITheme.make_panel_style(Color(0.06, 0.068, 0.078, 1.0), Color(0.25, 0.29, 0.33, 1.0), 10)
    board_backdrop.add_theme_stylebox_override("panel", board_style)

    var ui_style := PawnUITheme.make_panel_style(Color(0.055, 0.063, 0.071, 0.96), Color(0.31, 0.36, 0.4, 1.0), 12)
    ui_backdrop.add_theme_stylebox_override("panel", ui_style)

func start_run() -> void:
    score_manager.reset()
    player_items = []
    _pending_reward_node_id = ""
    game_state.reset_run()
    combat_log.clear_log()
    _apply_starter_items()
    _generate_run_path()
    _show_path_choice()

func _generate_run_path() -> void:
    var run_cfg: Dictionary = DataLoader.load_config("run_nodes")
    game_state.run_state["path_graph"] = RunPathGenerator.generate_path(rng, run_cfg)
    game_state.run_state["current_floor"] = 0
    game_state.run_state["current_node"] = {}

func _show_path_choice() -> void:
    selected = null
    board_view.clear_highlights()
    board_view.visible = false
    board_backdrop.visible = false
    bottom_bar.visible = false
    ui_backdrop.visible = false
    item_draft.hide_draft()
    end_screen.hide_screen()
    var path_graph: Dictionary = game_state.run_state.get("path_graph", {})
    var available: Array = path_graph.get("available", [])
    path_map.show_path(path_graph, available)

func _hide_path_choice() -> void:
    path_map.hide_path()
    board_view.visible = true
    board_backdrop.visible = true
    bottom_bar.visible = true
    ui_backdrop.visible = true

func _on_path_node_selected(node_id: String) -> void:
    var path_graph: Dictionary = game_state.run_state.get("path_graph", {})
    var node: Dictionary = RunPathGenerator.get_node(path_graph, node_id)
    if node.is_empty():
        return
    path_graph["current"] = node_id
    game_state.run_state["path_graph"] = path_graph
    game_state.run_state["current_node"] = node
    game_state.run_state["current_floor"] = int(node.get("floor", 1))
    _hide_path_choice()
    _begin_run_node(node)

func _begin_run_node(node: Dictionary) -> void:
    var node_type: String = str(node.get("type", "combat"))
    append_log("Path: %s" % str(node.get("label", node_type.capitalize())))
    match node_type:
        "combat", "elite", "ambush", "boss":
            start_encounter_for_node(node)
        "relic":
            _pending_reward_node_id = str(node.get("id", ""))
            show_item_draft("relic")
        "rest":
            _resolve_rest_node(node)
        "story":
            _resolve_story_node(node)
        _:
            _complete_current_node()

func _apply_starter_items() -> void:
    var encounters: Dictionary = DataLoader.load_config("encounters")
    var starter_ids: Array = encounters.get("starter_items", [])
    if starter_ids.is_empty():
        return
    var items_cfg: Dictionary = DataLoader.load_config("items")
    for item_id in starter_ids:
        if not items_cfg.has(item_id):
            continue
        if _player_has_item(item_id):
            continue
        var data: Dictionary = items_cfg[item_id].duplicate(true)
        data["id"] = item_id
        player_items.append(data)

func start_encounter(index: int) -> void:
    var legacy_cfg: Dictionary = _legacy_encounter_cfg(index)
    start_encounter_for_node({
        "id": "legacy_%d" % index,
        "floor": index + 1,
        "type": "boss" if bool(legacy_cfg.get("is_boss", false)) else "combat",
        "label": "Encounter %d" % (index + 1),
        "reward": "run_complete" if bool(legacy_cfg.get("is_boss", false)) else "draft",
        "encounter_cfg": legacy_cfg
    })

func start_encounter_for_node(node: Dictionary) -> void:
    var encounter_cfg: Dictionary = node.get("encounter_cfg", {})
    if encounter_cfg.is_empty():
        encounter_cfg = _encounter_cfg_for_node(node)
    var node_id: String = str(node.get("id", ""))
    var floor_index: int = int(node.get("floor", 1))

    game_state.run_state["encounter_index"] = floor_index - 1
    game_state.run_state["active_node_id"] = node_id
    game_state.run_state["turn"] = 1

    var board := BoardGenerator.generate_board(rng, encounter_cfg.get("board", {}))
    game_state.run_state["board"] = board

    var player := _get_or_create_player()
    var player_pos := _spawn_player(board)
    board.set_unit(player_pos, player)
    reveal_adjacent(board, player.position)

    var enemies := _spawn_enemies(board, encounter_cfg)
    game_state.run_state["enemies"] = enemies

    board_view.build_board(board)
    board_view.update_board(board)
    _apply_layout()
    stats_panel.update_unit(player)
    _refresh_tactical_hud()

    append_log("Floor %d: %s" % [floor_index, str(node.get("label", "Combat"))])
    start_player_phase()

func _legacy_encounter_cfg(index: int) -> Dictionary:
    var encounters: Dictionary = DataLoader.load_config("encounters")
    var list: Array = encounters.get("encounters", [])
    if index >= list.size():
        return { "enemy_types": ["king"], "spawn_min": 1, "spawn_max": 1, "is_boss": true }
    return (list[index] as Dictionary).duplicate(true)

func _encounter_cfg_for_node(node: Dictionary) -> Dictionary:
    var run_cfg: Dictionary = DataLoader.load_config("run_nodes")
    var rules_by_type: Dictionary = run_cfg.get("encounter_rules", {})
    var node_type: String = str(node.get("type", "combat"))
    var floor_index: int = int(node.get("floor", 1))
    var rules: Array = rules_by_type.get(node_type, rules_by_type.get("combat", []))
    var selected_rule: Dictionary = {}
    for rule in rules:
        if typeof(rule) != TYPE_DICTIONARY:
            continue
        if floor_index >= int(rule.get("min_floor", 1)):
            selected_rule = rule
    if selected_rule.is_empty():
        selected_rule = { "enemy_types": ["pawn"], "spawn_min": 1, "spawn_max": 1 }
    var cfg: Dictionary = selected_rule.duplicate(true)
    cfg["node_type"] = node_type
    cfg["floor"] = floor_index
    cfg["is_boss"] = bool(cfg.get("is_boss", node_type == "boss"))
    cfg["board"] = _board_cfg_for_floor(floor_index)
    return cfg

func _board_cfg_for_floor(floor_index: int) -> Dictionary:
    if floor_index >= 6:
        return { "rows": 10, "cols": 12 }
    if floor_index >= 4:
        return { "rows": 9, "cols": 10 }
    return DataLoader.load_config("encounters").get("board", { "rows": 8, "cols": 9 })

func start_player_phase() -> void:
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if player == null:
        return
    turn_system.start_player_phase(player)
    selected = null
    board_view.clear_highlights()
    stats_panel.set_phase("Player", _current_turn())
    stats_panel.update_unit(player)
    _refresh_tactical_hud()

func start_enemy_phase() -> void:
    var enemies: Array = game_state.run_state.get("enemies", [])
    stats_panel.set_phase("Enemy", _current_turn())
    _refresh_tactical_hud()
    var ordered := turn_system.start_enemy_phase(enemies)
    for enemy in ordered:
        var enemy_unit: Unit = enemy as Unit
        if enemy_unit == null or enemy_unit.is_dead():
            continue
        await _run_enemy_turn(enemy_unit)
        if _check_player_dead():
            return
        if _check_encounter_cleared():
            return
        var costs: Dictionary = DataLoader.load_config("action_costs")
        var delay_ms: int = int(costs.get("enemy_action_delay_ms", 120))
        if delay_ms > 0:
            await get_tree().create_timer(float(delay_ms) / 1000.0).timeout
    start_tick_phase()

func start_tick_phase() -> void:
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    var units := _all_units()
    stats_panel.set_phase("Tick", _current_turn())
    turn_system.start_tick_phase(units, board)
    _maybe_mutate_board(board)
    _remove_dead_units()
    board_view.update_board(board)
    _refresh_tactical_hud()
    if _check_player_dead():
        return
    if _check_encounter_cleared():
        return
    game_state.run_state["turn"] = _current_turn() + 1
    start_player_phase()

func _on_tile_clicked(pos: Vector2i) -> void:
    if _resolving_action:
        return
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if board == null or player == null:
        return
    if turn_system.phase != TurnSystem.Phase.PLAYER:
        return

    var tile: Tile = board.get_tile(pos)
    if tile == null:
        return

    if tile.piece == player:
        selected = player
        var moves: Array = MovementSystem.get_valid_moves(player, board)
        var attacks: Array = _get_attack_positions(player, board)
        board_view.show_highlights(moves, attacks, player.position)
        _refresh_tactical_hud()
        return

    if selected == player:
        var costs: Dictionary = DataLoader.load_config("action_costs")
        var attack_cost: int = int(costs.get("attack", 1))
        var move_cost: int = int(costs.get("move", 1))
        if tile.piece != null and tile.piece != player and MovementSystem.is_adjacent(player.position, pos):
            if turn_system.spend_ap(player, attack_cost):
                _resolving_action = true
                _attack(player, tile.piece)
                await _after_player_action()
                _resolving_action = false
            return
        var valid_moves: Array = MovementSystem.get_valid_moves(player, board)
        if pos in valid_moves and turn_system.spend_ap(player, move_cost):
            _resolving_action = true
            await _move_unit(player, pos)
            await _after_player_action()
            _resolving_action = false

func _on_tile_hovered(pos: Vector2i) -> void:
    _update_tile_info(pos)
    if selected != null:
        board_view.set_preview_tile(pos)

func _get_attack_positions(unit: Unit, board: BoardData) -> Array:
    var positions: Array = []
    var adjacent := MovementSystem.get_adjacent_positions(unit.position)
    for pos in adjacent:
        var tile: Tile = board.get_tile(pos)
        if tile == null or tile.piece == null:
            continue
        if not tile.piece.is_player and not tile.piece.is_ally:
            positions.append(pos)
    return positions

func _after_player_action() -> void:
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    var costs: Dictionary = DataLoader.load_config("action_costs")
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if player != null and bool(costs.get("one_action_per_unit_phase", true)):
        player.ap = 0
    selected = null
    board_view.clear_highlights()
    board_view.update_board(board)
    stats_panel.update_unit(game_state.run_state.get("player", null))
    _refresh_tactical_hud()
    if _check_encounter_cleared():
        return
    if _check_player_dead():
        return
    if player != null and player.ap <= 0:
        await start_enemy_phase()

func _on_end_turn_pressed() -> void:
    if _resolving_action or turn_system.phase != TurnSystem.Phase.PLAYER:
        return
    _resolving_action = true
    await start_enemy_phase()
    _resolving_action = false

func _run_enemy_turn(enemy: Unit) -> void:
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if board == null or player == null:
        return

    var costs: Dictionary = DataLoader.load_config("action_costs")
    var attack_cost: int = int(costs.get("attack", 1))
    var move_cost: int = int(costs.get("move", 1))
    var wait_cost: int = int(costs.get("wait", 1))

    var action := AISystem.decide_action(enemy, board, player)
    var action_type: String = str(action.get("type", "wait"))
    if action_type == "attack":
        if MovementSystem.is_adjacent(enemy.position, player.position) and turn_system.spend_ap(enemy, attack_cost):
            _attack(enemy, player)
            _refresh_tactical_hud()
            if player.is_dead():
                return
    elif action_type == "move":
        var target_value: Variant = action.get("target", enemy.position)
        var target: Vector2i = enemy.position
        if typeof(target_value) == TYPE_VECTOR2I:
            target = target_value
        if target == enemy.position:
            turn_system.spend_ap(enemy, wait_cost)
        elif turn_system.spend_ap(enemy, move_cost):
            await _move_unit(enemy, target)
            _refresh_tactical_hud()
    else:
        turn_system.spend_ap(enemy, wait_cost)

    if bool(costs.get("one_action_per_unit_phase", true)):
        enemy.ap = 0

func _attack(attacker: Unit, defender: Unit) -> void:
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    var result := CombatSystem.apply_attack(attacker, defender, board, rng)
    var damage: int = int(result.get("final", 0))
    board_view.play_attack_flash(defender.position)
    board_view.show_damage_number(defender.position, damage)
    var detail: String = _damage_detail(result)
    append_log("%s hits %s for %d%s" % [attacker.display_name, defender.display_name, damage, detail])
    if defender.is_dead():
        append_log("%s falls" % defender.display_name)
        _on_unit_killed(attacker, defender)

func _on_unit_killed(attacker: Unit, victim: Unit) -> void:
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    if board == null:
        return
    board.clear_unit(victim.position)

    if attacker.is_player:
        attacker.kills += 1
        if victim.is_boss:
            score_manager.add_score("boss_kill")
        else:
            score_manager.add_score("enemy_kill")
        if EvolutionSystem.check_and_evolve(attacker):
            score_manager.add_score("evolution")
            append_log("Evolved to %s" % attacker.display_name)
            stats_panel.update_unit(attacker)

    _remove_dead_units()
    board_view.update_board(board)

func _move_unit(unit: Unit, target: Vector2i) -> void:
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    var from_pos := unit.position
    if board == null:
        return
    var target_tile: Tile = board.get_tile(target)
    if target_tile == null or MovementSystem.is_blocked(target_tile):
        return
    board.clear_unit(from_pos)
    board.set_unit(target, unit)
    await board_view.animate_unit_move(from_pos, target, unit)

    var tile: Tile = board.get_tile(target)
    if tile != null:
        var entry: Dictionary = tile.terrain_data.get("entry_effect", {})
        var effect_type: String = entry.get("type", "")
        var amount: int = int(entry.get("amount", 0))
        if effect_type == "hp" and amount < 0:
            var killed := unit.apply_damage(abs(amount))
            if killed:
                append_log("%s falls" % unit.display_name)
                board.clear_unit(unit.position)
                if unit.is_player:
                    end_run(false)
                else:
                    _remove_dead_units()
                return
        if unit.is_player:
            reveal_adjacent(board, unit.position)

func _check_encounter_cleared() -> bool:
    var enemies: Array = game_state.run_state.get("enemies", [])
    if enemies.size() > 0:
        return false

    var node: Dictionary = game_state.run_state.get("current_node", {})
    var node_type: String = str(node.get("type", "combat"))
    score_manager.add_score("encounter_clear")
    if node_type == "boss":
        end_run(true)
    else:
        var reward: String = str(node.get("reward", "draft"))
        if reward == "draft" or reward == "elite_draft":
            _pending_reward_node_id = str(node.get("id", ""))
            show_item_draft(reward)
        else:
            _complete_current_node()
    return true

func _check_player_dead() -> bool:
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if player == null:
        return false
    if player.is_dead():
        end_run(false)
        return true
    return false

func show_item_draft(reward_type: String = "draft") -> void:
    var items_cfg: Dictionary = DataLoader.load_config("items")
    var encounters: Dictionary = DataLoader.load_config("encounters")
    var draft_size: int = int(encounters.get("item_draft_size", 3))
    if reward_type == "elite_draft":
        draft_size += 1
    var pool: Array = []
    for item_id in items_cfg.keys():
        if not _player_has_item(item_id):
            var data: Dictionary = items_cfg[item_id]
            var entry := data.duplicate(true)
            entry["id"] = item_id
            pool.append(entry)
    pool.shuffle()
    var options := pool.slice(0, min(draft_size, pool.size()))
    item_draft.show_draft(options)

func _on_item_selected(item_id: String) -> void:
    var items_cfg: Dictionary = DataLoader.load_config("items")
    if not items_cfg.has(item_id):
        return
    var data: Dictionary = items_cfg[item_id].duplicate(true)
    data["id"] = item_id
    player_items.append(data)

    var player: Unit = game_state.run_state.get("player", null) as Unit
    if player != null:
        ItemSystem.apply_items(player, player_items)
        score_manager.add_score("item_pickup")
        stats_panel.update_unit(player)
        _refresh_tactical_hud()

    item_draft.hide_draft()
    _complete_current_node()

func _on_draft_skipped() -> void:
    item_draft.hide_draft()
    _complete_current_node()

func _complete_current_node() -> void:
    var path_graph: Dictionary = game_state.run_state.get("path_graph", {})
    var node_id: String = _pending_reward_node_id
    if node_id.is_empty():
        node_id = str(path_graph.get("current", ""))
    if node_id.is_empty():
        end_run(true)
        return
    path_graph = RunPathGenerator.complete_node(path_graph, node_id)
    game_state.run_state["path_graph"] = path_graph
    _pending_reward_node_id = ""
    if path_graph.get("available", []).is_empty():
        end_run(true)
        return
    _show_path_choice()

func _resolve_rest_node(node: Dictionary) -> void:
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if player == null:
        player = _get_or_create_player()
    var run_cfg: Dictionary = DataLoader.load_config("run_nodes")
    var node_types: Dictionary = run_cfg.get("node_types", {})
    var rest_cfg: Dictionary = node_types.get("rest", {})
    var heal_percent: float = float(rest_cfg.get("heal_percent", 0.3))
    var amount: int = max(1, int(round(player.max_hp * heal_percent)))
    player.hp = min(player.max_hp, player.hp + amount)
    stats_panel.update_unit(player)
    append_log("A still square lends %d HP." % amount)
    _pending_reward_node_id = str(node.get("id", ""))
    _complete_current_node()

func _resolve_story_node(node: Dictionary) -> void:
    var run_cfg: Dictionary = DataLoader.load_config("run_nodes")
    var lines: Array = run_cfg.get("story_lines", [])
    var line := "The Plain says nothing."
    if not lines.is_empty():
        line = str(lines[rng.randi_range(0, lines.size() - 1)])
    append_log(line)
    _pending_reward_node_id = str(node.get("id", ""))
    _complete_current_node()

func end_run(victory: bool) -> void:
    var score: int = score_manager.get_final_score()
    end_screen.show_screen(victory, score)
    _refresh_tactical_hud()

func _on_restart_requested() -> void:
    end_screen.hide_screen()
    start_run()

func _get_or_create_player() -> Unit:
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if player != null:
        return player
    var pieces: Dictionary = DataLoader.load_config("pieces")
    player = Unit.new()
    player.is_player = true
    player.init_from_piece("pawn", pieces.get("pawn", {}))
    ItemSystem.apply_items(player, player_items)
    game_state.run_state["player"] = player
    return player

func _spawn_player(board: BoardData) -> Vector2i:
    var encounters: Dictionary = DataLoader.load_config("encounters")
    var quadrant: String = encounters.get("player_spawn_quadrant", "bottom_left")
    var positions := BoardGenerator.get_spawn_positions(board, quadrant, 1, rng)
    if positions.is_empty():
        return Vector2i.ZERO
    return positions[0]

func _spawn_enemies(board: BoardData, encounter_cfg: Dictionary) -> Array:
    var enemies: Array = []
    var pieces: Dictionary = DataLoader.load_config("pieces")

    var enemy_types: Array = encounter_cfg.get("enemy_types", [])
    if enemy_types.is_empty():
        enemy_types = ["pawn"]
    var spawn_min: int = int(encounter_cfg.get("spawn_min", 1))
    var spawn_max: int = int(encounter_cfg.get("spawn_max", 1))
    var count: int = rng.randi_range(spawn_min, spawn_max)
    var elite_items: int = int(encounter_cfg.get("elite_items", 0))

    var encounters: Dictionary = DataLoader.load_config("encounters")
    var quadrant: String = encounters.get("enemy_spawn_quadrant", "top_right")
    var positions := BoardGenerator.get_spawn_positions(board, quadrant, count, rng)

    for i in range(min(count, positions.size())):
        var piece_id: String = enemy_types[rng.randi_range(0, enemy_types.size() - 1)]
        var unit := Unit.new()
        unit.init_from_piece(piece_id, pieces.get(piece_id, {}))
        unit.is_boss = bool(encounter_cfg.get("is_boss", false))
        if elite_items > 0 and i == 0:
            _equip_enemy_items(unit, elite_items)
        var pos: Vector2i = positions[i]
        board.set_unit(pos, unit)
        enemies.append(unit)

    return enemies

func _equip_enemy_items(unit: Unit, count: int) -> void:
    var items_cfg: Dictionary = DataLoader.load_config("items")
    var ids: Array = items_cfg.keys()
    ids.shuffle()
    var items: Array = []
    for item_id in ids.slice(0, min(count, ids.size())):
        var item_data: Dictionary = items_cfg[item_id].duplicate(true)
        item_data["id"] = item_id
        items.append(item_data)
    unit.apply_items(items)

func _player_has_item(item_id: String) -> bool:
    for item in player_items:
        if item.get("id", "") == item_id:
            return true
    return false

func _remove_dead_units() -> void:
    var enemies: Array = game_state.run_state.get("enemies", [])
    for i in range(enemies.size() - 1, -1, -1):
        var enemy: Unit = enemies[i]
        if enemy == null or enemy.is_dead():
            enemies.remove_at(i)
    game_state.run_state["enemies"] = enemies

func _all_units() -> Array:
    var units: Array = []
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if player != null:
        units.append(player)
    var enemies: Array = game_state.run_state.get("enemies", [])
    for enemy in enemies:
        units.append(enemy)
    return units

func reveal_adjacent(board: BoardData, pos: Vector2i) -> void:
    var positions := MovementSystem.get_adjacent_positions(pos)
    positions.append(pos)
    for p in positions:
        var tile: Tile = board.get_tile(p)
        if tile != null:
            tile.revealed = true

func append_log(text: String) -> void:
    game_state.add_log(text)
    combat_log.append_log(text)

func _current_turn() -> int:
    return int(game_state.run_state.get("turn", 1))

func _maybe_mutate_board(board: BoardData) -> void:
    if board == null:
        return
    var encounters: Dictionary = DataLoader.load_config("encounters")
    var interval: int = int(encounters.get("terrain_mutation_turns", 0))
    if interval <= 0:
        return
    if _current_turn() % interval != 0:
        return
    var pos: Vector2i = BoardGenerator.mutate_empty_tile(board, rng)
    if pos == Vector2i(-1, -1):
        return
    board_view.play_mutation_flash(pos)
    append_log("The Plain shifts.")

func _refresh_tactical_hud() -> void:
    if enemy_info_label == null:
        return
    var player: Unit = game_state.run_state.get("player", null) as Unit
    var enemies: Array = game_state.run_state.get("enemies", [])
    _update_enemy_panel(player, enemies)
    _update_turn_order(enemies)
    _update_items_panel(player)
    if tile_info_label.text.is_empty() or tile_info_label.text == "Tile: -":
        tile_info_label.text = "Tile: Hover the board."

func _update_tile_info(pos: Vector2i) -> void:
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if board == null:
        tile_info_label.text = "Tile: -"
        return
    var tile: Tile = board.get_tile(pos)
    if tile == null:
        tile_info_label.text = "Tile: Outside the law."
        return
    if tile.terrain_data.get("fog", false) and not tile.revealed:
        tile_info_label.text = "Tile %s\nFog. It does not answer yet." % _format_pos(pos)
        return

    var lines: Array = ["Tile %s: %s" % [_format_pos(pos), _terrain_label(tile.terrain_id)]]
    if MovementSystem.is_blocked(tile):
        lines.append("Blocks movement.")
    var movement_note: String = _movement_preview(pos, tile, player)
    if not movement_note.is_empty():
        lines.append(movement_note)
    if tile.piece != null:
        lines.append("%s HP %d/%d AP %d" % [tile.piece.display_name, tile.piece.hp, tile.piece.max_hp, tile.piece.ap])
        if player != null and selected == player and tile.piece != player and MovementSystem.is_adjacent(player.position, pos):
            var preview: Dictionary = CombatSystem.preview_attack(player, tile.piece, board)
            lines.append("Strike: %d-%d damage" % [int(preview.get("min", 0)), int(preview.get("max", 0))])
    tile_info_label.text = _join_strings(lines, "\n")

func _movement_preview(pos: Vector2i, tile: Tile, player: Unit) -> String:
    if player == null or selected != player or tile.piece != null:
        return ""
    if MovementSystem.is_blocked(tile):
        return "Move: blocked."
    var valid_moves: Array = MovementSystem.get_valid_moves(player, game_state.run_state.get("board", null) as BoardData)
    if pos in valid_moves:
        return "Move: legal. Cost 1 AP."
    return ""

func _format_pos(pos: Vector2i) -> String:
    return "%d,%d" % [pos.x + 1, pos.y + 1]

func _terrain_label(terrain_id: String) -> String:
    match terrain_id:
        "normal":
            return "Plain"
        "cursed":
            return "Cursed"
        "fire":
            return "Burning"
        "blessed":
            return "Blessed"
        "elevated":
            return "Raised"
        "fog":
            return "Fog"
        "rock":
            return "Rock"
        "house":
            return "House"
        _:
            return terrain_id.capitalize()

func _damage_detail(result: Dictionary) -> String:
    var parts: Array = []
    var terrain_bonus: int = int(result.get("terrain_bonus", 0))
    var terrain_reduce: int = int(result.get("terrain_reduce", 0))
    var ignored_def: int = int(result.get("ignored_def", 0))
    if terrain_bonus != 0:
        parts.append("+%d terrain" % terrain_bonus)
    if terrain_reduce != 0:
        parts.append("-%d terrain" % terrain_reduce)
    if ignored_def != 0:
        parts.append("ignores %d DEF" % ignored_def)
    if parts.is_empty():
        return ""
    return " (%s)" % _join_strings(parts, ", ")

func _update_enemy_panel(player: Unit, enemies: Array) -> void:
    if player == null or enemies.is_empty():
        enemy_info_label.text = "No enemy sighted."
        return
    var enemy: Unit = _nearest_enemy(player, enemies)
    if enemy == null:
        enemy_info_label.text = "No enemy sighted."
        return
    var dist: int = abs(enemy.position.x - player.position.x) + abs(enemy.position.y - player.position.y)
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    var intent: String = AISystem.describe_intent(enemy, board, player)
    enemy_info_label.text = "%s  HP %d/%d  AP %d\nATK %d  DEF %d  SPD %d  Range %d\nIntent: %s" % [
        enemy.display_name,
        enemy.hp,
        enemy.max_hp,
        enemy.ap,
        enemy.atk,
        enemy.def,
        enemy.spd,
        dist,
        intent
    ]

func _update_turn_order(enemies: Array) -> void:
    if enemies.is_empty():
        turn_order_label.text = "Order: The Plain waits."
        return
    var ordered: Array = enemies.duplicate()
    ordered.sort_custom(Callable(self, "_sort_units_by_spd_desc"))
    var names: Array = ["You"]
    var limit: int = int(min(4, ordered.size()))
    for i in range(limit):
        var enemy: Unit = ordered[i] as Unit
        if enemy != null:
            names.append(enemy.display_name)
    turn_order_label.text = "Order: %s" % _join_strings(names, " -> ")

func _update_items_panel(player: Unit) -> void:
    if player == null or player.items.is_empty():
        items_list_label.text = "No relics carried."
        return
    var lines: Array = []
    for item in player.items:
        if typeof(item) != TYPE_DICTIONARY:
            continue
        var item_data: Dictionary = item
        var school_name: String = str(item_data.get("school", "-")).capitalize()
        var details := _format_item_details(item_data)
        lines.append("%s [%s]: %s" % [item_data.get("display_name", "Relic"), school_name, details])
    if not player.active_synergies.is_empty():
        lines.append("Active: %s" % _join_strings(player.active_synergies, ", "))
    items_list_label.text = _join_strings(lines, "\n")

func _format_item_details(item: Dictionary) -> String:
    var parts: Array = []
    var stats: Dictionary = {}
    if typeof(item.get("stats", {})) == TYPE_DICTIONARY:
        stats = item.get("stats", {})
    for stat_name in ["hp", "atk", "def", "spd", "ap"]:
        var value: int = int(stats.get(stat_name, 0))
        if value == 0:
            continue
        var value_prefix := "+" if value > 0 else ""
        parts.append("%s%d %s" % [value_prefix, value, stat_name.to_upper()])
    var trigger_text := _trigger_summary(item)
    if not trigger_text.is_empty():
        parts.append(trigger_text)
    if parts.is_empty():
        return "No stat marks."
    return _join_strings(parts, "  |  ")

func _trigger_summary(item: Dictionary) -> String:
    var trigger_id: String = str(item.get("trigger_id", ""))
    match trigger_id:
        "on_hit_bleed":
            return "On hit: Bleed"
        "on_kill_heal":
            return "On kill: Heal %d" % int(item.get("trigger_value", 0))
        "on_hit_knockback":
            return "On hit: Push"
        "on_move_extra":
            return "Active: Extend move"
        "on_turn_ap":
            return "Turn start: +AP"
        "on_adj_defend":
            return "Adjacent threat: Shield"
        "on_low_hp_buff":
            return "Low HP: +ATK"
        _:
            return ""

func _nearest_enemy(player: Unit, enemies: Array) -> Unit:
    var best: Unit = null
    var best_dist := 999999
    for enemy in enemies:
        if enemy == null:
            continue
        var enemy_unit: Unit = enemy as Unit
        if enemy_unit == null:
            continue
        var dist: int = abs(enemy_unit.position.x - player.position.x) + abs(enemy_unit.position.y - player.position.y)
        if dist < best_dist:
            best = enemy_unit
            best_dist = dist
    return best

func _join_strings(values: Array, separator: String) -> String:
    var text := ""
    var first := true
    for value in values:
        if first:
            first = false
        else:
            text += separator
        text += str(value)
    return text

func _sort_units_by_spd_desc(a, b) -> bool:
    var unit_a: Unit = a as Unit
    var unit_b: Unit = b as Unit
    if unit_a == null:
        return false
    if unit_b == null:
        return true
    return unit_a.spd > unit_b.spd
