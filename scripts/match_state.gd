extends Node

signal countdown_tick(remaining: float)
signal phase_changed(new_phase: int)
signal room_claimed(room_id: String, actor_id: String)
signal player_room_changed(room_id: String)

enum Phase {
	COUNTDOWN,
	INVADING
}

var current_phase: Phase = Phase.COUNTDOWN
var countdown_remaining: float = 25.0
var money: int = 0
var room_owners: Dictionary = {} # String (room_id) -> String (actor_id)
var room_locked: Dictionary = {} # String (room_id) -> bool
var room_display_names: Dictionary = {} # String (room_id) -> String (display_name)
var player_room_id: String = "" # "" represents corridor/outside

func _ready() -> void:
	reset_match()

func reset_match(countdown_duration: float = 25.0) -> void:
	current_phase = Phase.COUNTDOWN
	countdown_remaining = countdown_duration
	money = 0
	room_owners.clear()
	room_locked.clear()
	room_display_names.clear()
	player_room_id = ""

func register_room(room_id: String, display_name: String = "") -> void:
	if not room_owners.has(room_id):
		room_owners[room_id] = ""
		room_locked[room_id] = false
	if display_name != "":
		room_display_names[room_id] = display_name
	elif not room_display_names.has(room_id):
		room_display_names[room_id] = room_id

func get_room_display_name(room_id: String) -> String:
	return room_display_names.get(room_id, room_id)

func claim_room(room_id: String, actor_id: String) -> bool:
	if not room_owners.has(room_id):
		register_room(room_id)
	
	if room_locked.get(room_id, false):
		return false
	
	var current_owner: String = room_owners.get(room_id, "")
	if current_owner != "":
		return false
	
	room_owners[room_id] = actor_id
	room_locked[room_id] = true
	room_claimed.emit(room_id, actor_id)
	return true

func is_room_locked(room_id: String) -> bool:
	return room_locked.get(room_id, false)

func get_room_owner(room_id: String) -> String:
	return room_owners.get(room_id, "")

func can_actor_enter_room(room_id: String, actor_id: String) -> bool:
	if not is_room_locked(room_id):
		return true
	return get_room_owner(room_id) == actor_id

func set_player_room(room_id: String) -> void:
	if player_room_id != room_id:
		player_room_id = room_id
		player_room_changed.emit(player_room_id)

func _process(delta: float) -> void:
	if current_phase == Phase.COUNTDOWN:
		countdown_remaining = maxf(0.0, countdown_remaining - delta)
		countdown_tick.emit(countdown_remaining)
		if countdown_remaining <= 0.0:
			current_phase = Phase.INVADING
			phase_changed.emit(current_phase)
