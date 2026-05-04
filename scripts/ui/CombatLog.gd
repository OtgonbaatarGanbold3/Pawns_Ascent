extends Control
class_name CombatLog

@onready var log_view: RichTextLabel = $Log

func _ready() -> void:
    log_view.add_theme_font_size_override("font_size", 16)
    log_view.add_theme_color_override("default_color", Color(0.9, 0.9, 0.9))
    log_view.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func append_log(text: String) -> void:
    log_view.append_text(text + "\n")
    log_view.scroll_to_line(log_view.get_line_count() - 1)

func clear_log() -> void:
    log_view.clear()

func set_font_scale(font_scale: float) -> void:
    var font_size: int = int(round(16 * font_scale))
    log_view.add_theme_font_size_override("font_size", max(12, font_size))
