class_name MainGame
extends Node2D

@onready var grid_manager: GridMapManager = $GridMapManager
@onready var actors_container: Node2D = $Actors
@onready var camera: Camera2D = $Camera2D

@onready var hud = $HUD

var player: PlayerActor
var allies: Array[AllyBot] = []
var invader: InvaderActor
var selected_cell: Vector2i = Vector2i(-9999, -9999)
var cell_menu_open: bool = false
var current_menu_items: Array = []

var is_camera_drag_unlocked: bool = false
var is_dragging_camera: bool = false
var is_mouse_down: bool = false
var has_moved_significantly: bool = false
var drag_start_mouse_pos: Vector2 = Vector2.ZERO
var drag_start_camera_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	_spawn_all_actors()
	_setup_camera()
	if hud != null:
		hud.cell_menu_item_chosen.connect(_on_cell_menu_item_chosen)
		hud.cell_menu_closed.connect(_on_cell_menu_closed)

func _setup_camera() -> void:
	if player != null:
		camera.position = player.position
	camera.zoom = Vector2(1.5, 1.5)

func _process(delta: float) -> void:
	if player != null and is_instance_valid(player):
		# 检查是否已到达起步矿内以解锁视角拖动
		if not is_camera_drag_unlocked:
			var p_room_id: String = MatchState.get_player_owned_room_id()
			if p_room_id != "" and grid_manager != null:
				var r: RoomData = grid_manager.get_room_by_id(p_room_id)
				if r != null and (r.is_cell_starter(player.current_cell) or player.current_cell in r.starter_cells):
					is_camera_drag_unlocked = true
					print("视角拖动已解锁：玩家已到达房间起步矿")

		# 玩家走动或未解锁拖动时视角自动平滑跟随玩家；停下且解锁拖动时允许自由拖拽视角
		if not is_camera_drag_unlocked or player.is_moving:
			camera.position = camera.position.lerp(player.position, delta * 12.0)
		else:
			var max_x: float = float(GridMapManager.GRID_WIDTH * GridMapManager.TILE_SIZE)
			var max_y: float = float(GridMapManager.GRID_HEIGHT * GridMapManager.TILE_SIZE)
			camera.position.x = clampf(camera.position.x, 0.0, max_x)
			camera.position.y = clampf(camera.position.y, 0.0, max_y)

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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		if MatchState.game_result != MatchState.GameResult.NONE:
			restart_game()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if cell_menu_open:
			close_cell_menu()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		if is_mouse_down and is_camera_drag_unlocked:
			var delta_vec: Vector2 = event.position - drag_start_mouse_pos
			if delta_vec.length() > 6.0:
				if cell_menu_open:
					close_cell_menu()
				has_moved_significantly = true
				is_dragging_camera = true
				var target_cam_pos: Vector2 = drag_start_camera_pos - delta_vec / camera.zoom.x
				var max_x: float = float(GridMapManager.GRID_WIDTH * GridMapManager.TILE_SIZE)
				var max_y: float = float(GridMapManager.GRID_HEIGHT * GridMapManager.TILE_SIZE)
				target_cam_pos.x = clampf(target_cam_pos.x, 0.0, max_x)
				target_cam_pos.y = clampf(target_cam_pos.y, 0.0, max_y)
				camera.position = target_cam_pos
		elif grid_manager != null:
			var m_pos: Vector2 = get_global_mouse_position()
			var h_cell: Vector2i = grid_manager.world_to_cell(m_pos)
			if h_cell != grid_manager.hovered_cell:
				grid_manager.hovered_cell = h_cell
				grid_manager.queue_redraw()

	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				is_mouse_down = true
				has_moved_significantly = false
				drag_start_mouse_pos = event.position
				drag_start_camera_pos = camera.position
			else:
				is_mouse_down = false
				if event.button_index == MOUSE_BUTTON_LEFT and not has_moved_significantly:
					if cell_menu_open:
						close_cell_menu()
						get_viewport().set_input_as_handled()
						return
					var mouse_pos: Vector2 = get_global_mouse_position()
					var cell: Vector2i = grid_manager.world_to_cell(mouse_pos)
					handle_cell_click(cell)
					get_viewport().set_input_as_handled()
				is_dragging_camera = false
				has_moved_significantly = false

func restart_game() -> void:
	MatchState.reset_match()
	get_tree().reload_current_scene()

func handle_cell_click(cell: Vector2i) -> void:
	selected_cell = cell
	if grid_manager != null:
		grid_manager.selected_cell = cell
		grid_manager.queue_redraw()
	current_menu_items = CellMenu.items_for_cell(cell, grid_manager, "player")
	cell_menu_open = true
	if hud != null:
		hud.show_cell_menu(current_menu_items, _menu_screen_pos())

func close_cell_menu() -> void:
	cell_menu_open = false
	if hud != null:
		hud.hide_cell_menu()

func execute_menu_item(index: int) -> bool:
	if index < 0 or index >= current_menu_items.size():
		close_cell_menu()
		return false
	var item: Dictionary = current_menu_items[index]
	if not item.get("enabled", false):
		return false
	var cell: Vector2i = selected_cell
	var action: String = str(item.get("action", ""))
	var ok: bool = false
	match action:
		"build_turret":
			ok = try_build_silicic_turret(cell)
		"build_item":
			ok = try_build_item(cell, str(item.get("item_id", "")))
		"upgrade_door":
			var door_room: RoomData = grid_manager.get_room_at_cell(cell)
			if door_room != null:
				ok = MatchState.upgrade_door(door_room.room_id, "player")
		"upgrade_starter":
			var starter_room: RoomData = grid_manager.get_room_by_starter_cell(cell)
			if starter_room != null:
				ok = MatchState.upgrade_starter(starter_room.room_id, "player")
		"upgrade_chem_plant":
			var plant: Dictionary = MatchState.get_building_at_cell(cell)
			ok = MatchState.upgrade_chem_plant(str(plant.get("room_id", "")), "player", cell)
		"upgrade_turret":
			if grid_manager.turrets.has(cell):
				ok = MatchState.upgrade_turret(grid_manager.turrets[cell])
		"switch_line":
			if grid_manager.turrets.has(cell):
				ok = MatchState.upgrade_turret(grid_manager.turrets[cell], str(item.get("branch", "")))
		"upgrade_mine":
			var mine_room: RoomData = grid_manager.get_room_at_cell(cell)
			if mine_room != null:
				ok = MatchState.upgrade_mine(mine_room.room_id, "player", cell)
		"demolish":
			var dem_room: RoomData = grid_manager.get_room_at_cell(cell)
			if dem_room != null:
				ok = MatchState.demolish_building(dem_room.room_id, "player", cell, grid_manager)
	close_cell_menu()
	return ok

func _menu_screen_pos() -> Vector2:
	return get_viewport().get_mouse_position()

func _on_cell_menu_item_chosen(index: int) -> void:
	execute_menu_item(index)

func _on_cell_menu_closed() -> void:
	cell_menu_open = false

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

	var turret_cost: int = int(MatchState.BUILD_CATALOG["silicic_turret_1"]["cost_money"])
	if MatchState.money < turret_cost:
		print("建造失败: 钱不够不能造塔 (需要 %d, 当前 %d)" % [turret_cost, MatchState.money])
		return false

	if MatchState.spend_money(turret_cost):
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
