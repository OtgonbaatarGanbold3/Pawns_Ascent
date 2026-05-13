extends Resource
class_name Tile

var terrain_id: String = ""
var terrain_data: Dictionary = {}
var position: Vector2i = Vector2i.ZERO
var piece = null
var revealed: bool = true
var objective_id: String = ""
var objective_type: String = ""

func init_from_terrain(new_terrain_id: String, data: Dictionary) -> void:
    terrain_id = new_terrain_id
    terrain_data = data.duplicate(true)
    objective_id = ""
    objective_type = ""

func set_piece(unit) -> void:
    piece = unit

func clear_piece() -> void:
    piece = null
