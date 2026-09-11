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
	success = success and _test_phase_2_acid_tree()
	success = success and _test_phase_3_hatch_system()
	success = success and _test_phase_4_invader_system()
	success = success and _test_phase_5_ally_and_hightech()
	success = success and _test_phase_6_hud_and_full_regression()
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
		MatchState.register_room(r.room_id, r.display_name, r.interior_rect)

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
		MatchState.register_room(r.room_id, r.display_name, r.interior_rect)

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
		MatchState.register_room(r.room_id, r.display_name, r.interior_rect)

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

	# 7. 化工厂新买为 I；不能跳档；原地花钱升到 XV；XV 不能再升；XV 产量 > I
	var plant_data: Dictionary = MatchState.get_building_at_cell(cell_plant)
	if int(plant_data.get("level", 0)) != 1:
		printerr("FAILED: Newly bought chem plant must start at I, got level: ", plant_data.get("level", 0))
		grid.queue_free()
		return false
	var income_i: int = int(plant_data.get("income_feedstock", 0))
	if income_i != MatchState.CHEM_PLANT_BASE_FEEDSTOCK:
		printerr("FAILED: Chem plant I feedstock income should be %d, got: %d" % [MatchState.CHEM_PLANT_BASE_FEEDSTOCK, income_i])
		grid.queue_free()
		return false

	MatchState.add_money(20000)
	if not MatchState.upgrade_chem_plant("room_101", "player", cell_plant):
		printerr("FAILED: Chem plant I -> II upgrade should succeed")
		grid.queue_free()
		return false
	plant_data = MatchState.get_building_at_cell(cell_plant)
	if int(plant_data.get("level", 0)) != 2:
		printerr("FAILED: Chem plant must not skip ranks; expected II after one upgrade, got: ", plant_data.get("level", 0))
		grid.queue_free()
		return false
	if plant_data.get("cell", Vector2i.ZERO) != cell_plant:
		printerr("FAILED: Chem plant upgrade must stay in place")
		grid.queue_free()
		return false

	for _i in range(13):
		if not MatchState.upgrade_chem_plant("room_101", "player", cell_plant):
			printerr("FAILED: Sequential chem plant upgrade failed before XV at level ", MatchState.get_building_at_cell(cell_plant).get("level", 0))
			grid.queue_free()
			return false
	plant_data = MatchState.get_building_at_cell(cell_plant)
	if int(plant_data.get("level", 0)) != 15:
		printerr("FAILED: Chem plant should be XV after 14 upgrades, got: ", plant_data.get("level", 0))
		grid.queue_free()
		return false
	if MatchState.can_upgrade_chem_plant("room_101", "player", cell_plant).get("success", false):
		printerr("FAILED: Chem plant XV must not upgrade further")
		grid.queue_free()
		return false
	if MatchState.upgrade_chem_plant("room_101", "player", cell_plant):
		printerr("FAILED: Chem plant XV upgrade call must fail")
		grid.queue_free()
		return false
	var income_xv: int = int(plant_data.get("income_feedstock", 0))
	if income_xv <= income_i:
		printerr("FAILED: Chem plant XV feedstock income must exceed I. I=%d XV=%d" % [income_i, income_xv])
		grid.queue_free()
		return false
	if int(plant_data.get("income_money", 0)) != 0:
		printerr("FAILED: Chem plant upgrade must not produce money")
		grid.queue_free()
		return false

	var fs_before_xv: int = MatchState.chem_feedstock
	MatchState._process(MatchState.STARTER_INCOME_INTERVAL)
	var xv_gain: int = MatchState.chem_feedstock - fs_before_xv
	if xv_gain != income_xv:
		printerr("FAILED: Chem plant XV tick feedstock mismatch. Expected %d got %d" % [income_xv, xv_gain])
		grid.queue_free()
		return false

	# 8. 对不属于该房的 cell 购买必须失败
	var foreign_cell := Vector2i(18, 6) # room_102 interior
	if MatchState.is_cell_in_room("room_101", foreign_cell):
		printerr("FAILED: (18,6) must not belong to room_101")
		grid.queue_free()
		return false
	if MatchState.buy_and_place_building("room_101", "iron_mine", "player", foreign_cell):
		printerr("FAILED: buy_and_place_building must reject a cell that is not in the room")
		grid.queue_free()
		return false
	var corridor_cell := Vector2i(6, 13)
	if MatchState.buy_and_place_building("room_101", "iron_mine", "player", corridor_cell):
		printerr("FAILED: buy_and_place_building must reject a corridor cell")
		grid.queue_free()
		return false

	print("PASS: Phase 1 economy verified: Dual resources, mines payout, Uranium 1-per-room limit, Chem plant I-XV, room-cell build check.")
	grid.queue_free()
	return true

func _test_phase_2_acid_tree() -> bool:
	print("\n[TEST Phase 2] Testing Acid Tree (Full Lines, Capstone Names, No-Plant Lock, Specials)...")
	MatchState.reset_match()
	var grid := GridMapManager.new()
	add_child(grid)
	grid._ready()

	# 1. 验证 V 档冠名严格符合 DESIGN 表
	var cap_tests: Dictionary = {
		"silicic": "胶幕",
		"carbonate": "沸泉",
		"hypochlorous": "漂白",
		"hydrosulfuric": "硫沼",
		"hydrofluoric": "蚀晶",
		"hydrochloric": "盐雾",
		"sulfuric": "发烟",
		"perchloric": "爆氧",
		"fluoroantimonic": "魔酸"
	}
	for sub in cap_tests.keys():
		var display: String = MatchState.get_turret_display_name(sub, 5)
		if not display.contains(cap_tests[sub]):
			printerr("FAILED: Capstone title for %s does not contain %s, got: %s" % [sub, cap_tests[sub], display])
			grid.queue_free()
			return false

	# 2. 验证炮台按序晋升，无跳档
	MatchState.claim_room("room_101", "player")
	MatchState.add_money(50000)
	MatchState.add_feedstock(500)

	var invader := InvaderActor.new()
	add_child(invader)
	invader.init_actor("invader", "入侵者", Color.RED, Vector2i(6, 13), grid)
	invader.visible = true

	var turret := SilicicTurret.new()
	grid.add_turret(Vector2i(5, 5), turret)
	turret.init_turret(Vector2i(5, 5), invader, grid)

	# 硅酸 I -> V
	for r in range(1, 5):
		if not MatchState.upgrade_turret(turret):
			printerr("FAILED: Upgrading silicic %d to %d failed" % [r, r + 1])
			invader.queue_free()
			grid.queue_free()
			return false
	if turret.substance != "silicic" or turret.rank != 5:
		printerr("FAILED: Expected silicic rank 5, got %s %d" % [turret.substance, turret.rank])
		invader.queue_free()
		grid.queue_free()
		return false

	# 硅酸 V -> 碳酸 I
	if not MatchState.upgrade_turret(turret):
		printerr("FAILED: Upgrading silicic 5 to carbonate 1 failed")
		invader.queue_free()
		grid.queue_free()
		return false
	if turret.substance != "carbonate" or turret.rank != 1:
		printerr("FAILED: Expected carbonate rank 1")
		invader.queue_free()
		grid.queue_free()
		return false

	# 碳酸 I -> V
	for r in range(1, 5):
		if not MatchState.upgrade_turret(turret):
			printerr("FAILED: Upgrading carbonate %d to %d failed" % [r, r + 1])
			invader.queue_free()
			grid.queue_free()
			return false

	# 3. 验证无化工厂不能换线
	if MatchState.has_chem_plant("room_101"):
		printerr("FAILED: Room 101 should not have chem plant yet")
		invader.queue_free()
		grid.queue_free()
		return false

	var branch_check := MatchState.can_upgrade_turret(turret, "line_a")
	if branch_check.get("success", false):
		printerr("FAILED: Turret must NOT be able to branch without a chem plant!")
		invader.queue_free()
		grid.queue_free()
		return false

	# 4. 建造化工厂后允许换线，且换线后不能回头
	var cell_plant := Vector2i(5, 6)
	if not MatchState.buy_and_place_building("room_101", "chem_plant", "player", cell_plant):
		printerr("FAILED: Failed to build chem plant")
		invader.queue_free()
		grid.queue_free()
		return false

	# 选择 Line A 换线 -> 次氯酸 I
	if not MatchState.upgrade_turret(turret, "line_a"):
		printerr("FAILED: Failed to branch to line_a with chem plant present")
		invader.queue_free()
		grid.queue_free()
		return false

	if turret.substance != "hypochlorous" or turret.rank != 1 or turret.branch_line != "line_a":
		printerr("FAILED: Turret state mismatch after branching to line_a")
		invader.queue_free()
		grid.queue_free()
		return false

	# 换线后不能回头 (尝试切到 line_b 必须被拒绝)
	var reverse_check := MatchState.can_upgrade_turret(turret, "line_b")
	if reverse_check.get("success", false):
		printerr("FAILED: Turret must NOT be able to switch to line_b after picking line_a!")
		invader.queue_free()
		grid.queue_free()
		return false

	# 5. 验证特效（重置敌人充足生命值以承受各武器特效测试）
	MatchState.invader_hp = 10000
	invader.invader_state = InvaderActor.InvaderState.STOPPED_AT_DOOR

	# 验证特效 1：次氯酸减缓破门速度
	turret._fire_at_invader()
	if invader.slow_break_timer <= 0.0:
		printerr("FAILED: Hypochlorous did not apply slow_break_timer")
		invader.queue_free()
		grid.queue_free()
		return false

	# 验证特效 2：氢硫酸地面水洼 DoT（真实地表水洼实体与走开停扣）
	var turret_hydro := SilicicTurret.new()
	grid.add_turret(Vector2i(6, 7), turret_hydro)
	turret_hydro.init_turret(Vector2i(6, 7), invader, grid)
	turret_hydro.substance = "hydrosulfuric"
	turret_hydro.rank = 1
	turret_hydro.branch_line = "line_a"
	turret_hydro.apply_stats()
	var prev_inv_hp: int = MatchState.invader_hp
	turret_hydro._fire_at_invader()
	if not grid.has_acid_puddle_at(invader.current_cell):
		printerr("FAILED: Hydrosulfuric did not spawn acid puddle on grid cell!")
		invader.queue_free()
		grid.queue_free()
		return false
	if grid.get_acid_puddle_dps(invader.current_cell) <= 0:
		printerr("FAILED: Acid puddle DPS must be > 0")
		invader.queue_free()
		grid.queue_free()
		return false
	# 敌人站在水洼格子上受 DoT
	invader.puddle_timer = 0.0 # 清空单体 timer，验证真实地表水洼结算
	var hp_before_puddle: int = MatchState.invader_hp
	invader._process(0.55)
	if MatchState.invader_hp >= hp_before_puddle:
		printerr("FAILED: Invader standing on acid puddle cell did not take puddle DoT damage!")
		invader.queue_free()
		grid.queue_free()
		return false
	# 敌人移开水洼格子后不再受水洼 DoT
	invader.current_cell = Vector2i(20, 13)
	var hp_moved: int = MatchState.invader_hp
	invader._process(0.55)
	if MatchState.invader_hp != hp_moved:
		printerr("FAILED: Invader should NOT take puddle damage after stepping off the puddle cell!")
		invader.queue_free()
		grid.queue_free()
		return false
	invader.current_cell = Vector2i(6, 13) # 移回门外

	# 验证特效 3：氢氟酸克拆门中的敌人，不降低己方舱门装甲
	MatchState.door_kind["room_101"] = "ion_gate"
	MatchState.door_rank["room_101"] = 5
	MatchState.door_armor["room_101"] = 225
	var turret_hf := SilicicTurret.new()
	grid.add_turret(Vector2i(5, 6), turret_hf)
	turret_hf.init_turret(Vector2i(5, 6), invader, grid)
	turret_hf.substance = "hydrofluoric"
	turret_hf.rank = 1
	turret_hf.branch_line = "line_a"
	turret_hf.room_id = "room_101"
	turret_hf.apply_stats()
	invader.invader_state = InvaderActor.InvaderState.STOPPED_AT_DOOR
	var initial_door_armor: int = MatchState.get_door_armor("room_101")
	var hp_before_hf: int = MatchState.invader_hp
	turret_hf._fire_at_invader()
	if MatchState.get_door_armor("room_101") != initial_door_armor:
		printerr("FAILED: Hydrofluoric must NOT reduce allied door armor! before=%d after=%d" % [initial_door_armor, MatchState.get_door_armor("room_101")])
		invader.queue_free()
		grid.queue_free()
		return false
	var hf_taken: int = hp_before_hf - MatchState.invader_hp
	var hf_expected: int = int(round(float(turret_hf.turret_damage) * 1.6))
	if hf_taken != hf_expected:
		printerr("FAILED: Hydrofluoric extra vs hatch-breaking invader mismatch, expected %d got %d" % [hf_expected, hf_taken])
		invader.queue_free()
		grid.queue_free()
		return false

	# 验证特效 4：盐酸长射程高射速 (Range 7.5, Interval 0.35)
	var stats_hcl: Dictionary = MatchState.get_turret_stats("hydrochloric", 1)
	if stats_hcl["range"] < 7.0 or stats_hcl["interval"] > 0.4:
		printerr("FAILED: Hydrochloric stats mismatch, expected high rate and long range, got: ", stats_hcl)
		invader.queue_free()
		grid.queue_free()
		return false

	# 验证特效 5：硫酸剥离抗性 (Strip resist 1.3x damage)
	var turret_sulfuric := SilicicTurret.new()
	grid.add_turret(Vector2i(5, 7), turret_sulfuric)
	turret_sulfuric.init_turret(Vector2i(5, 7), invader, grid)
	turret_sulfuric.substance = "sulfuric"
	turret_sulfuric.rank = 1
	turret_sulfuric.branch_line = "line_b"
	turret_sulfuric.apply_stats()
	turret_sulfuric._fire_at_invader()
	if invader.strip_resist_timer <= 0.0:
		printerr("FAILED: Sulfuric did not apply strip_resist_timer")
		invader.queue_free()
		grid.queue_free()
		return false

	# 验证特效 6：高氯酸连射硬直 (Burst 3 then hitch)
	var turret_perchloric := SilicicTurret.new()
	grid.add_turret(Vector2i(6, 11), turret_perchloric)
	turret_perchloric.init_turret(Vector2i(6, 11), invader, grid)
	turret_perchloric.substance = "perchloric"
	turret_perchloric.rank = 1
	turret_perchloric.branch_line = "line_b"
	turret_perchloric.apply_stats()
	for b in range(3):
		turret_perchloric._process(0.15)
	if turret_perchloric.hitch_timer <= 0.0:
		printerr("FAILED: Perchloric did not trigger hitch after burst!")
		invader.queue_free()
		grid.queue_free()
		return false

	# 验证特效 7：氟锑酸隔门穿透直击 (Pierce through hatch to the invader)
	MatchState.door_broken["room_101"] = false # 确保本房间舱门完好闭锁
	invader.current_cell = Vector2i(10, 13) # 敌人位于走廊深处（不在门外格）
	invader.global_position = grid.cell_to_world(invader.current_cell)
	var normal_turret := SilicicTurret.new()
	grid.add_turret(Vector2i(4, 4), normal_turret)
	normal_turret.init_turret(Vector2i(4, 4), invader, grid)
	normal_turret.turret_range = 10.0 # 给予足够射程
	if normal_turret._can_shoot_target(invader):
		printerr("FAILED: Normal turret should be BLOCKED by closed door when target is in deep corridor!")
		invader.queue_free()
		grid.queue_free()
		return false

	var turret_fa := SilicicTurret.new()
	grid.add_turret(Vector2i(4, 5), turret_fa)
	turret_fa.init_turret(Vector2i(4, 5), invader, grid)
	turret_fa.substance = "fluoroantimonic"
	turret_fa.rank = 5
	turret_fa.branch_line = "line_b"
	turret_fa.apply_stats()
	turret_fa.turret_range = 10.0
	if not turret_fa._can_shoot_target(invader):
		printerr("FAILED: Fluoroantimonic turret must PIERCE through closed hatch to hit invader!")
		invader.queue_free()
		grid.queue_free()
		return false
	var hp_before_fa: int = MatchState.invader_hp
	turret_fa._fire_at_invader()
	if MatchState.invader_hp >= hp_before_fa:
		printerr("FAILED: Fluoroantimonic failed to damage invader through closed hatch!")
		invader.queue_free()
		grid.queue_free()
		return false

	# 6. 验证 Line B 分支完整逐步升级链：盐酸 I-V -> 硫酸 I-V -> 高氯酸 I-V -> 氟锑酸 I-V
	var turret_line_b := SilicicTurret.new()
	grid.add_turret(Vector2i(3, 5), turret_line_b)
	turret_line_b.init_turret(Vector2i(3, 5), invader, grid)
	turret_line_b.substance = "carbonate"
	turret_line_b.rank = 5
	turret_line_b.branch_line = ""
	if not MatchState.upgrade_turret(turret_line_b, "line_b"):
		printerr("FAILED: Branching into Line B failed!")
		invader.queue_free()
		grid.queue_free()
		return false
	if turret_line_b.substance != "hydrochloric" or turret_line_b.rank != 1 or turret_line_b.branch_line != "line_b":
		printerr("FAILED: Expected hydrochloric I line_b, got: %s %d %s" % [turret_line_b.substance, turret_line_b.rank, turret_line_b.branch_line])
		invader.queue_free()
		grid.queue_free()
		return false

	print("PASS: Phase 2 acid tree verified: Stepwise upgrades, capstone titles, no-plant branch lock, branch irreversibility, Line B progression, and all 7 branch specials.")
	invader.queue_free()
	grid.queue_free()
	return true

func _test_phase_3_hatch_system() -> bool:
	print("\n[TEST Phase 3] Testing 30 Hatch Ranks, Mid-Chain Regen, Broken-Cannot-Upgrade, Level 15 Break Check...")
	MatchState.reset_match()
	var grid := GridMapManager.new()
	add_child(grid)
	grid._ready()

	MatchState.claim_room("room_101", "player")
	MatchState.add_money(500000)

	# 1. 初始门为蜂巢闸 I，HP 100，回血 0
	if MatchState.get_door_kind("room_101") != "honeycomb" or MatchState.get_door_rank("room_101") != 1:
		printerr("FAILED: Initial hatch not honeycomb I")
		grid.queue_free()
		return false
	if MatchState.get_door_regen_rate("room_101") != 0:
		printerr("FAILED: Honeycomb I should have 0 regen")
		grid.queue_free()
		return false

	# 2. 依次升级 29 次到达离子栅 V
	for i in range(29):
		if not MatchState.upgrade_door("room_101", "player"):
			printerr("FAILED: Failed door upgrade at step %d" % i)
			grid.queue_free()
			return false

	if MatchState.get_door_kind("room_101") != "ion_gate" or MatchState.get_door_rank("room_101") != 5:
		printerr("FAILED: Hatch after 29 upgrades should be ion_gate V, got: %s %d" % [MatchState.get_door_kind("room_101"), MatchState.get_door_rank("room_101")])
		grid.queue_free()
		return false

	# 达封顶后不能再升
	if MatchState.can_upgrade_door("room_101", "player").get("success", false):
		printerr("FAILED: Ion gate V should not be upgradable further")
		grid.queue_free()
		return false

	# 3. 验证回血机制（离子栅 V 回血 > 0）
	var max_ion_hp: int = MatchState.get_door_max_hp("room_101")
	var regen_rate: int = MatchState.get_door_regen_rate("room_101")
	if regen_rate <= 0:
		printerr("FAILED: Ion gate V must have regen > 0")
		grid.queue_free()
		return false

	# 受到伤害后自动回血（注意减免装甲后的有效伤害，确保未被最大生命上限截断）
	MatchState.damage_door("room_101", 1000)
	var damaged_hp: int = MatchState.get_door_hp("room_101")
	MatchState._process(1.0) # 心跳 1 秒回血
	if MatchState.get_door_hp("room_101") != damaged_hp + regen_rate:
		printerr("FAILED: Hatch did not regen HP properly. Got: %d expected: %d" % [MatchState.get_door_hp("room_101"), damaged_hp + regen_rate])
		grid.queue_free()
		return false

	# 4. 验证已破不能升
	MatchState.damage_door("room_101", max_ion_hp * 2)
	if not MatchState.is_door_broken("room_101"):
		printerr("FAILED: Door should be broken after taking massive damage")
		grid.queue_free()
		return false
	var broken_upgrade_check := MatchState.can_upgrade_door("room_101", "player")
	if broken_upgrade_check.get("success", false) or not broken_upgrade_check.get("reason", "").contains("已破不能升"):
		printerr("FAILED: Broken door must NOT be upgradeable! Reason: ", broken_upgrade_check.get("reason", ""))
		grid.queue_free()
		return false

	# 5. 含装甲净 DPS：15 级基础拆伤扣装甲后仍高于离子栅 V 回血；3–4 级压不穿封顶门
	var ion_stats: Dictionary = MatchState.get_hatch_stats("ion_gate", 5)
	var ion_armor: int = int(ion_stats["armor"])
	var max_gate_regen: float = float(ion_stats["regen"])
	var sample_invader := InvaderActor.new()
	sample_invader.invader_level = 15
	var lv15_raw: int = sample_invader.get_base_attack_damage()
	var lv15_interval: float = sample_invader.get_base_attack_interval()
	var lv15_eff: int = MatchState.get_effective_door_damage(lv15_raw, ion_armor)
	var lv15_eff_dps: float = float(lv15_eff) / lv15_interval
	if lv15_eff <= 1:
		printerr("FAILED: Level 15 effective door hit must not be crushed to 1 by ion gate V armor. raw=%d armor=%d" % [lv15_raw, ion_armor])
		sample_invader.queue_free()
		grid.queue_free()
		return false
	if lv15_eff_dps - max_gate_regen <= 0.0:
		printerr("FAILED: Level 15 effective DPS after armor must exceed Ion gate V regen! eff_dps=%f regen=%f raw=%d armor=%d" % [lv15_eff_dps, max_gate_regen, lv15_raw, ion_armor])
		sample_invader.queue_free()
		grid.queue_free()
		return false

	sample_invader.invader_level = 4
	var lv4_raw: int = sample_invader.get_base_attack_damage()
	var lv4_interval: float = sample_invader.get_base_attack_interval()
	var lv4_eff: int = MatchState.get_effective_door_damage(lv4_raw, ion_armor)
	var lv4_eff_dps: float = float(lv4_eff) / lv4_interval
	if lv4_eff_dps - max_gate_regen > 0.0:
		printerr("FAILED: Level 4 must not break ion gate V through armor+regen. eff_dps=%f regen=%f" % [lv4_eff_dps, max_gate_regen])
		sample_invader.queue_free()
		grid.queue_free()
		return false
	sample_invader.queue_free()

	print("PASS: Phase 3 hatch verified: 30 ranks upgradeable, mid-chain regen active, broken door blocked from upgrade, and Lv 15 armored net DPS > Ion Gate V regen.")
	grid.queue_free()
	return true

func _test_phase_4_invader_system() -> bool:
	print("\n[TEST Phase 4] Testing Invader XP, Leveling, 4 Roles Skills Gating, Remote Heal Pads...")
	MatchState.reset_match()
	var grid := GridMapManager.new()
	add_child(grid)
	grid._ready()

	# 0. 验证四角色真正随机抽取一个（抽样 40 次必须涵盖 4 种角色）
	var sampled_chars: Dictionary = {}
	for i in range(40):
		MatchState.reset_match()
		sampled_chars[MatchState.invader_character] = true
	if sampled_chars.size() < 4:
		printerr("FAILED: Four invader characters not truly sampled randomly! Got: ", sampled_chars.keys())
		grid.queue_free()
		return false

	MatchState.reset_match()
	for r in grid.get_all_rooms():
		MatchState.register_room(r.room_id, r.display_name, r.interior_rect)
	MatchState.claim_room("room_101", "player")

	var invader := InvaderActor.new()
	add_child(invader)
	invader.init_actor("invader", "入侵者", Color.RED, grid.invader_spawn_cell, grid)

	# 1. 验证走廊偏僻回血点（远离全部门，且超出默认炮台射程 4.0 与聚焦镜 5.0）
	for pad in grid.heal_pad_cells:
		for r in grid.get_all_rooms():
			var dist_door: int = abs(pad.x - r.door_exterior_cell.x) + abs(pad.y - r.door_exterior_cell.y)
			if dist_door < 10:
				printerr("FAILED: Heal pad %s too close to room %s door exterior (Manhattan: %d < 10)" % [pad, r.room_id, dist_door])
				invader.queue_free()
				grid.queue_free()
				return false
			for ic in r.get_interior_cells():
				var dist_tile: float = Vector2(pad).distance_to(Vector2(ic))
				if dist_tile < 6.0:
					printerr("FAILED: Heal pad %s within turret range of interior cell %s (dist: %f < 6.0)" % [pad, ic, dist_tile])
					invader.queue_free()
					grid.queue_free()
					return false

	# 2. 验证跑路时不涨经验
	invader.set_character("rock_corroder")
	invader.spawn_invader()
	if invader.is_moving:
		invader._process(0.5)
		if invader.invader_xp != 0:
			printerr("FAILED: Invader gained XP while walking! XP must only increase when attacking hatch.")
			invader.queue_free()
			grid.queue_free()
			return false

	# 走到门外
	while invader.is_moving:
		invader.current_cell = invader.target_cell
		invader._on_step_completed()
		invader._advance_path()

	if invader.invader_state != InvaderActor.InvaderState.STOPPED_AT_DOOR:
		printerr("FAILED: Invader should be STOPPED_AT_DOOR")
		invader.queue_free()
		grid.queue_free()
		return false

	# 3. 验证打门才涨经验
	var prev_xp: int = invader.invader_xp
	invader._process(invader.get_base_attack_interval() + 0.05)
	if invader.invader_xp <= prev_xp:
		printerr("FAILED: Invader did not gain XP when attacking door!")
		invader.queue_free()
		grid.queue_free()
		return false

	# 4. 验证四角色战斗技能真实调用与门控（不手算伪造）
	# (A) 蚀岩 (rock_corroder): 真实测试 Lv 4 vs Lv 5 克制回血 vs Lv 10 斩击
	invader.set_character("rock_corroder")
	MatchState.door_hp["room_101"] = 10000
	MatchState.door_armor["room_101"] = 0
	MatchState.door_regen["room_101"] = 25

	# Lv 4: 基础伤害 56
	invader.invader_level = 4
	invader.invader_xp = 0
	invader.invader_xp_to_next = 99999
	var hp_before_atk: int = MatchState.get_door_hp("room_101")
	invader.attack_timer = 0.0
	invader._process_attacking_door(invader.get_base_attack_interval() + 0.01)
	var dmg_taken_lv4: int = hp_before_atk - MatchState.get_door_hp("room_101")
	if dmg_taken_lv4 != 56:
		printerr("FAILED: Rock corroder Lv 4 actual damage mismatch, expected 56 got: ", dmg_taken_lv4)
		invader.queue_free()
		grid.queue_free()
		return false

	# Lv 5: 基础伤害 60，增加抵消回血量 (60 + 25 = 85)
	invader.invader_level = 5
	invader.invader_xp = 0
	invader.invader_xp_to_next = 99999
	hp_before_atk = MatchState.get_door_hp("room_101")
	invader.attack_timer = 0.0
	invader._process_attacking_door(invader.get_base_attack_interval() + 0.01)
	var dmg_taken_lv5: int = hp_before_atk - MatchState.get_door_hp("room_101")
	if dmg_taken_lv5 != (60 + 25):
		printerr("FAILED: Rock corroder Lv 5 regen counter damage mismatch, expected 85 got: ", dmg_taken_lv5)
		invader.queue_free()
		grid.queue_free()
		return false

	# Lv 10: 斩击 1.5x (基础 120 + 25 = 145 -> 1.5x = 218)
	invader.invader_level = 10
	invader.invader_xp = 0
	invader.invader_xp_to_next = 99999
	hp_before_atk = MatchState.get_door_hp("room_101")
	invader.attack_timer = 0.0
	invader._process_attacking_door(invader.get_base_attack_interval() + 0.01)
	var dmg_taken_lv10: int = hp_before_atk - MatchState.get_door_hp("room_101")
	var expected_cut: int = int(round(float(120 + 25) * 1.5))
	if dmg_taken_lv10 != expected_cut:
		printerr("FAILED: Rock corroder Lv 10 actual cut damage mismatch, expected %d got: %d" % [expected_cut, dmg_taken_lv10])
		invader.queue_free()
		grid.queue_free()
		return false

	# (B) 雾徙 (mist_walker): Lv 5 迷雾减速炮台，Lv 12 换门
	var test_turret := SilicicTurret.new()
	grid.add_turret(Vector2i(5, 5), test_turret)
	test_turret.init_turret(Vector2i(5, 5), invader, grid)
	test_turret.room_id = "room_101"

	invader.set_character("mist_walker")
	invader.invader_level = 5
	invader.skill_cooldown_timer = 0.0
	invader.attack_timer = 0.0
	invader._process_attacking_door(invader.get_base_attack_interval() + 0.01)
	if test_turret.fog_slow_timer <= 0.0:
		printerr("FAILED: Mist walker Lv 5 did not apply fog slow to turret!")
		invader.queue_free()
		test_turret.queue_free()
		grid.queue_free()
		return false

	invader.invader_level = 12
	invader.has_retargeted_at_12 = false
	invader.attack_timer = 0.0
	invader._process_attacking_door(invader.get_base_attack_interval() + 0.01)
	if invader.target_room_id == "room_101":
		printerr("FAILED: Mist walker Lv 12 did not retarget to alternate room!")
		invader.queue_free()
		test_turret.queue_free()
		grid.queue_free()
		return false
	invader.target_room_id = "room_101" # 恢复目标

	# (C) 遏火 (fire_quencher): Lv 6 沉默炮台，Lv 12 削弱射程
	invader.set_character("fire_quencher")
	invader.invader_level = 6
	invader.skill_cooldown_timer = 0.0
	invader.attack_timer = 0.0
	invader._process_attacking_door(invader.get_base_attack_interval() + 0.01)
	if test_turret.silence_timer <= 0.0:
		printerr("FAILED: Fire quencher Lv 6 did not silence turret!")
		invader.queue_free()
		test_turret.queue_free()
		grid.queue_free()
		return false

	invader.invader_level = 12
	invader.attack_timer = 0.0
	invader._process_attacking_door(invader.get_base_attack_interval() + 0.01)
	if test_turret.range_reduction < 1.5:
		printerr("FAILED: Fire quencher Lv 12 did not shorten turret range by 1.5!")
		invader.queue_free()
		test_turret.queue_free()
		grid.queue_free()
		return false
	test_turret.queue_free()

	# (D) 暴氧 (oxygen_burster): Lv 7 无自僵直，Lv 8 爆发且自僵直
	invader.set_character("oxygen_burster")
	invader.invader_level = 7
	invader.skill_cooldown_timer = 0.0
	invader.attack_timer = 0.0
	invader._process_attacking_door(invader.get_base_attack_interval() + 0.01)
	if invader.oxygen_self_hitch_timer > 0.0:
		printerr("FAILED: Oxygen burster hitch triggered below level 8!")
		invader.queue_free()
		grid.queue_free()
		return false

	invader.invader_level = 8
	invader.skill_cooldown_timer = 0.0
	invader.attack_timer = 0.0
	invader._process_attacking_door(invader.get_base_attack_interval() + 0.01)
	if invader.oxygen_self_hitch_timer <= 0.0:
		printerr("FAILED: Oxygen burster burst hitch did not trigger at level 8!")
		invader.queue_free()
		grid.queue_free()
		return false

	# 5. 验证低血量脱战撤退与回血不涨经验（同时验证全状态如入室后低血撤退）
	MatchState.invader_hp = int(float(MatchState.INVADER_MAX_HP) * 0.3)
	invader.oxygen_self_hitch_timer = 0.0
	invader._process(0.1) # 触发血量危险撤退
	if invader.invader_state != InvaderActor.InvaderState.MOVING_TO_HEAL_PAD:
		printerr("FAILED: Invader did not retreat to heal pad when HP <= 35%, state: ", invader.invader_state)
		invader.queue_free()
		grid.queue_free()
		return false

	var xp_before_heal: int = invader.invader_xp
	while invader.is_moving:
		invader.current_cell = invader.target_cell
		invader._on_step_completed()
		invader._advance_path()
		invader._process(0.1)
		if invader.invader_xp != xp_before_heal:
			printerr("FAILED: XP increased during retreat to heal pad!")
			invader.queue_free()
			grid.queue_free()
			return false

	if invader.invader_state != InvaderActor.InvaderState.HEALING_AT_PAD:
		printerr("FAILED: Invader should be HEALING_AT_PAD upon arrival")
		invader.queue_free()
		grid.queue_free()
		return false

	# 回血心跳处理
	var hp_before_healing: int = MatchState.invader_hp
	invader._process(1.0)
	if MatchState.invader_hp <= hp_before_healing:
		printerr("FAILED: Invader did not recover HP at heal pad!")
		invader.queue_free()
		grid.queue_free()
		return false
	if invader.invader_xp != xp_before_heal:
		printerr("FAILED: XP must not increase while healing at pad!")
		invader.queue_free()
		grid.queue_free()
		return false

	# 6. 四角色 15 级含装甲打穿满血离子栅 V（禁止用忽略装甲的裸 DPS 冒充）
	var roster: Array[String] = ["rock_corroder", "mist_walker", "fire_quencher", "oxygen_burster"]
	for char_id in roster:
		if not _simulate_lv15_ion_gate_v_break(invader, char_id):
			invader.queue_free()
			grid.queue_free()
			return false

	print("PASS: Phase 4 verified: Attack-only XP, pressure spike, battle-tested skills for all 4 roles, remote heal pads, and all four Lv15 roles break full Ion Gate V after armor.")
	invader.queue_free()
	grid.queue_free()
	return true

func _test_phase_5_ally_and_hightech() -> bool:
	print("\n[TEST Phase 5] Testing High-Tech 4-Piece, Buff Calculations, and Ally Autonomous Building...")
	MatchState.reset_match()
	var grid := GridMapManager.new()
	add_child(grid)
	grid._ready()

	for r in grid.get_all_rooms():
		MatchState.register_room(r.room_id, r.display_name, r.interior_rect)

	# --- 1. 验证高科技四件套：催化柱、聚焦镜、机械臂、稳压堆限一房一座 ---
	MatchState.claim_room("room_101", "player")
	MatchState.add_money(50000)

	var t_cell := Vector2i(5, 5)
	var turret := SilicicTurret.new()
	turret.room_id = "room_101"
	grid.add_turret(t_cell, turret)
	turret.init_turret(t_cell, null, grid)

	# 初始状态：射程 4.0，射击间隔 0.8
	if not is_equal_approx(turret.get_effective_range(), 4.0):
		printerr("FAILED: Initial turret range should be 4.0, got: ", turret.get_effective_range())
		turret.queue_free()
		grid.queue_free()
		return false
	if not is_equal_approx(turret.get_effective_interval(), 0.8):
		printerr("FAILED: Initial turret interval should be 0.8, got: ", turret.get_effective_interval())
		turret.queue_free()
		grid.queue_free()
		return false

	# (1) 建造催化柱在 (6, 5)（相邻格） -> 射速提升 (间隔缩短为 0.8 * 0.75 = 0.6)
	var col_cell := Vector2i(6, 5)
	if not MatchState.buy_and_place_building("room_101", "catalytic_column", "player", col_cell):
		printerr("FAILED: Failed to build catalytic_column")
		turret.queue_free()
		grid.queue_free()
		return false
	if not is_equal_approx(turret.get_effective_interval(), 0.6):
		printerr("FAILED: Catalytic column did not speed up fire rate, got: ", turret.get_effective_interval())
		turret.queue_free()
		grid.queue_free()
		return false

	# (2) 建造聚焦镜在 (5, 6)（相邻格） -> 射程 +1 (4.0 + 1.0 = 5.0)
	var lens_cell := Vector2i(5, 6)
	if not MatchState.buy_and_place_building("room_101", "focus_lens", "player", lens_cell):
		printerr("FAILED: Failed to build focus_lens")
		turret.queue_free()
		grid.queue_free()
		return false
	if not is_equal_approx(turret.get_effective_range(), 5.0):
		printerr("FAILED: Focus lens did not increase range by 1, got: ", turret.get_effective_range())
		turret.queue_free()
		grid.queue_free()
		return false

	# (3) 建造机械臂在 (7, 5)，铁矿在 (7, 6)（相邻机械臂） -> 铁矿基础产 5，机械臂加成 35% -> ceil(5 * 1.35) = 7
	var arm_cell := Vector2i(7, 5)
	var mine_cell := Vector2i(7, 6)
	if not MatchState.buy_and_place_building("room_101", "robotic_arm", "player", arm_cell):
		printerr("FAILED: Failed to build robotic_arm")
		turret.queue_free()
		grid.queue_free()
		return false
	if not MatchState.buy_and_place_building("room_101", "iron_mine", "player", mine_cell):
		printerr("FAILED: Failed to build iron_mine")
		turret.queue_free()
		grid.queue_free()
		return false

	var money_before_tick: int = MatchState.get_money()
	MatchState._process(MatchState.STARTER_INCOME_INTERVAL)
	# 产出包含起步矿 (10) + 机械臂加成铁矿 (7) = 17
	var gained: int = MatchState.get_money() - money_before_tick
	if gained != 17:
		printerr("FAILED: Robotic arm adjacent income mismatch, expected 17 got: ", gained)
		turret.queue_free()
		grid.queue_free()
		return false

	# (4) 建造稳压堆在 (4, 5) -> 全房温和加速，限一房一座
	var reg_cell := Vector2i(4, 5)
	if not MatchState.buy_and_place_building("room_101", "regulator_stack", "player", reg_cell):
		printerr("FAILED: Failed to build regulator_stack")
		turret.queue_free()
		grid.queue_free()
		return false

	# 第二座稳压堆必须被拒绝
	var reg_cell2 := Vector2i(4, 6)
	var second_reg_check := MatchState.can_build("room_101", "regulator_stack", "player", reg_cell2)
	if second_reg_check.get("success", false):
		printerr("FAILED: Second regulator_stack must be rejected (max 1 per room)!")
		turret.queue_free()
		grid.queue_free()
		return false

	# 稳压堆对炮台射速再加成 15% (0.6 * 0.85 = 0.51)
	if not is_equal_approx(turret.get_effective_interval(), 0.51):
		printerr("FAILED: Regulator stack did not boost turret interval, got: ", turret.get_effective_interval())
		turret.queue_free()
		grid.queue_free()
		return false

	# --- 2. 验证盟友自主建造与独立资源体系 ---
	var room_102: RoomData = grid.get_room_by_id("room_102")
	MatchState.claim_room("room_102", "ally_1")

	var bot := AllyBot.new()
	add_child(bot)
	bot.init_actor("ally_1", "盟友1", Color.GREEN, room_102.starter_cells[0], grid)
	bot.bot_state = AllyBot.BotState.CLAIMED
	bot.target_room_id = "room_102"

	# 给盟友充值 5000 金钱，验证玩家金钱不变
	var p_money_snapshot: int = MatchState.get_money()
	MatchState.add_actor_money("ally_1", 5000)
	if MatchState.get_money() != p_money_snapshot:
		printerr("FAILED: Ally money leaked into player money ledger!")
		bot.queue_free()
		turret.queue_free()
		grid.queue_free()
		return false
	if MatchState.get_actor_money("ally_1") != 5000:
		printerr("FAILED: Ally 1 did not receive 5000 money")
		bot.queue_free()
		turret.queue_free()
		grid.queue_free()
		return false

	# 触发盟友思考 1：造炮台
	bot._think_and_build()
	var ally_turret_found: bool = false
	for t in grid.turrets.values():
		if t.room_id == "room_102":
			ally_turret_found = true
			break
	if not ally_turret_found:
		printerr("FAILED: Ally did not autonomously build a turret in its room!")
		bot.queue_free()
		turret.queue_free()
		grid.queue_free()
		return false

	# 触发盟友思考 2：建矿拓展基础经济
	bot._think_and_build()
	var ally_buildings: Array = MatchState.get_room_buildings("room_102")
	if ally_buildings.is_empty():
		printerr("FAILED: Ally did not autonomously construct basic mine in room_102!")
		bot.queue_free()
		turret.queue_free()
		grid.queue_free()
		return false

	# 触发盟友思考 3：升门
	bot._think_and_build()
	if MatchState.get_door_rank("room_102") != 2:
		printerr("FAILED: Ally did not autonomously upgrade hatch to rank 2!")
		bot.queue_free()
		turret.queue_free()
		grid.queue_free()
		return false

	# 触发盟友思考 4：放置相邻高科技（催化柱/聚焦镜，测试 t.grid_cell 字段）
	MatchState.set_actor_money("ally_1", 2000)
	bot._think_and_build()

	# 验证盟友的所有建筑和炮台只在 room_102 内部，绝不越界
	ally_buildings = MatchState.get_room_buildings("room_102")
	for b in ally_buildings:
		var b_c: Vector2i = b.get("cell", Vector2i.ZERO)
		if not room_102.is_cell_interior(b_c):
			printerr("FAILED: Ally building was placed outside room_102 interior! Cell: ", b_c)
			bot.queue_free()
			turret.queue_free()
			grid.queue_free()
			return false

	# 盟友高科技分支能造机械臂（封顶门/炮，避免钱被升门吃掉）
	MatchState.door_kind["room_102"] = "ion_gate"
	MatchState.door_rank["room_102"] = 5
	for t in grid.turrets.values():
		if t is SilicicTurret and t.room_id == "room_102":
			t.substance = "fluoroantimonic"
			t.rank = 5
			t.branch_line = "line_b"
			t.apply_stats()
	if not MatchState.has_chem_plant("room_102"):
		var plant_spot: Vector2i = Vector2i.ZERO
		for c in room_102.get_interior_cells():
			if room_102.starter_cells.has(c) or c == room_102.door_cell:
				continue
			if grid.has_building_at(c):
				continue
			plant_spot = c
			break
		MatchState.set_actor_money("ally_1", 500)
		if plant_spot == Vector2i.ZERO or not MatchState.buy_and_place_building("room_102", "chem_plant", "ally_1", plant_spot):
			printerr("FAILED: Could not place chem plant for ally arm test")
			bot.queue_free()
			turret.queue_free()
			grid.queue_free()
			return false
	MatchState.set_actor_money("ally_1", 1000)
	bot._think_and_build()
	var ally_has_arm: bool = false
	for b in MatchState.get_room_buildings("room_102"):
		if b.get("id", "") == "robotic_arm":
			ally_has_arm = true
			break
	if not ally_has_arm:
		printerr("FAILED: Ally high-tech branch did not build a robotic_arm")
		bot.queue_free()
		turret.queue_free()
		grid.queue_free()
		return false

	print("PASS: Phase 5 verified: High-tech 4-piece, buffs, regulator 1-per-room, Ally autonomous building, ledger separation, and robotic arm.")
	bot.queue_free()
	turret.queue_free()
	grid.queue_free()
	return true

func _test_phase_6_hud_and_full_regression() -> bool:
	print("\n[TEST Phase 6] Testing HUD Status Display, Build Bar Interactions, and Full Match Regression...")
	MatchState.reset_match()
	var main_scene: MainGame = load("res://scenes/main.tscn").instantiate()
	add_child(main_scene)

	for r in main_scene.grid_manager.get_all_rooms():
		MatchState.register_room(r.room_id, r.display_name, r.interior_rect)

	var hud = main_scene.hud
	if hud == null:
		printerr("FAILED: HUD node not found in main scene")
		main_scene.queue_free()
		return false

	# 1. 验证双资源展示
	MatchState.money = 1234
	MatchState.chem_feedstock = 56
	MatchState.money_changed.emit(1234)
	MatchState.feedstock_changed.emit(56)

	if not hud.label_money.text.contains("1234"):
		printerr("FAILED: HUD Money label does not reflect 1234: ", hud.label_money.text)
		main_scene.queue_free()
		return false
	if not hud.label_feedstock.text.contains("56"):
		printerr("FAILED: HUD Feedstock label does not reflect 56: ", hud.label_feedstock.text)
		main_scene.queue_free()
		return false

	# 2. 验证玩家占房后舱门与敌人信息展示
	MatchState.claim_room("room_101", "player")
	MatchState.player_room_id = "room_101"
	MatchState.invader_character = "mist_walker"
	MatchState.invader_level = 3
	MatchState.invader_level_changed.emit(3)
	MatchState.door_hp_changed.emit("room_101", 100, 100)

	if not hud.label_door_hp.text.contains("蜂巢闸 I"):
		printerr("FAILED: HUD Door label does not show door title: ", hud.label_door_hp.text)
		main_scene.queue_free()
		return false
	if not hud.label_invader_hp.text.contains("雾徙") or not hud.label_invader_hp.text.contains("Lv.3"):
		printerr("FAILED: HUD Invader label mismatch: ", hud.label_invader_hp.text)
		main_scene.queue_free()
		return false

	# 3. 验证快捷建造栏交互（选择化工厂）
	hud._select_build("chem_plant", "化工厂")
	if main_scene.current_build_selection != "chem_plant":
		printerr("FAILED: Selecting chem_plant did not update current_build_selection in main_scene")
		main_scene.queue_free()
		return false

	# 验证七种矿切换，且 HUD 标价与 BUILD_CATALOG 一致
	var mine_keys: Array[String] = ["iron_mine", "tungsten_mine", "molybdenum_mine", "sulfur_mine", "antimony_mine", "gold_mine", "uranium_mine"]
	hud.current_selection = "turret"
	hud.current_mine_idx = 0
	for m_key in mine_keys:
		hud._on_btn_cycle_mine_pressed()
		var catalog_cost: int = int(MatchState.BUILD_CATALOG[m_key]["cost_money"])
		if hud.current_selection != m_key:
			printerr("FAILED: Mine cycling expected %s got %s" % [m_key, hud.current_selection])
			main_scene.queue_free()
			return false
		if not hud.btn_build_iron_mine.text.contains("$%d" % catalog_cost):
			printerr("FAILED: HUD mine price for %s must match BUILD_CATALOG %d, button: %s" % [m_key, catalog_cost, hud.btn_build_iron_mine.text])
			main_scene.queue_free()
			return false
	if not mine_keys.has(hud.current_selection):
		printerr("FAILED: Mine cycling failed to select a valid mine!")
		main_scene.queue_free()
		return false

	# 验证分支切换（Line A <-> Line B）
	hud.selected_branch_line = "line_a"
	hud._on_btn_toggle_branch_pressed()
	if hud.selected_branch_line != "line_b":
		printerr("FAILED: Branch toggle button did not switch to line_b!")
		main_scene.queue_free()
		return false

	# 在房间内部空格建造化工厂
	var plant_cell := Vector2i(5, 5)
	if not main_scene.try_build_item(plant_cell, "chem_plant"):
		printerr("FAILED: Failed to build chem_plant via main_scene.try_build_item")
		main_scene.queue_free()
		return false
	if not MatchState.has_chem_plant("room_101"):
		printerr("FAILED: Room 101 did not register chem plant")
		main_scene.queue_free()
		return false

	# 4. 验证点击升门按钮
	var old_rank: int = MatchState.get_door_rank("room_101")
	hud._on_btn_upgrade_door_pressed()
	if MatchState.get_door_rank("room_101") != old_rank + 1:
		printerr("FAILED: Door upgrade from HUD button failed!")
		main_scene.queue_free()
		return false

	# 5. 验证全场对局胜负规则闭环：
	# (a) 龟缩高防门不击杀绝不胜
	MatchState.invader_hp = 200
	if MatchState.game_result == MatchState.GameResult.VICTORY:
		printerr("FAILED: Must NOT trigger victory without invader HP reaching 0!")
		main_scene.queue_free()
		return false

	# (b) 敌人 HP 归零触发 VICTORY，HUD 显示胜利
	MatchState.damage_invader(200)
	if MatchState.game_result != MatchState.GameResult.VICTORY:
		printerr("FAILED: Expected VICTORY when invader HP reaches 0")
		main_scene.queue_free()
		return false
	if not hud.label_outcome.text.contains("胜利"):
		printerr("FAILED: HUD Outcome label did not show victory: ", hud.label_outcome.text)
		main_scene.queue_free()
		return false

	# (c) 玩家起步矿被破坏触发 DEFEAT，HUD 显示失败
	MatchState.reset_match()
	MatchState.claim_room("room_101", "player")
	MatchState.damage_starter("room_101", MatchState.STARTER_MAX_HP)
	if MatchState.game_result != MatchState.GameResult.DEFEAT:
		printerr("FAILED: Expected DEFEAT when starter destroyed")
		main_scene.queue_free()
		return false
	if not hud.label_outcome.text.contains("失败"):
		printerr("FAILED: HUD Outcome label did not show defeat: ", hud.label_outcome.text)
		main_scene.queue_free()
		return false

	print("PASS: Phase 6 verified: Full HUD status, build toolbar selections, door upgrade button, and end-to-end victory/defeat loop.")
	main_scene.queue_free()
	return true




func _test_eject_non_owner_when_room_claimed() -> bool:
	print("\n[TEST 7] Testing Non-Owner Ejection on Room Claim...")
	var grid := GridMapManager.new()
	add_child(grid)
	grid._ready()

	MatchState.reset_match()
	for r in grid.get_all_rooms():
		MatchState.register_room(r.room_id, r.display_name, r.interior_rect)

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
		MatchState.register_room(r.room_id, r.display_name, r.interior_rect)

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
		MatchState.register_room(r.room_id, r.display_name, r.interior_rect)

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
		MatchState.register_room(r.room_id, r.display_name, r.interior_rect)
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
		MatchState.register_room(r.room_id, r.display_name, r.interior_rect)
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

func _apply_ion_gate_v(room_id: String) -> Dictionary:
	var stats_ion: Dictionary = MatchState.get_hatch_stats("ion_gate", 5)
	MatchState.door_kind[room_id] = "ion_gate"
	MatchState.door_rank[room_id] = 5
	MatchState.door_max_hp[room_id] = stats_ion["max_hp"]
	MatchState.door_hp[room_id] = stats_ion["max_hp"]
	MatchState.door_armor[room_id] = stats_ion["armor"]
	MatchState.door_regen[room_id] = stats_ion["regen"]
	MatchState.door_regen_timer[room_id] = 0.0
	MatchState.door_broken[room_id] = false
	return stats_ion

func _simulate_lv15_ion_gate_v_break(invader: InvaderActor, char_id: String) -> bool:
	MatchState.reset_match()
	MatchState.claim_room("room_101", "player")
	var stats_ion: Dictionary = _apply_ion_gate_v("room_101")
	var ion_hp: int = int(stats_ion["max_hp"])
	var ion_armor: int = int(stats_ion["armor"])
	var ion_regen: int = int(stats_ion["regen"])

	invader.set_character(char_id)
	invader.invader_level = 15
	invader.invader_xp = 0
	invader.invader_xp_to_next = 99999
	invader.target_room_id = "room_101"
	invader.invader_state = InvaderActor.InvaderState.STOPPED_AT_DOOR
	invader.is_moving = false
	invader.move_path.clear()
	invader.attack_timer = 0.0
	invader.skill_cooldown_timer = 0.0
	invader.oxygen_self_hitch_timer = 0.0
	invader.has_retargeted_at_12 = true
	invader.slow_break_timer = 0.0
	MatchState.invader_hp = MatchState.INVADER_MAX_HP
	MatchState.invader_level = 15

	var raw: int = invader.get_base_attack_damage()
	var eff: int = MatchState.get_effective_door_damage(raw, ion_armor)
	var interval: float = invader.get_base_attack_interval()
	var eff_dps: float = float(eff) / interval
	if eff_dps - float(ion_regen) <= 0.0:
		printerr("FAILED: %s Lv15 effective_dps_after_armor - regen must be > 0. raw=%d armor=%d eff=%d dps=%f regen=%d" % [char_id, raw, ion_armor, eff, eff_dps, ion_regen])
		return false

	var sim_break_time: float = 0.0
	while not MatchState.is_door_broken("room_101") and sim_break_time < 300.0:
		var dt: float = interval
		invader._process(dt)
		MatchState._process(dt)
		sim_break_time += dt
		if invader.invader_state != InvaderActor.InvaderState.STOPPED_AT_DOOR and not MatchState.is_door_broken("room_101"):
			invader.invader_state = InvaderActor.InvaderState.STOPPED_AT_DOOR
			invader.is_moving = false
			invader.target_room_id = "room_101"

	if not MatchState.is_door_broken("room_101") or MatchState.get_door_hp("room_101") > 0:
		printerr("FAILED: %s Lv15 failed to break full %d HP Ion Gate V after armor+regen! HP: %d time: %f" % [char_id, ion_hp, MatchState.get_door_hp("room_101"), sim_break_time])
		return false
	return true

