extends VBoxContainer
class_name StatsPanel

@onready var piece_label: Label = $PieceLabel
@onready var hp_label: Label = $HpLabel
@onready var atk_label: Label = $AtkLabel
@onready var def_label: Label = $DefLabel
@onready var spd_label: Label = $SpdLabel
@onready var ap_label: Label = $ApLabel
@onready var phase_label: Label = $PhaseLabel
@onready var turn_label: Label = $TurnLabel
@onready var kills_label: Label = $KillsLabel
@onready var items_label: Label = $ItemsLabel

var gold_label: Label
var score_label: Label
var floor_label: Label

func _ready() -> void:
    gold_label = _ensure_label("GoldLabel", "Gold: 0")
    score_label = _ensure_label("ScoreLabel", "Score: 0")
    floor_label = _ensure_label("FloorLabel", "Floor: -")
    _apply_font_sizes(20)

func set_phase(phase_text: String, turn: int) -> void:
    phase_label.text = "%s has the move" % phase_text
    turn_label.text = "Ring %d" % turn

func update_run_info(gold: int, base_score: int, floor_index: int, node_label: String = "") -> void:
    if gold_label == null:
        return
    gold_label.text = "Gold: %d" % gold
    score_label.text = "Score: %d" % base_score
    if node_label.is_empty():
        floor_label.text = "Floor: %d" % floor_index
    else:
        floor_label.text = "Floor: %d - %s" % [floor_index, node_label]

func update_unit(unit: Unit) -> void:
    if unit == null:
        piece_label.text = "Form: -"
        hp_label.text = "HP: -"
        atk_label.text = "ATK: -"
        def_label.text = "DEF: -"
        spd_label.text = "SPD: -"
        ap_label.text = "AP: -"
        kills_label.text = "Fallen: -"
        items_label.text = "Relics: -"
        return

    piece_label.text = "Form: %s" % unit.display_name
    hp_label.text = "HP: %d/%d" % [unit.hp, unit.max_hp]
    atk_label.text = "ATK: %d" % unit.atk
    def_label.text = "DEF: %d" % unit.def
    spd_label.text = "SPD: %d" % unit.spd
    ap_label.text = "AP: %d/%d" % [unit.ap, unit.max_ap]
    kills_label.text = "Fallen: %d" % unit.kills
    items_label.text = "Relics: %d" % unit.items.size()

func _apply_font_sizes(font_size: int) -> void:
    for label in [phase_label, turn_label, gold_label, score_label, floor_label, piece_label, hp_label, atk_label, def_label, spd_label, ap_label, kills_label, items_label]:
        if label == null:
            continue
        label.add_theme_font_size_override("font_size", font_size)

func set_font_scale(font_scale: float) -> void:
    var font_size: int = int(round(20 * font_scale))
    _apply_font_sizes(max(12, font_size))

func _ensure_label(label_name: String, default_text: String) -> Label:
    var existing := get_node_or_null(label_name) as Label
    if existing != null:
        return existing
    var label := Label.new()
    label.name = label_name
    label.text = default_text
    var insert_index: int = max(0, get_children().find(piece_label))
    add_child(label)
    move_child(label, insert_index)
    return label
