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
var _choice_overlay: ChoiceOverlay = null
var _pending_choice_node: Dictionary = {}
var _pending_choice_options: Array = []
var _pending_choice_mode := "outcome"
var _pending_item_pick := ""
var _pending_post_combat_options: Array = []
var _pending_post_combat_reward := ""
var _last_node_summary: Dictionary = {}
var _enemy_phase_movement_locked := false
var _encounter_completed := false
var _pending_run_setup: Dictionary = {}
var _pending_end_victory := false
var _pending_end_score := 0
var _run_result_recorded := false

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
    _choice_overlay = ChoiceOverlay.new()
    _choice_overlay.name = "ChoiceOverlay"
    add_child(_choice_overlay)
    _choice_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _choice_overlay.choice_selected.connect(_on_choice_selected)
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
    _choice_overlay.hide_choices()
    _show_run_setup_mode()

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

func start_run(setup: Dictionary = {}) -> void:
    score_manager.reset()
    player_items = []
    _pending_reward_node_id = ""
    _pending_choice_node = {}
    _pending_choice_options = []
    _pending_choice_mode = "outcome"
    _pending_item_pick = ""
    _pending_post_combat_options = []
    _pending_post_combat_reward = ""
    _last_node_summary = {}
    _run_result_recorded = false
    game_state.reset_run(setup)
    combat_log.clear_log()
    _apply_starter_items()
    _log_run_setup()
    _generate_run_path()
    _show_path_choice()

func _generate_run_path() -> void:
    var run_cfg: Dictionary = DataLoader.load_config("run_nodes")
    var path_graph := RunPathGenerator.generate_path(rng, run_cfg)
    path_graph = _apply_run_mode_to_path(path_graph, run_cfg)
    game_state.run_state["path_graph"] = path_graph
    game_state.run_state["current_floor"] = 0
    game_state.run_state["current_node"] = {}

func _apply_run_mode_to_path(path_graph: Dictionary, run_cfg: Dictionary) -> Dictionary:
    if _current_setup_id("mode", "legacy") == "legacy":
        return path_graph
    var nodes: Dictionary = path_graph.get("nodes", {})
    var node_types: Dictionary = run_cfg.get("node_types", {})
    for node_id in nodes.keys():
        var node: Dictionary = nodes[node_id]
        if str(node.get("type", "")) != "story":
            continue
        var replacement_type := "relic" if int(node.get("floor", 1)) % 2 == 0 else "shrine"
        var type_cfg: Dictionary = node_types.get(replacement_type, {})
        node["type"] = replacement_type
        node["label"] = str(type_cfg.get("label", replacement_type.capitalize()))
        node["icon"] = str(type_cfg.get("icon", "Node"))
        node["summary"] = str(type_cfg.get("summary", "The Plain waits."))
        node["reward"] = str(type_cfg.get("reward", "none"))
        nodes[node_id] = node
    path_graph["nodes"] = nodes
    return path_graph

func _annotate_path_previews(path_graph: Dictionary) -> void:
    var nodes: Dictionary = path_graph.get("nodes", {})
    for node_id in nodes.keys():
        var node: Dictionary = nodes[node_id]
        node["preview"] = _preview_for_node(node)
        nodes[node_id] = node
    path_graph["nodes"] = nodes

func _preview_for_node(node: Dictionary) -> Dictionary:
    var node_type: String = str(node.get("type", "combat"))
    var pacing := _pacing_for_floor(int(node.get("floor", 1)))
    var risk: String = str(DataLoader.load_config("run_pacing").get("node_risk", {}).get(node_type, "Unknown"))
    var preview := {
        "risk": risk,
        "intensity": str(pacing.get("intensity", "unknown")).capitalize(),
        "summary": str(pacing.get("preview", node.get("summary", ""))),
        "reward": _reward_preview(node),
        "objective": _objective_preview_for_node(node),
        "enemy_count": 0,
        "pattern": ""
    }
    if node_type in ["combat", "elite", "ambush", "boss"]:
        var template := _best_preview_template(node)
        var enemies: Array = template.get("enemies", [])
        preview["enemy_count"] = enemies.size() + _active_enemy_count_bonus()
        preview["pattern"] = str(template.get("label", "Unstable Pattern"))
    return preview

func _reward_preview(node: Dictionary) -> String:
    var node_type: String = str(node.get("type", "combat"))
    match node_type:
        "combat":
            return "Gold + relic draft"
        "elite":
            return "More gold + larger draft"
        "ambush":
            return "High gold + relic draft"
        "boss":
            return "Run completion"
        "relic":
            return "Larger relic draft"
        "rest":
            return "Heal or scavenge"
        "story":
            return "Choice consequence"
        "shrine":
            return "Perk choice"
        "shop":
            return "Spend gold"
        "upgrade":
            return "Improve the run"
        "ally_hire":
            return "Temporary contract"
        _:
            return "Unknown"

func _path_run_context() -> Dictionary:
    var setup: Dictionary = game_state.run_state.get("setup", {})
    var theme_cfg := _current_theme_cfg()
    var difficulty_cfg := _current_difficulty_cfg()
    var consequences: Array = game_state.run_state.get("active_consequences", [])
    var consequence_names: Array = []
    for consequence in consequences:
        if typeof(consequence) == TYPE_DICTIONARY:
            consequence_names.append(str((consequence as Dictionary).get("label", "Consequence")))
    var contracts: Array = game_state.run_state.get("active_contracts", [])
    var contract_names: Array = []
    for contract in contracts:
        if typeof(contract) == TYPE_DICTIONARY:
            contract_names.append("%s (%d)" % [str((contract as Dictionary).get("label", "Contract")), int((contract as Dictionary).get("duration", 0))])
    var allies: Array = game_state.run_state.get("active_allies", [])
    var ally_names: Array = []
    for ally in allies:
        if typeof(ally) == TYPE_DICTIONARY:
            ally_names.append("%s (%d)" % [str((ally as Dictionary).get("display_name", "Ally")), int((ally as Dictionary).get("duration", 0))])
    return {
        "mode": str(setup.get("mode", "legacy")).capitalize(),
        "theme": str(theme_cfg.get("display_name", "Neutral")),
        "difficulty": str(difficulty_cfg.get("display_name", "Wanderer")),
        "gold": int(game_state.run_state.get("gold", 0)),
        "consequences": consequence_names,
        "contracts": contract_names,
        "allies": ally_names,
        "legacy_boss": str(game_state.get_legacy_boss().get("display_name", ""))
    }

func _objective_preview_for_node(node: Dictionary) -> String:
    var node_type: String = str(node.get("type", "combat"))
    if not node_type in ["combat", "elite", "ambush"]:
        return ""
    var chance := _objective_chance_for_node_type(node_type, int(node.get("floor", 1)))
    if chance <= 0.0:
        return ""
    return "Objective chance: %d%%" % int(round(chance * 100.0))

func _show_run_setup_mode() -> void:
    var cfg: Dictionary = DataLoader.load_config("run_themes")
    _pending_run_setup = cfg.get("default_setup", {}).duplicate(true)
    _pending_choice_mode = "setup_mode"
    _pending_choice_options = _config_choice_options(cfg.get("modes", {}), "mode")
    _choice_overlay.show_choices(
        "Choose the Run",
        "The first square waits to learn what kind of law you will enter.",
        _pending_choice_options
    )

func _show_run_setup_theme() -> void:
    var cfg: Dictionary = DataLoader.load_config("run_themes")
    _pending_choice_mode = "setup_theme"
    _pending_choice_options = _config_choice_options(cfg.get("themes", {}), "theme")
    _choice_overlay.show_choices(
        "Choose the Plain",
        "Every version of the board lies in a different way.",
        _pending_choice_options
    )

func _show_run_setup_difficulty() -> void:
    var cfg: Dictionary = DataLoader.load_config("run_themes")
    _pending_choice_mode = "setup_difficulty"
    _pending_choice_options = _config_choice_options(cfg.get("difficulties", {}), "difficulty")
    _choice_overlay.show_choices(
        "Choose the Pressure",
        "The score grows with the cruelty that witnesses it.",
        _pending_choice_options
    )

func _config_choice_options(entries: Dictionary, value_key: String) -> Array:
    var options: Array = []
    for id in entries.keys():
        var entry: Dictionary = entries[id]
        options.append({
            "label": str(entry.get("display_name", str(id).capitalize())),
            "summary": str(entry.get("summary", "")),
            "value": str(id),
            "value_key": value_key
        })
    return options

func _on_setup_choice_selected(index: int) -> void:
    if index < 0 or index >= _pending_choice_options.size():
        return
    var option: Dictionary = _pending_choice_options[index]
    var key: String = str(option.get("value_key", ""))
    if not key.is_empty():
        _pending_run_setup[key] = str(option.get("value", ""))
    _choice_overlay.hide_choices()
    _pending_choice_options = []
    match _pending_choice_mode:
        "setup_mode":
            _show_run_setup_theme()
        "setup_theme":
            _show_run_setup_difficulty()
        "setup_difficulty":
            _pending_choice_mode = "outcome"
            start_run(_pending_run_setup)

func _log_run_setup() -> void:
    var setup: Dictionary = game_state.run_state.get("setup", {})
    var cfg: Dictionary = DataLoader.load_config("run_themes")
    var mode: Dictionary = cfg.get("modes", {}).get(str(setup.get("mode", "legacy")), {})
    var theme_entry: Dictionary = cfg.get("themes", {}).get(str(setup.get("theme", "neutral")), {})
    var difficulty: Dictionary = cfg.get("difficulties", {}).get(str(setup.get("difficulty", "wanderer")), {})
    append_log("%s. %s. %s." % [
        str(mode.get("display_name", "Legacy Run")),
        str(theme_entry.get("display_name", "Neutral")),
        str(difficulty.get("display_name", "Wanderer"))
    ])

func _best_preview_template(node: Dictionary) -> Dictionary:
    var templates_cfg: Dictionary = DataLoader.load_config("encounter_templates")
    var templates: Array = templates_cfg.get("templates", [])
    var node_type: String = str(node.get("type", "combat"))
    var floor_index: int = int(node.get("floor", 1))
    var allowed_tags: Array = _pacing_for_floor(floor_index).get("template_tags", [])
    var best: Dictionary = {}
    var best_score := -999999
    for entry in templates:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var template: Dictionary = entry
        if not _template_matches(template, node_type, floor_index):
            continue
        var score: int = int(template.get("weight", 1)) + _template_tag_score(template, allowed_tags)
        if score > best_score:
            best = template
            best_score = score
    return best

func _show_path_choice() -> void:
    selected = null
    board_view.clear_highlights()
    board_view.visible = false
    board_backdrop.visible = false
    bottom_bar.visible = false
    ui_backdrop.visible = false
    item_draft.hide_draft()
    end_screen.hide_screen()
    _choice_overlay.hide_choices()
    var path_graph: Dictionary = game_state.run_state.get("path_graph", {})
    var available: Array = path_graph.get("available", [])
    _annotate_path_previews(path_graph)
    path_graph["run_context"] = _path_run_context()
    game_state.run_state["path_graph"] = path_graph
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
            _apply_node_rewards(node)
            show_item_draft(_draft_reward_for_node(node))
        "rest":
            _resolve_rest_node(node)
        "story":
            _resolve_story_node(node)
        "shrine":
            _resolve_shrine_node(node)
        "shop":
            _resolve_shop_node(node)
        "upgrade":
            _resolve_upgrade_node(node)
        "ally_hire":
            _resolve_ally_hire_node(node)
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
    var template: Dictionary = _select_encounter_template(node)
    if not template.is_empty():
        encounter_cfg["template"] = template
    var node_id: String = str(node.get("id", ""))
    var floor_index: int = int(node.get("floor", 1))

    game_state.run_state["encounter_index"] = floor_index - 1
    game_state.run_state["active_node_id"] = node_id
    game_state.run_state["turn"] = 1
    _encounter_completed = false

    var board := BoardGenerator.generate_board(rng, encounter_cfg.get("board", {}))
    game_state.run_state["board"] = board
    _apply_template_terrain(board, template)
    _apply_pacing_terrain(board, floor_index)
    _apply_theme_terrain(board)
    _apply_consequence_terrain(board)

    var player := _get_or_create_player()
    var player_pos := _spawn_player(board)
    board.set_unit(player_pos, player)
    reveal_adjacent(board, player.position)

    var enemies := _spawn_enemies(board, encounter_cfg)
    _spawn_legacy_boss_if_needed(board, encounter_cfg, enemies)
    game_state.run_state["enemies"] = enemies
    var allies := _spawn_allies(board)
    game_state.run_state["allies"] = allies
    _apply_pending_board_mutations(board)
    _place_encounter_objective(board, node, floor_index)

    board_view.build_board(board)
    board_view.update_board(board)
    _apply_layout()
    stats_panel.update_unit(player)
    _refresh_tactical_hud()

    append_log("Floor %d: %s" % [floor_index, str(node.get("label", "Combat"))])
    if not template.is_empty():
        append_log("Pattern: %s - %s" % [str(template.get("label", "Encounter")), str(template.get("summary", ""))])
    _log_objective_intro()
    _log_active_consequences()
    _log_active_contracts()
    _decrement_consequences_after_encounter_start()
    _decrement_contracts_after_encounter_start()
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
    var theme_cfg := _current_theme_cfg()
    var difficulty_cfg := _current_difficulty_cfg()
    var enemy_types: Array = cfg.get("enemy_types", [])
    for piece_id in theme_cfg.get("enemy_pool_bonus", []):
        if not piece_id in enemy_types:
            enemy_types.append(piece_id)
    cfg["enemy_types"] = enemy_types
    cfg["enemy_stat_bonus"] = _merge_stat_bonuses(
        cfg.get("enemy_stat_bonus", {}),
        difficulty_cfg.get("enemy_stat_bonus", {})
    )
    var count_bonus: int = _active_enemy_count_bonus() + int(_pacing_for_floor(floor_index).get("enemy_count_bonus", 0)) + int(difficulty_cfg.get("enemy_count_bonus", 0))
    cfg["spawn_min"] = max(1, int(cfg.get("spawn_min", 1)) + count_bonus)
    cfg["spawn_max"] = max(int(cfg.get("spawn_min", 1)), int(cfg.get("spawn_max", 1)) + count_bonus)
    return cfg

func _select_encounter_template(node: Dictionary) -> Dictionary:
    var templates_cfg: Dictionary = DataLoader.load_config("encounter_templates")
    var templates: Array = templates_cfg.get("templates", [])
    var node_type: String = str(node.get("type", "combat"))
    var floor_index: int = int(node.get("floor", 1))
    var allowed_tags: Array = _pacing_for_floor(floor_index).get("template_tags", [])
    var candidates: Array = []
    var weights: Array = []
    var total_weight := 0
    for entry in templates:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var template: Dictionary = entry
        if not _template_matches(template, node_type, floor_index):
            continue
        var weight: int = max(1, int(template.get("weight", 1)) + _template_tag_score(template, allowed_tags))
        candidates.append(template)
        weights.append(weight)
        total_weight += weight
    if candidates.is_empty():
        return {}
    var roll := rng.randi_range(1, total_weight)
    var running := 0
    for i in range(candidates.size()):
        running += int(weights[i])
        if roll <= running:
            return (candidates[i] as Dictionary).duplicate(true)
    return (candidates[0] as Dictionary).duplicate(true)

func _template_matches(template: Dictionary, node_type: String, floor_index: int) -> bool:
    var node_types: Array = template.get("node_types", [])
    if not node_type in node_types:
        return false
    if floor_index < int(template.get("min_floor", 1)):
        return false
    if template.has("max_floor") and floor_index > int(template.get("max_floor", floor_index)):
        return false
    return true

func _template_tag_score(template: Dictionary, allowed_tags: Array) -> int:
    var score := 0
    var tags: Array = template.get("tags", [])
    for tag in tags:
        if tag in allowed_tags:
            score += 8
    return score

func _pacing_for_floor(floor_index: int) -> Dictionary:
    var pacing: Dictionary = DataLoader.load_config("run_pacing").get("floors", {})
    return pacing.get(str(floor_index), {})

func _board_cfg_for_floor(floor_index: int) -> Dictionary:
    var cfg: Dictionary = DataLoader.load_config("map_generation")
    var bands: Array = cfg.get("floor_bands", [])
    for band_value in bands:
        if typeof(band_value) != TYPE_DICTIONARY:
            continue
        var band: Dictionary = band_value
        if floor_index >= int(band.get("min_floor", 1)) and floor_index <= int(band.get("max_floor", 999)):
            return {
                "floor": floor_index,
                "rows": int(band.get("rows", 8)),
                "cols": int(band.get("cols", 9)),
                "theme": _current_setup_id("theme", "neutral")
            }
    var fallback: Dictionary = DataLoader.load_config("encounters").get("board", { "rows": 8, "cols": 9 })
    fallback["floor"] = floor_index
    fallback["theme"] = _current_setup_id("theme", "neutral")
    return fallback

func start_player_phase() -> void:
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if player == null:
        return
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    turn_system.start_player_phase(player, board)
    selected = player
    _show_player_action_range()
    stats_panel.set_phase("Player", _current_turn())
    stats_panel.update_unit(player)
    _refresh_tactical_hud()

func start_enemy_phase(movement_locked: bool = false) -> void:
    _enemy_phase_movement_locked = movement_locked
    var enemies: Array = game_state.run_state.get("enemies", [])
    stats_panel.set_phase("Enemy", _current_turn())
    _refresh_tactical_hud()
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    var ordered := turn_system.start_enemy_phase(enemies, board)
    for enemy in ordered:
        var enemy_unit: Unit = enemy as Unit
        if enemy_unit == null or enemy_unit.is_dead():
            continue
        await _run_enemy_turn(enemy_unit, _enemy_phase_movement_locked)
        if _check_player_dead():
            _enemy_phase_movement_locked = false
            return
        if _check_encounter_cleared():
            _enemy_phase_movement_locked = false
            return
        var costs: Dictionary = DataLoader.load_config("action_costs")
        var delay_ms: int = int(costs.get("enemy_action_delay_ms", 120))
        if delay_ms > 0:
            await get_tree().create_timer(float(delay_ms) / 1000.0).timeout
    _enemy_phase_movement_locked = false
    start_tick_phase()

func start_tick_phase() -> void:
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    var units := _all_units()
    stats_panel.set_phase("Tick", _current_turn())
    turn_system.start_tick_phase(units, board)
    if _update_objectives_on_tick():
        return
    _apply_theme_tick(board)
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

    var costs: Dictionary = DataLoader.load_config("action_costs")
    var attack_cost: int = int(costs.get("attack", 1))
    var move_cost: int = int(costs.get("move", 1))
    if tile.piece != null and tile.piece != player and MovementSystem.can_attack(player, tile.piece, board):
        if turn_system.spend_ap(player, attack_cost):
            _resolving_action = true
            _attack(player, tile.piece)
            await _after_player_action()
            _resolving_action = false
        return
    var valid_moves: Array = MovementSystem.get_valid_moves(player, board)
    if pos in valid_moves and turn_system.spend_ap(player, move_cost):
        _resolving_action = true
        await _resolve_player_move(player, pos)
        await _after_player_action(_simultaneous_move_enabled())
        _resolving_action = false
        return
    _show_player_action_range()

func _on_tile_hovered(pos: Vector2i) -> void:
    if turn_system.phase == TurnSystem.Phase.PLAYER:
        board_view.set_preview_tile(pos)
        _show_enemy_response_preview(pos)
    _update_tile_info(pos)

func _get_attack_positions(unit: Unit, board: BoardData) -> Array:
    return MovementSystem.get_attack_positions(unit, board)

func _show_player_action_range() -> void:
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if board == null or player == null:
        board_view.clear_highlights()
        return
    var moves: Array = MovementSystem.get_valid_moves(player, board)
    var attacks: Array = _get_attack_positions(player, board)
    board_view.show_highlights(moves, attacks, player.position)

func _show_enemy_response_preview(player_target: Vector2i) -> void:
    var response := _enemy_response_for_target(player_target)
    board_view.show_enemy_intents(response.get("intent_positions", []), response.get("danger_positions", []))

func _enemy_response_for_target(player_target: Vector2i) -> Dictionary:
    var result := {
        "legal": false,
        "plans": [],
        "intent_positions": [],
        "danger_positions": [],
        "threats": [],
        "blocked": []
    }
    if not _simultaneous_move_enabled():
        return result
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if board == null or player == null:
        return result
    if not player_target in MovementSystem.get_valid_moves(player, board):
        return result

    var enemies: Array = game_state.run_state.get("enemies", [])
    var plans: Array = [{
        "unit": player,
        "from": player.position,
        "to": player_target,
        "is_player": true
    }]
    plans.append_array(SimultaneousMovementSystem.build_enemy_move_plans(enemies, board, player, player_target))
    var resolved: Dictionary = SimultaneousMovementSystem.resolve_move_plans(board, plans)
    var approved: Array = resolved.get("approved", [])
    var blocked: Array = resolved.get("blocked", [])
    result["legal"] = true
    result["plans"] = approved
    result["blocked"] = blocked

    var intents: Array = []
    var dangers: Array = []
    var threats: Array = []
    for plan in approved:
        var unit: Unit = plan.get("unit", null) as Unit
        if unit == null or unit.is_player:
            continue
        var target: Vector2i = plan.get("to", unit.position)
        intents.append(target)
        if _position_can_attack(unit, target, player_target, board):
            dangers.append(target)
            threats.append(unit.display_name)
    result["intent_positions"] = intents
    result["danger_positions"] = dangers
    result["threats"] = threats
    return result

func _after_player_action(enemy_movement_locked: bool = false) -> void:
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
        await start_ally_phase(enemy_movement_locked)

func _on_end_turn_pressed() -> void:
    if _resolving_action or turn_system.phase != TurnSystem.Phase.PLAYER:
        return
    _resolving_action = true
    await start_ally_phase()
    _resolving_action = false

func start_ally_phase(enemy_movement_locked: bool = false) -> void:
    var allies: Array = game_state.run_state.get("allies", [])
    var active_allies: Array = []
    for ally_value in allies:
        var ally: Unit = ally_value as Unit
        if ally != null and not ally.is_dead():
            active_allies.append(ally)
    if active_allies.is_empty():
        await start_enemy_phase(enemy_movement_locked)
        return
    turn_system.start_ally_phase()
    stats_panel.set_phase("Ally", _current_turn())
    _refresh_tactical_hud()
    active_allies.sort_custom(Callable(self, "_sort_units_by_spd_desc"))
    for ally_value in active_allies:
        var ally: Unit = ally_value as Unit
        if ally == null or ally.is_dead():
            continue
        ally.ap = ally.max_ap
        await _run_ally_turn(ally)
        if _check_encounter_cleared():
            return
        var costs: Dictionary = DataLoader.load_config("action_costs")
        var delay_ms: int = int(costs.get("enemy_action_delay_ms", 120))
        if delay_ms > 0:
            await get_tree().create_timer(float(delay_ms) / 1000.0).timeout
    await start_enemy_phase(enemy_movement_locked)

func _run_ally_turn(ally: Unit) -> void:
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    if board == null:
        return
    var enemies: Array = game_state.run_state.get("enemies", [])
    var target := _nearest_target(ally, enemies)
    if target == null:
        return
    await _run_ai_turn_against(ally, target, false)

func _run_enemy_turn(enemy: Unit, movement_locked: bool = false) -> void:
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if board == null or player == null:
        return
    await _run_ai_turn_against(enemy, player, movement_locked)

func _run_ai_turn_against(unit: Unit, target_unit: Unit, movement_locked: bool = false) -> void:
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    if board == null or unit == null or target_unit == null:
        return
    var costs: Dictionary = DataLoader.load_config("action_costs")
    var attack_cost: int = int(costs.get("attack", 1))
    var move_cost: int = int(costs.get("move", 1))
    var wait_cost: int = int(costs.get("wait", 1))

    var action := AISystem.decide_action(unit, board, target_unit)
    var action_type: String = str(action.get("type", "wait"))
    if action_type == "attack":
        if MovementSystem.can_attack(unit, target_unit, board) and turn_system.spend_ap(unit, attack_cost):
            _attack(unit, target_unit)
            _refresh_tactical_hud()
            if target_unit.is_dead():
                return
    elif action_type == "move":
        if movement_locked:
            turn_system.spend_ap(unit, wait_cost)
            if bool(costs.get("one_action_per_unit_phase", true)):
                unit.ap = 0
            return
        var target_value: Variant = action.get("target", unit.position)
        var target: Vector2i = unit.position
        if typeof(target_value) == TYPE_VECTOR2I:
            target = target_value
        if target == unit.position:
            turn_system.spend_ap(unit, wait_cost)
        elif turn_system.spend_ap(unit, move_cost):
            await _move_unit(unit, target)
            _refresh_tactical_hud()
    else:
        turn_system.spend_ap(unit, wait_cost)

    if bool(costs.get("one_action_per_unit_phase", true)):
        unit.ap = 0

func _resolve_player_move(player: Unit, target: Vector2i) -> void:
    if not _simultaneous_move_enabled():
        await _move_unit(player, target)
        return
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    if board == null or player == null:
        return
    var enemies: Array = game_state.run_state.get("enemies", [])
    var plans: Array = [{
        "unit": player,
        "from": player.position,
        "to": target,
        "is_player": true
    }]
    plans.append_array(SimultaneousMovementSystem.build_enemy_move_plans(enemies, board, player, target))
    var resolved: Dictionary = SimultaneousMovementSystem.resolve_move_plans(board, plans)
    var approved: Array = resolved.get("approved", [])
    var moved_enemies: Array = []
    if approved.is_empty():
        return
    for plan in approved:
        var unit: Unit = plan.get("unit", null) as Unit
        if unit != null and not unit.is_player:
            moved_enemies.append(unit.display_name)
    if not moved_enemies.is_empty() and bool(DataLoader.load_config("simultaneous_movement").get("log_enemy_plans", true)):
        append_log("The line moves with you: %s" % _join_strings(moved_enemies, ", "))
    await _apply_move_plans(approved)

func _apply_move_plans(plans: Array) -> void:
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    if board == null:
        return
    for plan in plans:
        var unit: Unit = plan.get("unit", null) as Unit
        if unit == null:
            continue
        var from_pos: Vector2i = plan.get("from", unit.position)
        board.clear_unit(from_pos)
    for plan in plans:
        var unit: Unit = plan.get("unit", null) as Unit
        if unit == null:
            continue
        var target: Vector2i = plan.get("to", unit.position)
        board.set_unit(target, unit)
    board_view.update_board(board)
    for plan in plans:
        var unit: Unit = plan.get("unit", null) as Unit
        if unit == null:
            continue
        var from_pos: Vector2i = plan.get("from", unit.position)
        var target: Vector2i = plan.get("to", unit.position)
        await board_view.animate_unit_move(from_pos, target, unit)
    for plan in plans:
        var unit: Unit = plan.get("unit", null) as Unit
        if unit != null:
            _apply_entry_effect(unit)
    _remove_dead_units()
    board_view.update_board(board)

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
    var victim_pos := victim.position
    board.clear_unit(victim.position)

    if attacker.is_player:
        attacker.kills += 1
        if victim.is_boss:
            score_manager.add_score("boss_kill")
        else:
            score_manager.add_score("enemy_kill")
        if EvolutionSystem.check_and_evolve(attacker):
            _refresh_player_build(attacker)
            _record_evolution_step(attacker.piece_id)
            score_manager.add_score("evolution")
            append_log("Evolved to %s" % attacker.display_name)
            stats_panel.update_unit(attacker)
        _apply_theme_on_player_kill(victim_pos)
    elif attacker.is_ally and not victim.is_player and not victim.is_ally:
        score_manager.add_score("enemy_kill")

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
    _apply_entry_effect(unit)

func _apply_entry_effect(unit: Unit) -> void:
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    if board == null or unit == null:
        return
    var tile: Tile = board.get_tile(unit.position)
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
            if _handle_player_objective_entry(unit.position):
                return

func _check_encounter_cleared() -> bool:
    if _encounter_completed:
        return true
    var enemies: Array = game_state.run_state.get("enemies", [])
    if enemies.size() > 0:
        return false
    return _complete_encounter("all enemies fell")

func _complete_encounter(reason: String) -> bool:
    if _encounter_completed:
        return true
    _encounter_completed = true
    game_state.run_state["encounter_complete_reason"] = reason
    var node: Dictionary = game_state.run_state.get("current_node", {})
    var node_type: String = str(node.get("type", "combat"))
    _last_node_summary = _make_node_summary(node)
    _save_active_ally_hp()
    _decrement_allies_after_encounter_complete()
    _apply_node_rewards(node)
    if node_type == "boss":
        end_run(true)
    else:
        var reward: String = _draft_reward_for_node(node)
        if reward == "draft" or reward == "elite_draft":
            _pending_reward_node_id = str(node.get("id", ""))
            _show_post_combat_summary(reward)
        else:
            _show_post_combat_summary("")
    return true

func _place_encounter_objective(board: BoardData, node: Dictionary, floor_index: int) -> void:
    var objective := _select_objective(node, floor_index)
    game_state.run_state["objective"] = {}
    if objective.is_empty():
        return
    var pos := _pick_objective_position(board, str(objective.get("placement", "center")))
    if pos == Vector2i(-1, -1):
        return
    objective["position"] = pos
    objective["completed"] = false
    objective["hold_progress"] = 0
    game_state.run_state["objective"] = objective
    var tile: Tile = board.get_tile(pos)
    if tile != null:
        tile.objective_id = str(objective.get("id", ""))
        tile.objective_type = str(objective.get("type", ""))

func _select_objective(node: Dictionary, floor_index: int) -> Dictionary:
    var cfg: Dictionary = DataLoader.load_config("encounter_objectives")
    var node_type: String = str(node.get("type", "combat"))
    var chance: float = _objective_chance_for_node_type(node_type, floor_index)
    if chance <= 0.0 or rng.randf() > chance:
        return {}
    var types: Dictionary = cfg.get("types", {})
    var candidates: Array = []
    var weights: Array = []
    var total_weight := 0
    for type_id in types.keys():
        var entry: Dictionary = types[type_id]
        if floor_index < int(entry.get("min_floor", 1)):
            continue
        var weight: int = max(1, int(entry.get("weight", 1)))
        var copy: Dictionary = entry.duplicate(true)
        copy["id"] = "%s_%d" % [str(type_id), floor_index]
        copy["type"] = str(type_id)
        candidates.append(copy)
        weights.append(weight)
        total_weight += weight
    if candidates.is_empty():
        return {}
    var roll := rng.randi_range(1, total_weight)
    var running := 0
    for i in range(candidates.size()):
        running += int(weights[i])
        if roll <= running:
            return candidates[i]
    return candidates[0]

func _pick_objective_position(board: BoardData, placement: String) -> Vector2i:
    var player: Unit = game_state.run_state.get("player", null) as Unit
    var positions := _objective_candidates(board, placement)
    if positions.is_empty():
        return Vector2i(-1, -1)
    var best: Vector2i = positions[0]
    if placement == "far_from_player" and player != null:
        var best_dist := -999999
        for pos in positions:
            var dist: int = abs(pos.x - player.position.x) + abs(pos.y - player.position.y)
            if dist > best_dist:
                best = pos
                best_dist = dist
        return best
    positions.shuffle()
    return positions[0]

func _objective_candidates(board: BoardData, placement: String) -> Array[Vector2i]:
    var positions: Array[Vector2i] = []
    var source: Array = []
    match placement:
        "center":
            source = _positions_for_zone(board, "center")
        "far_from_player":
            source = _positions_for_zone(board, "top_right")
            source.append_array(_positions_for_zone(board, "center"))
        _:
            source = _positions_for_zone(board, "center")
    for pos in source:
        var tile: Tile = board.get_tile(pos)
        if tile == null or tile.piece != null or MovementSystem.is_blocked(tile):
            continue
        if not tile.objective_type.is_empty():
            continue
        positions.append(pos)
    return positions

func _handle_player_objective_entry(pos: Vector2i) -> bool:
    var objective: Dictionary = game_state.run_state.get("objective", {})
    if objective.is_empty() or bool(objective.get("completed", false)):
        return false
    if pos != objective.get("position", Vector2i(-1, -1)):
        return false
    var objective_type: String = str(objective.get("type", ""))
    match objective_type:
        "cache":
            _complete_objective(false)
            return false
        "escape":
            _complete_objective(true)
            return true
        "seal":
            append_log("The seal waits. Hold through the answer.")
            return false
    return false

func _update_objectives_on_tick() -> bool:
    var objective: Dictionary = game_state.run_state.get("objective", {})
    if objective.is_empty() or bool(objective.get("completed", false)):
        return false
    if str(objective.get("type", "")) != "seal":
        return false
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if player == null or player.is_dead():
        return false
    if player.position == objective.get("position", Vector2i(-1, -1)):
        objective["hold_progress"] = int(objective.get("hold_progress", 0)) + 1
        game_state.run_state["objective"] = objective
        append_log("The seal counts you: %d/%d" % [int(objective.get("hold_progress", 0)), int(objective.get("hold_turns", 1))])
        if int(objective.get("hold_progress", 0)) >= int(objective.get("hold_turns", 1)):
            _complete_objective(true)
            return true
    elif int(objective.get("hold_progress", 0)) > 0:
        objective["hold_progress"] = 0
        game_state.run_state["objective"] = objective
        append_log("The seal opens again.")
    return false

func _complete_objective(clear_encounter: bool) -> void:
    var objective: Dictionary = game_state.run_state.get("objective", {})
    if objective.is_empty() or bool(objective.get("completed", false)):
        return
    objective["completed"] = true
    game_state.run_state["objective"] = objective
    _clear_objective_marker(objective)
    _apply_objective_reward(objective)
    if clear_encounter:
        _complete_encounter(str(objective.get("display_name", "Objective")))
    else:
        board_view.update_board(game_state.run_state.get("board", null) as BoardData)
        _refresh_tactical_hud()

func _apply_objective_reward(objective: Dictionary) -> void:
    var log_text: String = str(objective.get("log", ""))
    if not log_text.is_empty():
        append_log(log_text)
    var gold_delta: int = _roll_int_range(objective.get("reward_gold", [0, 0]))
    gold_delta += int(_current_theme_cfg().get("theme_mechanic", {}).get("objective_gold_bonus", 0))
    if gold_delta != 0:
        game_state.run_state["gold"] = max(0, int(game_state.run_state.get("gold", 0)) + gold_delta)
        append_log("Gold %+d" % gold_delta)
    var score_events: Array = objective.get("score_events", [])
    for event_id in score_events:
        score_manager.add_score(str(event_id))

func _objective_chance_for_node_type(node_type: String, floor_index: int) -> float:
    var cfg: Dictionary = DataLoader.load_config("encounter_objectives")
    var chance: float = float(cfg.get("objective_chance", {}).get(node_type, 0.0))
    var bonuses: Array = cfg.get("floor_chance_bonus", [])
    for bonus_value in bonuses:
        if typeof(bonus_value) != TYPE_DICTIONARY:
            continue
        var bonus: Dictionary = bonus_value
        if floor_index >= int(bonus.get("min_floor", 1)):
            chance += float(bonus.get("bonus", 0.0))
    return clamp(chance, 0.0, 1.0)

func _clear_objective_marker(objective: Dictionary) -> void:
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    if board == null:
        return
    var pos: Vector2i = objective.get("position", Vector2i(-1, -1))
    var tile: Tile = board.get_tile(pos)
    if tile == null:
        return
    tile.objective_id = ""
    tile.objective_type = ""

func _log_objective_intro() -> void:
    var objective: Dictionary = game_state.run_state.get("objective", {})
    if objective.is_empty():
        return
    append_log("Objective: %s - %s" % [str(objective.get("display_name", "Objective")), str(objective.get("summary", ""))])

func _make_node_summary(node: Dictionary) -> Dictionary:
    var player: Unit = game_state.run_state.get("player", null) as Unit
    var score_before: int = score_manager.get_base_score()
    return {
        "label": str(node.get("label", "Node")),
        "floor": int(node.get("floor", 0)),
        "hp": player.hp if player != null else 0,
        "max_hp": player.max_hp if player != null else 0,
        "kills": player.kills if player != null else 0,
        "gold_before": int(game_state.run_state.get("gold", 0)),
        "score_before": score_before
    }

func _show_post_combat_summary(reward: String) -> void:
    _pending_choice_mode = "post_combat"
    _pending_post_combat_reward = reward
    _pending_post_combat_options = [{
        "label": "Continue",
        "summary": "Take the result and move on."
    }]
    board_view.visible = false
    board_backdrop.visible = false
    bottom_bar.visible = false
    ui_backdrop.visible = false
    _choice_overlay.show_choices("Node Cleared", _format_post_combat_summary(), _pending_post_combat_options)

func _format_post_combat_summary() -> String:
    var player: Unit = game_state.run_state.get("player", null) as Unit
    var hp_text := "-"
    var kills := 0
    if player != null:
        hp_text = "%d/%d" % [player.hp, player.max_hp]
        kills = player.kills
    var gold_delta: int = int(game_state.run_state.get("gold", 0)) - int(_last_node_summary.get("gold_before", 0))
    var score_delta: int = score_manager.get_base_score() - int(_last_node_summary.get("score_before", 0))
    var lines: Array = [
        "Floor %d: %s" % [int(_last_node_summary.get("floor", 0)), str(_last_node_summary.get("label", "Node"))],
        "HP: %s" % hp_text,
        "Fallen: %d" % kills,
        "Gold %+d" % gold_delta,
        "Score %+d" % score_delta
    ]
    var clear_reason: String = str(game_state.run_state.get("encounter_complete_reason", ""))
    if not clear_reason.is_empty():
        lines.append("Cleared by: %s" % clear_reason)
    var objective: Dictionary = game_state.run_state.get("objective", {})
    if not objective.is_empty():
        var objective_status := "completed" if bool(objective.get("completed", false)) else "missed"
        lines.append("Objective: %s (%s)" % [str(objective.get("display_name", "Objective")), objective_status])
    var consequences: Array = game_state.run_state.get("active_consequences", [])
    if not consequences.is_empty():
        var names: Array = []
        for consequence in consequences:
            if typeof(consequence) == TYPE_DICTIONARY:
                names.append(str((consequence as Dictionary).get("label", "Omen")))
        if not names.is_empty():
            lines.append("Carried forward: %s" % _join_strings(names, ", "))
    if not _pending_post_combat_reward.is_empty():
        lines.append("Reward waits: %s" % _pending_post_combat_reward.capitalize())
    return _join_strings(lines, "\n")

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
    var outcomes: Dictionary = DataLoader.load_config("run_outcomes")
    var draft_rewards: Dictionary = outcomes.get("draft_rewards", {})
    var draft_cfg: Dictionary = draft_rewards.get(reward_type, {})
    var draft_size: int = int(encounters.get("item_draft_size", 3))
    draft_size += int(draft_cfg.get("draft_size_bonus", 0))
    var options := _curated_first_draft(items_cfg, draft_size)
    if options.is_empty():
        var pool: Array = []
        for item_id in _current_theme_cfg().get("draft_bias", []):
            var biased_id := str(item_id)
            if _player_has_item(biased_id) or not items_cfg.has(biased_id):
                continue
            var biased: Dictionary = items_cfg[biased_id].duplicate(true)
            biased["id"] = biased_id
            pool.append(biased)
        for item_id in items_cfg.keys():
            if not _player_has_item(item_id):
                var data: Dictionary = items_cfg[item_id]
                var entry := data.duplicate(true)
                entry["id"] = item_id
                pool.append(entry)
        pool.shuffle()
        options = pool.slice(0, min(draft_size, pool.size()))
    item_draft.show_draft(options)

func _curated_first_draft(items_cfg: Dictionary, draft_size: int) -> Array:
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if player == null or not player.items.is_empty():
        return []
    var item_pools: Dictionary = DataLoader.load_config("item_pools")
    var first_categories: Array = item_pools.get("first_draft", [])
    var categories: Dictionary = item_pools.get("categories", {})
    if first_categories.is_empty():
        return []
    var options: Array = []
    var used: Dictionary = {}
    for category in first_categories:
        if options.size() >= draft_size:
            break
        var ids: Array = categories.get(str(category), [])
        ids.shuffle()
        for item_id in ids:
            var id := str(item_id)
            if used.has(id) or _player_has_item(id) or not items_cfg.has(id):
                continue
            var entry: Dictionary = items_cfg[id].duplicate(true)
            entry["id"] = id
            options.append(entry)
            used[id] = true
            break
    return options

func _on_item_selected(item_id: String) -> void:
    var encounters: Dictionary = DataLoader.load_config("encounters")
    var max_items: int = int(encounters.get("max_player_items", 6))
    if player_items.size() >= max_items:
        _pending_item_pick = item_id
        item_draft.hide_draft()
        _show_item_swap_choice(item_id)
        return
    _add_player_item(item_id)
    item_draft.hide_draft()
    _complete_current_node()

func _add_player_item(item_id: String, replace_index: int = -1) -> void:
    var items_cfg: Dictionary = DataLoader.load_config("items")
    if not items_cfg.has(item_id):
        return
    var data: Dictionary = items_cfg[item_id].duplicate(true)
    data["id"] = item_id
    if replace_index >= 0 and replace_index < player_items.size():
        player_items[replace_index] = data
    else:
        player_items.append(data)

    var player: Unit = game_state.run_state.get("player", null) as Unit
    if player != null:
        _refresh_player_build(player)
        score_manager.add_score("item_pickup")
        stats_panel.update_unit(player)
        _refresh_tactical_hud()

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
    var outcomes: Dictionary = DataLoader.load_config("run_outcomes")
    var options: Array = outcomes.get("rest_options", [])
    if options.is_empty():
        _pending_reward_node_id = str(node.get("id", ""))
        _complete_current_node()
        return
    _show_choice_node(node, "Rest", str(node.get("summary", "A still square.")), options)

func _resolve_story_node(node: Dictionary) -> void:
    var outcomes: Dictionary = DataLoader.load_config("run_outcomes")
    var events: Array = outcomes.get("story_events", [])
    if events.is_empty():
        _pending_reward_node_id = str(node.get("id", ""))
        _complete_current_node()
        return
    var event: Dictionary = events[rng.randi_range(0, events.size() - 1)]
    var title: String = str(event.get("title", "Story"))
    var line: String = str(event.get("line", "The Plain says nothing."))
    var options: Array = event.get("choices", [])
    if options.is_empty():
        append_log(line)
        _pending_reward_node_id = str(node.get("id", ""))
        _complete_current_node()
        return
    _show_choice_node(node, title, line, options)

func _resolve_shrine_node(node: Dictionary) -> void:
    var options := _perk_choice_options()
    if options.is_empty():
        _pending_reward_node_id = str(node.get("id", ""))
        _complete_current_node()
        return
    _show_choice_node(
        node,
        "Shrine",
        str(node.get("summary", "A rule lies exposed.")),
        options
    )

func _resolve_shop_node(node: Dictionary) -> void:
    var outcomes: Dictionary = DataLoader.load_config("run_outcomes")
    var options: Array = _theme_shop_options(outcomes.get("shop_options", []))
    _show_choice_node(node, "Market", str(node.get("summary", "Hands wait.")), options)

func _resolve_upgrade_node(node: Dictionary) -> void:
    var outcomes: Dictionary = DataLoader.load_config("run_outcomes")
    var options: Array = outcomes.get("upgrade_options", [])
    _show_choice_node(node, "Anvil", str(node.get("summary", "A mark can deepen.")), options)

func _resolve_ally_hire_node(node: Dictionary) -> void:
    var outcomes: Dictionary = DataLoader.load_config("run_outcomes")
    var options: Array = outcomes.get("ally_hire_options", [])
    _show_choice_node(node, "Contract", str(node.get("summary", "A banner waits.")), options)

func _show_choice_node(node: Dictionary, title: String, body: String, options: Array) -> void:
    _pending_choice_node = node.duplicate(true)
    _pending_choice_options = _with_effect_previews(options)
    _pending_choice_mode = "outcome"
    append_log(body)
    board_view.visible = false
    board_backdrop.visible = false
    bottom_bar.visible = false
    ui_backdrop.visible = false
    _choice_overlay.show_choices(title, body, _pending_choice_options)

func _on_choice_selected(index: int) -> void:
    if _pending_choice_mode.begins_with("setup_"):
        _on_setup_choice_selected(index)
        return
    if _pending_choice_mode == "legacy":
        _on_legacy_choice_selected(index)
        return
    if _pending_choice_mode == "post_combat":
        _on_post_combat_continue()
        return
    if _pending_choice_mode == "replace_item":
        _on_item_replacement_selected(index)
        return
    if index < 0 or index >= _pending_choice_options.size():
        return
    var option: Dictionary = _pending_choice_options[index]
    var node: Dictionary = _pending_choice_node
    if not _can_afford_choice(option):
        append_log("Not enough gold.")
        return
    _choice_overlay.hide_choices()
    _pending_choice_node = {}
    _pending_choice_options = []
    _pending_reward_node_id = str(node.get("id", ""))
    var effects: Dictionary = option.get("effects", {})
    var opened_draft := _apply_outcome_effects(effects, node)
    if not opened_draft:
        _complete_current_node()

func _on_post_combat_continue() -> void:
    _choice_overlay.hide_choices()
    _pending_choice_mode = "outcome"
    var reward := _pending_post_combat_reward
    _pending_post_combat_reward = ""
    _pending_post_combat_options = []
    _hide_path_choice()
    if reward == "draft" or reward == "elite_draft":
        show_item_draft(reward)
    else:
        _complete_current_node()

func _show_item_swap_choice(item_id: String) -> void:
    var items_cfg: Dictionary = DataLoader.load_config("items")
    if not items_cfg.has(item_id):
        _complete_current_node()
        return
    var incoming: Dictionary = items_cfg[item_id]
    var options: Array = []
    for item in player_items:
        var held: Dictionary = item
        options.append({
            "label": "Replace %s" % str(held.get("display_name", "Relic")),
            "summary": "Carry %s instead." % str(incoming.get("display_name", "the new relic"))
        })
    options.append({
        "label": "Leave It",
        "summary": "Keep what already weighs on you."
    })
    _pending_choice_mode = "replace_item"
    _pending_choice_options = options
    _choice_overlay.show_choices(
        "Too Much to Carry",
        "The new relic waits. One old weight must be left behind.",
        options
    )

func _on_item_replacement_selected(index: int) -> void:
    _choice_overlay.hide_choices()
    var item_id: String = _pending_item_pick
    _pending_item_pick = ""
    _pending_choice_mode = "outcome"
    _pending_choice_options = []
    if index >= 0 and index < player_items.size() and not item_id.is_empty():
        _add_player_item(item_id, index)
    _complete_current_node()

func _with_effect_previews(options: Array) -> Array:
    var result: Array = []
    for option_value in options:
        if typeof(option_value) != TYPE_DICTIONARY:
            continue
        var option: Dictionary = (option_value as Dictionary).duplicate(true)
        var effects: Dictionary = option.get("effects", {})
        var preview := _effect_preview(effects)
        if not preview.is_empty():
            var summary: String = str(option.get("summary", ""))
            option["summary"] = "%s\n%s" % [summary, preview] if not summary.is_empty() else preview
        if not _can_afford_choice(option):
            option["disabled"] = true
            var gold: int = int(game_state.run_state.get("gold", 0))
            var cost: int = int(effects.get("cost_gold", 0))
            option["disabled_reason"] = "Need %d more gold." % max(0, cost - gold)
        result.append(option)
    return result

func _effect_preview(effects: Dictionary) -> String:
    var parts: Array = []
    var cost: int = int(effects.get("cost_gold", 0))
    if cost > 0:
        parts.append("Cost %d gold" % cost)
    if effects.has("gold_range"):
        var range_values: Array = effects.get("gold_range", [])
        if range_values.size() >= 2:
            parts.append("Gold %s-%s" % [str(range_values[0]), str(range_values[1])])
    if effects.has("heal_percent"):
        parts.append("Heal %d%%" % int(round(float(effects.get("heal_percent", 0.0)) * 100.0)))
    var hp_delta: int = int(effects.get("hp_delta", 0))
    if hp_delta != 0:
        parts.append("HP %+d" % hp_delta)
    if effects.has("item_id"):
        var item_id: String = str(effects.get("item_id", ""))
        var item: Dictionary = DataLoader.load_config("items").get(item_id, {})
        parts.append("Relic: %s" % str(item.get("display_name", item_id)))
    if effects.has("player_stat_bonus"):
        parts.append(_stat_bonus_text(effects.get("player_stat_bonus", {})))
    if effects.has("contract"):
        var contract: Dictionary = effects.get("contract", {})
        parts.append("%s for %d encounters" % [str(contract.get("label", "Contract")), int(contract.get("duration", 1))])
    if effects.has("ally_id"):
        var ally_id: String = str(effects.get("ally_id", ""))
        var ally: Dictionary = DataLoader.load_config("ally_units").get(ally_id, {})
        parts.append("Ally: %s" % str(ally.get("display_name", ally_id)))
    if effects.has("consequence"):
        parts.append("Next board changes")
    return _join_strings(parts.filter(func(value): return not str(value).is_empty()), " | ")

func _stat_bonus_text(stats: Dictionary) -> String:
    var parts: Array = []
    for stat_name in ["hp", "atk", "def", "spd", "ap"]:
        var value: int = int(stats.get(stat_name, 0))
        if value == 0:
            continue
        parts.append("%+d %s" % [value, stat_name.to_upper()])
    return _join_strings(parts, ", ")

func _can_afford_choice(option: Dictionary) -> bool:
    var effects: Dictionary = option.get("effects", {})
    var cost: int = int(effects.get("cost_gold", 0))
    return cost <= 0 or int(game_state.run_state.get("gold", 0)) >= cost

func _perk_choice_options() -> Array:
    var perks_cfg: Dictionary = DataLoader.load_config("perks")
    var owned: Array = game_state.run_state.get("perks", [])
    var ids: Array = []
    for perk_id in perks_cfg.keys():
        if not perk_id in owned:
            ids.append(perk_id)
    ids.shuffle()
    var options: Array = []
    for perk_id in ids.slice(0, min(3, ids.size())):
        var perk: Dictionary = perks_cfg[perk_id]
        var effects: Dictionary = perk.get("effects", {}).duplicate(true)
        effects["perk_id"] = perk_id
        options.append({
            "label": str(perk.get("display_name", perk_id)),
            "summary": str(perk.get("summary", "")),
            "effects": effects
        })
    return options

func _theme_shop_options(base_options: Array) -> Array:
    var options: Array = base_options.duplicate(true)
    var items_cfg: Dictionary = DataLoader.load_config("items")
    for item_id_value in _current_theme_cfg().get("draft_bias", []):
        var item_id := str(item_id_value)
        if _player_has_item(item_id) or not items_cfg.has(item_id):
            continue
        var item: Dictionary = items_cfg.get(item_id, {})
        options.insert(0, {
            "label": "Buy %s" % str(item.get("display_name", item_id)),
            "summary": "40 gold. The market offers what this Plain favors.",
            "effects": {
                "cost_gold": 40,
                "item_id": item_id,
                "score_events": ["item_pickup"],
                "log": "%s changes hands." % str(item.get("display_name", item_id))
            }
        })
        break
    return options

func _add_perk(perk_id: String) -> void:
    var perks: Array = game_state.run_state.get("perks", [])
    if perk_id in perks:
        return
    var perks_cfg: Dictionary = DataLoader.load_config("perks")
    if not perks_cfg.has(perk_id):
        return
    perks.append(perk_id)
    game_state.run_state["perks"] = perks
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if player != null:
        _refresh_player_build(player)
        stats_panel.update_unit(player)

func _refresh_player_build(player: Unit) -> void:
    if player == null:
        return
    player.run_stat_bonuses = _aggregate_run_stat_bonuses()
    ItemSystem.apply_items(player, player_items)
    player.trigger_flags["move_range_bonus"] = int(player.trigger_flags.get("move_range_bonus", 0)) + _aggregate_perk_move_bonus()

func _aggregate_run_stat_bonuses() -> Dictionary:
    var totals := _aggregate_perk_stat_bonuses()
    totals = _merge_stat_bonuses(totals, game_state.run_state.get("run_stat_bonuses", {}))
    for contract_value in game_state.run_state.get("active_contracts", []):
        if typeof(contract_value) != TYPE_DICTIONARY:
            continue
        totals = _merge_stat_bonuses(totals, (contract_value as Dictionary).get("stat_bonus", {}))
    return totals

func _aggregate_perk_stat_bonuses() -> Dictionary:
    var totals := {"hp": 0, "atk": 0, "def": 0, "spd": 0, "ap": 0}
    var perks_cfg: Dictionary = DataLoader.load_config("perks")
    var owned: Array = game_state.run_state.get("perks", [])
    for perk_id in owned:
        var perk: Dictionary = perks_cfg.get(str(perk_id), {})
        var effects: Dictionary = perk.get("effects", {})
        var stats: Dictionary = effects.get("stat_bonus", {})
        for stat_name in totals.keys():
            totals[stat_name] = int(totals.get(stat_name, 0)) + int(stats.get(stat_name, 0))
    return totals

func _aggregate_perk_move_bonus() -> int:
    var total := 0
    var perks_cfg: Dictionary = DataLoader.load_config("perks")
    var owned: Array = game_state.run_state.get("perks", [])
    for perk_id in owned:
        var perk: Dictionary = perks_cfg.get(str(perk_id), {})
        var effects: Dictionary = perk.get("effects", {})
        total += int(effects.get("move_range_bonus", 0))
    return total

func _reveal_all_fog() -> void:
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    if board == null:
        return
    for row in range(board.rows):
        for col in range(board.cols):
            var tile: Tile = board.get_tile(Vector2i(col, row))
            if tile != null and bool(tile.terrain_data.get("fog", false)):
                tile.revealed = true
    board_view.update_board(board)

func _apply_node_rewards(node: Dictionary) -> void:
    var outcomes: Dictionary = DataLoader.load_config("run_outcomes")
    var node_rewards: Dictionary = outcomes.get("node_rewards", {})
    var node_type: String = str(node.get("type", ""))
    var reward_cfg: Dictionary = node_rewards.get(node_type, {})
    var effects: Dictionary = reward_cfg.get("effects", {})
    _apply_outcome_effects(effects, node)

func _draft_reward_for_node(node: Dictionary) -> String:
    var outcomes: Dictionary = DataLoader.load_config("run_outcomes")
    var node_rewards: Dictionary = outcomes.get("node_rewards", {})
    var node_type: String = str(node.get("type", ""))
    var reward_cfg: Dictionary = node_rewards.get(node_type, {})
    return str(reward_cfg.get("draft_reward_type", node.get("reward", "draft")))

func _apply_outcome_effects(effects: Dictionary, node: Dictionary = {}) -> bool:
    if effects.is_empty():
        return false
    var cost: int = int(effects.get("cost_gold", 0))
    if cost > 0:
        game_state.run_state["gold"] = max(0, int(game_state.run_state.get("gold", 0)) - cost)
        append_log("Gold -%d" % cost)
    var log_text: String = str(effects.get("log", ""))
    if not log_text.is_empty():
        append_log(log_text)

    var score_events: Array = effects.get("score_events", [])
    for event_id in score_events:
        score_manager.add_score(str(event_id))

    var gold_delta: int = int(effects.get("gold", 0))
    if effects.has("gold_range"):
        gold_delta += _roll_int_range(effects.get("gold_range", []))
    if gold_delta != 0:
        game_state.run_state["gold"] = max(0, int(game_state.run_state.get("gold", 0)) + gold_delta)
        append_log("Gold %+d" % gold_delta)

    var hp_delta: int = int(effects.get("hp_delta", 0))
    if hp_delta != 0 or effects.has("heal_percent"):
        var player: Unit = game_state.run_state.get("player", null) as Unit
        if player == null:
            player = _get_or_create_player()
        if effects.has("heal_percent"):
            hp_delta += max(1, int(round(player.max_hp * float(effects.get("heal_percent", 0.0)))))
        if hp_delta > 0:
            player.hp = min(player.max_hp, player.hp + hp_delta)
        else:
            player.apply_damage(abs(hp_delta))
        stats_panel.update_unit(player)
        append_log("HP %+d" % hp_delta)
        if player.is_dead():
            end_run(false)
            return true

    var pending_mutations: int = int(effects.get("pending_board_mutations", 0))
    if pending_mutations > 0:
        game_state.run_state["pending_board_mutations"] = int(game_state.run_state.get("pending_board_mutations", 0)) + pending_mutations

    var consequence: Dictionary = effects.get("consequence", {})
    if not consequence.is_empty():
        _add_consequence(consequence)

    var perk_id: String = str(effects.get("perk_id", ""))
    if not perk_id.is_empty():
        _add_perk(perk_id)

    var item_id: String = str(effects.get("item_id", ""))
    if not item_id.is_empty():
        _add_player_item(item_id)

    var stat_bonus: Dictionary = effects.get("player_stat_bonus", {})
    if not stat_bonus.is_empty():
        var run_bonuses: Dictionary = game_state.run_state.get("run_stat_bonuses", {})
        game_state.run_state["run_stat_bonuses"] = _merge_stat_bonuses(run_bonuses, stat_bonus)
        var stat_player: Unit = game_state.run_state.get("player", null) as Unit
        if stat_player != null:
            _refresh_player_build(stat_player)
            stats_panel.update_unit(stat_player)

    var contract: Dictionary = effects.get("contract", {})
    if not contract.is_empty():
        _add_contract(contract)

    var ally_id: String = str(effects.get("ally_id", ""))
    if not ally_id.is_empty():
        _add_active_ally(ally_id)

    if bool(effects.get("reveal_fog", false)):
        _reveal_all_fog()

    _refresh_tactical_hud()
    var draft_reward_type: String = str(effects.get("draft_reward_type", ""))
    if not draft_reward_type.is_empty():
        _pending_reward_node_id = str(node.get("id", _pending_reward_node_id))
        show_item_draft(draft_reward_type)
        return true
    return false

func _roll_int_range(value: Variant) -> int:
    if typeof(value) != TYPE_ARRAY:
        return 0
    var range_values: Array = value
    if range_values.size() < 2:
        return 0
    var low: int = int(range_values[0])
    var high: int = int(range_values[1])
    if high < low:
        var swap := low
        low = high
        high = swap
    return rng.randi_range(low, high)

func _add_consequence(consequence: Dictionary) -> void:
    var active: Array = game_state.run_state.get("active_consequences", [])
    var copy: Dictionary = consequence.duplicate(true)
    copy["duration"] = max(1, int(copy.get("duration", 1)))
    active.append(copy)
    game_state.run_state["active_consequences"] = active
    var log_text: String = str(copy.get("log", ""))
    if not log_text.is_empty():
        append_log(log_text)

func _add_contract(contract: Dictionary) -> void:
    var active: Array = game_state.run_state.get("active_contracts", [])
    var copy: Dictionary = contract.duplicate(true)
    copy["duration"] = max(1, int(copy.get("duration", 1)))
    active.append(copy)
    game_state.run_state["active_contracts"] = active
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if player != null:
        _refresh_player_build(player)
        stats_panel.update_unit(player)
    append_log("%s signed." % str(copy.get("label", "Contract")))

func _add_active_ally(ally_id: String) -> void:
    var ally_cfg: Dictionary = DataLoader.load_config("ally_units").get(ally_id, {})
    if ally_cfg.is_empty():
        return
    var active: Array = game_state.run_state.get("active_allies", [])
    var record := {
        "id": ally_id,
        "record_id": "%s_%d" % [ally_id, int(game_state.run_state.get("ally_serial", 0))],
        "display_name": str(ally_cfg.get("display_name", ally_id)),
        "duration": max(1, int(ally_cfg.get("duration", 1))),
        "current_hp": -1
    }
    game_state.run_state["ally_serial"] = int(game_state.run_state.get("ally_serial", 0)) + 1
    active.append(record)
    game_state.run_state["active_allies"] = active
    append_log("%s signs on." % str(record.get("display_name", "Ally")))

func _active_enemy_count_bonus() -> int:
    var total := 0
    for consequence in game_state.run_state.get("active_consequences", []):
        if typeof(consequence) == TYPE_DICTIONARY:
            total += int((consequence as Dictionary).get("enemy_count_bonus", 0))
    return total

func _active_forced_role() -> String:
    for consequence in game_state.run_state.get("active_consequences", []):
        if typeof(consequence) != TYPE_DICTIONARY:
            continue
        var role_id: String = str((consequence as Dictionary).get("force_enemy_role", ""))
        if not role_id.is_empty():
            return role_id
    return ""

func _decrement_consequences_after_encounter_start() -> void:
    var active: Array = game_state.run_state.get("active_consequences", [])
    for i in range(active.size() - 1, -1, -1):
        if typeof(active[i]) != TYPE_DICTIONARY:
            active.remove_at(i)
            continue
        var consequence: Dictionary = active[i]
        consequence["duration"] = int(consequence.get("duration", 1)) - 1
        if int(consequence.get("duration", 0)) <= 0:
            active.remove_at(i)
        else:
            active[i] = consequence
    game_state.run_state["active_consequences"] = active

func _decrement_contracts_after_encounter_start() -> void:
    var active: Array = game_state.run_state.get("active_contracts", [])
    var changed := false
    for i in range(active.size() - 1, -1, -1):
        if typeof(active[i]) != TYPE_DICTIONARY:
            active.remove_at(i)
            changed = true
            continue
        var contract: Dictionary = active[i]
        contract["duration"] = int(contract.get("duration", 1)) - 1
        if int(contract.get("duration", 0)) <= 0:
            append_log("%s ends." % str(contract.get("label", "Contract")))
            active.remove_at(i)
            changed = true
        else:
            active[i] = contract
    game_state.run_state["active_contracts"] = active
    if changed:
        var player: Unit = game_state.run_state.get("player", null) as Unit
        if player != null:
            _refresh_player_build(player)
            stats_panel.update_unit(player)

func _decrement_allies_after_encounter_complete() -> void:
    var active: Array = game_state.run_state.get("active_allies", [])
    for i in range(active.size() - 1, -1, -1):
        if typeof(active[i]) != TYPE_DICTIONARY:
            active.remove_at(i)
            continue
        var ally: Dictionary = active[i]
        ally["duration"] = int(ally.get("duration", 1)) - 1
        if int(ally.get("duration", 0)) <= 0:
            append_log("%s leaves the file." % str(ally.get("display_name", "Ally")))
            active.remove_at(i)
        else:
            active[i] = ally
    game_state.run_state["active_allies"] = active

func _save_active_ally_hp() -> void:
    var by_record: Dictionary = {}
    for ally_value in game_state.run_state.get("allies", []):
        var ally: Unit = ally_value as Unit
        if ally == null:
            continue
        var record_id: String = str(ally.trigger_flags.get("ally_record_id", ""))
        if not record_id.is_empty():
            by_record[record_id] = ally
    var active: Array = game_state.run_state.get("active_allies", [])
    for i in range(active.size()):
        if typeof(active[i]) != TYPE_DICTIONARY:
            continue
        var record: Dictionary = active[i]
        var record_id: String = str(record.get("record_id", ""))
        var ally: Unit = by_record.get(record_id, null) as Unit
        if ally != null and not ally.is_dead():
            record["current_hp"] = ally.hp
            active[i] = record
    game_state.run_state["active_allies"] = active

func _log_active_consequences() -> void:
    var active: Array = game_state.run_state.get("active_consequences", [])
    if active.is_empty():
        return
    var names: Array = []
    for consequence in active:
        if typeof(consequence) == TYPE_DICTIONARY:
            names.append(str((consequence as Dictionary).get("label", "Consequence")))
    if not names.is_empty():
        append_log("Carried forward: %s" % _join_strings(names, ", "))

func _log_active_contracts() -> void:
    var active: Array = game_state.run_state.get("active_contracts", [])
    if active.is_empty():
        return
    var names: Array = []
    for contract in active:
        if typeof(contract) == TYPE_DICTIONARY:
            names.append("%s %d" % [str((contract as Dictionary).get("label", "Contract")), int((contract as Dictionary).get("duration", 0))])
    if not names.is_empty():
        append_log("Contracts: %s" % _join_strings(names, ", "))

func _apply_pending_board_mutations(board: BoardData) -> void:
    var count: int = int(game_state.run_state.get("pending_board_mutations", 0))
    if count <= 0:
        return
    for i in range(count):
        BoardGenerator.mutate_empty_tile(board, rng)
    game_state.run_state["pending_board_mutations"] = 0
    append_log("The next board remembers.")

func _apply_template_terrain(board: BoardData, template: Dictionary) -> void:
    if board == null or template.is_empty():
        return
    var marks: Array = template.get("terrain_marks", [])
    _apply_terrain_marks(board, marks)

func _apply_consequence_terrain(board: BoardData) -> void:
    if board == null:
        return
    for consequence in game_state.run_state.get("active_consequences", []):
        if typeof(consequence) != TYPE_DICTIONARY:
            continue
        _apply_terrain_marks(board, (consequence as Dictionary).get("terrain_marks", []))

func _apply_pacing_terrain(board: BoardData, floor_index: int) -> void:
    var pacing := _pacing_for_floor(floor_index)
    var bonus_count: int = int(pacing.get("terrain_mark_bonus", 0))
    if bonus_count <= 0:
        return
    _apply_terrain_marks(board, [{
        "terrain": "cursed",
        "quadrant": "center",
        "count": bonus_count
    }])

func _apply_theme_terrain(board: BoardData) -> void:
    if board == null:
        return
    var marks: Array = _current_theme_cfg().get("terrain_marks", [])
    _apply_terrain_marks(board, marks)

func _apply_theme_tick(board: BoardData) -> void:
    if board == null:
        return
    var mechanic: Dictionary = _current_theme_cfg().get("theme_mechanic", {})
    var interval: int = int(mechanic.get("terrain_pulse_interval", 0))
    if interval <= 0 or _current_turn() % interval != 0:
        return
    var pulse: Dictionary = mechanic.get("terrain_pulse", {})
    if pulse.is_empty():
        return
    _apply_terrain_marks(board, [pulse])
    var log_text: String = str(mechanic.get("log", ""))
    append_log(log_text if not log_text.is_empty() else "The board answers its own heat.")
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if player != null:
        board_view.show_float_text(player.position, "Theme", Color(1.0, 0.62, 0.34))

func _apply_theme_on_player_kill(victim_pos: Vector2i) -> void:
    var mechanic: Dictionary = _current_theme_cfg().get("theme_mechanic", {})
    if mechanic.is_empty():
        return
    var terrain_id: String = str(mechanic.get("on_kill_terrain", ""))
    if not terrain_id.is_empty():
        _replace_tile_terrain(victim_pos, terrain_id)
        board_view.play_mutation_flash(victim_pos)
        board_view.show_float_text(victim_pos, terrain_id.capitalize(), Color(0.72, 0.9, 1.0))
        var terrain_log: String = str(mechanic.get("on_kill_terrain_log", ""))
        if not terrain_log.is_empty():
            append_log(terrain_log)
    var every: int = int(mechanic.get("on_kill_every", 0))
    if every <= 0:
        return
    var count: int = int(game_state.run_state.get("theme_kill_count", 0)) + 1
    game_state.run_state["theme_kill_count"] = count
    if count % every != 0:
        return
    _apply_theme_aoe(victim_pos, int(mechanic.get("aoe_damage", 0)), int(mechanic.get("aoe_radius", 1)), str(mechanic.get("log", "")))

func _apply_theme_aoe(center: Vector2i, damage: int, radius: int, log_text: String) -> void:
    if damage <= 0:
        return
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    if board == null:
        return
    if not log_text.is_empty():
        append_log(log_text)
    var player: Unit = game_state.run_state.get("player", null) as Unit
    var enemies: Array = game_state.run_state.get("enemies", [])
    for enemy_value in enemies.duplicate():
        var enemy: Unit = enemy_value as Unit
        if enemy == null or enemy.is_dead():
            continue
        var dist: int = abs(enemy.position.x - center.x) + abs(enemy.position.y - center.y)
        if dist > radius:
            continue
        board_view.play_attack_flash(enemy.position)
        board_view.show_float_text(enemy.position, "Chain", Color(0.78, 0.92, 1.0))
        append_log("%s takes %d from the theme." % [enemy.display_name, damage])
        if enemy.apply_damage(damage):
            board.clear_unit(enemy.position)
            if player != null:
                player.kills += 1
                score_manager.add_score("enemy_kill")
                if EvolutionSystem.check_and_evolve(player):
                    _refresh_player_build(player)
                    _record_evolution_step(player.piece_id)
                    score_manager.add_score("evolution")
                    append_log("Evolved to %s" % player.display_name)
    _remove_dead_units()

func _replace_tile_terrain(pos: Vector2i, terrain_id: String) -> void:
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    if board == null or not board.is_in_bounds(pos):
        return
    var terrain_cfg: Dictionary = DataLoader.load_config("terrain")
    if not terrain_cfg.has(terrain_id):
        return
    var tile: Tile = board.get_tile(pos)
    if tile == null or not tile.objective_type.is_empty() or tile.piece != null:
        return
    var replacement := Tile.new()
    replacement.init_from_terrain(terrain_id, terrain_cfg.get(terrain_id, {}))
    replacement.revealed = not bool(replacement.terrain_data.get("fog", false))
    board.set_tile(pos, replacement)

func _apply_terrain_marks(board: BoardData, marks: Array) -> void:
    var terrain_cfg: Dictionary = DataLoader.load_config("terrain")
    for mark_value in marks:
        if typeof(mark_value) != TYPE_DICTIONARY:
            continue
        var mark: Dictionary = mark_value
        var terrain_id: String = str(mark.get("terrain", "normal"))
        if not terrain_cfg.has(terrain_id):
            continue
        var count: int = max(1, int(mark.get("count", 1)))
        var quadrant: String = str(mark.get("quadrant", "center"))
        var positions := _positions_for_zone(board, quadrant)
        positions.shuffle()
        var placed := 0
        for pos in positions:
            if placed >= count:
                break
            var tile: Tile = board.get_tile(pos)
            if tile == null or tile.piece != null or not tile.objective_type.is_empty():
                continue
            var replacement := Tile.new()
            replacement.init_from_terrain(terrain_id, terrain_cfg.get(terrain_id, {}))
            replacement.revealed = not bool(replacement.terrain_data.get("fog", false))
            board.set_tile(pos, replacement)
            placed += 1

func _current_setup_id(key: String, fallback: String) -> String:
    var setup: Dictionary = game_state.run_state.get("setup", {})
    return str(setup.get(key, fallback))

func _current_theme_cfg() -> Dictionary:
    var cfg: Dictionary = DataLoader.load_config("run_themes")
    return cfg.get("themes", {}).get(_current_setup_id("theme", "neutral"), {})

func _current_difficulty_cfg() -> Dictionary:
    var cfg: Dictionary = DataLoader.load_config("run_themes")
    return cfg.get("difficulties", {}).get(_current_setup_id("difficulty", "wanderer"), {})

func _merge_stat_bonuses(base: Dictionary, extra: Dictionary) -> Dictionary:
    var merged := base.duplicate(true)
    for stat_name in extra.keys():
        merged[stat_name] = int(merged.get(stat_name, 0)) + int(extra.get(stat_name, 0))
    return merged

func _first_open_position(board: BoardData, zone: String, used_positions: Dictionary) -> Vector2i:
    var positions := _positions_for_zone(board, zone)
    positions.shuffle()
    for pos in positions:
        if used_positions.has(_pos_key(pos)):
            continue
        var tile: Tile = board.get_tile(pos)
        if tile != null and tile.piece == null and not MovementSystem.is_blocked(tile):
            return pos
    return Vector2i(-1, -1)

func _positions_for_zone(board: BoardData, zone: String) -> Array:
    var positions: Array = []
    var mid_row := int(board.rows / 2.0)
    var mid_col := int(board.cols / 2.0)
    var row_start := 0
    var row_end := board.rows
    var col_start := 0
    var col_end := board.cols
    match zone:
        "bottom_left":
            row_start = mid_row
            col_end = mid_col
        "top_right":
            row_end = mid_row
            col_start = mid_col
        "center":
            row_start = max(0, mid_row - 2)
            row_end = min(board.rows, mid_row + 3)
            col_start = max(0, mid_col - 2)
            col_end = min(board.cols, mid_col + 3)
        _:
            pass
    for row in range(row_start, row_end):
        for col in range(col_start, col_end):
            positions.append(Vector2i(col, row))
    return positions

func _pos_key(pos: Vector2i) -> String:
    return "%d,%d" % [pos.x, pos.y]

func end_run(victory: bool) -> void:
    var score: int = score_manager.get_final_score(game_state.run_state)
    _record_run_result_once(victory, score)
    _show_legacy_choice(victory, score)
    _refresh_tactical_hud()

func _on_restart_requested() -> void:
    end_screen.hide_screen()
    _show_run_setup_mode()

func _record_run_result_once(victory: bool, score: int) -> void:
    if _run_result_recorded:
        return
    _run_result_recorded = true
    var player: Unit = game_state.run_state.get("player", null) as Unit
    var summary := {
        "piece": player.piece_id if player != null else "",
        "kills": player.kills if player != null else 0
    }
    game_state.record_run_result(victory, score, summary)

func _show_legacy_choice(victory: bool, score: int) -> void:
    _pending_end_victory = victory
    _pending_end_score = score
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if player == null:
        end_screen.show_screen(victory, score, _score_details())
        return
    _pending_choice_mode = "legacy"
    _pending_choice_options = [
        {
            "label": "Carry This Shape",
            "summary": "The next final board will remember %s." % player.display_name
        },
        {
            "label": "No Legacy",
            "summary": "Let the King wait alone."
        }
    ]
    board_view.visible = false
    board_backdrop.visible = false
    bottom_bar.visible = false
    ui_backdrop.visible = false
    _choice_overlay.show_choices(
        "Choose What Follows",
        "A finished run leaves one piece behind in the law.",
        _pending_choice_options
    )

func _on_legacy_choice_selected(index: int) -> void:
    _choice_overlay.hide_choices()
    if index == 0:
        var record := _legacy_record_for_player()
        if not record.is_empty():
            game_state.set_legacy_boss(record)
    else:
        game_state.clear_legacy_boss()
    _pending_choice_mode = "outcome"
    _pending_choice_options = []
    end_screen.show_screen(_pending_end_victory, _pending_end_score, _score_details())

func _score_details() -> Dictionary:
    var setup: Dictionary = game_state.run_state.get("setup", {})
    var key := "%s:%s:%s" % [str(setup.get("mode", "legacy")), str(setup.get("theme", "neutral")), str(setup.get("difficulty", "wanderer"))]
    var best_scores: Dictionary = game_state.meta_state.get("best_scores", {})
    var legacy: Dictionary = game_state.get_legacy_boss()
    return {
        "base_score": score_manager.get_base_score(),
        "multipliers": score_manager.get_multiplier_breakdown(game_state.run_state),
        "best_score": int(best_scores.get(key, 0)),
        "legacy_boss": str(legacy.get("display_name", "")),
        "run_history": game_state.meta_state.get("run_history", [])
    }

func _legacy_record_for_player() -> Dictionary:
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if player == null:
        return {}
    var item_ids: Array = []
    var school_counts: Dictionary = {}
    for item in player_items:
        var item_data: Dictionary = item
        item_ids.append(str(item_data.get("id", "")))
        var school: String = str(item_data.get("school", ""))
        if not school.is_empty():
            school_counts[school] = int(school_counts.get(school, 0)) + 1
    var meta: Dictionary = game_state.meta_state
    return {
        "piece_type": player.piece_id,
        "items": item_ids,
        "display_name": "%s, Carried Forward" % player.display_name,
        "run_origin": int(meta.get("run_count", 0)),
        "kills": player.kills,
        "evolution_path": game_state.run_state.get("evolution_path", [player.piece_id]),
        "school_counts": school_counts
    }

func _get_or_create_player() -> Unit:
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if player != null:
        return player
    var pieces: Dictionary = DataLoader.load_config("player_pieces")
    player = Unit.new()
    player.is_player = true
    player.init_from_piece("pawn", pieces.get("pawn", {}))
    _refresh_player_build(player)
    game_state.run_state["player"] = player
    game_state.run_state["evolution_path"] = [player.piece_id]
    return player

func _record_evolution_step(piece_id: String) -> void:
    var path: Array = game_state.run_state.get("evolution_path", [])
    if path.is_empty() or str(path[path.size() - 1]) != piece_id:
        path.append(piece_id)
    game_state.run_state["evolution_path"] = path

func _spawn_player(board: BoardData) -> Vector2i:
    var encounters: Dictionary = DataLoader.load_config("encounters")
    var quadrant: String = encounters.get("player_spawn_quadrant", "bottom_left")
    var positions := BoardGenerator.get_spawn_positions(board, quadrant, 1, rng)
    if positions.is_empty():
        return Vector2i.ZERO
    return positions[0]

func _spawn_enemies(board: BoardData, encounter_cfg: Dictionary) -> Array:
    var enemies: Array = []
    var pieces: Dictionary = DataLoader.load_config("enemy_pieces")
    var template: Dictionary = encounter_cfg.get("template", {})
    if not template.is_empty():
        return _spawn_template_enemies(board, template, encounter_cfg, pieces)

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
        _apply_enemy_run_bonuses(unit, encounter_cfg)
        _apply_enemy_role(unit, _forced_role_or_default(""))
        if elite_items > 0 and i == 0:
            _equip_enemy_items(unit, elite_items)
        var pos: Vector2i = positions[i]
        board.set_unit(pos, unit)
        enemies.append(unit)

    return enemies

func _spawn_template_enemies(board: BoardData, template: Dictionary, encounter_cfg: Dictionary, pieces: Dictionary) -> Array:
    var enemies: Array = []
    var specs: Array = template.get("enemies", [])
    var used_positions: Dictionary = {}
    for spec_value in specs:
        if typeof(spec_value) != TYPE_DICTIONARY:
            continue
        var spec: Dictionary = spec_value
        var piece_id: String = str(spec.get("piece", "pawn"))
        var unit := Unit.new()
        unit.init_from_piece(piece_id, pieces.get(piece_id, {}))
        unit.is_boss = bool(encounter_cfg.get("is_boss", false)) or piece_id == "king"
        _apply_enemy_run_bonuses(unit, encounter_cfg)
        _apply_enemy_role(unit, _forced_role_or_default(str(spec.get("role", ""))))
        var item_ids: Array = spec.get("items", [])
        if not item_ids.is_empty():
            _equip_enemy_item_ids(unit, item_ids)
        var quadrant: String = str(spec.get("quadrant", "top_right"))
        var pos := _first_open_position(board, quadrant, used_positions)
        if pos == Vector2i(-1, -1):
            continue
        used_positions[_pos_key(pos)] = true
        board.set_unit(pos, unit)
        enemies.append(unit)
    var bonus_count: int = max(0, _active_enemy_count_bonus() + int(_pacing_for_floor(int(encounter_cfg.get("floor", 1))).get("enemy_count_bonus", 0)))
    var fallback_types: Array = encounter_cfg.get("enemy_types", ["pawn"])
    for i in range(bonus_count):
        var piece_id: String = str(fallback_types[rng.randi_range(0, fallback_types.size() - 1)])
        var unit := Unit.new()
        unit.init_from_piece(piece_id, pieces.get(piece_id, {}))
        _apply_enemy_run_bonuses(unit, encounter_cfg)
        _apply_enemy_role(unit, _forced_role_or_default("pursuer"))
        var pos := _first_open_position(board, "top_right", used_positions)
        if pos == Vector2i(-1, -1):
            break
        used_positions[_pos_key(pos)] = true
        board.set_unit(pos, unit)
        enemies.append(unit)
    return enemies

func _spawn_legacy_boss_if_needed(board: BoardData, encounter_cfg: Dictionary, enemies: Array) -> void:
    if board == null or not bool(encounter_cfg.get("is_boss", false)):
        return
    var legacy: Dictionary = game_state.get_legacy_boss()
    if legacy.is_empty():
        return
    var pieces: Dictionary = DataLoader.load_config("enemy_pieces")
    var piece_id: String = str(legacy.get("piece_type", "pawn"))
    if not pieces.has(piece_id):
        return
    var unit := Unit.new()
    unit.init_from_piece(piece_id, pieces.get(piece_id, {}))
    unit.display_name = str(legacy.get("display_name", unit.display_name))
    unit.is_boss = true
    _scale_legacy_boss(unit)
    _equip_enemy_item_ids(unit, legacy.get("items", []))
    var used: Dictionary = {}
    for enemy in enemies:
        var existing: Unit = enemy as Unit
        if existing != null:
            used[_pos_key(existing.position)] = true
    var pos := _first_open_position(board, "top_right", used)
    if pos == Vector2i(-1, -1):
        return
    board.set_unit(pos, unit)
    enemies.append(unit)
    append_log("%s waits beside the King." % unit.display_name)

func _spawn_allies(board: BoardData) -> Array:
    var allies: Array = []
    if board == null:
        return allies
    var active: Array = game_state.run_state.get("active_allies", [])
    if active.is_empty():
        return allies
    var ally_cfgs: Dictionary = DataLoader.load_config("ally_units")
    var pieces: Dictionary = DataLoader.load_config("player_pieces")
    var used: Dictionary = {}
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if player != null:
        used[_pos_key(player.position)] = true
    for record_value in active:
        if typeof(record_value) != TYPE_DICTIONARY:
            continue
        var record: Dictionary = record_value
        var ally_id: String = str(record.get("id", ""))
        var cfg: Dictionary = ally_cfgs.get(ally_id, {})
        if cfg.is_empty():
            continue
        var piece_id: String = str(cfg.get("piece", "pawn"))
        var unit := Unit.new()
        unit.is_ally = true
        unit.init_from_piece(piece_id, pieces.get(piece_id, {}))
        unit.display_name = str(record.get("display_name", cfg.get("display_name", unit.display_name)))
        unit.trigger_flags["ally_record_id"] = str(record.get("record_id", ""))
        _apply_enemy_role(unit, str(cfg.get("role", "")))
        _equip_enemy_item_ids(unit, cfg.get("items", []))
        var saved_hp: int = int(record.get("current_hp", -1))
        if saved_hp > 0:
            unit.hp = min(saved_hp, unit.max_hp)
        var pos := _first_open_position(board, "bottom_left", used)
        if pos == Vector2i(-1, -1):
            continue
        used[_pos_key(pos)] = true
        board.set_unit(pos, unit)
        allies.append(unit)
        append_log("%s joins the board." % unit.display_name)
    return allies

func _scale_legacy_boss(unit: Unit) -> void:
    var run_count: int = int(game_state.meta_state.get("run_count", 1))
    var legacy_scale: int = clamp(run_count, 1, 6)
    unit.base_hp = int(floor(unit.base_hp * (1.0 + 0.15 * float(legacy_scale))))
    unit.base_atk = int(floor(unit.base_atk * (1.0 + 0.10 * float(legacy_scale))))
    unit.base_def = int(floor(unit.base_def * (1.0 + 0.10 * float(legacy_scale))))
    unit.apply_items(unit.items)
    unit.hp = unit.max_hp
    unit.ap = unit.max_ap

func _apply_enemy_run_bonuses(unit: Unit, encounter_cfg: Dictionary) -> void:
    if unit == null:
        return
    var bonus: Dictionary = encounter_cfg.get("enemy_stat_bonus", {})
    if bonus.is_empty():
        return
    unit.run_stat_bonuses = _merge_stat_bonuses(unit.run_stat_bonuses, bonus)
    unit.apply_items(unit.items)

func _equip_enemy_items(unit: Unit, count: int) -> void:
    var items_cfg: Dictionary = DataLoader.load_config("items")
    var ids: Array = items_cfg.keys()
    ids.shuffle()
    var items: Array = []
    for item_id in ids.slice(0, min(count, ids.size())):
        var item_data: Dictionary = items_cfg[item_id].duplicate(true)
        item_data["id"] = item_id
        items.append(item_data)
    ItemSystem.apply_items(unit, items)

func _equip_enemy_item_ids(unit: Unit, item_ids: Array) -> void:
    var items_cfg: Dictionary = DataLoader.load_config("items")
    var items: Array = []
    for item_id in item_ids:
        if not items_cfg.has(str(item_id)):
            continue
        var item_data: Dictionary = items_cfg[str(item_id)].duplicate(true)
        item_data["id"] = str(item_id)
        items.append(item_data)
    if not items.is_empty():
        ItemSystem.apply_items(unit, items)

func _apply_enemy_role(unit: Unit, role_id: String) -> void:
    if unit == null or role_id.is_empty():
        return
    var roles: Dictionary = DataLoader.load_config("enemy_roles")
    var role: Dictionary = roles.get(role_id, {})
    if role.is_empty():
        return
    unit.role_id = role_id
    unit.role_name = str(role.get("display_name", role_id.capitalize()))
    var stats: Dictionary = role.get("stat_bonus", {})
    unit.run_stat_bonuses = _merge_stat_bonuses(unit.run_stat_bonuses, stats)
    unit.apply_items(unit.items)

func _forced_role_or_default(default_role: String) -> String:
    var forced: String = _active_forced_role()
    if not forced.is_empty():
        return forced
    return default_role

func _player_has_item(item_id: String) -> bool:
    for item in player_items:
        if item.get("id", "") == item_id:
            return true
    return false

func _remove_dead_units() -> void:
    var board: BoardData = game_state.run_state.get("board", null) as BoardData
    var enemies: Array = game_state.run_state.get("enemies", [])
    for i in range(enemies.size() - 1, -1, -1):
        var enemy: Unit = enemies[i] as Unit
        if enemy == null or enemy.is_dead():
            if board != null and enemy != null:
                board.clear_unit(enemy.position)
            enemies.remove_at(i)
    game_state.run_state["enemies"] = enemies
    var allies: Array = game_state.run_state.get("allies", [])
    var fallen_records: Dictionary = {}
    for i in range(allies.size() - 1, -1, -1):
        var ally: Unit = allies[i] as Unit
        if ally == null or ally.is_dead():
            if ally != null:
                fallen_records[str(ally.trigger_flags.get("ally_record_id", ""))] = ally.display_name
                if board != null:
                    board.clear_unit(ally.position)
            allies.remove_at(i)
    game_state.run_state["allies"] = allies
    if fallen_records.is_empty():
        return
    var active: Array = game_state.run_state.get("active_allies", [])
    for i in range(active.size() - 1, -1, -1):
        if typeof(active[i]) != TYPE_DICTIONARY:
            continue
        var record: Dictionary = active[i]
        var record_id: String = str(record.get("record_id", ""))
        if fallen_records.has(record_id):
            append_log("%s falls out of contract." % str(record.get("display_name", fallen_records[record_id])))
            active.remove_at(i)
    game_state.run_state["active_allies"] = active

func _all_units() -> Array:
    var units: Array = []
    var player: Unit = game_state.run_state.get("player", null) as Unit
    if player != null:
        units.append(player)
    for ally in game_state.run_state.get("allies", []):
        if ally != null:
            units.append(ally)
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

func _simultaneous_move_enabled() -> bool:
    var cfg: Dictionary = DataLoader.load_config("simultaneous_movement")
    return bool(cfg.get("enabled", true)) and bool(cfg.get("enemy_moves_on_player_move", true))

func _maybe_mutate_board(board: BoardData) -> void:
    if board == null:
        return
    var encounters: Dictionary = DataLoader.load_config("encounters")
    var mechanic: Dictionary = _current_theme_cfg().get("theme_mechanic", {})
    var interval: int = int(mechanic.get("mutation_interval_override", encounters.get("terrain_mutation_turns", 0)))
    if interval <= 0:
        return
    if _current_turn() % interval != 0:
        return
    var pos: Vector2i = BoardGenerator.mutate_empty_tile(board, rng)
    if pos == Vector2i(-1, -1):
        return
    var stat_bonus: Dictionary = mechanic.get("on_mutation_stat_bonus", {})
    if not stat_bonus.is_empty():
        var player: Unit = game_state.run_state.get("player", null) as Unit
        if player != null:
            player.trigger_stat_bonuses = _merge_stat_bonuses(player.trigger_stat_bonuses, stat_bonus)
            _refresh_player_build(player)
            stats_panel.update_unit(player)
            board_view.show_float_text(player.position, "+ATK", Color(0.88, 0.72, 1.0))
        var log_text: String = str(mechanic.get("log", ""))
        if not log_text.is_empty():
            append_log(log_text)
    board_view.play_mutation_flash(pos)
    append_log("The Plain shifts.")

func _refresh_tactical_hud() -> void:
    if enemy_info_label == null:
        return
    var player: Unit = game_state.run_state.get("player", null) as Unit
    var enemies: Array = game_state.run_state.get("enemies", [])
    var allies: Array = game_state.run_state.get("allies", [])
    var node: Dictionary = game_state.run_state.get("current_node", {})
    stats_panel.update_run_info(
        int(game_state.run_state.get("gold", 0)),
        score_manager.get_base_score(),
        int(game_state.run_state.get("current_floor", 0)),
        str(node.get("label", ""))
    )
    _update_enemy_panel(player, enemies)
    _update_turn_order(enemies, allies)
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
    if not tile.objective_type.is_empty():
        lines.append(_objective_tile_text(tile))
    if MovementSystem.is_blocked(tile):
        lines.append("Blocks movement.")
    var movement_note: String = _movement_preview(pos, tile, player)
    if not movement_note.is_empty():
        lines.append(movement_note)
        var response_note: String = _enemy_response_summary(pos)
        if not response_note.is_empty():
            lines.append(response_note)
    if tile.piece != null:
        lines.append("%s HP %d/%d AP %d" % [tile.piece.display_name, tile.piece.hp, tile.piece.max_hp, tile.piece.ap])
        if not tile.piece.role_id.is_empty():
            lines.append(_role_detail(tile.piece.role_id))
        if player != null and tile.piece != player and MovementSystem.can_attack(player, tile.piece, board):
            var preview: Dictionary = CombatSystem.preview_attack(player, tile.piece, board)
            lines.append("Strike: %d-%d damage" % [int(preview.get("min", 0)), int(preview.get("max", 0))])
    tile_info_label.text = _join_strings(lines, "\n")

func _objective_tile_text(tile: Tile) -> String:
    var objective: Dictionary = game_state.run_state.get("objective", {})
    var display_name: String = str(objective.get("display_name", tile.objective_type.capitalize()))
    match tile.objective_type:
        "cache":
            return "Objective: %s. Step here before the fight ends." % display_name
        "seal":
            var progress: int = int(objective.get("hold_progress", 0))
            var required: int = int(objective.get("hold_turns", 1))
            return "Objective: %s. Hold through enemy answer. %d/%d" % [display_name, progress, required]
        "escape":
            return "Objective: %s. Step here to end the encounter." % display_name
        _:
            return "Objective: %s." % display_name

func _movement_preview(pos: Vector2i, tile: Tile, player: Unit) -> String:
    if player == null or tile.piece != null or turn_system.phase != TurnSystem.Phase.PLAYER:
        return ""
    if MovementSystem.is_blocked(tile):
        return "Move: blocked."
    var valid_moves: Array = MovementSystem.get_valid_moves(player, game_state.run_state.get("board", null) as BoardData)
    if pos in valid_moves:
        return "Move: legal. Cost 1 AP."
    return ""

func _enemy_response_summary(player_target: Vector2i) -> String:
    var response := _enemy_response_for_target(player_target)
    if not bool(response.get("legal", false)):
        return ""
    var threats: Array = response.get("threats", [])
    var plans: Array = response.get("plans", [])
    var moved := 0
    for plan in plans:
        var unit: Unit = plan.get("unit", null) as Unit
        if unit != null and not unit.is_player:
            moved += 1
    if moved <= 0:
        return "Enemy response: none."
    if not threats.is_empty():
        return "Enemy response: %d move, %s threaten." % [moved, _join_strings(threats, ", ")]
    return "Enemy response: %d move." % moved

func _position_can_attack(attacker: Unit, attacker_pos: Vector2i, target_pos: Vector2i, board: BoardData) -> bool:
    if attacker == null or board == null:
        return false
    var max_range: int = int(DataLoader.load_config("combat_rules").get("attack_range", 2))
    var directions: Array[Vector2i] = [
        Vector2i.UP,
        Vector2i.DOWN,
        Vector2i.LEFT,
        Vector2i.RIGHT,
        Vector2i(-1, -1),
        Vector2i(1, -1),
        Vector2i(-1, 1),
        Vector2i(1, 1)
    ]
    for direction in directions:
        for step in range(1, max_range + 1):
            var pos: Vector2i = attacker_pos + direction * step
            if not board.is_in_bounds(pos):
                break
            var tile: Tile = board.get_tile(pos)
            if tile == null or MovementSystem.is_blocked(tile):
                break
            if pos == target_pos:
                return true
            if tile.piece != null and pos != attacker.position:
                break
    return false

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
    var status_reduce: int = int(result.get("status_reduce", 0))
    var ignored_def: int = int(result.get("ignored_def", 0))
    if terrain_bonus != 0:
        parts.append("+%d terrain" % terrain_bonus)
    if terrain_reduce != 0:
        parts.append("-%d terrain" % terrain_reduce)
    if status_reduce != 0:
        parts.append("-%d status" % status_reduce)
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
    var role_detail: String = _role_detail(enemy.role_id)
    var role_text := ""
    if not enemy.role_name.is_empty():
        role_text = " [%s]" % enemy.role_name
    enemy_info_label.text = "%s%s  HP %d/%d  AP %d\nATK %d  DEF %d  SPD %d  Dist %d\nIntent: %s%s" % [
        enemy.display_name,
        role_text,
        enemy.hp,
        enemy.max_hp,
        enemy.ap,
        enemy.atk,
        enemy.def,
        enemy.spd,
        dist,
        intent,
        "\n%s" % role_detail if not role_detail.is_empty() else ""
    ]

func _role_detail(role_id: String) -> String:
    if role_id.is_empty():
        return ""
    var role: Dictionary = DataLoader.load_config("enemy_roles").get(role_id, {})
    if role.is_empty():
        return ""
    return "%s: %s" % [str(role.get("display_name", role_id.capitalize())), str(role.get("summary", ""))]

func _update_turn_order(enemies: Array, allies: Array = []) -> void:
    if enemies.is_empty() and allies.is_empty():
        turn_order_label.text = "Order: The Plain waits."
        return
    var ordered_allies: Array = allies.duplicate()
    ordered_allies.sort_custom(Callable(self, "_sort_units_by_spd_desc"))
    var ordered_enemies: Array = enemies.duplicate()
    ordered_enemies.sort_custom(Callable(self, "_sort_units_by_spd_desc"))
    var names: Array = ["You"]
    for i in range(int(min(2, ordered_allies.size()))):
        var ally: Unit = ordered_allies[i] as Unit
        if ally != null:
            names.append("Ally: %s" % ally.display_name)
    var limit: int = int(min(4, ordered_enemies.size()))
    for i in range(limit):
        var enemy: Unit = ordered_enemies[i] as Unit
        if enemy != null:
            names.append(enemy.display_name)
    turn_order_label.text = "Order: %s" % _join_strings(names, " -> ")

func _update_items_panel(player: Unit) -> void:
    var run_lines: Array = [
        "Gold: %d" % int(game_state.run_state.get("gold", 0)),
        "Score: %d" % score_manager.get_base_score()
    ]
    var consequences: Array = game_state.run_state.get("active_consequences", [])
    if not consequences.is_empty():
        var names: Array = []
        for consequence in consequences:
            if typeof(consequence) == TYPE_DICTIONARY:
                var entry: Dictionary = consequence
                names.append("%s (%d)" % [str(entry.get("label", "Consequence")), int(entry.get("duration", 1))])
        if not names.is_empty():
            run_lines.append("Omen: %s" % _join_strings(names, ", "))
    var pending_mutations: int = int(game_state.run_state.get("pending_board_mutations", 0))
    if pending_mutations > 0:
        run_lines.append("Owed shifts: %d" % pending_mutations)
    var contracts: Array = game_state.run_state.get("active_contracts", [])
    if not contracts.is_empty():
        var contract_names: Array = []
        for contract in contracts:
            if typeof(contract) == TYPE_DICTIONARY:
                var contract_entry: Dictionary = contract
                contract_names.append("%s (%d)" % [str(contract_entry.get("label", "Contract")), int(contract_entry.get("duration", 1))])
        if not contract_names.is_empty():
            run_lines.append("Contracts: %s" % _join_strings(contract_names, ", "))
    var active_allies: Array = game_state.run_state.get("active_allies", [])
    if not active_allies.is_empty():
        var ally_names: Array = []
        for ally_record in active_allies:
            if typeof(ally_record) == TYPE_DICTIONARY:
                var ally_entry: Dictionary = ally_record
                ally_names.append("%s (%d)" % [str(ally_entry.get("display_name", "Ally")), int(ally_entry.get("duration", 1))])
        if not ally_names.is_empty():
            run_lines.append("Allies: %s" % _join_strings(ally_names, ", "))
    if player == null or player.items.is_empty():
        run_lines.append("No relics carried.")
        items_list_label.text = _join_strings(run_lines, "\n")
        return
    var lines: Array = run_lines
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
    return _nearest_target(player, enemies)

func _nearest_target(unit: Unit, targets: Array) -> Unit:
    var best: Unit = null
    var best_dist := 999999
    if unit == null:
        return null
    for target_value in targets:
        if target_value == null:
            continue
        var target_unit: Unit = target_value as Unit
        if target_unit == null or target_unit.is_dead():
            continue
        var dist: int = abs(target_unit.position.x - unit.position.x) + abs(target_unit.position.y - unit.position.y)
        if dist < best_dist:
            best = target_unit
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
