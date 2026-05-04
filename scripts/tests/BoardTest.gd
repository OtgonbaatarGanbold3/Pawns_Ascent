extends Node


func _ready() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 1
    var board = BoardGenerator.generate_board(rng)
    print("BoardTest size:", board.rows, "x", board.cols)
