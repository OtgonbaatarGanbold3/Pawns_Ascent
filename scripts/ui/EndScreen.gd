extends Control
class_name EndScreen

signal restart_requested

@onready var result_label: Label = $Panel/VBox/ResultLabel
@onready var score_label: Label = $Panel/VBox/ScoreLabel
@onready var restart_button: Button = $Panel/VBox/RestartButton
@onready var panel: Control = $Panel

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    restart_button.pressed.connect(_on_restart_pressed)
    panel.custom_minimum_size = Vector2(420, 200)
    result_label.add_theme_font_size_override("font_size", 22)
    score_label.add_theme_font_size_override("font_size", 18)
    restart_button.custom_minimum_size = Vector2(160, 44)
    restart_button.add_theme_font_size_override("font_size", 18)
    resized.connect(_on_resized)

func show_screen(victory: bool, score: int) -> void:
    visible = true
    _center_panel()
    result_label.text = "Victory" if victory else "Defeat"
    score_label.text = "Score: %d" % score

func hide_screen() -> void:
    visible = false

func _on_restart_pressed() -> void:
    emit_signal("restart_requested")

func _on_resized() -> void:
    if visible:
        _center_panel()

func _center_panel() -> void:
    var viewport_size := get_viewport_rect().size
    var panel_size := panel.custom_minimum_size
    panel.position = (viewport_size - panel_size) * 0.5
