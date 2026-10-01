class_name PlayerActor
extends ActorBase

func _ready() -> void:
	super._ready()
	move_speed = 6.0 # Slightly faster than bots for good responsiveness

func _process(delta: float) -> void:
	super._process(delta)
	
	if not is_moving:
		_handle_input()

func _handle_input() -> void:
	var dir := Vector2i.ZERO
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		dir = Vector2i.LEFT
	elif Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		dir = Vector2i.RIGHT
	elif Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		dir = Vector2i.UP
	elif Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		dir = Vector2i.DOWN

	if dir != Vector2i.ZERO:
		_try_move_direction(dir)

func _try_move_direction(dir: Vector2i) -> void:
	var next_cell: Vector2i = current_cell + dir
	if grid_manager != null and grid_manager.is_cell_walkable_for(next_cell, actor_id):
		target_cell = next_cell
		is_moving = true
		move_progress = 0.0

func _on_step_completed() -> void:
	super._on_step_completed()
	_update_player_room_state()

func _after_ejected_from_room(_p_room_id: String) -> void:
	_update_player_room_state()

func _update_player_room_state() -> void:
	if grid_manager == null:
		return
	var room := grid_manager.get_room_at_cell(current_cell)
	if room != null:
		MatchState.set_player_room(room.room_id)
	else:
		MatchState.set_player_room("")

func _on_room_claimed(room: RoomData) -> void:
	print("Player claimed room: ", room.display_name)
