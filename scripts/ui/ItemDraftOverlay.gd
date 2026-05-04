extends Control
class_name ItemDraftOverlay

signal item_selected(item_id: String)
signal draft_skipped

@onready var item_button_1: Button = $Panel/VBox/Buttons/ItemButton1
@onready var item_button_2: Button = $Panel/VBox/Buttons/ItemButton2
@onready var item_button_3: Button = $Panel/VBox/Buttons/ItemButton3
@onready var desc_label: Label = $Panel/VBox/DescLabel
@onready var skip_button: Button = $Panel/VBox/SkipButton
@onready var panel: Control = $Panel

var items: Array = []

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    item_button_1.pressed.connect(_on_item_pressed.bind(0))
    item_button_2.pressed.connect(_on_item_pressed.bind(1))
    item_button_3.pressed.connect(_on_item_pressed.bind(2))
    skip_button.pressed.connect(_on_skip_pressed)
    panel.custom_minimum_size = Vector2(560, 240)
    desc_label.add_theme_font_size_override("font_size", 16)
    for button in [item_button_1, item_button_2, item_button_3, skip_button]:
        button.custom_minimum_size = Vector2(160, 44)
        button.add_theme_font_size_override("font_size", 18)
    resized.connect(_on_resized)

func show_draft(options: Array) -> void:
    items = options
    visible = true
    _center_panel()
    _apply_button(item_button_1, 0)
    _apply_button(item_button_2, 1)
    _apply_button(item_button_3, 2)
    desc_label.text = "Choose one item"

func hide_draft() -> void:
    visible = false

func _on_resized() -> void:
    if visible:
        _center_panel()

func _center_panel() -> void:
    var viewport_size := get_viewport_rect().size
    var panel_size := panel.custom_minimum_size
    panel.position = (viewport_size - panel_size) * 0.5

func _apply_button(button: Button, index: int) -> void:
    if index >= items.size():
        button.text = "-"
        button.disabled = true
        return
    var item: Dictionary = items[index]
    button.text = item.get("display_name", "Item")
    button.disabled = false

func _on_item_pressed(index: int) -> void:
    if index >= items.size():
        return
    var item: Dictionary = items[index]
    var item_id: String = item.get("id", "")
    emit_signal("item_selected", item_id)

func _on_skip_pressed() -> void:
    emit_signal("draft_skipped")
