extends Resource
class_name BoardData

var rows: int = 0
var cols: int = 0
var tiles: Array = []

func init_board(new_rows: int, new_cols: int) -> void:
    rows = new_rows
    cols = new_cols
    tiles = []
    for row_index in range(rows):
        var row: Array = []
        for col_index in range(cols):
            row.append(null)
        tiles.append(row)

func is_in_bounds(pos: Vector2i) -> bool:
    return pos.x >= 0 and pos.y >= 0 and pos.x < cols and pos.y < rows

func get_tile(pos: Vector2i):
    if not is_in_bounds(pos):
        return null
    return tiles[pos.y][pos.x]

func set_tile(pos: Vector2i, tile) -> void:
    if not is_in_bounds(pos):
        return
    tiles[pos.y][pos.x] = tile
    if tile != null:
        tile.position = pos

func set_unit(pos: Vector2i, unit) -> void:
    var tile = get_tile(pos)
    if tile == null:
        return
    tile.piece = unit
    if unit != null:
        unit.position = pos

func clear_unit(pos: Vector2i) -> void:
    var tile = get_tile(pos)
    if tile == null:
        return
    tile.piece = null
