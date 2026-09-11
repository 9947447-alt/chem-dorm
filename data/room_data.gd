class_name RoomData
extends RefCounted

var room_id: String = ""
var display_name: String = ""
var spec_size: Vector2i = Vector2i.ZERO
var interior_rect: Rect2i = Rect2i()
var door_cell: Vector2i = Vector2i.ZERO
var door_exterior_cell: Vector2i = Vector2i.ZERO
var starter_cells: Array[Vector2i] = []

func _init(
	p_id: String = "",
	p_name: String = "",
	p_spec: Vector2i = Vector2i.ZERO,
	p_interior: Rect2i = Rect2i(),
	p_door: Vector2i = Vector2i.ZERO,
	p_exterior: Vector2i = Vector2i.ZERO,
	p_starters: Array[Vector2i] = []
) -> void:
	room_id = p_id
	display_name = p_name
	spec_size = p_spec
	interior_rect = p_interior
	door_cell = p_door
	door_exterior_cell = p_exterior
	starter_cells = p_starters

func is_cell_interior(cell: Vector2i) -> bool:
	return interior_rect.has_point(cell)

func is_cell_starter(cell: Vector2i) -> bool:
	return cell in starter_cells
