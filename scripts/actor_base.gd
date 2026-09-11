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

func init_actor(p_id: String, p_name: String, p_color: Color, p_cell: Vector2i, p_grid: GridMapManager) -> void:
	actor_id = p_id
	display_name = p_name
	actor_color = p_color
	current_cell = p_cell
	target_cell = p_cell
	grid_manager = p_grid
	position = grid_manager.cell_to_world(current_cell)
	queue_redraw()

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
