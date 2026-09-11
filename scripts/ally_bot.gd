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
var build_think_timer: float = 0.0

func _ready() -> void:
	super._ready()
	move_speed = 4.5

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
	elif bot_state == BotState.CLAIMED:
		build_think_timer += delta
		if build_think_timer >= 1.0:
			build_think_timer = 0.0
			_think_and_build()

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

func _after_ejected_from_room(p_room_id: String) -> void:
	if bot_state == BotState.CLAIMED:
		return
	if target_room_id == p_room_id:
		target_room_id = ""
		room_intent.erase(p_room_id)
	if bot_state != BotState.MOVING_TO_ROOM:
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

func _think_and_build() -> void:
	if target_room_id == "" or grid_manager == null:
		return
	if MatchState.get_room_owner(target_room_id) != actor_id:
		return
	if MatchState.get_starter_hp(target_room_id) <= 0:
		return
	
	var room: RoomData = grid_manager.get_room_by_id(target_room_id)
	if room == null:
		return

	# 收集当前可用空白地块
	var empty_cells: Array[Vector2i] = []
	for c in room.get_interior_cells():
		if room.starter_cells.has(c) or c == room.door_cell:
			continue
		if grid_manager.has_building_at(c):
			continue
		empty_cells.append(c)

	# 决策 1: 确保房间内至少有一座炮台进行基础火力防守
	var my_turrets: Array[SilicicTurret] = []
	for t in grid_manager.turrets.values():
		if t is SilicicTurret and t.room_id == target_room_id:
			my_turrets.append(t)

	if my_turrets.is_empty() and not empty_cells.is_empty():
		if MatchState.get_actor_money(actor_id) >= MatchState.TURRET_COST:
			empty_cells.sort_custom(func(a: Vector2i, b: Vector2i): return a.distance_squared_to(room.door_cell) < b.distance_squared_to(room.door_cell))
			var t_cell: Vector2i = empty_cells[0]
			var invader_target: ActorBase = null
			var actors_node = get_parent()
			if actors_node != null:
				invader_target = actors_node.get_node_or_null("Invader")
			if grid_manager.build_turret_for_actor(target_room_id, t_cell, actor_id, invader_target):
				return

	# 决策 2: 确保房间内至少有一座基础矿山提供持续资金
	var room_mines: Array = []
	for b in MatchState.get_room_buildings(target_room_id):
		if b.get("category", "") == "mine":
			room_mines.append(b)
	if room_mines.is_empty() and not empty_cells.is_empty():
		if MatchState.get_actor_money(actor_id) >= MatchState.BUILD_CATALOG["iron_mine"]["cost_money"]:
			var mine_cell: Vector2i = empty_cells.pop_front()
			if MatchState.buy_and_place_building(target_room_id, "iron_mine", actor_id, mine_cell):
				return

	# 决策 3: 升级舱门（若未破损且可升门，优先保证防线厚度）
	if not MatchState.is_door_broken(target_room_id):
		var door_check: Dictionary = MatchState.can_upgrade_door(target_room_id, actor_id)
		if door_check.get("success", false):
			MatchState.upgrade_door(target_room_id, actor_id)
			return

	# 决策 3: 升级现有炮台
	for t in my_turrets:
		var up_check := MatchState.can_upgrade_turret(t)
		if up_check.get("success", false):
			MatchState.upgrade_turret(t)
			return
		if t.substance == "carbonate" and t.rank == 5 and t.branch_line == "":
			if MatchState.has_chem_plant(target_room_id):
				var pick_branch: String = "line_a" if int(actor_id.replace("ally_", "")) % 2 == 1 else "line_b"
				var branch_check := MatchState.can_upgrade_turret(t, pick_branch)
				if branch_check.get("success", false):
					MatchState.upgrade_turret(t, pick_branch)
					return

	# 决策 4: 建造化工厂 (如果有炮台且尚未有化工厂)
	if not MatchState.has_chem_plant(target_room_id) and not my_turrets.is_empty() and not empty_cells.is_empty():
		if MatchState.get_actor_money(actor_id) >= 200:
			var plant_cell: Vector2i = empty_cells.pop_back()
			MatchState.buy_and_place_building(target_room_id, "chem_plant", actor_id, plant_cell)
			return

	# 决策 5: 建造高科技建筑 (稳压堆、机械臂、催化柱、聚焦镜)
	if not empty_cells.is_empty():
		var money: int = MatchState.get_actor_money(actor_id)
		# 稳压堆限一房一座
		if not MatchState.has_regulator_stack(target_room_id) and money >= 2000:
			var reg_cell: Vector2i = empty_cells.pop_back()
			if MatchState.buy_and_place_building(target_room_id, "regulator_stack", actor_id, reg_cell):
				return
		
		# 相邻催化柱或聚焦镜
		for t in my_turrets:
			var neighbors := [
				t.grid_cell + Vector2i(1, 0),
				t.grid_cell + Vector2i(-1, 0),
				t.grid_cell + Vector2i(0, 1),
				t.grid_cell + Vector2i(0, -1)
			]
			for n in neighbors:
				if empty_cells.has(n):
					if money >= 800 and not MatchState.has_adjacent_high_tech(t.grid_cell, "catalytic_column"):
						empty_cells.erase(n)
						if MatchState.buy_and_place_building(target_room_id, "catalytic_column", actor_id, n):
							return
					elif money >= 600 and not MatchState.has_adjacent_high_tech(t.grid_cell, "focus_lens"):
						empty_cells.erase(n)
						if MatchState.buy_and_place_building(target_room_id, "focus_lens", actor_id, n):
							return

	# 决策 6: 建造矿山拓展经济
	if not empty_cells.is_empty():
		var money: int = MatchState.get_actor_money(actor_id)
		var mine_types: Array[String] = [
			"uranium_mine", "gold_mine", "antimony_mine",
			"sulfur_mine", "molybdenum_mine", "tungsten_mine", "iron_mine"
		]
		for m_id in mine_types:
			var cost: int = MatchState.BUILD_CATALOG[m_id]["cost_money"]
			if money >= cost:
				var check := MatchState.can_build(target_room_id, m_id, actor_id, empty_cells[0])
				if check.get("success", false):
					var mine_cell: Vector2i = empty_cells.pop_front()
					if MatchState.buy_and_place_building(target_room_id, m_id, actor_id, mine_cell):
						return
