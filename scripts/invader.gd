class_name InvaderActor
extends ActorBase

enum InvaderState {
	WAITING_FOR_SPAWN,
	APPROACHING_DOOR,
	STOPPED_AT_DOOR,
	MOVING_TO_HEAL_PAD,
	HEALING_AT_PAD,
	ENTERING_ROOM,
	ATTACKING_STARTER,
	IDLE,
	DEAD
}

var invader_state: InvaderState = InvaderState.WAITING_FOR_SPAWN
var target_exterior_cell: Vector2i = Vector2i.ZERO
var target_room_id: String = ""
var attack_timer: float = 0.0
var target_strategy: String = "round_robin" # "round_robin", "lowest_hp", "distance"

# 敌人角色与等级经验体系
var invader_character: String = "" # rock_corroder(蚀岩), mist_walker(雾徙), fire_quencher(遏火), oxygen_burster(暴氧)
var invader_level: int = 1
var invader_xp: int = 0
var invader_xp_to_next: int = 40

# 技能控制与冷却
var skill_cooldown_timer: float = 0.0
var oxygen_self_hitch_timer: float = 0.0
var heal_tick_timer: float = 0.0
var has_retargeted_at_12: bool = false

# 特效 debuff 状态
var slow_break_timer: float = 0.0
var strip_resist_timer: float = 0.0
var puddle_timer: float = 0.0
var puddle_dps: int = 0
var puddle_tick_timer: float = 0.0
var silicic_slow_timer: float = 0.0
var silicic_slow_factor: float = 1.0
var carbonate_hitch_timer: float = 0.0

const CHARACTER_NAMES: Dictionary = {
	"rock_corroder": "蚀岩",
	"mist_walker": "雾徙",
	"fire_quencher": "遏火",
	"oxygen_burster": "暴氧"
}

func set_character(char_id: String) -> void:
	if CHARACTER_NAMES.has(char_id):
		invader_character = char_id
		display_name = CHARACTER_NAMES[char_id]
		MatchState.invader_character = char_id

func apply_slow_break(duration: float) -> void:
	slow_break_timer = maxf(slow_break_timer, duration)

func apply_silicic_slow(duration: float, factor: float) -> void:
	if duration <= 0.0:
		return
	# factor 必须 < 1，禁止把减速做成加速
	var f: float = clampf(factor, 0.2, 0.9)
	if silicic_slow_timer <= 0.0:
		silicic_slow_factor = f
	else:
		silicic_slow_factor = minf(silicic_slow_factor, f)
	silicic_slow_timer = maxf(silicic_slow_timer, duration)
	_sync_status_text()

func apply_carbonate_hitch(duration: float) -> void:
	if duration <= 0.0:
		return
	carbonate_hitch_timer = maxf(carbonate_hitch_timer, duration)
	_sync_status_text()

func apply_strip_resist(duration: float) -> void:
	strip_resist_timer = maxf(strip_resist_timer, duration)

func apply_puddle(duration: float, damage_per_sec: int) -> void:
	puddle_timer = maxf(puddle_timer, duration)
	puddle_dps = max(puddle_dps, damage_per_sec)

func get_effective_move_speed() -> float:
	if carbonate_hitch_timer > 0.0:
		return 0.0
	if silicic_slow_timer > 0.0:
		return move_speed * silicic_slow_factor
	return move_speed

func _sync_status_text() -> void:
	var parts: PackedStringArray = PackedStringArray()
	if silicic_slow_timer > 0.0:
		parts.append("胶滞")
	if carbonate_hitch_timer > 0.0:
		parts.append("沸断")
	var text: String = " ".join(parts)
	if text != MatchState.invader_status_text:
		MatchState.invader_status_text = text
		MatchState.invader_hp_changed.emit(MatchState.invader_hp, MatchState.INVADER_MAX_HP)

func _ready() -> void:
	super._ready()
	move_speed = 3.5
	visible = false
	invader_state = InvaderState.WAITING_FOR_SPAWN
	MatchState.phase_changed.connect(_on_phase_changed)
	
	# 四角色抽一个（优先继承 MatchState 抽样，未设定则随机抽取）
	if MatchState.invader_character != "":
		set_character(MatchState.invader_character)
	elif invader_character != "":
		set_character(invader_character)
	else:
		var pool: Array[String] = ["rock_corroder", "mist_walker", "fire_quencher", "oxygen_burster"]
		set_character(pool[randi() % pool.size()])

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
	_pick_target_and_move()

func get_alive_rooms() -> Array[RoomData]:
	var alive: Array[RoomData] = []
	if grid_manager == null:
		return alive
	for r in grid_manager.get_all_rooms():
		if not MatchState.is_door_broken(r.room_id) and MatchState.get_starter_hp(r.room_id) > 0:
			alive.append(r)
	if alive.is_empty():
		for r in grid_manager.get_all_rooms():
			if MatchState.get_starter_hp(r.room_id) > 0:
				alive.append(r)
	return alive

func select_dynamic_target() -> RoomData:
	if grid_manager == null:
		return null
	
	var alive_rooms: Array[RoomData] = get_alive_rooms()
	if alive_rooms.is_empty():
		return null
	
	var chosen_room: RoomData = null
	
	match target_strategy:
		"lowest_hp":
			var lowest_hp: int = 99999999
			for r in alive_rooms:
				var hp: int = MatchState.get_door_hp(r.room_id)
				if hp < lowest_hp:
					lowest_hp = hp
					chosen_room = r
		"distance":
			var min_dist: int = 999999
			for r in alive_rooms:
				var path := grid_manager.astar_corridor.get_id_path(current_cell, r.door_exterior_cell)
				var d: int = path.size() if path.size() > 0 else 999999
				if d < min_dist:
					min_dist = d
					chosen_room = r
		_: # "round_robin"
			var all_rooms: Array[RoomData] = grid_manager.get_all_rooms()
			var cur_all_idx: int = -1
			for i in range(all_rooms.size()):
				if all_rooms[i].room_id == target_room_id:
					cur_all_idx = i
					break
			
			for step in range(1, all_rooms.size() + 1):
				var check_idx: int = (cur_all_idx + step) % all_rooms.size()
				var candidate: RoomData = all_rooms[check_idx]
				if not MatchState.is_door_broken(candidate.room_id) and MatchState.get_starter_hp(candidate.room_id) > 0:
					chosen_room = candidate
					break
			
			if chosen_room == null and not alive_rooms.is_empty():
				chosen_room = alive_rooms[0]
	
	if chosen_room == null and not alive_rooms.is_empty():
		chosen_room = alive_rooms[0]
	
	return chosen_room

func pick_target_after_healing() -> RoomData:
	var target_room: RoomData = select_dynamic_target()
	if target_room != null:
		target_room_id = target_room.room_id
		target_exterior_cell = target_room.door_exterior_cell
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
		print("Invader healed, dynamically retargeted to room %s at %s" % [target_room_id, target_exterior_cell])
	else:
		invader_state = InvaderState.IDLE
	return target_room

func _pick_target_and_move() -> void:
	var player_room_id: String = MatchState.get_player_owned_room_id()
	var target_room: RoomData = null
	if player_room_id != "" and not MatchState.is_door_broken(player_room_id):
		target_room = grid_manager.get_room_by_id(player_room_id)
	
	if target_room != null:
		target_room_id = target_room.room_id
		target_exterior_cell = target_room.door_exterior_cell
	else:
		var alive_rooms: Array[RoomData] = get_alive_rooms()
		var min_dist: int = 999999
		for r in alive_rooms:
			var path := grid_manager.astar_corridor.get_id_path(current_cell, r.door_exterior_cell)
			var d: int = path.size() if path.size() > 0 else 999999
			if d < min_dist:
				min_dist = d
				target_room = r
		
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

func add_xp(amount: int) -> void:
	# 打门才涨经验，跑路/回血不涨
	if invader_state != InvaderState.STOPPED_AT_DOOR:
		return
	invader_xp += amount
	MatchState.invader_xp = invader_xp
	while invader_xp >= invader_xp_to_next and invader_level < 15:
		invader_xp -= invader_xp_to_next
		invader_level += 1
		invader_xp_to_next = MatchState.get_invader_xp_to_next(invader_level)
		MatchState.invader_level = invader_level
		MatchState.invader_level_up.emit(invader_character, invader_level)
		MatchState.invader_level_changed.emit(invader_level)
		print("敌人升级！当前等级: %d [%s]" % [invader_level, display_name])

func get_base_attack_damage() -> int:
	if invader_level == 1:
		return MatchState.INVADER_ATTACK_DAMAGE # 20 (V0 保持)
	elif invader_level == 2:
		return 30
	elif invader_level == 3:
		return 42 # 3-4 级压力波
	elif invader_level == 4:
		return 56 # 3-4 级压力波
	elif invader_level < 10:
		return 60 + (invader_level - 5) * 12
	elif invader_level < 15:
		return 120 + (invader_level - 10) * 10
	else:
		return MatchState.INVADER_LV15_ATTACK_DAMAGE

func get_base_attack_interval() -> float:
	if invader_level == 1:
		return MatchState.INVADER_ATTACK_INTERVAL # 1.0 (V0 保持)
	elif invader_level <= 4:
		return 0.85
	elif invader_level < 15:
		return 0.75
	else:
		return MatchState.INVADER_LV15_ATTACK_INTERVAL

func _tick_status_timers(delta: float) -> void:
	if silicic_slow_timer > 0.0:
		silicic_slow_timer = maxf(0.0, silicic_slow_timer - delta)
		if silicic_slow_timer <= 0.0:
			silicic_slow_factor = 1.0
	if carbonate_hitch_timer > 0.0:
		carbonate_hitch_timer = maxf(0.0, carbonate_hitch_timer - delta)
	if slow_break_timer > 0.0:
		slow_break_timer = maxf(0.0, slow_break_timer - delta)
	if strip_resist_timer > 0.0:
		strip_resist_timer = maxf(0.0, strip_resist_timer - delta)
	if oxygen_self_hitch_timer > 0.0:
		oxygen_self_hitch_timer = maxf(0.0, oxygen_self_hitch_timer - delta)
	if skill_cooldown_timer > 0.0:
		skill_cooldown_timer = maxf(0.0, skill_cooldown_timer - delta)
	_sync_status_text()

func _process(delta: float) -> void:
	_tick_status_timers(delta)
	super._process(delta)

	if invader_state == InvaderState.DEAD or invader_state == InvaderState.IDLE:
		return

	if MatchState.game_result != MatchState.GameResult.NONE:
		invader_state = InvaderState.IDLE
		is_moving = false
		move_path.clear()
		return

	# 处理 debuff 衰减与 DoT
	if puddle_timer > 0.0:
		puddle_timer = maxf(0.0, puddle_timer - delta)
		puddle_tick_timer += delta
		if puddle_tick_timer >= 0.5:
			puddle_tick_timer -= 0.5
			take_damage(int(round(float(puddle_dps) * 0.5)))
	elif grid_manager != null and grid_manager.has_acid_puddle_at(current_cell):
		# 踩入地面酸液水洼实体：持续承受水洼灼烧 DoT
		puddle_tick_timer += delta
		if puddle_tick_timer >= 0.5:
			puddle_tick_timer -= 0.5
			var p_dps: int = grid_manager.get_acid_puddle_dps(current_cell)
			take_damage(int(round(float(p_dps) * 0.5)))

	# 检查低血量撤退至走廊回血点（全状态生效，包括入室拆起步矿）
	if MatchState.invader_hp <= int(float(MatchState.INVADER_MAX_HP) * 0.35):
		if invader_state == InvaderState.STOPPED_AT_DOOR or invader_state == InvaderState.APPROACHING_DOOR or invader_state == InvaderState.ATTACKING_STARTER or invader_state == InvaderState.ENTERING_ROOM:
			_retreat_to_heal_pad()

	if invader_state == InvaderState.STOPPED_AT_DOOR:
		_process_attacking_door(delta)
	elif invader_state == InvaderState.HEALING_AT_PAD:
		_process_healing(delta)
	elif invader_state == InvaderState.ATTACKING_STARTER:
		_process_attacking_starter(delta)

func _retreat_to_heal_pad() -> void:
	if grid_manager == null:
		return
	var pad_cell: Vector2i = grid_manager.get_closest_heal_pad_to(current_cell)
	if pad_cell != Vector2i.ZERO:
		var path: Array[Vector2i] = grid_manager.get_invader_path_to_heal_pad(current_cell, pad_cell)
		if not path.is_empty():
			invader_state = InvaderState.MOVING_TO_HEAL_PAD
			set_target_path(path)
			print("敌人血量危险 (<=35%)，撤退至走廊回血点: ", pad_cell)

func _process_healing(delta: float) -> void:
	# 回血时不涨经验
	heal_tick_timer += delta
	if heal_tick_timer >= 0.5:
		heal_tick_timer -= 0.5
		var new_hp: int = min(MatchState.INVADER_MAX_HP, MatchState.invader_hp + 15)
		MatchState.invader_hp = new_hp
		MatchState.invader_hp_changed.emit(new_hp, MatchState.INVADER_MAX_HP)
		queue_redraw()

	if MatchState.invader_hp >= int(float(MatchState.INVADER_MAX_HP) * 0.9):
		# 生命值恢复至安全线，动态索敌重返战场
		heal_tick_timer = 0.0
		pick_target_after_healing()

func _process_attacking_door(delta: float) -> void:
	if target_room_id == "":
		return

	if oxygen_self_hitch_timer > 0.0:
		return # 暴氧 Lv 8 爆发后处于僵直自停状态
	if carbonate_hitch_timer > 0.0:
		return # 碳酸命中：暂停拆门扣血

	if not MatchState.is_door_broken(target_room_id):
		var break_scale: float = 1.0
		if slow_break_timer > 0.0:
			break_scale *= 0.5
		if silicic_slow_timer > 0.0:
			break_scale *= silicic_slow_factor
		attack_timer += delta * break_scale
		var interval: float = get_base_attack_interval()
		if attack_timer >= interval:
			attack_timer = 0.0

			# 只有攻击门才涨经验
			add_xp(15)

			var dmg: int = get_base_attack_damage()

			# 角色专属技能检验（严格未到级不能用）
			match invader_character:
				"rock_corroder":
					# 蚀岩 Lv 5: 强化克制回血门 (抵消回血量)
					if invader_level >= 5:
						dmg += MatchState.get_door_regen_rate(target_room_id)
					# 蚀岩 Lv 10: 对当前舱门造成 50% 额外斩击伤害
					if invader_level >= 10:
						dmg = int(round(float(dmg) * 1.5))
				"mist_walker":
					# 雾徙 Lv 5: 迷雾减速周围炮台
					if invader_level >= 5 and skill_cooldown_timer <= 0.0:
						skill_cooldown_timer = 5.0
						_apply_mist_to_room(target_room_id)
					# 雾徙 Lv 12: 瞬间切换攻击另一扇门
					if invader_level >= 12 and not has_retargeted_at_12:
						has_retargeted_at_12 = true
						_retarget_alternate_door()
						return
				"fire_quencher":
					# 遏火 Lv 6: 周期性沉默一座炮台 3 秒
					if invader_level >= 6 and skill_cooldown_timer <= 0.0:
						skill_cooldown_timer = 7.0
						_silence_one_turret_in_room(target_room_id)
					# 遏火 Lv 12: 削弱房间内所有炮台 1.5 格射程
					if invader_level >= 12:
						_shorten_room_turrets_range(target_room_id)
				"oxygen_burster":
					# 暴氧 Lv 8: 爆发拆门 (3倍伤害) 并自僵直 1.5 秒
					if invader_level >= 8 and skill_cooldown_timer <= 0.0:
						skill_cooldown_timer = 6.0
						dmg *= 3
						oxygen_self_hitch_timer = 1.5
					# 暴氧 Lv 15: 对离子栅 V 造成双倍特攻
					if invader_level >= 15:
						if MatchState.get_door_kind(target_room_id) == "ion_gate" and MatchState.get_door_rank(target_room_id) == 5:
							dmg *= 2

			MatchState.damage_door(target_room_id, dmg)
			if grid_manager != null:
				grid_manager.queue_redraw()

	if MatchState.is_door_broken(target_room_id):
		_enter_room_towards_starter()

func _apply_mist_to_room(r_id: String) -> void:
	if grid_manager == null:
		return
	for t in grid_manager.turrets.values():
		if t is SilicicTurret and t.room_id == r_id:
			t.apply_fog_slow(4.0)

func _silence_one_turret_in_room(r_id: String) -> void:
	if grid_manager == null:
		return
	for t in grid_manager.turrets.values():
		if t is SilicicTurret and t.room_id == r_id:
			t.apply_silence(3.0)
			break

func _shorten_room_turrets_range(r_id: String) -> void:
	if grid_manager == null:
		return
	for t in grid_manager.turrets.values():
		if t is SilicicTurret and t.room_id == r_id:
			t.set_range_reduction(1.5)

func _retarget_alternate_door() -> void:
	if grid_manager == null:
		return
	for r in grid_manager.get_all_rooms():
		if r.room_id != target_room_id and not MatchState.is_door_broken(r.room_id):
			target_room_id = r.room_id
			target_exterior_cell = r.door_exterior_cell
			MatchState.invader_target_room_id = target_room_id
			var path: Array[Vector2i] = grid_manager.get_invader_path_to_cell(current_cell, target_exterior_cell)
			if not path.is_empty():
				invader_state = InvaderState.APPROACHING_DOOR
				set_target_path(path)
			break

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
			MatchState.damage_starter(target_room_id, get_base_attack_damage())
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
		elif invader_state == InvaderState.MOVING_TO_HEAL_PAD:
			invader_state = InvaderState.HEALING_AT_PAD
			print("Invader arrived at heal pad %s and started healing." % [current_cell])
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
	
	# Draw name label with Level
	var font := ThemeDB.fallback_font
	var font_size := 11
	var title_text := "%s (Lv.%d)" % [display_name, invader_level]
	draw_string(font, Vector2(-40, -radius - 16), title_text, HORIZONTAL_ALIGNMENT_CENTER, 80, font_size, Color(1.0, 0.4, 0.4))

