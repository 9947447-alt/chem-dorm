class_name AllyBot
extends ActorBase

enum BotState {
	SEARCHING,
	MOVING_TO_ROOM,
	CLAIMED
}

static var room_intent: Dictionary = {} # String (room_id) -> String (actor_id)

var bot_state: BotState = BotState.SEARCHING
var target_room_id: String = ""
var think_timer: float = 0.0

func _ready() -> void:
	move_speed = 4.5
	MatchState.room_claimed.connect(_on_any_room_claimed)

func start_ai() -> void:
	bot_state = BotState.SEARCHING
	_select_and_navigate_to_room()

func _process(delta: float) -> void:
	super._process(delta)
	
	if bot_state == BotState.SEARCHING:
		think_timer += delta
		if think_timer >= 0.2:
			think_timer = 0.0
			_select_and_navigate_to_room()

func _select_and_navigate_to_room() -> void:
	if grid_manager == null:
		return
	
	# Find all unlocked rooms
	var unlocked_rooms: Array[RoomData] = []
	for r in grid_manager.get_all_rooms():
		if not MatchState.is_room_locked(r.room_id):
			unlocked_rooms.append(r)
	
	if unlocked_rooms.is_empty():
		bot_state = BotState.SEARCHING
		return
	
	# Prefer rooms not already intended by another ally
	var candidate_rooms: Array[RoomData] = []
	for r in unlocked_rooms:
		var intended_by: String = room_intent.get(r.room_id, "")
		if intended_by == "" or intended_by == actor_id:
			candidate_rooms.append(r)
	
	# If all unlocked rooms have intent, fall back to any unlocked room
	if candidate_rooms.is_empty():
		candidate_rooms = unlocked_rooms
	
	# Find candidate room with shortest path
	var best_room: RoomData = null
	var best_path: Array[Vector2i] = []
	var min_length: int = 999999
	
	for r in candidate_rooms:
		var starter_goal: Vector2i = r.starter_cells[0]
		var path: Array[Vector2i] = grid_manager.get_path_for_actor(current_cell, starter_goal, actor_id)
		if path.size() > 0 and path.size() < min_length:
			min_length = path.size()
			best_room = r
			best_path = path

	if best_room != null and not best_path.is_empty():
		if target_room_id != "" and room_intent.get(target_room_id) == actor_id:
			room_intent.erase(target_room_id)
		target_room_id = best_room.room_id
		room_intent[target_room_id] = actor_id
		bot_state = BotState.MOVING_TO_ROOM
		set_target_path(best_path)

func _on_any_room_claimed(p_room_id: String, p_actor_id: String) -> void:
	room_intent.erase(p_room_id)
	
	if bot_state == BotState.CLAIMED:
		return
	
	# If someone else claimed our target room, abandon and repath
	if p_room_id == target_room_id and p_actor_id != actor_id:
		target_room_id = ""
		move_path.clear()
		is_moving = false
		bot_state = BotState.SEARCHING
		_select_and_navigate_to_room()

func _on_path_blocked() -> void:
	if bot_state != BotState.CLAIMED:
		if target_room_id != "" and room_intent.get(target_room_id) == actor_id:
			room_intent.erase(target_room_id)
		target_room_id = ""
		bot_state = BotState.SEARCHING
		_select_and_navigate_to_room()

func _on_room_claimed(room: RoomData) -> void:
	bot_state = BotState.CLAIMED
	target_room_id = room.room_id
	room_intent.erase(room.room_id)
	move_path.clear()
	is_moving = false
	print("Ally %s claimed room: %s" % [display_name, room.display_name])
