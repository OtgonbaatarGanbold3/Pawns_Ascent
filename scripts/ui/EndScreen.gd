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
    mouse_filter = Control.MOUSE_FILTER_STOP
    result_label.add_theme_font_size_override("font_size", 22)
    score_label.add_theme_font_size_override("font_size", 18)
    restart_button.custom_minimum_size = Vector2(160, 44)
    restart_button.add_theme_font_size_override("font_size", 18)
    _apply_styles()
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
    var viewport_size: Vector2 = get_viewport_rect().size
    var margin: float = clamp(viewport_size.x * 0.05, 20.0, 64.0)
    var panel_size: Vector2 = Vector2(
        min(panel.custom_minimum_size.x, viewport_size.x - margin * 2.0),
        min(panel.custom_minimum_size.y, viewport_size.y - margin * 2.0)
    )
    panel.size = panel_size
    panel.position = (viewport_size - panel_size) * 0.5

func _apply_styles() -> void:
    var panel_style := PawnUITheme.make_panel_style(Color(0.055, 0.065, 0.075, 0.98), Color(0.36, 0.42, 0.48, 1.0), 18)
    panel.add_theme_stylebox_override("panel", panel_style)
