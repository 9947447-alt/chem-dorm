class_name ActorBase
extends Node2D

signal reached_cell(cell: Vector2i)

@export var actor_id: String = ""
@export var display_name: String = ""
@export var move_speed: float = 5.0 # cells per second
@export var actor_color: Color = Color.WHITE

var current_cell: Vector2i = Vector2i.ZERO
var target_cell: Vector2i = Vector2i.ZERO
var is_moving: bool = false
var move_progress: float = 0.0
var move_path: Array[Vector2i] = []
var grid_manager: GridMapManager = null

func _ready() -> void:
	_connect_claim_signal()

func _exit_tree() -> void:
	if MatchState.room_claimed.is_connected(_on_room_claimed_global):
		MatchState.room_claimed.disconnect(_on_room_claimed_global)

func init_actor(p_id: String, p_name: String, p_color: Color, p_cell: Vector2i, p_grid: GridMapManager) -> void:
	actor_id = p_id
	display_name = p_name
	actor_color = p_color
	current_cell = p_cell
	target_cell = p_cell
	grid_manager = p_grid
	position = grid_manager.cell_to_world(current_cell)
	_connect_claim_signal()
	queue_redraw()

func _connect_claim_signal() -> void:
	if not MatchState.room_claimed.is_connected(_on_room_claimed_global):
		MatchState.room_claimed.connect(_on_room_claimed_global)

func _on_room_claimed_global(p_room_id: String, p_claiming_actor_id: String) -> void:
	if is_queued_for_deletion():
		return
	var was_ejected: bool = false
	if p_claiming_actor_id != actor_id:
		was_ejected = _check_and_eject_if_in_room(p_room_id)
	_on_any_room_claimed(p_room_id, p_claiming_actor_id)
	if was_ejected:
		_after_ejected_from_room(p_room_id)

func _check_and_eject_if_in_room(p_room_id: String) -> bool:
	if grid_manager == null:
		return false
	var room: RoomData = grid_manager.get_room_by_id(p_room_id)
	if room == null:
		return false
	
	var in_room: bool = _is_cell_in_room(current_cell, room)
	if not in_room and is_moving:
		in_room = _is_cell_in_room(target_cell, room)
	
	if in_room:
		eject_to_cell(room.door_exterior_cell)
		return true
	return false

func _is_cell_in_room(cell: Vector2i, room: RoomData) -> bool:
	return room.is_cell_interior(cell) or cell == room.door_cell or room.is_cell_starter(cell)

func eject_to_cell(dest_cell: Vector2i) -> void:
	current_cell = dest_cell
	target_cell = dest_cell
	is_moving = false
	move_progress = 0.0
	move_path.clear()
	if grid_manager != null:
		position = grid_manager.cell_to_world(dest_cell)
		grid_manager.queue_redraw()
	queue_redraw()

func _after_ejected_from_room(_p_room_id: String) -> void:
	pass

func _on_any_room_claimed(_p_room_id: String, _p_actor_id: String) -> void:
	pass

func set_target_path(path: Array[Vector2i]) -> void:
	move_path = path
	if not move_path.is_empty():
		if move_path[0] == current_cell:
			move_path.pop_front()
		if not is_moving:
			_advance_path()

func _advance_path() -> void:
	if move_path.is_empty():
		is_moving = false
		return
	
	var next_cell: Vector2i = move_path.pop_front()
	# Check walkability before moving
	if grid_manager != null and not grid_manager.is_cell_walkable_for(next_cell, actor_id):
		# Path blocked (e.g. room was just locked)
		move_path.clear()
		is_moving = false
		_on_path_blocked()
		return
	
	target_cell = next_cell
	is_moving = true
	move_progress = 0.0

func _on_path_blocked() -> void:
	pass

func _process(delta: float) -> void:
	if is_moving:
		move_progress += move_speed * delta
		var start_pos: Vector2 = grid_manager.cell_to_world(current_cell)
		var end_pos: Vector2 = grid_manager.cell_to_world(target_cell)
		
		if move_progress >= 1.0:
			position = end_pos
			current_cell = target_cell
			move_progress = 0.0
			is_moving = false
			_on_step_completed()
			_advance_path()
		else:
			position = start_pos.lerp(end_pos, move_progress)

func _on_step_completed() -> void:
	reached_cell.emit(current_cell)
	
	# Check starter occupancy to claim room
	if grid_manager != null:
		var room := grid_manager.get_room_by_starter_cell(current_cell)
		if room != null:
			if not MatchState.is_room_locked(room.room_id):
				var claimed: bool = MatchState.claim_room(room.room_id, actor_id)
				if claimed:
					_on_room_claimed(room)
					grid_manager.queue_redraw()

func _on_room_claimed(_room: RoomData) -> void:
	pass

func _draw() -> void:
	var radius: float = float(GridMapManager.TILE_SIZE) * 0.4
	# Draw body
	draw_circle(Vector2.ZERO, radius, actor_color)
	draw_circle(Vector2.ZERO, radius, Color(0.1, 0.1, 0.1), false, 2.0)
	
	# Draw name label
	var font := ThemeDB.fallback_font
	var font_size := 11
	draw_string(font, Vector2(-30, -radius - 4), display_name, HORIZONTAL_ALIGNMENT_CENTER, 60, font_size, Color.WHITE)
