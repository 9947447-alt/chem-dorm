class_name MainGame
extends Node2D

@onready var grid_manager: GridMapManager = $GridMapManager
@onready var actors_container: Node2D = $Actors
@onready var camera: Camera2D = $Camera2D

@onready var hud = $HUD

var player: PlayerActor
var allies: Array[AllyBot] = []
var invader: InvaderActor
var current_build_selection: String = "turret"

func _ready() -> void:
	_setup_camera()
	_spawn_all_actors()
	if hud != null:
		hud.build_selection_changed.connect(_on_build_selection_changed)
		hud.upgrade_door_requested.connect(_try_upgrade_player_door)
		hud.upgrade_turret_requested.connect(_try_upgrade_player_turret)

func _on_build_selection_changed(item_id: String) -> void:
	current_build_selection = item_id

func _setup_camera() -> void:
	# Center camera to display the whole dormitory (approx 38x28 tiles)
	var center_x: float = (GridMapManager.GRID_WIDTH * GridMapManager.TILE_SIZE) * 0.5
	var center_y: float = (GridMapManager.GRID_HEIGHT * GridMapManager.TILE_SIZE) * 0.5
	camera.position = Vector2(center_x, center_y)
	camera.zoom = Vector2(0.8, 0.8)

func _spawn_all_actors() -> void:
	# 1. Spawn Player
	player = PlayerActor.new()
	player.name = "Player"
	actors_container.add_child(player)
	player.init_actor("player", "玩家", Color(0.15, 0.85, 1.0), Vector2i(8, 13), grid_manager)

	# 2. Spawn 5 Ally Bots
	var ally_start_cells: Array[Vector2i] = [
		Vector2i(10, 13),
		Vector2i(12, 13),
		Vector2i(14, 13),
		Vector2i(10, 14),
		Vector2i(12, 14)
	]
	var ally_colors: Array[Color] = [
		Color(0.2, 0.85, 0.35),
		Color(0.3, 0.90, 0.45),
		Color(0.2, 0.80, 0.55),
		Color(0.4, 0.95, 0.30),
		Color(0.15, 0.75, 0.40)
	]

	allies.clear()
	for i in range(5):
		var bot := AllyBot.new()
		bot.name = "Ally_%d" % (i + 1)
		actors_container.add_child(bot)
		bot.init_actor(
			"ally_%d" % (i + 1),
			"盟友%d" % (i + 1),
			ally_colors[i],
			ally_start_cells[i],
			grid_manager
		)
		allies.append(bot)

	# 3. Spawn Invader (inactive/hidden until countdown ends)
	invader = InvaderActor.new()
	invader.name = "Invader"
	actors_container.add_child(invader)
	invader.init_actor(
		"invader",
		"入侵者",
		Color(0.95, 0.22, 0.22),
		grid_manager.invader_spawn_cell,
		grid_manager
	)

	# Start Ally AIs
	for bot in allies:
		bot.start_ai()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos: Vector2 = get_global_mouse_position()
		var cell: Vector2i = grid_manager.world_to_cell(mouse_pos)
		
		# 检查是否点击了炮台 -> 尝试升级炮台
		if grid_manager.turrets.has(cell):
			_upgrade_turret_at(cell)
			return

		# 检查是否点击了舱门 -> 尝试升级门
		var p_room_id := MatchState.get_player_owned_room_id()
		if p_room_id != "":
			var p_room := grid_manager.get_room_by_id(p_room_id)
			if p_room != null and cell == p_room.door_cell:
				_try_upgrade_player_door()
				return

		# 建造选定项目
		if current_build_selection == "turret":
			try_build_silicic_turret(cell)
		else:
			try_build_item(cell, current_build_selection)

func try_build_silicic_turret(cell: Vector2i) -> bool:
	var player_room_id: String = MatchState.get_player_owned_room_id()
	if player_room_id == "":
		print("建造失败: 未占房不能造塔")
		return false

	var room: RoomData = grid_manager.get_room_by_id(player_room_id)
	if room == null:
		return false

	if not room.is_cell_interior(cell):
		print("建造失败: 只能在自己占领的房间内部建造")
		return false

	if room.is_cell_starter(cell) or cell == room.door_cell:
		print("建造失败: 不能在起步矿或门上建造")
		return false

	if grid_manager.has_building_at(cell):
		print("建造失败: 该格已有建筑")
		return false

	if MatchState.money < MatchState.TURRET_COST:
		print("建造失败: 钱不够不能造塔 (需要 %d, 当前 %d)" % [MatchState.TURRET_COST, MatchState.money])
		return false

	if MatchState.spend_money(MatchState.TURRET_COST):
		var turret := SilicicTurret.new()
		turret.name = "SilicicTurret_%d_%d" % [cell.x, cell.y]
		turret.room_id = player_room_id
		grid_manager.add_turret(cell, turret)
		turret.init_turret(cell, invader, grid_manager)
		print("建造成功: 在 %s 建造硅酸炮台 I" % [cell])
		return true

	return false

func try_build_item(cell: Vector2i, item_id: String) -> bool:
	var player_room_id: String = MatchState.get_player_owned_room_id()
	if player_room_id == "":
		print("建造失败: 未占房不能建造")
		return false

	var room: RoomData = grid_manager.get_room_by_id(player_room_id)
	if room == null or not room.is_cell_interior(cell):
		print("建造失败: 只能在自己占领的房间内部建造")
		return false

	if room.is_cell_starter(cell) or cell == room.door_cell:
		print("建造失败: 不能在起步矿或门上建造")
		return false

	if grid_manager.has_building_at(cell):
		print("建造失败: 该格已有建筑")
		return false

	return MatchState.buy_and_place_building(player_room_id, item_id, "player", cell)

func _try_upgrade_player_door() -> void:
	var p_room_id: String = MatchState.get_player_owned_room_id()
	if p_room_id != "":
		MatchState.upgrade_door(p_room_id, "player")

func _upgrade_turret_at(cell: Vector2i) -> void:
	if not grid_manager.turrets.has(cell):
		return
	var t: SilicicTurret = grid_manager.turrets[cell]
	var can_up := MatchState.can_upgrade_turret(t)
	if can_up.get("success", false):
		MatchState.upgrade_turret(t)
		return
	if t.substance == "carbonate" and t.rank == 5 and t.branch_line == "":
		var line_a_check := MatchState.can_upgrade_turret(t, "line_a")
		if line_a_check.get("success", false):
			MatchState.upgrade_turret(t, "line_a")
		else:
			print("换线失败: ", line_a_check.get("reason", ""))

func _try_upgrade_player_turret() -> void:
	var p_room_id: String = MatchState.get_player_owned_room_id()
	if p_room_id == "":
		return
	for t in grid_manager.turrets.values():
		if t is SilicicTurret and t.room_id == p_room_id:
			_upgrade_turret_at(t.grid_cell)
			break

