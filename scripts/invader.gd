class_name InvaderActor
extends ActorBase

enum InvaderState {
	WAITING_FOR_SPAWN,
	APPROACHING_DOOR,
	STOPPED_AT_DOOR
}

var invader_state: InvaderState = InvaderState.WAITING_FOR_SPAWN
var target_exterior_cell: Vector2i = Vector2i.ZERO

func _ready() -> void:
	super._ready()
	move_speed = 3.5
	visible = false
	invader_state = InvaderState.WAITING_FOR_SPAWN
	MatchState.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(new_phase: int) -> void:
	if new_phase == MatchState.Phase.INVADING:
		spawn_invader()

func spawn_invader() -> void:
	if grid_manager == null:
		return
	
	visible = true
	current_cell = grid_manager.invader_spawn_cell
	target_cell = current_cell
	position = grid_manager.cell_to_world(current_cell)
	
	# Find closest door exterior cell in the corridor
	target_exterior_cell = grid_manager.get_closest_door_exterior_to(current_cell)
	if target_exterior_cell != Vector2i.ZERO:
		var path: Array[Vector2i] = grid_manager.get_invader_path_to_cell(current_cell, target_exterior_cell)
		if not path.is_empty():
			invader_state = InvaderState.APPROACHING_DOOR
			set_target_path(path)
		else:
			invader_state = InvaderState.STOPPED_AT_DOOR
	else:
		invader_state = InvaderState.STOPPED_AT_DOOR
	
	print("Invader spawned at %s, moving towards door exterior %s" % [current_cell, target_exterior_cell])

func _advance_path() -> void:
	if move_path.is_empty():
		is_moving = false
		if invader_state == InvaderState.APPROACHING_DOOR:
			invader_state = InvaderState.STOPPED_AT_DOOR
			print("Invader arrived outside hatch at cell %s and stopped." % [current_cell])
		return
	
	var next_cell: Vector2i = move_path.pop_front()
	target_cell = next_cell
	is_moving = true
	move_progress = 0.0

func _draw() -> void:
	var radius: float = float(GridMapManager.TILE_SIZE) * 0.45
	# Draw body with distinct invader spike / diamond shape or circle
	draw_rect(Rect2(-radius, -radius, radius * 2.0, radius * 2.0), actor_color)
	draw_rect(Rect2(-radius, -radius, radius * 2.0, radius * 2.0), Color(1.0, 0.9, 0.2), false, 2.0)
	
	# Draw name label
	var font := ThemeDB.fallback_font
	var font_size := 11
	draw_string(font, Vector2(-30, -radius - 4), display_name, HORIZONTAL_ALIGNMENT_CENTER, 60, font_size, Color(1.0, 0.4, 0.4))
