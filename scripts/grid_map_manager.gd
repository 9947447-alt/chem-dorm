class_name GridMapManager
extends Node2D

const TILE_SIZE: int = 32
const GRID_WIDTH: int = 38
const GRID_HEIGHT: int = 28

enum CellType {
	VOID,
	WALL,
	CORRIDOR,
	ROOM_FLOOR,
	DOOR,
	STARTER,
	ENTRANCE
}

var cells: Dictionary = {} # Vector2i -> CellType
var rooms: Array[RoomData] = []
var room_by_id: Dictionary = {} # String -> RoomData
var room_by_door: Dictionary = {} # Vector2i -> RoomData
var invader_spawn_cell: Vector2i = Vector2i(1, 13)
var heal_pad_cells: Array[Vector2i] = [Vector2i(2, 14), Vector2i(35, 14)] # 走廊偏僻回血点
var corridor_cells: Array[Vector2i] = []

var astar_full: AStarGrid2D
var astar_corridor: AStarGrid2D
var turrets: Dictionary = {} # Vector2i -> SilicicTurret

func _ready() -> void:
	_init_rooms()
	_build_grid()
	_init_astar()
	if not MatchState.building_added.is_connected(_on_building_added):
		MatchState.building_added.connect(_on_building_added)
	queue_redraw()

func _on_building_added(_room_id: String, _building_data: Dictionary) -> void:
	queue_redraw()

func _init_rooms() -> void:
	rooms.clear()
	room_by_id.clear()
	room_by_door.clear()

	# Room 1: 8x8
	var r1 := RoomData.new(
		"room_101",
		"宿舍 101 (8x8)",
		Vector2i(8, 8),
		Rect2i(3, 4, 8, 8),
		Vector2i(6, 12),
		Vector2i(6, 13),
		[Vector2i(3, 4), Vector2i(4, 4)]
	)

	# Room 2: 10x8
	var r2 := RoomData.new(
		"room_102",
		"宿舍 102 (10x8)",
		Vector2i(10, 8),
		Rect2i(14, 4, 10, 8),
		Vector2i(18, 12),
		Vector2i(18, 13),
		[Vector2i(14, 4), Vector2i(15, 4)]
	)

	# Room 3: 6x10
	var r3 := RoomData.new(
		"room_103",
		"宿舍 103 (6x10)",
		Vector2i(6, 10),
		Rect2i(27, 2, 6, 10),
		Vector2i(29, 12),
		Vector2i(29, 13),
		[Vector2i(27, 2), Vector2i(28, 2)]
	)

	# Room 4: 8x8
	var r4 := RoomData.new(
		"room_104",
		"宿舍 104 (8x8)",
		Vector2i(8, 8),
		Rect2i(3, 16, 8, 8),
		Vector2i(6, 15),
		Vector2i(6, 14),
		[Vector2i(3, 23), Vector2i(4, 23)]
	)

	# Room 5: 10x8
	var r5 := RoomData.new(
		"room_105",
		"宿舍 105 (10x8)",
		Vector2i(10, 8),
		Rect2i(14, 16, 10, 8),
		Vector2i(18, 15),
		Vector2i(18, 14),
		[Vector2i(14, 23), Vector2i(15, 23)]
	)

	# Room 6: 6x10
	var r6 := RoomData.new(
		"room_106",
		"宿舍 106 (6x10)",
		Vector2i(6, 10),
		Rect2i(27, 16, 6, 10),
		Vector2i(29, 15),
		Vector2i(29, 14),
		[Vector2i(27, 25), Vector2i(28, 25)]
	)

	var room_list: Array[RoomData] = [r1, r2, r3, r4, r5, r6]
	for r in room_list:
		rooms.append(r)
		room_by_id[r.room_id] = r
		room_by_door[r.door_cell] = r
		MatchState.register_room(r.room_id, r.display_name)

func _build_grid() -> void:
	cells.clear()
	corridor_cells.clear()

	# 1. Initialize all cells within bounding area as VOID
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			cells[Vector2i(x, y)] = CellType.VOID

	# 2. Build Corridor (Y = 13..14, X = 1..35)
	for x in range(1, 36):
		for y in [13, 14]:
			var cell := Vector2i(x, y)
			cells[cell] = CellType.CORRIDOR
			corridor_cells.append(cell)

	# Entrance at X = 1, Y = 13
	cells[invader_spawn_cell] = CellType.ENTRANCE

	# 3. Build Rooms (floors, starters, walls, doors)
	for r in rooms:
		# Interior floor
		for x in range(r.interior_rect.position.x, r.interior_rect.end.x):
			for y in range(r.interior_rect.position.y, r.interior_rect.end.y):
				var c := Vector2i(x, y)
				cells[c] = CellType.ROOM_FLOOR

		# Starters
		for s in r.starter_cells:
			cells[s] = CellType.STARTER

		# Boundary Walls
		var min_x: int = r.interior_rect.position.x - 1
		var max_x: int = r.interior_rect.end.x
		var min_y: int = r.interior_rect.position.y - 1
		var max_y: int = r.interior_rect.end.y

		for x in range(min_x, max_x + 1):
			cells[Vector2i(x, min_y)] = CellType.WALL
			cells[Vector2i(x, max_y)] = CellType.WALL

		for y in range(min_y, max_y + 1):
			cells[Vector2i(min_x, y)] = CellType.WALL
			cells[Vector2i(max_x, y)] = CellType.WALL

		# Door (replaces wall at door_cell)
		cells[r.door_cell] = CellType.DOOR

	# 4. Corridor Boundary Walls
	for x in range(0, 37):
		# North wall of corridor
		var n_cell := Vector2i(x, 12)
		if cells.get(n_cell, CellType.VOID) == CellType.VOID:
			cells[n_cell] = CellType.WALL

		# South wall of corridor
		var s_cell := Vector2i(x, 15)
		if cells.get(s_cell, CellType.VOID) == CellType.VOID:
			cells[s_cell] = CellType.WALL

	# Corridor West & East walls
	cells[Vector2i(0, 13)] = CellType.WALL
	cells[Vector2i(0, 14)] = CellType.WALL
	cells[Vector2i(36, 13)] = CellType.WALL
	cells[Vector2i(36, 14)] = CellType.WALL

func _init_astar() -> void:
	# General AStar
	astar_full = AStarGrid2D.new()
	astar_full.region = Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT)
	astar_full.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar_full.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_full.update()

	# Corridor only AStar (for Invader)
	astar_corridor = AStarGrid2D.new()
	astar_corridor.region = Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT)
	astar_corridor.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar_corridor.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_corridor.update()

	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var c := Vector2i(x, y)
			var type: CellType = cells.get(c, CellType.VOID)
			if type == CellType.WALL or type == CellType.VOID:
				astar_full.set_point_solid(c, true)
				astar_corridor.set_point_solid(c, true)
			elif type == CellType.ROOM_FLOOR or type == CellType.STARTER or type == CellType.DOOR:
				astar_full.set_point_solid(c, false)
				astar_corridor.set_point_solid(c, true) # Corridor astar blocks rooms
			else:
				# CORRIDOR / ENTRANCE
				astar_full.set_point_solid(c, false)
				astar_corridor.set_point_solid(c, false)

func get_room_by_id(p_id: String) -> RoomData:
	return room_by_id.get(p_id, null)

func get_room_at_cell(cell: Vector2i) -> RoomData:
	for r in rooms:
		if r.is_cell_interior(cell) or cell == r.door_cell:
			return r
	return null

func get_room_by_starter_cell(cell: Vector2i) -> RoomData:
	for r in rooms:
		if r.is_cell_starter(cell):
			return r
	return null

func get_all_rooms() -> Array[RoomData]:
	return rooms

func is_cell_walkable_for(cell: Vector2i, actor_id: String) -> bool:
	if not cells.has(cell):
		return false
	var type: CellType = cells[cell]
	if type == CellType.WALL or type == CellType.VOID:
		return false
	
	# If cell is door or inside room, check lock
	var room := get_room_at_cell(cell)
	if room != null:
		if not MatchState.can_actor_enter_room(room.room_id, actor_id):
			return false
	return true

func get_path_for_actor(from_cell: Vector2i, to_cell: Vector2i, actor_id: String) -> Array[Vector2i]:
	# Set door solidities based on actor
	for r in rooms:
		var can_enter: bool = MatchState.can_actor_enter_room(r.room_id, actor_id)
		astar_full.set_point_solid(r.door_cell, not can_enter)

	# Ensure actor is not trapped if starting on a newly locked door
	astar_full.set_point_solid(from_cell, false)

	var raw_path: Array[Vector2i] = astar_full.get_id_path(from_cell, to_cell)
	return raw_path

func get_invader_path_to_cell(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	# Invader moves purely along corridor
	var raw_path: Array[Vector2i] = astar_corridor.get_id_path(from_cell, to_cell)
	return raw_path

func get_invader_path_to_starter(from_cell: Vector2i, room: RoomData) -> Array[Vector2i]:
	if not MatchState.is_door_broken(room.room_id):
		return []
	astar_full.set_point_solid(room.door_cell, false)
	astar_full.set_point_solid(from_cell, false)
	var path: Array[Vector2i] = astar_full.get_id_path(from_cell, room.starter_cells[0])
	return path

func has_building_at(cell: Vector2i) -> bool:
	return turrets.has(cell) or MatchState.cell_to_building.has(cell)

func add_turret(cell: Vector2i, turret: SilicicTurret) -> void:
	turrets[cell] = turret
	add_child(turret)
	queue_redraw()

func build_turret_for_actor(room_id: String, cell: Vector2i, actor_id: String, target_invader: ActorBase = null) -> bool:
	if MatchState.get_room_owner(room_id) != actor_id:
		return false
	var room: RoomData = get_room_by_id(room_id)
	if room == null or not room.is_cell_interior(cell):
		return false
	if room.is_cell_starter(cell) or cell == room.door_cell:
		return false
	if has_building_at(cell):
		return false
	if not MatchState.spend_actor_money(actor_id, MatchState.TURRET_COST):
		return false
	
	var turret := SilicicTurret.new()
	turret.name = "Turret_%d_%d" % [cell.x, cell.y]
	turret.room_id = room_id
	add_turret(cell, turret)
	turret.init_turret(cell, target_invader, self)
	return true

func get_closest_door_exterior_to(from_cell: Vector2i) -> Vector2i:
	var closest_cell: Vector2i = Vector2i.ZERO
	var min_dist: int = 999999
	for r in rooms:
		var path := astar_corridor.get_id_path(from_cell, r.door_exterior_cell)
		if path.size() > 0 and path.size() < min_dist:
			min_dist = path.size()
			closest_cell = r.door_exterior_cell
	return closest_cell

func get_closest_heal_pad_to(from_cell: Vector2i) -> Vector2i:
	var closest_cell: Vector2i = Vector2i.ZERO
	var min_dist: int = 999999
	for pad in heal_pad_cells:
		var path := astar_corridor.get_id_path(from_cell, pad)
		if path.size() > 0 and path.size() < min_dist:
			min_dist = path.size()
			closest_cell = pad
	return closest_cell

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE * 0.5, cell.y * TILE_SIZE + TILE_SIZE * 0.5)

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / TILE_SIZE)), int(floor(world_pos.y / TILE_SIZE)))

func _draw() -> void:
	# Visual rendering of all tiles
	for cell in cells.keys():
		var type: CellType = cells[cell]
		var rect := Rect2(cell.x * TILE_SIZE, cell.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)

		match type:
			CellType.VOID:
				draw_rect(rect, Color(0.08, 0.09, 0.11))
			CellType.WALL:
				draw_rect(rect, Color(0.16, 0.18, 0.22))
				draw_rect(rect, Color(0.24, 0.27, 0.33), false, 1.0)
			CellType.CORRIDOR:
				draw_rect(rect, Color(0.28, 0.31, 0.36))
				draw_rect(rect, Color(0.33, 0.36, 0.42), false, 1.0)
			CellType.ENTRANCE:
				draw_rect(rect, Color(0.35, 0.25, 0.25))
				draw_rect(rect, Color(0.6, 0.3, 0.3), false, 1.0)
			CellType.ROOM_FLOOR:
				draw_rect(rect, Color(0.20, 0.22, 0.27))
				draw_rect(rect, Color(0.25, 0.28, 0.34), false, 1.0)
			CellType.STARTER:
				var room := get_room_by_starter_cell(cell)
				var s_hp: int = MatchState.get_starter_hp(room.room_id) if room != null else MatchState.STARTER_MAX_HP
				if s_hp <= 0:
					draw_rect(rect, Color(0.2, 0.2, 0.22))
					draw_rect(rect, Color(0.6, 0.2, 0.2), false, 1.5)
				else:
					draw_rect(rect, Color(0.22, 0.42, 0.65))
					draw_rect(rect, Color(0.40, 0.65, 0.95), false, 1.5)
			CellType.DOOR:
				var room := get_room_at_cell(cell)
				var is_broken: bool = room != null and MatchState.is_door_broken(room.room_id)
				if is_broken:
					draw_rect(rect, Color(0.12, 0.12, 0.14))
					draw_rect(rect, Color(0.95, 0.2, 0.2), false, 1.5)
				else:
					var is_locked: bool = room != null and MatchState.is_room_locked(room.room_id)
					if is_locked:
						draw_rect(rect, Color(0.85, 0.28, 0.22))
						draw_rect(rect, Color(1.0, 0.45, 0.35), false, 2.0)
					else:
						draw_rect(rect, Color(0.18, 0.72, 0.65))
						draw_rect(rect, Color(0.35, 0.95, 0.85), false, 2.0)

	# Draw Room labels and metadata
	var font := ThemeDB.fallback_font
	var font_size := 12
	for r in rooms:
		var center_pos := Vector2(
			(r.interior_rect.position.x + r.interior_rect.size.x * 0.5) * TILE_SIZE,
			(r.interior_rect.position.y + r.interior_rect.size.y * 0.5) * TILE_SIZE
		)
		var owner_name: String = MatchState.get_room_owner(r.room_id)
		var status_str: String = "[空闲]"
		if MatchState.is_room_locked(r.room_id):
			status_str = "[已锁: " + owner_name + "]"
		var label_text := "%s\n%s" % [r.display_name, status_str]
		draw_string(font, center_pos - Vector2(50, 0), label_text, HORIZONTAL_ALIGNMENT_CENTER, 100, font_size, Color(0.85, 0.88, 0.92))

	# Draw Entrance Marker
	var entrance_pos := cell_to_world(invader_spawn_cell)
	draw_string(font, entrance_pos + Vector2(-12, -20), "走廊入口", HORIZONTAL_ALIGNMENT_LEFT, 80, font_size, Color(1.0, 0.6, 0.6))

	# Draw Heal Pads Marker
	for pad in heal_pad_cells:
		var pad_pos := cell_to_world(pad)
		var pad_rect := Rect2(pad.x * TILE_SIZE + 4, pad.y * TILE_SIZE + 4, TILE_SIZE - 8, TILE_SIZE - 8)
		draw_rect(pad_rect, Color(0.2, 0.6, 0.35, 0.8))
		draw_rect(pad_rect, Color(0.4, 0.9, 0.5), false, 1.5)
		draw_string(font, pad_pos + Vector2(-16, -18), "回血点", HORIZONTAL_ALIGNMENT_CENTER, 32, 10, Color(0.5, 1.0, 0.6))

	# Draw Placed Buildings (Mines, Chem Plants)
	for b_cell in MatchState.cell_to_building.keys():
		var b_info: Dictionary = MatchState.cell_to_building[b_cell]
		var b_rect := Rect2(b_cell.x * TILE_SIZE + 2, b_cell.y * TILE_SIZE + 2, TILE_SIZE - 4, TILE_SIZE - 4)
		var b_id: String = b_info.get("id", "")
		var b_color: Color = Color(0.4, 0.4, 0.5)
		var b_sym: String = "M"
		match b_id:
			"iron_mine":
				b_color = Color(0.45, 0.5, 0.55)
				b_sym = "Fe"
			"tungsten_mine":
				b_color = Color(0.35, 0.45, 0.6)
				b_sym = "W"
			"molybdenum_mine":
				b_color = Color(0.3, 0.55, 0.65)
				b_sym = "Mo"
			"sulfur_mine":
				b_color = Color(0.75, 0.75, 0.2)
				b_sym = "S"
			"antimony_mine":
				b_color = Color(0.55, 0.65, 0.7)
				b_sym = "Sb"
			"gold_mine":
				b_color = Color(0.9, 0.75, 0.1)
				b_sym = "Au"
			"uranium_mine":
				b_color = Color(0.2, 0.95, 0.2)
				b_sym = "U"
			"chem_plant":
				b_color = Color(0.7, 0.25, 0.85)
				b_sym = "化"
			"catalytic_column":
				b_color = Color(0.85, 0.2, 0.6)
				b_sym = "催"
			"focus_lens":
				b_color = Color(0.1, 0.8, 0.9)
				b_sym = "镜"
			"robotic_arm":
				b_color = Color(0.95, 0.55, 0.1)
				b_sym = "臂"
			"regulator_stack":
				b_color = Color(0.2, 0.4, 0.95)
				b_sym = "堆"
		draw_rect(b_rect, b_color)
		draw_rect(b_rect, b_color.lightened(0.3), false, 1.5)
		draw_string(font, Vector2(b_cell.x * TILE_SIZE + 4, b_cell.y * TILE_SIZE + TILE_SIZE - 8), b_sym, HORIZONTAL_ALIGNMENT_CENTER, TILE_SIZE - 8, 11, Color.WHITE)

