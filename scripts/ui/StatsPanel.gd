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

func _ready() -> void:
    _apply_font_sizes(20)

func set_phase(phase_text: String, turn: int) -> void:
    phase_label.text = "%s has the move" % phase_text
    turn_label.text = "Ring %d" % turn

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
    for label in [phase_label, turn_label, piece_label, hp_label, atk_label, def_label, spd_label, ap_label, kills_label, items_label]:
        label.add_theme_font_size_override("font_size", font_size)

func set_font_scale(font_scale: float) -> void:
    var font_size: int = int(round(20 * font_scale))
    _apply_font_sizes(max(12, font_size))
