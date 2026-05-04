extends Control
class_name RunController

@onready var board_view: BoardView = $BoardView
@onready var bottom_bar: Control = $BottomBar
@onready var bar_row: HBoxContainer = $BottomBar/BarRow
@onready var left_column: VBoxContainer = $BottomBar/BarRow/LeftColumn
@onready var right_column: VBoxContainer = $BottomBar/BarRow/RightColumn
@onready var stats_panel: StatsPanel = $BottomBar/BarRow/LeftColumn/StatsPanel
@onready var combat_log: CombatLog = $BottomBar/BarRow/CombatLog
@onready var end_turn_button: Button = $BottomBar/BarRow/RightColumn/EndTurnButton
@onready var item_draft: ItemDraftOverlay = $ItemDraftOverlay
@onready var end_screen: EndScreen = $EndScreen
@onready var game_state: Node = get_node("/root/GameState")
@onready var score_manager: Node = get_node("/root/ScoreManager")
@onready var background: ColorRect = $Background
@onready var board_backdrop: ColorRect = $BoardBackdrop
@onready var ui_backdrop: ColorRect = $UIBackdrop
@onready var title_label: Label = $BottomBar/BarRow/LeftColumn/TitleLabel
@onready var hint_label: Label = $BottomBar/BarRow/RightColumn/HintLabel

const BASE_VIEWPORT_HEIGHT := 1080.0
const MIN_TILE_SIZE := 48
const MAX_TILE_SIZE := 120

var rng := RandomNumberGenerator.new()
var turn_system := TurnSystem.new()

var selected: Unit = null
var player_items: Array = []

func _ready() -> void:
    rng.randomize()
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
    game_state.reset_run()
    board_view.tile_clicked.connect(_on_tile_clicked)
    end_turn_button.pressed.connect(_on_end_turn_pressed)
    item_draft.item_selected.connect(_on_item_selected)
    item_draft.draft_skipped.connect(_on_draft_skipped)
    end_screen.restart_requested.connect(_on_restart_requested)
    hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    resized.connect(_on_root_resized)
    _apply_layout()
    item_draft.hide_draft()
    end_screen.hide_screen()
    start_run()

func _apply_layout() -> void:
    var viewport_size := get_viewport_rect().size
    if viewport_size == Vector2.ZERO:
        return

    var ui_scale: float = _ui_scale(viewport_size)
    var outer_margin := int(round(20 * ui_scale))
    var gap := int(round(12 * ui_scale))
    var pad := int(round(10 * ui_scale))

    _apply_ui_scale(ui_scale)

    background.size = viewport_size
    var bar_min := bottom_bar.get_combined_minimum_size()
    var bar_height := int(round(max(bar_min.y + pad * 2, 160 * ui_scale)))
    var max_bar_height := int(viewport_size.y * 0.45)
    if bar_height > max_bar_height:
        bar_height = max_bar_height

    var bar_width := viewport_size.x - outer_margin * 2
    bottom_bar.position = Vector2(outer_margin, viewport_size.y - outer_margin - bar_height)
    bottom_bar.size = Vector2(bar_width, bar_height)
    bar_row.size = bottom_bar.size

    ui_backdrop.position = bottom_bar.position - Vector2(pad, pad)
    ui_backdrop.size = bottom_bar.size + Vector2(pad * 2, pad * 2)

    var top_area_height := bottom_bar.position.y - outer_margin - gap
    var top_area_width := viewport_size.x - outer_margin * 2
    if top_area_height < 0:
        top_area_height = 0

    var board_dims: Vector2i = board_view.get_board_dims()
    if board_dims == Vector2i.ZERO:
        board_dims = Vector2i(9, 8)

    var tile_from_width := int(floor(top_area_width / float(board_dims.x)))
    var tile_from_height := int(floor(top_area_height / float(board_dims.y)))
    var target_tile: int = int(min(tile_from_width, tile_from_height))
    target_tile = clamp(target_tile, MIN_TILE_SIZE, MAX_TILE_SIZE)
    board_view.set_tile_size(target_tile)

    var board_size: Vector2 = board_view.get_board_pixel_size()
    var board_x: float = outer_margin + max(0.0, (top_area_width - board_size.x) * 0.5)
    var board_y: float = outer_margin + max(0.0, (top_area_height - board_size.y) * 0.5)
    board_view.position = Vector2(board_x, board_y)

    board_backdrop.position = board_view.position - Vector2(pad, pad)
    board_backdrop.size = board_size + Vector2(pad * 2, pad * 2)

func _on_root_resized() -> void:
    _apply_layout()

func _ui_scale(viewport_size: Vector2) -> float:
    return clamp(viewport_size.y / BASE_VIEWPORT_HEIGHT, 0.8, 1.4)

func _apply_ui_scale(ui_scale: float) -> void:
    var title_size := int(round(22 * ui_scale))
    var hint_size := int(round(16 * ui_scale))
    var button_font := int(round(20 * ui_scale))
    var button_width := int(round(200 * ui_scale))
    var button_height := int(round(56 * ui_scale))

    title_label.add_theme_font_size_override("font_size", title_size)
    hint_label.add_theme_font_size_override("font_size", hint_size)
    hint_label.custom_minimum_size = Vector2(int(round(260 * ui_scale)), int(round(72 * ui_scale)))

    stats_panel.set_font_scale(ui_scale)
    stats_panel.custom_minimum_size = Vector2(int(round(220 * ui_scale)), 0)

    combat_log.set_font_scale(ui_scale)
    combat_log.custom_minimum_size = Vector2(int(round(360 * ui_scale)), int(round(160 * ui_scale)))
    combat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    combat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL

    end_turn_button.custom_minimum_size = Vector2(button_width, button_height)
    end_turn_button.add_theme_font_size_override("font_size", button_font)

    bar_row.add_theme_constant_override("separation", int(round(16 * ui_scale)))
    left_column.add_theme_constant_override("separation", int(round(6 * ui_scale)))
    right_column.add_theme_constant_override("separation", int(round(8 * ui_scale)))

func start_run() -> void:
    score_manager.reset()
    player_items = []
    game_state.reset_run()
    combat_log.clear_log()
    _apply_starter_items()
    start_encounter(0)

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
    var encounters: Dictionary = DataLoader.load_config("encounters")
    var list: Array = encounters.get("encounters", [])
    if index >= list.size():
        end_run(true)
        return

    var encounter_cfg: Dictionary = list[index]
    game_state.run_state["encounter_index"] = index
    game_state.run_state["turn"] = 1

    var board := BoardGenerator.generate_board(rng)
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

    append_log("Encounter %d" % (index + 1))
    start_player_phase()

func start_player_phase() -> void:
    var player: Unit = game_state.run_state.get("player", null)
    if player == null:
        return
    turn_system.start_player_phase(player)
    selected = null
    board_view.clear_highlights()
    stats_panel.set_phase("Player", _current_turn())
    stats_panel.update_unit(player)

func start_enemy_phase() -> void:
    var enemies: Array = game_state.run_state.get("enemies", [])
    stats_panel.set_phase("Enemy", _current_turn())
    var ordered := turn_system.start_enemy_phase(enemies)
    for enemy in ordered:
        _run_enemy_turn(enemy)
        if _check_player_dead():
            return
        if _check_encounter_cleared():
            return
    start_tick_phase()

func start_tick_phase() -> void:
    var board: BoardData = game_state.run_state.get("board", null)
    var units := _all_units()
    stats_panel.set_phase("Tick", _current_turn())
    turn_system.start_tick_phase(units, board)
    _remove_dead_units()
    board_view.update_board(board)
    if _check_player_dead():
        return
    if _check_encounter_cleared():
        return
    game_state.run_state["turn"] = _current_turn() + 1
    start_player_phase()

func _on_tile_clicked(pos: Vector2i) -> void:
    var board: BoardData = game_state.run_state.get("board", null)
    var player: Unit = game_state.run_state.get("player", null)
    if board == null or player == null:
        return
    if turn_system.phase != TurnSystem.Phase.PLAYER:
        return

    var tile: Tile = board.get_tile(pos)
    if tile == null:
        return

    if tile.piece == player:
        selected = player
        var moves := MovementSystem.get_valid_moves(player, board)
        var attacks := _get_attack_positions(player, board)
        board_view.show_highlights(moves, attacks)
        return

    if selected == player:
        var costs: Dictionary = DataLoader.load_config("action_costs")
        var attack_cost: int = int(costs.get("attack", 1))
        var move_cost: int = int(costs.get("move", 1))
        if tile.piece != null and tile.piece != player and MovementSystem.is_adjacent(player.position, pos):
            if turn_system.spend_ap(player, attack_cost):
                _attack(player, tile.piece)
                _after_player_action()
            return
        var valid_moves := MovementSystem.get_valid_moves(player, board)
        if pos in valid_moves and turn_system.spend_ap(player, move_cost):
            _move_unit(player, pos)
            _after_player_action()

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
    var board: BoardData = game_state.run_state.get("board", null)
    board_view.update_board(board)
    stats_panel.update_unit(game_state.run_state.get("player", null))
    if _check_encounter_cleared():
        return
    if _check_player_dead():
        return
    var player: Unit = game_state.run_state.get("player", null)
    if player != null and player.ap <= 0:
        start_enemy_phase()

func _on_end_turn_pressed() -> void:
    if turn_system.phase != TurnSystem.Phase.PLAYER:
        return
    start_enemy_phase()

func _run_enemy_turn(enemy: Unit) -> void:
    var board: BoardData = game_state.run_state.get("board", null)
    var player: Unit = game_state.run_state.get("player", null)
    if board == null or player == null:
        return

    var costs: Dictionary = DataLoader.load_config("action_costs")
    var attack_cost: int = int(costs.get("attack", 1))
    var move_cost: int = int(costs.get("move", 1))
    var wait_cost: int = int(costs.get("wait", 1))

    while enemy.ap > 0:
        var action := AISystem.decide_action(enemy, board, player)
        var action_type: String = action.get("type", "wait")
        if action_type == "attack":
            if not MovementSystem.is_adjacent(enemy.position, player.position):
                break
            if not turn_system.spend_ap(enemy, attack_cost):
                break
            _attack(enemy, player)
            if player.is_dead():
                return
        elif action_type == "move":
            var target: Vector2i = action.get("target", enemy.position)
            if target == enemy.position:
                if not turn_system.spend_ap(enemy, wait_cost):
                    break
                continue
            if not turn_system.spend_ap(enemy, move_cost):
                break
            _move_unit(enemy, target)
        else:
            if not turn_system.spend_ap(enemy, wait_cost):
                break

func _attack(attacker: Unit, defender: Unit) -> void:
    var board: BoardData = game_state.run_state.get("board", null)
    var result := CombatSystem.apply_attack(attacker, defender, board, rng)
    var damage: int = int(result.get("final", 0))
    board_view.play_attack_flash(defender.position)
    board_view.show_damage_number(defender.position, damage)
    append_log("%s hits %s for %d" % [attacker.display_name, defender.display_name, damage])
    if defender.is_dead():
        append_log("%s falls" % defender.display_name)
        _on_unit_killed(attacker, defender)

func _on_unit_killed(attacker: Unit, victim: Unit) -> void:
    var board: BoardData = game_state.run_state.get("board", null)
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
    var board: BoardData = game_state.run_state.get("board", null)
    var from_pos := unit.position
    if board == null:
        return
    board.clear_unit(from_pos)
    board.set_unit(target, unit)
    board_view.play_move_flash(target)

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

    score_manager.add_score("encounter_clear")
    var index: int = game_state.run_state.get("encounter_index", 0)
    var encounters: Dictionary = DataLoader.load_config("encounters")
    var list: Array = encounters.get("encounters", [])
    var encounter_cfg: Dictionary = list[index]
    if encounter_cfg.get("is_boss", false):
        end_run(true)
    else:
        show_item_draft()
    return true

func _check_player_dead() -> bool:
    var player: Unit = game_state.run_state.get("player", null)
    if player == null:
        return false
    if player.is_dead():
        end_run(false)
        return true
    return false

func show_item_draft() -> void:
    var items_cfg: Dictionary = DataLoader.load_config("items")
    var encounters: Dictionary = DataLoader.load_config("encounters")
    var draft_size: int = int(encounters.get("item_draft_size", 3))
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

    var player: Unit = game_state.run_state.get("player", null)
    if player != null:
        ItemSystem.apply_items(player, player_items)
        score_manager.add_score("item_pickup")
        stats_panel.update_unit(player)

    item_draft.hide_draft()
    start_encounter(game_state.run_state.get("encounter_index", 0) + 1)

func _on_draft_skipped() -> void:
    item_draft.hide_draft()
    start_encounter(game_state.run_state.get("encounter_index", 0) + 1)

func end_run(victory: bool) -> void:
    var score: int = score_manager.get_final_score()
    end_screen.show_screen(victory, score)

func _on_restart_requested() -> void:
    end_screen.hide_screen()
    start_run()

func _get_or_create_player() -> Unit:
    var player: Unit = game_state.run_state.get("player", null)
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
    var spawn_min: int = int(encounter_cfg.get("spawn_min", 1))
    var spawn_max: int = int(encounter_cfg.get("spawn_max", 1))
    var count: int = rng.randi_range(spawn_min, spawn_max)

    var encounters: Dictionary = DataLoader.load_config("encounters")
    var quadrant: String = encounters.get("enemy_spawn_quadrant", "top_right")
    var positions := BoardGenerator.get_spawn_positions(board, quadrant, count, rng)

    for i in range(min(count, positions.size())):
        var piece_id: String = enemy_types[rng.randi_range(0, enemy_types.size() - 1)]
        var unit := Unit.new()
        unit.init_from_piece(piece_id, pieces.get(piece_id, {}))
        unit.is_boss = bool(encounter_cfg.get("is_boss", false))
        var pos: Vector2i = positions[i]
        board.set_unit(pos, unit)
        enemies.append(unit)

    return enemies

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
    var player: Unit = game_state.run_state.get("player", null)
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
