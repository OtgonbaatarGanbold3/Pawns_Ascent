extends Resource
class_name Unit

var piece_id: String = ""
var display_name: String = ""
var position: Vector2i = Vector2i.ZERO

var is_player: bool = false
var is_ally: bool = false
var is_boss: bool = false

var items: Array = []
var status_effects: Dictionary = {}
var kills: int = 0

var base_hp: int = 0
var base_atk: int = 0
var base_def: int = 0
var base_spd: int = 0
var base_ap: int = 0
var move_type: String = ""
var move_range: int = 0
var evolve_kills: int = 0
var next_form: String = ""

var max_hp: int = 0
var atk: int = 0
var def: int = 0
var spd: int = 0
var max_ap: int = 0

var hp: int = 0
var ap: int = 0

func init_from_piece(new_piece_id: String, piece_data: Dictionary) -> void:
	piece_id = new_piece_id
	display_name = piece_data.get("display_name", new_piece_id)

	var base_stats: Dictionary = piece_data.get("base_stats", {})
	base_hp = int(base_stats.get("hp", 0))
	base_atk = int(base_stats.get("atk", 0))
	base_def = int(base_stats.get("def", 0))
	base_spd = int(base_stats.get("spd", 0))
	base_ap = int(base_stats.get("ap", 0))

	move_type = piece_data.get("move_type", "")
	move_range = int(piece_data.get("move_range", 0))
	evolve_kills = int(piece_data.get("evolve_kills", 0))
	next_form = piece_data.get("next_form", "")

	_rebuild_derived_stats()
	hp = max_hp
	ap = max_ap

func apply_items(items_data: Array) -> void:
	items = items_data.duplicate(true)
	_rebuild_derived_stats()
	if hp > 0:
		hp = min(hp, max_hp)
	ap = min(ap, max_ap)

func apply_damage(amount: int) -> bool:
	if amount <= 0:
		return false
	hp = max(hp - amount, 0)
	return hp == 0

func is_dead() -> bool:
	return hp <= 0

func _rebuild_derived_stats() -> void:
	var hp_bonus = 0
	var atk_bonus = 0
	var def_bonus = 0
	var spd_bonus = 0
	var ap_bonus = 0

	for item in items:
		var stats: Dictionary = item.get("stats", {})
		hp_bonus += int(stats.get("hp", 0))
		atk_bonus += int(stats.get("atk", 0))
		def_bonus += int(stats.get("def", 0))
		spd_bonus += int(stats.get("spd", 0))
		ap_bonus += int(stats.get("ap", 0))

	max_hp = base_hp + hp_bonus
	atk = base_atk + atk_bonus
	def = base_def + def_bonus
	spd = base_spd + spd_bonus
	max_ap = base_ap + ap_bonus
