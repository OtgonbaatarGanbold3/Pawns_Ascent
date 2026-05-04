extends Resource
class_name Tile

var terrain_id: String = ""
var terrain_data: Dictionary = {}
var position: Vector2i = Vector2i.ZERO
var piece = null
var revealed: bool = true

func init_from_terrain(new_terrain_id: String, data: Dictionary) -> void:
    terrain_id = new_terrain_id
    terrain_data = data.duplicate(true)

func set_piece(unit) -> void:
    piece = unit

func clear_piece() -> void:
    piece = null
