class_name InvaderActor
extends ActorBase

enum InvaderState {
	WAITING_FOR_SPAWN,
	APPROACHING_DOOR,
	STOPPED_AT_DOOR,
	ENTERING_ROOM,
	ATTACKING_STARTER,
	IDLE,
	DEAD
}

var invader_state: InvaderState = InvaderState.WAITING_FOR_SPAWN
var target_exterior_cell: Vector2i = Vector2i.ZERO
var target_room_id: String = ""
var attack_timer: float = 0.0

# 特效 debuff 状态
var slow_break_timer: float = 0.0
var strip_resist_timer: float = 0.0
var puddle_timer: float = 0.0
var puddle_dps: int = 0
var puddle_tick_timer: float = 0.0

func apply_slow_break(duration: float) -> void:
	slow_break_timer = maxf(slow_break_timer, duration)

func apply_strip_resist(duration: float) -> void:
	strip_resist_timer = maxf(strip_resist_timer, duration)

func apply_puddle(duration: float, damage_per_sec: int) -> void:
	puddle_timer = maxf(puddle_timer, duration)
	puddle_dps = max(puddle_dps, damage_per_sec)

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
	
	# Determine target room:
	# Prioritize room claimed by player if exists, otherwise closest door exterior.
	var player_room_id: String = MatchState.get_player_owned_room_id()
	var target_room: RoomData = null
	if player_room_id != "":
		target_room = grid_manager.get_room_by_id(player_room_id)
	
	if target_room != null:
		target_room_id = target_room.room_id
		target_exterior_cell = target_room.door_exterior_cell
	else:
		target_exterior_cell = grid_manager.get_closest_door_exterior_to(current_cell)
		for r in grid_manager.get_all_rooms():
			if r.door_exterior_cell == target_exterior_cell:
				target_room_id = r.room_id
				break

	MatchState.invader_target_room_id = target_room_id
	
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

func _process(delta: float) -> void:
	super._process(delta)

	if invader_state == InvaderState.DEAD or invader_state == InvaderState.IDLE:
		return

	if MatchState.game_result != MatchState.GameResult.NONE:
		invader_state = InvaderState.IDLE
		is_moving = false
		move_path.clear()
		return

	# 处理 debuff 衰减与 DoT
	if slow_break_timer > 0.0:
		slow_break_timer = maxf(0.0, slow_break_timer - delta)
	if strip_resist_timer > 0.0:
		strip_resist_timer = maxf(0.0, strip_resist_timer - delta)
	if puddle_timer > 0.0:
		puddle_timer = maxf(0.0, puddle_timer - delta)
		puddle_tick_timer += delta
		if puddle_tick_timer >= 0.5:
			puddle_tick_timer -= 0.5
			take_damage(int(round(float(puddle_dps) * 0.5)))

	if invader_state == InvaderState.STOPPED_AT_DOOR:
		_process_attacking_door(delta)
	elif invader_state == InvaderState.ATTACKING_STARTER:
		_process_attacking_starter(delta)

func _process_attacking_door(delta: float) -> void:
	if target_room_id == "":
		return
	
	if not MatchState.is_door_broken(target_room_id):
		var eff_delta: float = delta * (0.5 if slow_break_timer > 0.0 else 1.0)
		attack_timer += eff_delta
		if attack_timer >= MatchState.INVADER_ATTACK_INTERVAL:
			attack_timer = 0.0
			MatchState.damage_door(target_room_id, MatchState.INVADER_ATTACK_DAMAGE)
			if grid_manager != null:
				grid_manager.queue_redraw()
	
	if MatchState.is_door_broken(target_room_id):
		_enter_room_towards_starter()

func _enter_room_towards_starter() -> void:
	if grid_manager == null:
		return
	var room: RoomData = grid_manager.get_room_by_id(target_room_id)
	if room == null:
		return
	
	var path_to_starter: Array[Vector2i] = grid_manager.get_invader_path_to_starter(current_cell, room)
	if not path_to_starter.is_empty():
		invader_state = InvaderState.ENTERING_ROOM
		attack_timer = 0.0
		set_target_path(path_to_starter)
	else:
		invader_state = InvaderState.ATTACKING_STARTER
		attack_timer = 0.0

func _process_attacking_starter(delta: float) -> void:
	if target_room_id == "":
		return
	
	var s_hp: int = MatchState.get_starter_hp(target_room_id)
	if s_hp > 0:
		attack_timer += delta
		if attack_timer >= MatchState.INVADER_ATTACK_INTERVAL:
			attack_timer = 0.0
			MatchState.damage_starter(target_room_id, MatchState.INVADER_ATTACK_DAMAGE)
			if grid_manager != null:
				grid_manager.queue_redraw()
	else:
		invader_state = InvaderState.IDLE
		is_moving = false
		move_path.clear()

func _advance_path() -> void:
	if move_path.is_empty():
		is_moving = false
		if invader_state == InvaderState.APPROACHING_DOOR:
			invader_state = InvaderState.STOPPED_AT_DOOR
			print("Invader arrived outside hatch at cell %s and stopped." % [current_cell])
		elif invader_state == InvaderState.ENTERING_ROOM:
			invader_state = InvaderState.ATTACKING_STARTER
			print("Invader reached starter at cell %s and began attacking." % [current_cell])
		return
	
	var next_cell: Vector2i = move_path.pop_front()
	target_cell = next_cell
	is_moving = true
	move_progress = 0.0

func is_alive() -> bool:
	return invader_state != InvaderState.DEAD and MatchState.invader_hp > 0

func take_damage(damage: int) -> void:
	if not is_alive():
		return
	var final_damage: int = damage
	if strip_resist_timer > 0.0:
		final_damage = int(round(float(final_damage) * 1.3))
	var remaining: int = MatchState.damage_invader(final_damage)
	queue_redraw()
	if remaining <= 0:
		die()

func die() -> void:
	invader_state = InvaderState.DEAD
	is_moving = false
	move_path.clear()
	print("Invader defeated! Stopped action.")
	queue_redraw()

func _draw() -> void:
	var radius: float = float(GridMapManager.TILE_SIZE) * 0.45

	if invader_state == InvaderState.DEAD:
		draw_rect(Rect2(-radius, -radius, radius * 2.0, radius * 2.0), Color(0.3, 0.3, 0.3))
		draw_rect(Rect2(-radius, -radius, radius * 2.0, radius * 2.0), Color(0.5, 0.2, 0.2), false, 1.5)
		return

	# Draw body
	draw_rect(Rect2(-radius, -radius, radius * 2.0, radius * 2.0), actor_color)
	draw_rect(Rect2(-radius, -radius, radius * 2.0, radius * 2.0), Color(1.0, 0.9, 0.2), false, 2.0)
	
	# Draw HP bar
	var bar_w: float = 32.0
	var bar_h: float = 4.0
	var bar_y: float = -radius - 12.0
	var hp_ratio: float = clampf(float(MatchState.invader_hp) / float(MatchState.INVADER_MAX_HP), 0.0, 1.0)
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w, bar_h), Color(0.1, 0.1, 0.1))
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * hp_ratio, bar_h), Color(0.9, 0.2, 0.2))
	
	# Draw name label
	var font := ThemeDB.fallback_font
	var font_size := 11
	draw_string(font, Vector2(-30, -radius - 16), display_name, HORIZONTAL_ALIGNMENT_CENTER, 60, font_size, Color(1.0, 0.4, 0.4))
