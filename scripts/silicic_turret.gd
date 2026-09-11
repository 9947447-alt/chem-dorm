class_name SilicicTurret
extends Node2D

var grid_cell: Vector2i = Vector2i.ZERO
var fire_timer: float = 0.0
var target_invader: InvaderActor = null
var laser_visible_timer: float = 0.0
var laser_end_point: Vector2 = Vector2.ZERO

func init_turret(cell: Vector2i, invader: InvaderActor, grid: GridMapManager) -> void:
	grid_cell = cell
	target_invader = invader
	position = grid.cell_to_world(cell)
	queue_redraw()

func _process(delta: float) -> void:
	if laser_visible_timer > 0.0:
		laser_visible_timer -= delta
		if laser_visible_timer <= 0.0:
			queue_redraw()

	if MatchState.game_result != MatchState.GameResult.NONE:
		return

	if target_invader == null or not is_instance_valid(target_invader):
		return

	if not target_invader.is_alive() or not target_invader.visible:
		return

	var range_px: float = MatchState.TURRET_RANGE * float(GridMapManager.TILE_SIZE)
	var dist: float = global_position.distance_to(target_invader.global_position)

	if dist <= range_px:
		fire_timer += delta
		if fire_timer >= MatchState.TURRET_FIRE_INTERVAL:
			fire_timer = 0.0
			_fire_at_invader()
	else:
		fire_timer = 0.0

func _fire_at_invader() -> void:
	if target_invader == null or not is_instance_valid(target_invader):
		return
	target_invader.take_damage(MatchState.TURRET_DAMAGE)
	laser_end_point = target_invader.global_position - global_position
	laser_visible_timer = 0.1
	queue_redraw()

func _draw() -> void:
	var half: float = float(GridMapManager.TILE_SIZE) * 0.4
	# 绘制基座（几何块）
	var base_rect := Rect2(-half, -half, half * 2.0, half * 2.0)
	draw_rect(base_rect, Color(0.2, 0.45, 0.55))
	draw_rect(base_rect, Color(0.3, 0.75, 0.85), false, 2.0)

	# 绘制炮塔核心
	var core_radius: float = half * 0.5
	draw_circle(Vector2.ZERO, core_radius, Color(0.1, 0.85, 0.95))

	# 绘制攻击激光射线
	if laser_visible_timer > 0.0:
		draw_line(Vector2.ZERO, laser_end_point, Color(0.4, 0.95, 1.0, 0.9), 3.0)
