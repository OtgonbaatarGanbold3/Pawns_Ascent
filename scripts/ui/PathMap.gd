extends Control
class_name PathMap

signal node_selected(node_id: String)

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var subtitle_label: Label = $Panel/VBox/SubtitleLabel
@onready var nodes_row: HBoxContainer = $Panel/VBox/NodesRow
@onready var detail_label: Label = $Panel/VBox/DetailLabel

var _path_graph: Dictionary = {}
var _available: Array = []

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    title_label.add_theme_font_size_override("font_size", 28)
    subtitle_label.add_theme_font_size_override("font_size", 16)
    detail_label.add_theme_font_size_override("font_size", 15)
    subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    nodes_row.add_theme_constant_override("separation", 14)
    panel.add_theme_stylebox_override("panel", PawnUITheme.make_panel_style(Color(0.045, 0.052, 0.06, 0.98), Color(0.36, 0.42, 0.48, 1.0), 18))
    resized.connect(_on_resized)
    visible = false

func show_path(path_graph: Dictionary, available: Array) -> void:
    _path_graph = path_graph
    _available = available
    visible = true
    _center_panel()
    _rebuild_nodes()

func hide_path() -> void:
    visible = false

func _on_resized() -> void:
    if visible:
        _center_panel()

func _center_panel() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    var margin: float = clamp(viewport_size.x * 0.04, 24.0, 72.0)
    var panel_size := Vector2(
        min(980.0, viewport_size.x - margin * 2.0),
        min(430.0, viewport_size.y - margin * 2.0)
    )
    panel_size.x = max(520.0, panel_size.x)
    panel_size.y = max(320.0, panel_size.y)
    panel.size = panel_size
    panel.position = (viewport_size - panel_size) * 0.5

func _rebuild_nodes() -> void:
    for child in nodes_row.get_children():
        child.queue_free()

    title_label.text = str(_path_graph.get("zone_name", "The Outer Plain"))
    subtitle_label.text = "Choose the next square. The unchosen paths close behind you."
    if _available.is_empty():
        detail_label.text = "The path has ended."
        return
    detail_label.text = ""

    var nodes: Dictionary = _path_graph.get("nodes", {})
    for node_id in _available:
        var node: Dictionary = nodes.get(node_id, {})
        var button := Button.new()
        button.custom_minimum_size = Vector2(210, 180)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.text = _format_node(node)
        button.tooltip_text = str(node.get("summary", ""))
        button.mouse_entered.connect(_show_node_detail.bind(node))
        button.pressed.connect(_on_node_pressed.bind(str(node_id)))
        _style_node_button(button, str(node.get("type", "combat")))
        nodes_row.add_child(button)

func _format_node(node: Dictionary) -> String:
    var preview: Dictionary = node.get("preview", {})
    var lines: Array = [
        str(node.get("icon", "Node")),
        str(node.get("label", "Node")),
    ]
    lines.append("")
    lines.append("Floor %d  Risk: %s" % [int(node.get("floor", 1)), str(preview.get("risk", "?"))])
    var pattern: String = str(preview.get("pattern", ""))
    if not pattern.is_empty():
        lines.append("%s (%d)" % [pattern, int(preview.get("enemy_count", 0))])
    lines.append(str(preview.get("reward", node.get("summary", ""))))
    return _join_strings(lines, "\n")

func _show_node_detail(node: Dictionary) -> void:
    var preview: Dictionary = node.get("preview", {})
    var lines: Array = [
        "%s: %s" % [str(node.get("label", "Node")), str(node.get("summary", ""))],
        "Risk: %s  Pace: %s" % [str(preview.get("risk", "?")), str(preview.get("intensity", "?"))],
        str(preview.get("summary", "")),
        "Reward: %s" % str(preview.get("reward", "?"))
    ]
    var pattern: String = str(preview.get("pattern", ""))
    if not pattern.is_empty():
        lines.append("Likely pattern: %s, %d enemies" % [pattern, int(preview.get("enemy_count", 0))])
    detail_label.text = _join_strings(lines, "\n")

func _on_node_pressed(node_id: String) -> void:
    emit_signal("node_selected", node_id)

func _style_node_button(button: Button, node_type: String) -> void:
    var fill := Color(0.075, 0.083, 0.092)
    var border := Color(0.25, 0.3, 0.34)
    match node_type:
        "elite", "ambush":
            fill = Color(0.13, 0.075, 0.075)
            border = Color(0.5, 0.22, 0.18)
        "relic":
            fill = Color(0.08, 0.075, 0.13)
            border = Color(0.36, 0.28, 0.58)
        "rest":
            fill = Color(0.08, 0.105, 0.08)
            border = Color(0.28, 0.48, 0.32)
        "story":
            fill = Color(0.1, 0.09, 0.07)
            border = Color(0.48, 0.38, 0.22)
        "boss":
            fill = Color(0.13, 0.105, 0.055)
            border = Color(0.62, 0.48, 0.2)
    var normal := PawnUITheme.make_panel_style(fill, border, 12, 5, 2)
    button.add_theme_stylebox_override("normal", normal)
    var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
    hover.bg_color = fill.lightened(0.08)
    hover.border_color = border.lightened(0.2)
    button.add_theme_stylebox_override("hover", hover)

func _join_strings(values: Array, separator: String) -> String:
    var text := ""
    for i in range(values.size()):
        if i > 0:
            text += separator
        text += str(values[i])
    return text
