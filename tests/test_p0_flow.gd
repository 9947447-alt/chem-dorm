extends Node

func _ready() -> void:
	print("========================================")
	print("Starting chem-dorm P0 Automated Test Suite")
	print("========================================")

	var success: bool = true

	success = success and _test_room_specifications()
	success = success and _test_match_state_rules()
	success = success and _test_grid_walkability_and_navigation()
	success = success and _test_allies_claim_flow()
	success = success and _test_invader_corridor_movement()
	success = success and _test_phase_1_economy()
	success = success and _test_eject_non_owner_when_room_claimed()
	success = success and _test_income_generation()
	success = success and _test_silicic_i_placement_rules()
	success = success and _test_invader_attack_door_and_enter_room()
	success = success and _test_victory_and_defeat_conditions()

	if success:
		print("========================================")
		print("ALL chem-dorm ACCEPTANCE TESTS PASSED!")
		print("========================================")
		get_tree().quit(0)
	else:
		printerr("========================================")
		printerr("P0 TESTS FAILED!")
		printerr("========================================")
		get_tree().quit(1)

func _test_room_specifications() -> bool:
	print("\n[TEST 1] Testing Room Specifications (8x8, 10x8, 6x10)...")
	var grid := GridMapManager.new()
	add_child(grid)
	grid._ready()

	var all_rooms := grid.get_all_rooms()
	if all_rooms.size() != 6:
		printerr("FAILED: Expected 6 rooms, got ", all_rooms.size())
		grid.queue_free()
		return false

	var valid_specs: Array[Vector2i] = [Vector2i(8, 8), Vector2i(10, 8), Vector2i(6, 10)]
	for r in all_rooms:
		if not (r.spec_size in valid_specs):
			printerr("FAILED: Room %s has invalid spec %s" % [r.room_id, r.spec_size])
			grid.queue_free()
			return false

		# Check starter occupies exactly 2 cells
		if r.starter_cells.size() != 2:
			printerr("FAILED: Room %s starter cells count %d != 2" % [r.room_id, r.starter_cells.size()])
			grid.queue_free()
			return false

		# Check door is 1 cell
		if r.door_cell == Vector2i.ZERO:
			printerr("FAILED: Room %s has invalid door cell" % [r.room_id])
			grid.queue_free()
			return false

		# Check interior size matches spec
		if r.interior_rect.size != r.spec_size:
			printerr("FAILED: Room %s interior size %s != spec %s" % [r.room_id, r.interior_rect.size, r.spec_size])
			grid.queue_free()
			return false

		# Check door connects to corridor
		var exterior: Vector2i = r.door_exterior_cell
		if grid.cells.get(exterior, GridMapManager.CellType.VOID) != GridMapManager.CellType.CORRIDOR:
			printerr("FAILED: Door exterior for %s is not corridor: %s" % [r.room_id, exterior])
			grid.queue_free()
			return false

	print("PASS: All 6 rooms match specs (8x8, 10x8, 6x10), 2-cell starters, 1-cell doors connecting to corridor.")
	grid.queue_free()
	return true

func _test_match_state_rules() -> bool:
	print("\n[TEST 2] Testing MatchState centralized rules & claiming...")
	MatchState.reset_match()

	var room_id := "room_101"
	MatchState.register_room(room_id)

	# Initially unlocked
	if MatchState.is_room_locked(room_id):
		printerr("FAILED: Room should be unlocked initially")
		return false
	if not MatchState.can_actor_enter_room(room_id, "player"):
		printerr("FAILED: Player should be able to enter unlocked room")
		return false

	# Player claims room
	var claimed: bool = MatchState.claim_room(room_id, "player")
	if not claimed:
		printerr("FAILED: Player failed to claim empty room")
		return false
	if not MatchState.is_room_locked(room_id):
		printerr("FAILED: Room should be locked after claim")
		return false
	if MatchState.get_room_owner(room_id) != "player":
		printerr("FAILED: Room owner should be player")
		return false

	# Second actor attempts to claim already claimed room
	var steal: bool = MatchState.claim_room(room_id, "ally_1")
	if steal:
		printerr("FAILED: Ally_1 should not be able to steal locked room")
		return false

	# Walkability: Owner can enter, other actor cannot
	if not MatchState.can_actor_enter_room(room_id, "player"):
		printerr("FAILED: Owner player should be allowed to enter")
		return false
	if MatchState.can_actor_enter_room(room_id, "ally_1"):
		printerr("FAILED: Non-owner ally_1 should not be allowed into locked room")
		return false

	print("PASS: MatchState enforces atomic claim, room locking, and entrance permissions.")
	return true

func _test_grid_walkability_and_navigation() -> bool:
	print("\n[TEST 3] Testing Grid Walkability & AStar Navigation...")
	var grid := GridMapManager.new()
	add_child(grid)
	grid._ready()

	MatchState.reset_match()
	for r in grid.get_all_rooms():
		MatchState.register_room(r.room_id)

	# Corridor entrance to room 101 path
	var path_player := grid.get_path_for_actor(Vector2i(8, 13), Vector2i(3, 4), "player")
	if path_player.is_empty():
		printerr("FAILED: Player could not pathfind to room 101 starter")
		grid.queue_free()
		return false

	# Lock room 101 with player
	MatchState.claim_room("room_101", "player")

	# For ally_1, door to room 101 should now be solid / unreachable
	var path_ally := grid.get_path_for_actor(Vector2i(8, 13), Vector2i(3, 4), "ally_1")
	if not path_ally.is_empty():
		printerr("FAILED: Ally_1 should not have a valid path into player's locked room")
		grid.queue_free()
		return false

	print("PASS: Grid walkability updates dynamically when rooms are locked.")
	grid.queue_free()
	return true

func _test_allies_claim_flow() -> bool:
	print("\n[TEST 4] Testing 5 Allies Claiming 5 Separate Rooms...")
	var grid := GridMapManager.new()
	add_child(grid)
	grid._ready()

	MatchState.reset_match()
	for r in grid.get_all_rooms():
		MatchState.register_room(r.room_id)

	# Player claims room_101
	MatchState.claim_room("room_101", "player")

	# Simulate 5 allies claiming the remaining 5 rooms
	var remaining_rooms: Array[RoomData] = []
	for r in grid.get_all_rooms():
		if not MatchState.is_room_locked(r.room_id):
			remaining_rooms.append(r)

	if remaining_rooms.size() != 5:
		printerr("FAILED: Expected 5 remaining rooms, got ", remaining_rooms.size())
		grid.queue_free()
		return false

	var ally_ids: Array[String] = ["ally_1", "ally_2", "ally_3", "ally_4", "ally_5"]
	for i in range(5):
		var target_room: RoomData = remaining_rooms[i]
		var bot := AllyBot.new()
		add_child(bot)
		bot.init_actor(ally_ids[i], "Ally " + str(i + 1), Color.GREEN, Vector2i(10 + i * 2, 13), grid)
		
		# Step on starter
		var starter_cell: Vector2i = target_room.starter_cells[0]
		bot.current_cell = starter_cell
		bot._on_step_completed()
		bot.queue_free()

	# Verify each of the 6 rooms is locked with a unique owner
	var owners: Array[String] = []
	for r in grid.get_all_rooms():
		if not MatchState.is_room_locked(r.room_id):
			printerr("FAILED: Room %s was not locked" % [r.room_id])
			grid.queue_free()
			return false
		var owner: String = MatchState.get_room_owner(r.room_id)
		if owner in owners:
			printerr("FAILED: Duplicate room owner %s" % [owner])
			grid.queue_free()
			return false
		owners.append(owner)

	if owners.size() != 6:
		printerr("FAILED: Expected 6 unique owners, got ", owners.size())
		grid.queue_free()
		return false

	print("PASS: Player and 5 allies each successfully claimed a distinct room.")
	grid.queue_free()
	return true

func _test_invader_corridor_movement() -> bool:
	print("\n[TEST 5] Testing Invader Corridor Navigation...")
	var grid := GridMapManager.new()
	add_child(grid)
	grid._ready()

	MatchState.reset_match()
	for r in grid.get_all_rooms():
		MatchState.register_room(r.room_id)

	var invader := InvaderActor.new()
	add_child(invader)
	invader.init_actor("invader", "入侵者", Color.RED, grid.invader_spawn_cell, grid)

	# Trigger phase change to INVADING
	MatchState.current_phase = MatchState.Phase.INVADING
	MatchState.phase_changed.emit(MatchState.Phase.INVADING)

	# Verify invader state and path
	if invader.invader_state != InvaderActor.InvaderState.APPROACHING_DOOR and invader.invader_state != InvaderActor.InvaderState.STOPPED_AT_DOOR:
		printerr("FAILED: Invader did not start approaching door")
		invader.queue_free()
		grid.queue_free()
		return false

	# Find closest door exterior
	var closest_exterior: Vector2i = grid.get_closest_door_exterior_to(grid.invader_spawn_cell)
	if invader.target_exterior_cell != closest_exterior:
		printerr("FAILED: Invader target %s != closest door exterior %s" % [invader.target_exterior_cell, closest_exterior])
		invader.queue_free()
		grid.queue_free()
		return false

	# Simulate moving through all steps to destination
	while invader.is_moving:
		invader.current_cell = invader.target_cell
		invader._on_step_completed()
		invader._advance_path()

	if invader.invader_state != InvaderActor.InvaderState.STOPPED_AT_DOOR:
		printerr("FAILED: Invader did not stop at door exterior")
		invader.queue_free()
		grid.queue_free()
		return false

	if invader.current_cell != closest_exterior:
		printerr("FAILED: Invader stopped at %s instead of %s" % [invader.current_cell, closest_exterior])
		invader.queue_free()
		grid.queue_free()
		return false

	print("PASS: Invader spawned at entrance, walked corridor to nearest hatch, and stopped outside.")
	invader.queue_free()
	grid.queue_free()
	return true

func _test_phase_1_economy() -> bool:
	print("\n[TEST 6] Testing Phase 1 Economy (Dual Resource, Mines, Chem Plant, Uranium Limit)...")
	MatchState.reset_match()
	var grid := GridMapManager.new()
	add_child(grid)
	grid._ready()

	var r101: RoomData = grid.get_room_by_id("room_101")
	MatchState.claim_room("room_101", "player")

	# 1. 验证双资源初始值
	if MatchState.money != 0 or MatchState.chem_feedstock != 0:
		printerr("FAILED: Initial money or feedstock not 0")
		grid.queue_free()
		return false

	# 2. 验证起步矿升级
	if MatchState.get_starter_level("room_101") != 1:
		printerr("FAILED: Initial starter level not 1")
		grid.queue_free()
		return false
	
	# 没钱升级起步矿失败
	if MatchState.upgrade_starter("room_101", "player"):
		printerr("FAILED: Upgrade starter should fail without enough money")
		grid.queue_free()
		return false
	
	# 给钱升级
	MatchState.add_money(100)
	if not MatchState.upgrade_starter("room_101", "player"):
		printerr("FAILED: Upgrade starter should succeed with money")
		grid.queue_free()
		return false
	if MatchState.get_starter_level("room_101") != 2:
		printerr("FAILED: Starter level should be 2 after upgrade")
		grid.queue_free()
		return false

	# 3. 验证矿山建造与产出
	var cell_iron := Vector2i(5, 5)
	MatchState.add_money(1000)
	if not MatchState.buy_and_place_building("room_101", "iron_mine", "player", cell_iron):
		printerr("FAILED: Failed to build iron_mine")
		grid.queue_free()
		return false
	
	# 4. 验证铀矿一房一座限制与第二座购买失败
	var cell_uranium1 := Vector2i(5, 6)
	var cell_uranium2 := Vector2i(5, 7)
	MatchState.add_money(12000)
	if not MatchState.buy_and_place_building("room_101", "uranium_mine", "player", cell_uranium1):
		printerr("FAILED: First uranium mine purchase should succeed")
		grid.queue_free()
		return false

	# 第二座购买必须失败
	if MatchState.buy_and_place_building("room_101", "uranium_mine", "player", cell_uranium2):
		printerr("FAILED: Second uranium mine in same room must fail!")
		grid.queue_free()
		return false

	# 5. 验证化工厂建造与化学原料产出
	if MatchState.has_chem_plant("room_101"):
		printerr("FAILED: Room 101 should not have chem plant before building")
		grid.queue_free()
		return false

	var cell_plant := Vector2i(6, 6)
	if not MatchState.buy_and_place_building("room_101", "chem_plant", "player", cell_plant):
		printerr("FAILED: Failed to build chem_plant")
		grid.queue_free()
		return false

	if not MatchState.has_chem_plant("room_101"):
		printerr("FAILED: has_chem_plant should be true after building chem plant")
		grid.queue_free()
		return false

	# 6. 模拟一个产出周期，检查金钱与原料同时入账
	var prev_money: int = MatchState.money
	var prev_feedstock: int = MatchState.chem_feedstock
	MatchState._process(MatchState.STARTER_INCOME_INTERVAL)

	# 起步矿 lvl 2 (20) + 铁矿 (5) + 铀矿 (800) = 825 money
	var expected_money_gain: int = (MatchState.STARTER_INCOME_AMOUNT * 2) + 5 + 800
	var expected_feedstock_gain: int = 5 # 化工厂产出 5 原料

	if MatchState.money != prev_money + expected_money_gain:
		printerr("FAILED: Money gain mismatch. Expected: ", prev_money + expected_money_gain, " got: ", MatchState.money)
		grid.queue_free()
		return false

	if MatchState.chem_feedstock != prev_feedstock + expected_feedstock_gain:
		printerr("FAILED: Chem feedstock gain mismatch. Expected: ", prev_feedstock + expected_feedstock_gain, " got: ", MatchState.chem_feedstock)
		grid.queue_free()
		return false

	print("PASS: Phase 1 economy verified: Dual resources, mines payout, Uranium 1-per-room limit, Chem plant feedstock payout.")
	grid.queue_free()
	return true

func _test_eject_non_owner_when_room_claimed() -> bool:
	print("\n[TEST 7] Testing Non-Owner Ejection on Room Claim...")
	var grid := GridMapManager.new()
	add_child(grid)
	grid._ready()

	MatchState.reset_match()
	for r in grid.get_all_rooms():
		MatchState.register_room(r.room_id, r.display_name)

	var room_101: RoomData = grid.get_room_by_id("room_101")
	if room_101 == null:
		printerr("FAILED: room_101 not found")
		grid.queue_free()
		return false

	var exterior_cell: Vector2i = room_101.door_exterior_cell
	var starter_cell: Vector2i = room_101.starter_cells[0]
	var interior_cell: Vector2i = Vector2i(5, 5)

	# --- Scenario 1: Player claims room while Ally is inside interior ---
	var player := PlayerActor.new()
	add_child(player)
	player.init_actor("player", "玩家", Color.CYAN, starter_cell, grid)

	var ally := AllyBot.new()
	add_child(ally)
	ally.init_actor("ally_1", "盟友1", Color.GREEN, interior_cell, grid)

	if not room_101.is_cell_interior(player.current_cell):
		printerr("FAILED: Player is not in room_101 interior before claim")
		player.queue_free()
		ally.queue_free()
		grid.queue_free()
		return false

	if not room_101.is_cell_interior(ally.current_cell):
		printerr("FAILED: Ally is not in room_101 interior before claim")
		player.queue_free()
		ally.queue_free()
		grid.queue_free()
		return false

	# Player claims room
	player._on_step_completed()

	if not MatchState.is_room_locked("room_101") or MatchState.get_room_owner("room_101") != "player":
		printerr("FAILED: Player failed to claim room_101")
		player.queue_free()
		ally.queue_free()
		grid.queue_free()
		return false

	# Owner player is not ejected
	if player.current_cell != starter_cell:
		printerr("FAILED: Owner player was wrongly ejected from room: ", player.current_cell)
		player.queue_free()
		ally.queue_free()
		grid.queue_free()
		return false

	# Non-owner ally is ejected to door_exterior_cell
	if ally.current_cell != exterior_cell:
		printerr("FAILED: Non-owner ally was not ejected to door_exterior_cell! Got: ", ally.current_cell, " expected: ", exterior_cell)
		player.queue_free()
		ally.queue_free()
		grid.queue_free()
		return false

	if ally.position != grid.cell_to_world(exterior_cell):
		printerr("FAILED: Ally visual position does not match door_exterior_cell")
		player.queue_free()
		ally.queue_free()
		grid.queue_free()
		return false

	if room_101.is_cell_interior(ally.current_cell):
		printerr("FAILED: Ally is still in room interior after claim")
		player.queue_free()
		ally.queue_free()
		grid.queue_free()
		return false

	# Non-owner cannot walk into locked room
	if MatchState.can_actor_enter_room("room_101", "ally_1"):
		printerr("FAILED: Ally_1 should not be permitted into locked room_101")
		player.queue_free()
		ally.queue_free()
		grid.queue_free()
		return false

	if grid.is_cell_walkable_for(room_101.door_cell, "ally_1"):
		printerr("FAILED: Door should not be walkable for ally_1")
		player.queue_free()
		ally.queue_free()
		grid.queue_free()
		return false

	player.queue_free()
	ally.queue_free()

	# --- Scenario 2: Ally claims room_102 while Player is inside interior ---
	var room_102: RoomData = grid.get_room_by_id("room_102")
	var r2_exterior: Vector2i = room_102.door_exterior_cell
	var r2_starter: Vector2i = room_102.starter_cells[0]
	var r2_interior: Vector2i = Vector2i(16, 6)

	var ally2 := AllyBot.new()
	add_child(ally2)
	ally2.init_actor("ally_2", "盟友2", Color.GREEN, r2_starter, grid)

	var player2 := PlayerActor.new()
	add_child(player2)
	player2.init_actor("player", "玩家", Color.CYAN, r2_interior, grid)
	player2._update_player_room_state()

	if MatchState.player_room_id != "room_102":
		printerr("FAILED: Player room id should be room_102 before claim")
		ally2.queue_free()
		player2.queue_free()
		grid.queue_free()
		return false

	# Ally 2 claims room_102
	ally2._on_step_completed()

	if MatchState.get_room_owner("room_102") != "ally_2":
		printerr("FAILED: Ally 2 failed to claim room_102")
		ally2.queue_free()
		player2.queue_free()
		grid.queue_free()
		return false

	if ally2.current_cell != r2_starter:
		printerr("FAILED: Owner ally_2 was wrongly ejected")
		ally2.queue_free()
		player2.queue_free()
		grid.queue_free()
		return false

	if player2.current_cell != r2_exterior:
		printerr("FAILED: Non-owner player was not ejected to door_exterior_cell! Got: ", player2.current_cell)
		ally2.queue_free()
		player2.queue_free()
		grid.queue_free()
		return false

	if player2.position != grid.cell_to_world(r2_exterior):
		printerr("FAILED: Player visual position does not match door_exterior_cell")
		ally2.queue_free()
		player2.queue_free()
		grid.queue_free()
		return false

	if MatchState.player_room_id != "":
		printerr("FAILED: Player room id should be empty (corridor) after ejection, got: ", MatchState.player_room_id)
		ally2.queue_free()
		player2.queue_free()
		grid.queue_free()
		return false

	if grid.is_cell_walkable_for(room_102.door_cell, "player"):
		printerr("FAILED: Room 102 door should not be walkable for player")
		ally2.queue_free()
		player2.queue_free()
		grid.queue_free()
		return false

	ally2.queue_free()
	player2.queue_free()

	# --- Scenario 3: Multiple non-owners (one on interior, one on door) ejected on claim ---
	var room_103: RoomData = grid.get_room_by_id("room_103")
	var r3_exterior: Vector2i = room_103.door_exterior_cell
	var r3_starter: Vector2i = room_103.starter_cells[0]
	var r3_interior: Vector2i = Vector2i(28, 5)
	var r3_door: Vector2i = room_103.door_cell

	var ally3 := AllyBot.new()
	add_child(ally3)
	ally3.init_actor("ally_3", "盟友3", Color.GREEN, r3_starter, grid)

	var ally4 := AllyBot.new()
	add_child(ally4)
	ally4.init_actor("ally_4", "盟友4", Color.YELLOW, r3_interior, grid)

	var ally5 := AllyBot.new()
	add_child(ally5)
	ally5.init_actor("ally_5", "盟友5", Color.ORANGE, r3_door, grid)

	ally3._on_step_completed()

	if MatchState.get_room_owner("room_103") != "ally_3":
		printerr("FAILED: Ally 3 failed to claim room_103")
		ally3.queue_free()
		ally4.queue_free()
		ally5.queue_free()
		grid.queue_free()
		return false

	if ally3.current_cell != r3_starter:
		printerr("FAILED: Owner ally_3 was wrongly ejected")
		ally3.queue_free()
		ally4.queue_free()
		ally5.queue_free()
		grid.queue_free()
		return false

	if ally4.current_cell != r3_exterior or ally5.current_cell != r3_exterior:
		printerr("FAILED: Multiple non-owners were not both ejected to door_exterior_cell! Got ally4: ", ally4.current_cell, " ally5: ", ally5.current_cell)
		ally3.queue_free()
		ally4.queue_free()
		ally5.queue_free()
		grid.queue_free()
		return false

	ally3.queue_free()
	ally4.queue_free()
	ally5.queue_free()

	print("PASS: Non-owners (player/allies) immediately ejected to door_exterior_cell on room claim, owner remains inside, room locked.")
	grid.queue_free()
	return true

func _test_income_generation() -> bool:
	print("\n[TEST 8] Testing Starter Mine Income Generation & Interruption...")
	MatchState.reset_match()
	var grid := GridMapManager.new()
	add_child(grid)
	grid._ready()

	var _r101: RoomData = grid.get_room_by_id("room_101")
	MatchState.claim_room("room_101", "player")

	if MatchState.money != 0:
		printerr("FAILED: Initial money should be 0")
		grid.queue_free()
		return false

	# 模拟经过一个产钱周期
	MatchState._process(MatchState.STARTER_INCOME_INTERVAL)
	if MatchState.money != MatchState.STARTER_INCOME_AMOUNT:
		printerr("FAILED: Money after 1 interval should be %d, got %d" % [MatchState.STARTER_INCOME_AMOUNT, MatchState.money])
		grid.queue_free()
		return false

	# 模拟再经过一个产钱周期
	MatchState._process(MatchState.STARTER_INCOME_INTERVAL)
	if MatchState.money != MatchState.STARTER_INCOME_AMOUNT * 2:
		printerr("FAILED: Money after 2 intervals should be %d, got %d" % [MatchState.STARTER_INCOME_AMOUNT * 2, MatchState.money])
		grid.queue_free()
		return false

	# 起步矿被拆光后停止产钱
	MatchState.damage_starter("room_101", MatchState.STARTER_MAX_HP)
	var current_money: int = MatchState.money
	MatchState._process(MatchState.STARTER_INCOME_INTERVAL * 2.0)
	if MatchState.money != current_money:
		printerr("FAILED: Destroyed starter should not generate money! Got: ", MatchState.money)
		grid.queue_free()
		return false

	print("PASS: Starter mine generates fixed income on interval, stops when destroyed.")
	grid.queue_free()
	return true

func _test_silicic_i_placement_rules() -> bool:
	print("\n[TEST 9] Testing Silicic I Placement Rules (Unclaimed, No Money, Obstacle, Valid)...")
	var main_scene: MainGame = load("res://scenes/main.tscn").instantiate()
	add_child(main_scene)

	MatchState.reset_match()
	for r in main_scene.grid_manager.get_all_rooms():
		MatchState.register_room(r.room_id, r.display_name)

	# 1. 未占房不能造塔
	MatchState.money = 500
	var cell_in_101 := Vector2i(5, 5)
	if main_scene.try_build_silicic_turret(cell_in_101):
		printerr("FAILED: Should not allow building when player has not claimed a room")
		main_scene.queue_free()
		return false

	# 2. 玩家占房但钱不够不能造塔
	MatchState.claim_room("room_101", "player")
	MatchState.money = MatchState.TURRET_COST - 1
	if main_scene.try_build_silicic_turret(cell_in_101):
		printerr("FAILED: Should not allow building when player lacks money")
		main_scene.queue_free()
		return false

	# 3. 钱够了，但在起步矿、门、走廊等无效格子不能造塔
	MatchState.money = MatchState.TURRET_COST * 5
	var starter_cell := Vector2i(3, 4)
	if main_scene.try_build_silicic_turret(starter_cell):
		printerr("FAILED: Should not allow building on starter cell")
		main_scene.queue_free()
		return false

	var door_cell := Vector2i(6, 12)
	if main_scene.try_build_silicic_turret(door_cell):
		printerr("FAILED: Should not allow building on door cell")
		main_scene.queue_free()
		return false

	var corridor_cell := Vector2i(6, 13)
	if main_scene.try_build_silicic_turret(corridor_cell):
		printerr("FAILED: Should not allow building outside owned room")
		main_scene.queue_free()
		return false

	# 4. 在房间空格成功扣钱建造
	var initial_money: int = MatchState.money
	if not main_scene.try_build_silicic_turret(cell_in_101):
		printerr("FAILED: Failed to build Silicic I on valid empty floor cell")
		main_scene.queue_free()
		return false

	if MatchState.money != initial_money - MatchState.TURRET_COST:
		printerr("FAILED: Did not deduct turret cost properly. Remaining: ", MatchState.money)
		main_scene.queue_free()
		return false

	if not main_scene.grid_manager.has_building_at(cell_in_101):
		printerr("FAILED: Turret not registered in grid manager")
		main_scene.queue_free()
		return false

	# 5. 不能在已有建筑的格子上重复建造
	if main_scene.try_build_silicic_turret(cell_in_101):
		printerr("FAILED: Should not allow duplicate building on same cell")
		main_scene.queue_free()
		return false

	print("PASS: Silicic I respects room ownership, money cost, tile restrictions, and deduplication.")
	main_scene.queue_free()
	return true

func _test_invader_attack_door_and_enter_room() -> bool:
	print("\n[TEST 10] Testing Invader Door Attack, Breach Condition, and Room Entry...")
	var grid := GridMapManager.new()
	add_child(grid)
	grid._ready()

	MatchState.reset_match()
	for r in grid.get_all_rooms():
		MatchState.register_room(r.room_id, r.display_name)

	# 玩家占领 room_101
	MatchState.claim_room("room_101", "player")

	var invader := InvaderActor.new()
	add_child(invader)
	invader.init_actor("invader", "入侵者", Color.RED, grid.invader_spawn_cell, grid)

	# 倒计时结束，敌人入场
	MatchState.current_phase = MatchState.Phase.INVADING
	MatchState.phase_changed.emit(MatchState.Phase.INVADING)

	# 验证：在敌人到达门外前，门 HP 不变
	var initial_door_hp: int = MatchState.get_door_hp("room_101")
	if initial_door_hp != MatchState.DOOR_MAX_HP:
		printerr("FAILED: Initial door HP is not DOOR_MAX_HP")
		invader.queue_free()
		grid.queue_free()
		return false

	# 模拟敌人在路上移动一段过程
	if invader.is_moving:
		invader.current_cell = invader.target_cell
		invader._on_step_completed()
		invader._advance_path()
		# 在路上时执行 _process
		invader._process(1.0)
		if MatchState.get_door_hp("room_101") != initial_door_hp:
			printerr("FAILED: Door HP must not change while invader is not yet at door exterior!")
			invader.queue_free()
			grid.queue_free()
			return false

	# 走完所有走廊路径到达 door_exterior_cell (6, 13)
	while invader.is_moving:
		invader.current_cell = invader.target_cell
		invader._on_step_completed()
		invader._advance_path()

	if invader.current_cell != Vector2i(6, 13):
		printerr("FAILED: Invader reached wrong cell: ", invader.current_cell)
		invader.queue_free()
		grid.queue_free()
		return false

	if invader.invader_state != InvaderActor.InvaderState.STOPPED_AT_DOOR:
		printerr("FAILED: Invader state should be STOPPED_AT_DOOR")
		invader.queue_free()
		grid.queue_free()
		return false

	# 到达门外后开始拆门
	invader._process(MatchState.INVADER_ATTACK_INTERVAL)
	var expected_hp: int = MatchState.DOOR_MAX_HP - MatchState.INVADER_ATTACK_DAMAGE
	if MatchState.get_door_hp("room_101") != expected_hp:
		printerr("FAILED: Door HP did not decrease as expected. Got: ", MatchState.get_door_hp("room_101"))
		invader.queue_free()
		grid.queue_free()
		return false

	# 门破前敌人不进 interior
	if MatchState.is_door_broken("room_101"):
		printerr("FAILED: Door should not be broken yet")
		invader.queue_free()
		grid.queue_free()
		return false

	var r101: RoomData = grid.get_room_by_id("room_101")
	if r101.is_cell_interior(invader.current_cell):
		printerr("FAILED: Invader entered interior before door broke!")
		invader.queue_free()
		grid.queue_free()
		return false

	# 持续攻击直到门破
	while not MatchState.is_door_broken("room_101"):
		invader._process(MatchState.INVADER_ATTACK_INTERVAL)

	if not MatchState.is_door_broken("room_101"):
		printerr("FAILED: Door should be broken now")
		invader.queue_free()
		grid.queue_free()
		return false

	# 门破后敌人开始进入房间
	invader._process(0.1)
	if invader.invader_state != InvaderActor.InvaderState.ENTERING_ROOM and invader.invader_state != InvaderActor.InvaderState.ATTACKING_STARTER:
		printerr("FAILED: Invader state after door break should be ENTERING_ROOM or ATTACKING_STARTER, got: ", invader.invader_state)
		invader.queue_free()
		grid.queue_free()
		return false

	# 模拟敌人走入房间内部到达起步矿
	while invader.is_moving:
		invader.current_cell = invader.target_cell
		invader._on_step_completed()
		invader._advance_path()

	if invader.invader_state != InvaderActor.InvaderState.ATTACKING_STARTER:
		printerr("FAILED: Invader did not transition to ATTACKING_STARTER after reaching starter")
		invader.queue_free()
		grid.queue_free()
		return false

	print("PASS: Door HP stays intact before arrival, takes damage at door, breaches at 0 HP, invader enters interior toward starter.")
	invader.queue_free()
	grid.queue_free()
	return true

func _test_victory_and_defeat_conditions() -> bool:
	print("\n[TEST 11] Testing Victory & Defeat Conditions (Starter Destroyed vs Invader Killed)...")
	var grid := GridMapManager.new()
	add_child(grid)
	grid._ready()

	# --- 场景 1: 起步矿被拆光 -> 玩家败 ---
	MatchState.reset_match()
	for r in grid.get_all_rooms():
		MatchState.register_room(r.room_id, r.display_name)
	MatchState.claim_room("room_101", "player")

	var invader := InvaderActor.new()
	add_child(invader)
	invader.init_actor("invader", "入侵者", Color.RED, Vector2i(3, 4), grid)
	invader.target_room_id = "room_101"
	invader.invader_state = InvaderActor.InvaderState.ATTACKING_STARTER

	# 拆毁起步矿
	MatchState.damage_starter("room_101", MatchState.STARTER_MAX_HP)
	if MatchState.game_result != MatchState.GameResult.DEFEAT:
		printerr("FAILED: Game result should be DEFEAT when player's starter is destroyed")
		invader.queue_free()
		grid.queue_free()
		return false

	invader._process(0.1)
	if invader.invader_state != InvaderActor.InvaderState.IDLE:
		printerr("FAILED: Invader should stop action and enter IDLE on defeat")
		invader.queue_free()
		grid.queue_free()
		return false

	invader.queue_free()

	# --- 场景 2: 硅酸 I 射程内炮击，敌人 HP 到 0 -> 玩家胜，敌人停止行动 ---
	MatchState.reset_match()
	for r in grid.get_all_rooms():
		MatchState.register_room(r.room_id, r.display_name)
	MatchState.claim_room("room_101", "player")

	var invader2 := InvaderActor.new()
	add_child(invader2)
	# 放置在门外 (6, 13)
	invader2.init_actor("invader", "入侵者", Color.RED, Vector2i(6, 13), grid)
	invader2.visible = true
	invader2.invader_state = InvaderActor.InvaderState.STOPPED_AT_DOOR

	# 在 (6, 11) 放置硅酸 I（距离 (6, 13) 为 2 格，在 4 格射程内）
	var turret := SilicicTurret.new()
	grid.add_turret(Vector2i(6, 11), turret)
	turret.init_turret(Vector2i(6, 11), invader2, grid)

	# 模拟炮台射击敌人
	var initial_hp: int = MatchState.invader_hp
	turret._process(MatchState.TURRET_FIRE_INTERVAL)
	if MatchState.invader_hp != initial_hp - MatchState.TURRET_DAMAGE:
		printerr("FAILED: Invader HP was not damaged by turret. Expected: ", initial_hp - MatchState.TURRET_DAMAGE, " got: ", MatchState.invader_hp)
		invader2.queue_free()
		grid.queue_free()
		return false

	# 持续开火击杀敌人
	while MatchState.invader_hp > 0:
		turret._process(MatchState.TURRET_FIRE_INTERVAL)

	if MatchState.game_result != MatchState.GameResult.VICTORY:
		printerr("FAILED: Game result should be VICTORY when invader HP reaches 0")
		invader2.queue_free()
		grid.queue_free()
		return false

	if invader2.is_alive():
		printerr("FAILED: Invader should be dead when HP reaches 0")
		invader2.queue_free()
		grid.queue_free()
		return false

	if invader2.invader_state != InvaderActor.InvaderState.DEAD:
		printerr("FAILED: Invader state should be DEAD")
		invader2.queue_free()
		grid.queue_free()
		return false

	print("PASS: Starter destroyed triggers DEFEAT; Turret kills invader in range, triggers VICTORY and halts invader.")
	invader2.queue_free()
	grid.queue_free()
	return true

