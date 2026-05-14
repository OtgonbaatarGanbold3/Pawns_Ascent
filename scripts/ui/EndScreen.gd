extends Control
class_name EndScreen

signal restart_requested

@onready var result_label: Label = $Panel/VBox/ResultLabel
@onready var score_label: Label = $Panel/VBox/ScoreLabel
@onready var restart_button: Button = $Panel/VBox/RestartButton
@onready var panel: Control = $Panel

var breakdown_label: Label

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    restart_button.pressed.connect(_on_restart_pressed)
    panel.custom_minimum_size = Vector2(560, 320)
    mouse_filter = Control.MOUSE_FILTER_STOP
    result_label.add_theme_font_size_override("font_size", 22)
    score_label.add_theme_font_size_override("font_size", 18)
    breakdown_label = Label.new()
    breakdown_label.name = "BreakdownLabel"
    breakdown_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    breakdown_label.add_theme_font_size_override("font_size", 15)
    $Panel/VBox.add_child(breakdown_label)
    $Panel/VBox.move_child(breakdown_label, 2)
    restart_button.custom_minimum_size = Vector2(160, 44)
    restart_button.add_theme_font_size_override("font_size", 18)
    _apply_styles()
    resized.connect(_on_resized)

func show_screen(victory: bool, score: int, details: Dictionary = {}) -> void:
    visible = true
    _center_panel()
    result_label.text = "Victory" if victory else "Defeat"
    score_label.text = "Score: %d" % score
    breakdown_label.text = _format_details(details)

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

func _format_details(details: Dictionary) -> String:
    if details.is_empty():
        return ""
    var lines: Array = []
    lines.append("Base score: %d" % int(details.get("base_score", 0)))
    var multipliers: Array = details.get("multipliers", [])
    for entry in multipliers:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var item: Dictionary = entry
        lines.append("%s x%.2f" % [str(item.get("label", "Multiplier")), float(item.get("value", 1.0))])
    var best_score: int = int(details.get("best_score", 0))
    if best_score > 0:
        lines.append("Best here: %d" % best_score)
    var legacy: String = str(details.get("legacy_boss", ""))
    if not legacy.is_empty():
        lines.append("Legacy: %s" % legacy)
    var history: Array = details.get("run_history", [])
    if not history.is_empty():
        lines.append("")
        lines.append("Recent:")
        for i in range(min(3, history.size())):
            if typeof(history[i]) != TYPE_DICTIONARY:
                continue
            var entry: Dictionary = history[i]
            var result := "W" if bool(entry.get("victory", false)) else "D"
            lines.append("#%d %s F%d %d" % [int(entry.get("run", 0)), result, int(entry.get("floor", 0)), int(entry.get("score", 0))])
    return _join_strings(lines, "\n")

func _join_strings(values: Array, separator: String) -> String:
    var text := ""
    for i in range(values.size()):
        if i > 0:
            text += separator
        text += str(values[i])
    return text
