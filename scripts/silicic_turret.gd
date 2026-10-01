class_name SilicicTurret
extends Node2D

var grid_cell: Vector2i = Vector2i.ZERO
var grid_manager: GridMapManager = null
var fire_timer: float = 0.0
var target_invader: InvaderActor = null
var laser_visible_timer: float = 0.0
var laser_end_point: Vector2 = Vector2.ZERO

# 酸树属性与等级
var substance: String = "silicic"
var rank: int = 1
var branch_line: String = "" # "line_a" 或 "line_b"
var room_id: String = ""
var turret_range: float = 4.0
var fire_interval: float = 0.8
var turret_damage: int = 25
var total_cost_money: int = 100
var total_cost_feedstock: int = 0

# 高氯酸 (Perchloric) 连发硬直状态
var burst_count: int = 0
var hitch_timer: float = 0.0

# 敌人技能影响状态（遏火/雾徙）
var silence_timer: float = 0.0
var fog_slow_timer: float = 0.0
var range_reduction: float = 0.0

func apply_silence(duration: float) -> void:
	silence_timer = maxf(silence_timer, duration)

func apply_fog_slow(duration: float) -> void:
	fog_slow_timer = maxf(fog_slow_timer, duration)

func set_range_reduction(reduction: float) -> void:
	range_reduction = reduction

func init_turret(cell: Vector2i, invader: InvaderActor, grid: GridMapManager) -> void:
	grid_cell = cell
	target_invader = invader
	grid_manager = grid
	position = grid.cell_to_world(cell)

	var r: RoomData = grid.get_room_at_cell(cell)
	if r != null:
		room_id = r.room_id
	
	apply_stats()
	queue_redraw()

func apply_stats() -> void:
	var stats: Dictionary = MatchState.get_turret_stats(substance, rank)
	turret_range = stats.get("range", 4.0)
	fire_interval = stats.get("interval", 0.8)
	turret_damage = stats.get("damage", 25)
	queue_redraw()

func _process(delta: float) -> void:
	if laser_visible_timer > 0.0:
		laser_visible_timer -= delta
		if laser_visible_timer <= 0.0:
			queue_redraw()

	if MatchState.game_result != MatchState.GameResult.NONE:
		return

	if MatchState.is_room_fallen(room_id):
		fire_timer = 0.0
		return

	if silence_timer > 0.0:
		silence_timer = maxf(0.0, silence_timer - delta)
		return # 被沉默，无法攻击

	if fog_slow_timer > 0.0:
		fog_slow_timer = maxf(0.0, fog_slow_timer - delta)

	if target_invader == null or not is_instance_valid(target_invader):
		return

	if not target_invader.is_alive() or not target_invader.visible:
		return

	var eff_range: float = get_effective_range()
	var range_px: float = eff_range * float(GridMapManager.TILE_SIZE)
	var dist: float = global_position.distance_to(target_invader.global_position)
	var eff_interval: float = get_effective_interval()

	if dist <= range_px:
		if not _can_shoot_target(target_invader):
			fire_timer = 0.0
			return

		if substance == "perchloric":
			if hitch_timer > 0.0:
				hitch_timer -= delta
				return
			fire_timer += delta
			if fire_timer >= 0.12:
				fire_timer = 0.0
				_fire_at_invader()
				burst_count += 1
				if burst_count >= 3:
					burst_count = 0
					hitch_timer = 1.0 # 连射后短暂硬直停顿
		else:
			fire_timer += delta
			if fire_timer >= eff_interval:
				fire_timer = 0.0
				_fire_at_invader()
	else:
		fire_timer = 0.0

func _can_shoot_target(invader: InvaderActor) -> bool:
	if invader == null or not is_instance_valid(invader):
		return false
	if not invader.is_alive() or not invader.visible:
		return false
	return true

func _fire_at_invader() -> void:
	if target_invader == null or not is_instance_valid(target_invader):
		return

	var final_dmg: int = turret_damage

	# 换线物质特效触发
	match substance:
		"silicic":
			var slow: Dictionary = MatchState.get_silicic_slow_params(rank)
			target_invader.apply_silicic_slow(float(slow["duration"]), float(slow["factor"]))
		"carbonate":
			target_invader.apply_carbonate_hitch(MatchState.get_carbonate_hitch_duration(rank))
		"hypochlorous":
			# 减缓破门速度
			target_invader.apply_slow_break(2.0)
		"hydrosulfuric":
			# 地面水洼 DoT 灼烧：在敌人当前格生成真实地表酸液水洼实体
			if grid_manager != null:
				grid_manager.spawn_acid_puddle(target_invader.current_cell, 4.0, 45)
			target_invader.apply_puddle(4.0, 45)
		"hydrofluoric":
			# Extra vs hatch armor：对正在拆门的敌人附加破甲增伤，不溶蚀己方舱门
			if target_invader.invader_state == InvaderActor.InvaderState.STOPPED_AT_DOOR:
				final_dmg = int(round(float(final_dmg) * 1.6))
		"sulfuric":
			# 剥离抗性 (Strip resist)
			target_invader.apply_strip_resist(3.0)
		"fluoroantimonic":
			# 魔酸隔门穿透直击增伤
			final_dmg = int(round(float(final_dmg) * 1.25))

	target_invader.take_damage(final_dmg)
	if grid_manager != null:
		grid_manager.spawn_combat_popup(target_invader.current_cell, "-%d" % final_dmg, Color(1.0, 0.25, 0.25))
	laser_end_point = target_invader.global_position - global_position
	laser_visible_timer = 0.1
	queue_redraw()

func _draw() -> void:
	var half: float = float(GridMapManager.TILE_SIZE) * 0.4
	var base_rect := Rect2(-half, -half, half * 2.0, half * 2.0)

	var base_color := Color(0.2, 0.45, 0.55)
	var core_color := Color(0.1, 0.85, 0.95)
	var laser_color := Color(0.4, 0.95, 1.0, 0.9)

	match substance:
		"silicic":
			base_color = Color(0.2, 0.45, 0.55)
			core_color = Color(0.1, 0.85, 0.95)
			laser_color = Color(0.3, 0.9, 1.0, 0.9)
		"carbonate":
			base_color = Color(0.35, 0.55, 0.6)
			core_color = Color(0.65, 0.95, 1.0)
			laser_color = Color(0.7, 1.0, 1.0, 0.9)
		"hypochlorous":
			base_color = Color(0.25, 0.6, 0.35)
			core_color = Color(0.5, 1.0, 0.5)
			laser_color = Color(0.6, 1.0, 0.6, 0.9)
		"hydrosulfuric":
			base_color = Color(0.55, 0.55, 0.2)
			core_color = Color(0.9, 0.9, 0.2)
			laser_color = Color(0.95, 0.95, 0.3, 0.9)
		"hydrofluoric":
			base_color = Color(0.3, 0.4, 0.75)
			core_color = Color(0.6, 0.7, 1.0)
			laser_color = Color(0.7, 0.8, 1.0, 0.9)
		"hydrochloric":
			base_color = Color(0.5, 0.5, 0.55)
			core_color = Color(0.85, 0.9, 0.95)
			laser_color = Color(0.9, 0.95, 1.0, 0.9)
		"sulfuric":
			base_color = Color(0.65, 0.4, 0.15)
			core_color = Color(1.0, 0.65, 0.2)
			laser_color = Color(1.0, 0.7, 0.2, 0.9)
		"perchloric":
			base_color = Color(0.75, 0.2, 0.15)
			core_color = Color(1.0, 0.35, 0.25)
			laser_color = Color(1.0, 0.4, 0.3, 0.9)
		"fluoroantimonic":
			base_color = Color(0.55, 0.1, 0.65)
			core_color = Color(0.95, 0.2, 1.0)
			laser_color = Color(1.0, 0.3, 1.0, 0.95)

	# 绘制基座（几何块）
	draw_rect(base_rect, base_color)
	draw_rect(base_rect, base_color.lightened(0.3), false, 2.0)

	# 绘制炮塔核心
	var core_radius: float = half * 0.55
	draw_circle(Vector2.ZERO, core_radius, core_color)

	# 绘制攻击激光射线
	if laser_visible_timer > 0.0:
		draw_line(Vector2.ZERO, laser_end_point, laser_color, 3.5)

func get_effective_range() -> float:
	var eff: float = maxf(1.0, turret_range - range_reduction)
	if MatchState.has_adjacent_high_tech(grid_cell, "focus_lens"):
		eff += 1.0
	return eff

func get_effective_interval() -> float:
	var eff: float = fire_interval * (1.35 if fog_slow_timer > 0.0 else 1.0)
	if MatchState.has_adjacent_high_tech(grid_cell, "catalytic_column"):
		eff *= 0.75
	if MatchState.has_regulator_stack(room_id):
		eff *= 0.85
	var pa_count: int = MatchState.count_building_type_in_room(room_id, "particle_accelerator")
	if pa_count > 0:
		eff *= 1.0 / (1.0 + 0.5 * float(pa_count)) # 每个粒子加速器使攻速提升 50%
	return eff

