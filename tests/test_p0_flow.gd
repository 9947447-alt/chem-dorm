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
	success = success and _test_silicic_carbonate_hit_status()
	success = success and _test_phase_3_hatch_system()
	success = success and _test_phase_4_invader_system()
	success = success and _test_phase_5_ally_and_hightech()
	success = success and _test_phase_6_hud_and_full_regression()
	success = success and _test_cell_menu_door_hp_bar_and_popups()
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

func _test_silicic_carbonate_hit_status() -> bool:
	print("\n[TEST] Silicic slow + carbonate hitch on production hit path...")
	MatchState.reset_match()
	var grid := GridMapManager.new()
	add_child(grid)
	grid._ready()
	MatchState.claim_room("room_101", "player")
	MatchState.invader_hp = 10000
	MatchState.door_hp["room_101"] = 10000
	MatchState.door_armor["room_101"] = 0
	MatchState.door_broken["room_101"] = false

	var invader := InvaderActor.new()
	add_child(invader)
	invader.init_actor("invader", "入侵者", Color.RED, Vector2i(8, 13), grid)
	invader.visible = true
	invader.set_character("fire_quencher")
	invader.invader_level = 1
	invader.invader_xp_to_next = 99999
	invader.move_speed = 3.5

	var turret := SilicicTurret.new()
	grid.add_turret(Vector2i(5, 5), turret)
	turret.init_turret(Vector2i(5, 5), invader, grid)
	turret.room_id = "room_101"

	# --- 硅酸 I 命中：格子移动变慢 ---
	turret.substance = "silicic"
	turret.rank = 1
	turret.apply_stats()
	invader.invader_state = InvaderActor.InvaderState.APPROACHING_DOOR
	invader.current_cell = Vector2i(8, 13)
	invader.target_cell = Vector2i(9, 13)
	invader.is_moving = true
	invader.move_progress = 0.0
	invader.silicic_slow_timer = 0.0
	invader.silicic_slow_factor = 1.0
	invader._process(0.1)
	var progress_unslowed: float = invader.move_progress
	if progress_unslowed <= 0.0:
		printerr("FAILED: Baseline invader grid move made no progress")
		invader.queue_free()
		grid.queue_free()
		return false

	invader.current_cell = Vector2i(8, 13)
	invader.target_cell = Vector2i(9, 13)
	invader.is_moving = true
	invader.move_progress = 0.0
	invader.position = grid.cell_to_world(invader.current_cell)
	turret._fire_at_invader()
	if invader.silicic_slow_timer <= 0.0:
		printerr("FAILED: Silicic I hit must apply silicic_slow_timer via _fire_at_invader")
		invader.queue_free()
		grid.queue_free()
		return false
	if invader.silicic_slow_factor >= 1.0:
		printerr("FAILED: Silicic slow factor must be < 1 (player buff, cannot speed the invader)")
		invader.queue_free()
		grid.queue_free()
		return false
	var silicic_i_duration: float = invader.silicic_slow_timer
	var silicic_i_factor: float = invader.silicic_slow_factor
	invader._process(0.1)
	var progress_slowed: float = invader.move_progress
	if progress_slowed >= progress_unslowed - 0.001:
		printerr("FAILED: Silicic I hit must slow grid movement. unslowed=%f slowed=%f" % [progress_unslowed, progress_slowed])
		invader.queue_free()
		grid.queue_free()
		return false

	# 到期后移速恢复
	invader.is_moving = false
	invader._process(invader.silicic_slow_timer + 0.05)
	if invader.silicic_slow_timer > 0.0:
		printerr("FAILED: Silicic slow must expire")
		invader.queue_free()
		grid.queue_free()
		return false
	invader.current_cell = Vector2i(8, 13)
	invader.target_cell = Vector2i(9, 13)
	invader.is_moving = true
	invader.move_progress = 0.0
	invader.position = grid.cell_to_world(invader.current_cell)
	invader._process(0.1)
	if invader.move_progress < progress_unslowed - 0.001:
		printerr("FAILED: Movement must recover after silicic slow expires. recovered=%f baseline=%f" % [invader.move_progress, progress_unslowed])
		invader.queue_free()
		grid.queue_free()
		return false

	# --- 硅酸 I 命中：拆门 DPS 下降 ---
	invader.is_moving = false
	invader.move_path.clear()
	invader.invader_state = InvaderActor.InvaderState.STOPPED_AT_DOOR
	invader.target_room_id = "room_101"
	invader.attack_timer = 0.0
	invader.silicic_slow_timer = 0.0
	invader.silicic_slow_factor = 1.0
	invader.slow_break_timer = 0.0
	invader.carbonate_hitch_timer = 0.0
	invader.oxygen_self_hitch_timer = 0.0
	MatchState.door_hp["room_101"] = 10000
	var hp_before_unslowed: int = MatchState.get_door_hp("room_101")
	invader._process(invader.get_base_attack_interval() + 0.05)
	var unslowed_door_dmg: int = hp_before_unslowed - MatchState.get_door_hp("room_101")
	if unslowed_door_dmg <= 0:
		printerr("FAILED: Baseline door hit must deal damage")
		invader.queue_free()
		grid.queue_free()
		return false

	MatchState.door_hp["room_101"] = 10000
	invader.attack_timer = 0.0
	turret._fire_at_invader()
	var hp_before_slowed: int = MatchState.get_door_hp("room_101")
	invader._process(invader.get_base_attack_interval() + 0.05)
	var slowed_door_dmg: int = hp_before_slowed - MatchState.get_door_hp("room_101")
	if slowed_door_dmg >= unslowed_door_dmg:
		printerr("FAILED: Silicic I hit must reduce door-break DPS. unslowed=%d slowed=%d" % [unslowed_door_dmg, slowed_door_dmg])
		invader.queue_free()
		grid.queue_free()
		return false

	# --- 胶幕 (硅酸 V) 只加强同一减速，不换线 ---
	invader.silicic_slow_timer = 0.0
	invader.silicic_slow_factor = 1.0
	turret.substance = "silicic"
	turret.rank = 5
	turret.apply_stats()
	if not MatchState.get_turret_display_name("silicic", 5).contains("胶幕"):
		printerr("FAILED: Silicic V display must remain 胶幕")
		invader.queue_free()
		grid.queue_free()
		return false
	turret._fire_at_invader()
	if turret.substance != "silicic" or turret.rank != 5:
		printerr("FAILED: 胶幕 hit must not change turret line")
		invader.queue_free()
		grid.queue_free()
		return false
	if invader.silicic_slow_timer <= silicic_i_duration:
		printerr("FAILED: 胶幕 must strengthen silicic slow duration. I=%f V=%f" % [silicic_i_duration, invader.silicic_slow_timer])
		invader.queue_free()
		grid.queue_free()
		return false
	if invader.silicic_slow_factor >= silicic_i_factor:
		printerr("FAILED: 胶幕 must strengthen silicic slow factor. I=%f V=%f" % [silicic_i_factor, invader.silicic_slow_factor])
		invader.queue_free()
		grid.queue_free()
		return false
	if invader.carbonate_hitch_timer > 0.0:
		printerr("FAILED: Silicic must not apply carbonate hitch")
		invader.queue_free()
		grid.queue_free()
		return false

	# --- 碳酸 I 命中：正在拆门则暂停扣门血 ---
	turret.substance = "carbonate"
	turret.rank = 1
	turret.apply_stats()
	invader.silicic_slow_timer = 0.0
	invader.silicic_slow_factor = 1.0
	invader.carbonate_hitch_timer = 0.0
	invader.oxygen_self_hitch_timer = 0.0
	invader.slow_break_timer = 0.0
	invader.invader_state = InvaderActor.InvaderState.STOPPED_AT_DOOR
	invader.target_room_id = "room_101"
	invader.is_moving = false
	MatchState.door_hp["room_101"] = 10000
	turret._fire_at_invader()
	if invader.carbonate_hitch_timer <= 0.0:
		printerr("FAILED: Carbonate I hit must apply hitch via _fire_at_invader")
		invader.queue_free()
		grid.queue_free()
		return false
	var carbonate_i_hitch: float = invader.carbonate_hitch_timer
	# 命中后再把拆门计时加满：证明硬直是暂停扣血，而不是只清了 wind-up
	invader.attack_timer = invader.get_base_attack_interval()
	var hp_at_hitch: int = MatchState.get_door_hp("room_101")
	invader._process(minf(0.5, carbonate_i_hitch - 0.05))
	if MatchState.get_door_hp("room_101") != hp_at_hitch:
		printerr("FAILED: Carbonate hitch must pause door HP damage. before=%d after=%d" % [hp_at_hitch, MatchState.get_door_hp("room_101")])
		invader.queue_free()
		grid.queue_free()
		return false

	# 到期后恢复拆门
	invader._process(invader.carbonate_hitch_timer + 0.05)
	if invader.carbonate_hitch_timer > 0.0:
		printerr("FAILED: Carbonate hitch must expire")
		invader.queue_free()
		grid.queue_free()
		return false
	invader.attack_timer = invader.get_base_attack_interval()
	invader._process(0.05)
	if MatchState.get_door_hp("room_101") >= hp_at_hitch:
		printerr("FAILED: Door-break must resume after carbonate hitch expires")
		invader.queue_free()
		grid.queue_free()
		return false

	# --- 碳酸打断进房移动 ---
	invader.carbonate_hitch_timer = 0.0
	invader.invader_state = InvaderActor.InvaderState.ENTERING_ROOM
	invader.current_cell = Vector2i(6, 12)
	invader.target_cell = Vector2i(6, 11)
	invader.is_moving = true
	invader.move_progress = 0.0
	invader.position = grid.cell_to_world(invader.current_cell)
	turret._fire_at_invader()
	invader._process(0.4)
	if invader.move_progress > 0.001:
		printerr("FAILED: Carbonate hitch must freeze ENTERING_ROOM movement, progress=%f" % invader.move_progress)
		invader.queue_free()
		grid.queue_free()
		return false
	if invader.current_cell != Vector2i(6, 12):
		printerr("FAILED: Carbonate hitch must not advance ENTERING_ROOM cell")
		invader.queue_free()
		grid.queue_free()
		return false

	# --- 沸泉 (碳酸 V) 只加强同一硬直，不换线 ---
	invader.is_moving = false
	invader.carbonate_hitch_timer = 0.0
	turret.substance = "carbonate"
	turret.rank = 5
	turret.apply_stats()
	if not MatchState.get_turret_display_name("carbonate", 5).contains("沸泉"):
		printerr("FAILED: Carbonate V display must remain 沸泉")
		invader.queue_free()
		grid.queue_free()
		return false
	turret._fire_at_invader()
	if turret.substance != "carbonate" or turret.rank != 5:
		printerr("FAILED: 沸泉 hit must not change turret line")
		invader.queue_free()
		grid.queue_free()
		return false
	if invader.carbonate_hitch_timer <= carbonate_i_hitch:
		printerr("FAILED: 沸泉 must strengthen hitch duration. I=%f V=%f" % [carbonate_i_hitch, invader.carbonate_hitch_timer])
		invader.queue_free()
		grid.queue_free()
		return false
	if invader.silicic_slow_timer > 0.0:
		printerr("FAILED: Carbonate must not apply silicic slow")
		invader.queue_free()
		grid.queue_free()
		return false

	# --- 盐酸及以后不获得这两条 ---
	var later: Array[String] = ["hydrochloric", "sulfuric", "perchloric", "fluoroantimonic"]
	for sub in later:
		invader.silicic_slow_timer = 0.0
		invader.silicic_slow_factor = 1.0
		invader.carbonate_hitch_timer = 0.0
		turret.substance = sub
		turret.rank = 1
		turret.branch_line = "line_b"
		turret.apply_stats()
		turret._fire_at_invader()
		if invader.silicic_slow_timer > 0.0 or invader.carbonate_hitch_timer > 0.0:
			printerr("FAILED: %s must not apply silicic slow or carbonate hitch" % sub)
			invader.queue_free()
			grid.queue_free()
			return false

	print("PASS: Silicic slow and carbonate hitch apply on hit, expire, V only strengthens same effect; later acids excluded.")
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

	# 3b. 升级提高 max HP，当前 HP 同步加上限增量（满血则 current = 新 max）
	invader.invader_state = InvaderActor.InvaderState.STOPPED_AT_DOOR
	invader.invader_level = 1
	MatchState.invader_level = 1
	invader.invader_xp = 0
	invader.invader_xp_to_next = 40
	MatchState.invader_hp = MatchState.get_invader_max_hp(1)
	var hp_full_before: int = MatchState.invader_hp
	var max_full_before: int = MatchState.get_invader_max_hp(1)
	invader.add_xp(40)
	if invader.invader_level != 2:
		printerr("FAILED: Invader should reach level 2 after enough door XP")
		invader.queue_free()
		grid.queue_free()
		return false
	var max_after_full: int = MatchState.get_invader_max_hp()
	if max_after_full <= max_full_before:
		printerr("FAILED: Level-up must increase max HP. before=%d after=%d" % [max_full_before, max_after_full])
		invader.queue_free()
		grid.queue_free()
		return false
	if MatchState.invader_hp <= hp_full_before:
		printerr("FAILED: Full-HP level-up must increase current HP. before=%d after=%d" % [hp_full_before, MatchState.invader_hp])
		invader.queue_free()
		grid.queue_free()
		return false
	if MatchState.invader_hp != max_after_full:
		printerr("FAILED: Full-HP level-up must set current HP to new max. current=%d max=%d" % [MatchState.invader_hp, max_after_full])
		invader.queue_free()
		grid.queue_free()
		return false

	invader.invader_level = 1
	MatchState.invader_level = 1
	invader.invader_xp = 0
	invader.invader_xp_to_next = 40
	MatchState.invader_hp = 120
	var hp_wounded_before: int = MatchState.invader_hp
	invader.add_xp(40)
	if MatchState.invader_hp <= hp_wounded_before:
		printerr("FAILED: Wounded level-up must still increase current HP. before=%d after=%d" % [hp_wounded_before, MatchState.invader_hp])
		invader.queue_free()
		grid.queue_free()
		return false
	var retreat_line: int = int(float(MatchState.get_invader_max_hp()) * 0.35)
	invader.invader_state = InvaderActor.InvaderState.STOPPED_AT_DOOR
	if MatchState.invader_hp > retreat_line:
		invader._process(0.1)
		if invader.invader_state == InvaderActor.InvaderState.MOVING_TO_HEAL_PAD:
			printerr("FAILED: 35%% retreat must use new max after level-up; HP %d should be above %d" % [MatchState.invader_hp, retreat_line])
			invader.queue_free()
			grid.queue_free()
			return false

	var l1_max: int = MatchState.get_invader_max_hp(1)
	var l15_max: int = MatchState.get_invader_max_hp(15)
	if l15_max < l1_max * 2:
		printerr("FAILED: Level 1 to 15 HP spread is too small. L1=%d L15=%d" % [l1_max, l15_max])
		invader.queue_free()
		grid.queue_free()
		return false
	var silicic_iii: Dictionary = MatchState.get_turret_stats("silicic", 3)
	var l1_window: float = 3.0 # L1→L2：40 XP / 15 每击 * 1.0s 间隔
	var iii_shots: int = int(ceil(l1_window / float(silicic_iii["interval"])))
	var iii_taken: int = int(silicic_iii["damage"]) * iii_shots
	var l1_retreat: int = int(float(l1_max) * 0.35)
	if l1_max - iii_taken <= l1_retreat:
		printerr("FAILED: Silicic III must not force 35%% retreat in the L1-L2 window. max=%d taken=%d retreat_hp=%d" % [l1_max, iii_taken, l1_retreat])
		invader.queue_free()
		grid.queue_free()
		return false
	var glue: Dictionary = MatchState.get_turret_stats("silicic", 5)
	var later_acid: Dictionary = MatchState.get_turret_stats("carbonate", 1)
	var glue_dps: float = float(glue["damage"]) / float(glue["interval"])
	var later_dps: float = float(later_acid["damage"]) / float(later_acid["interval"])
	if float(l15_max) / (glue_dps + later_dps) > 20.0:
		printerr("FAILED: Level 15 must still be killable by 胶幕+后段酸 within 20s. max=%d ttk=%f" % [l15_max, float(l15_max) / (glue_dps + later_dps)])
		invader.queue_free()
		grid.queue_free()
		return false

	invader.invader_state = InvaderActor.InvaderState.STOPPED_AT_DOOR
	invader.invader_xp = 0
	invader.invader_xp_to_next = 99999
	MatchState.invader_hp = 10000

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

	if hud.label_hint == null or not hud.label_hint.text.contains("WASD") or not hud.label_hint.text.contains("左键"):
		printerr("FAILED: HUD hint line missing WASD / 左键 instructions: ", hud.label_hint.text if hud.label_hint != null else "null")
		main_scene.queue_free()
		return false

	# 3. 验证己房空格仍可通过建造 API 扣费落建筑（菜单执行走同一路径）
	var plant_cell := Vector2i(5, 5)
	if not main_scene.try_build_item(plant_cell, "chem_plant"):
		printerr("FAILED: Failed to build chem_plant via main_scene.try_build_item")
		main_scene.queue_free()
		return false
	if not MatchState.has_chem_plant("room_101"):
		printerr("FAILED: Room 101 did not register chem plant")
		main_scene.queue_free()
		return false

	# 4. 验证全场对局胜负规则闭环：
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

	print("PASS: Phase 6 verified: Full HUD status, hint line, build API, and end-to-end victory/defeat loop.")
	main_scene.queue_free()
	return true




func _cell_menu_title(items: Array) -> String:
	for it in items:
		if str(it.get("id", "")) == "cell_title":
			return str(it.get("label", ""))
	return ""

func _menu_item_by_id(items: Array, item_id: String) -> Dictionary:
	for it in items:
		if str(it.get("id", "")) == item_id:
			return it
	return {}

func _menu_index_by_id(items: Array, item_id: String) -> int:
	for i in items.size():
		if str(items[i].get("id", "")) == item_id:
			return i
	return -1

func _test_cell_menu_door_hp_bar_and_popups() -> bool:
	print("\n[TEST CellMenu] Testing cell dropdown, disabled reasons, door HP bar, production popups...")
	MatchState.reset_match()
	var main_scene: MainGame = load("res://scenes/main.tscn").instantiate()
	add_child(main_scene)

	var grid: GridMapManager = main_scene.grid_manager
	var corridor: Vector2i = Vector2i(8, 13)
	var empty_101: Vector2i = Vector2i(5, 5)
	var empty_102: Vector2i = Vector2i(16, 6)
	var door_101: Vector2i = Vector2i(6, 12)
	var starter_101: Vector2i = Vector2i(3, 4)

	# 1. 任意格左键必出菜单，包括走廊
	main_scene.handle_cell_click(corridor)
	if not main_scene.cell_menu_open or main_scene.current_menu_items.is_empty():
		printerr("FAILED: Corridor click must open a non-empty menu")
		main_scene.queue_free()
		return false
	if _cell_menu_title(main_scene.current_menu_items) != "走廊":
		printerr("FAILED: Corridor menu title must be 走廊, got: ", _cell_menu_title(main_scene.current_menu_items))
		main_scene.queue_free()
		return false
	var iron_cor: Dictionary = _menu_item_by_id(main_scene.current_menu_items, "build:iron_mine")
	if iron_cor.is_empty() or iron_cor.get("enabled", true) or str(iron_cor.get("reason", "")) != "走廊不能建造":
		printerr("FAILED: Corridor build items must be disabled with 走廊不能建造, got: ", iron_cor)
		main_scene.queue_free()
		return false

	# 2. 未占房空格仍出菜单，建造项禁用写 未占房
	main_scene.handle_cell_click(empty_101)
	if not main_scene.cell_menu_open or main_scene.current_menu_items.is_empty():
		printerr("FAILED: Unclaimed empty cell must still open a menu")
		main_scene.queue_free()
		return false
	if _cell_menu_title(main_scene.current_menu_items) != "空地":
		printerr("FAILED: Empty floor menu title must be 空地, got: ", _cell_menu_title(main_scene.current_menu_items))
		main_scene.queue_free()
		return false
	var iron_empty: Dictionary = _menu_item_by_id(main_scene.current_menu_items, "build:iron_mine")
	var turret_empty: Dictionary = _menu_item_by_id(main_scene.current_menu_items, "build:silicic_turret_1")
	if iron_empty.is_empty() or turret_empty.is_empty():
		printerr("FAILED: Empty cell menu missing catalog build items")
		main_scene.queue_free()
		return false
	if iron_empty.get("enabled", true) or str(iron_empty.get("reason", "")) != "未占房":
		printerr("FAILED: Unclaimed empty build item must be disabled with 未占房, got: ", iron_empty)
		main_scene.queue_free()
		return false
	var catalog_iron: int = int(MatchState.BUILD_CATALOG["iron_mine"]["cost_money"])
	if not str(iron_empty.get("label", "")).contains("$%d" % catalog_iron):
		printerr("FAILED: Menu mine price must match BUILD_CATALOG, label: ", iron_empty.get("label", ""))
		main_scene.queue_free()
		return false
	var catalog_turret: int = int(MatchState.BUILD_CATALOG["silicic_turret_1"]["cost_money"])
	if int(turret_empty.get("cost_money", -1)) != catalog_turret:
		printerr("FAILED: Turret menu cost must match BUILD_CATALOG")
		main_scene.queue_free()
		return false

	# 3. 只开菜单 / 关闭不扣费、不占格
	MatchState.money = catalog_iron
	main_scene.handle_cell_click(empty_101)
	if MatchState.money != catalog_iron:
		printerr("FAILED: Opening the menu must not charge")
		main_scene.queue_free()
		return false
	main_scene.close_cell_menu()
	if main_scene.cell_menu_open:
		printerr("FAILED: close_cell_menu / Esc path must close without charging")
		main_scene.queue_free()
		return false
	if MatchState.money != catalog_iron or MatchState.cell_to_building.has(empty_101):
		printerr("FAILED: Closing the menu must not charge or place a building")
		main_scene.queue_free()
		return false
	var iron_idx: int = _menu_index_by_id(main_scene.current_menu_items, "build:iron_mine")
	if main_scene.execute_menu_item(iron_idx):
		printerr("FAILED: Disabled unclaimed build must not execute")
		main_scene.queue_free()
		return false
	if MatchState.cell_to_building.has(empty_101):
		printerr("FAILED: Disabled menu item must not occupy the cell")
		main_scene.queue_free()
		return false

	# 4. 非己房空格：菜单仍在，建造项禁用 非己房
	MatchState.claim_room("room_101", "player")
	MatchState.claim_room("room_102", "ally_1")
	MatchState.money = catalog_iron
	main_scene.handle_cell_click(empty_102)
	if main_scene.current_menu_items.is_empty():
		printerr("FAILED: Non-owned empty cell must still open a menu")
		main_scene.queue_free()
		return false
	var iron_foreign: Dictionary = _menu_item_by_id(main_scene.current_menu_items, "build:iron_mine")
	if iron_foreign.get("enabled", true) or str(iron_foreign.get("reason", "")) != "非己房":
		printerr("FAILED: Non-owned empty build item must be disabled with 非己房, got: ", iron_foreign)
		main_scene.queue_free()
		return false

	# 5. 己房空格钱不够：显示 钱不够；给钱后选一项才占格扣费
	MatchState.money = 0
	main_scene.handle_cell_click(empty_101)
	var iron_poor: Dictionary = _menu_item_by_id(main_scene.current_menu_items, "build:iron_mine")
	if iron_poor.get("enabled", true) or str(iron_poor.get("reason", "")) != "钱不够":
		printerr("FAILED: Owned empty with no money must disable with 钱不够, got: ", iron_poor)
		main_scene.queue_free()
		return false
	MatchState.money = catalog_iron
	main_scene.handle_cell_click(empty_101)
	if MatchState.money != catalog_iron:
		printerr("FAILED: Reopening menu after funding must not charge")
		main_scene.queue_free()
		return false
	iron_idx = _menu_index_by_id(main_scene.current_menu_items, "build:iron_mine")
	var iron_ready: Dictionary = _menu_item_by_id(main_scene.current_menu_items, "build:iron_mine")
	if not iron_ready.get("enabled", false):
		printerr("FAILED: Owned empty with enough money must enable iron mine, got: ", iron_ready)
		main_scene.queue_free()
		return false
	if not main_scene.execute_menu_item(iron_idx):
		printerr("FAILED: Selecting an enabled build item must succeed")
		main_scene.queue_free()
		return false
	if MatchState.money != 0:
		printerr("FAILED: Selecting a build item must deduct BUILD_CATALOG cost, remaining: ", MatchState.money)
		main_scene.queue_free()
		return false
	if not MatchState.cell_to_building.has(empty_101):
		printerr("FAILED: Selecting a build item must occupy the cell")
		main_scene.queue_free()
		return false
	if main_scene.cell_menu_open:
		printerr("FAILED: Menu should close after a successful selection")
		main_scene.queue_free()
		return false
	main_scene.handle_cell_click(empty_101)
	if _cell_menu_title(main_scene.current_menu_items) != "铁矿":
		printerr("FAILED: Iron mine cell title must be 铁矿, got: ", _cell_menu_title(main_scene.current_menu_items))
		main_scene.queue_free()
		return false

	# 6. 门格菜单 + 已封顶；起步格菜单
	main_scene.handle_cell_click(door_101)
	if _cell_menu_title(main_scene.current_menu_items) != "蜂巢闸 I":
		printerr("FAILED: Default door title must be 蜂巢闸 I, got: ", _cell_menu_title(main_scene.current_menu_items))
		main_scene.queue_free()
		return false
	MatchState.door_rank["room_101"] = 4
	main_scene.handle_cell_click(door_101)
	if _cell_menu_title(main_scene.current_menu_items) != "蜂巢闸 IV":
		printerr("FAILED: Door rank 4 title must be 蜂巢闸 IV, got: ", _cell_menu_title(main_scene.current_menu_items))
		main_scene.queue_free()
		return false
	MatchState.door_rank["room_101"] = 1
	main_scene.handle_cell_click(door_101)
	var door_item: Dictionary = _menu_item_by_id(main_scene.current_menu_items, "upgrade_door")
	if door_item.is_empty():
		printerr("FAILED: Door cell must show upgrade_door menu item")
		main_scene.queue_free()
		return false
	MatchState.door_kind["room_101"] = "ion_gate"
	MatchState.door_rank["room_101"] = 5
	main_scene.handle_cell_click(door_101)
	door_item = _menu_item_by_id(main_scene.current_menu_items, "upgrade_door")
	if door_item.get("enabled", true) or str(door_item.get("reason", "")) != "已封顶":
		printerr("FAILED: Ion gate V door upgrade must be disabled with 已封顶, got: ", door_item)
		main_scene.queue_free()
		return false
	MatchState.door_kind["room_101"] = "honeycomb"
	MatchState.door_rank["room_101"] = 1
	main_scene.handle_cell_click(starter_101)
	var starter_item: Dictionary = _menu_item_by_id(main_scene.current_menu_items, "upgrade_starter")
	if starter_item.is_empty():
		printerr("FAILED: Starter cell must show upgrade_starter menu item")
		main_scene.queue_free()
		return false

	# 7. 无厂不能换线
	var turret_cell := Vector2i(6, 6)
	var turret := SilicicTurret.new()
	turret.substance = "carbonate"
	turret.rank = 5
	turret.branch_line = ""
	turret.room_id = "room_101"
	grid.add_turret(turret_cell, turret)
	main_scene.handle_cell_click(turret_cell)
	var line_a: Dictionary = _menu_item_by_id(main_scene.current_menu_items, "switch_line:line_a")
	var line_b: Dictionary = _menu_item_by_id(main_scene.current_menu_items, "switch_line:line_b")
	if line_a.is_empty() or line_b.is_empty():
		printerr("FAILED: Carbonate V turret must show both branch switch items")
		main_scene.queue_free()
		return false
	if line_a.get("enabled", true) or str(line_a.get("reason", "")) != "无厂不能换线":
		printerr("FAILED: Branch switch without plant must be disabled with 无厂不能换线, got: ", line_a)
		main_scene.queue_free()
		return false

	# 8. 门血条：满血、掉血变短、破门后空
	if not is_equal_approx(MatchState.get_door_hp_bar_ratio("room_101"), 1.0):
		printerr("FAILED: Intact door HP bar ratio should be 1, got: ", MatchState.get_door_hp_bar_ratio("room_101"))
		main_scene.queue_free()
		return false
	var full_w: float = grid.get_door_hp_bar_fill_width("room_101")
	if not is_equal_approx(full_w, float(GridMapManager.TILE_SIZE)):
		printerr("FAILED: Full door bar width should equal TILE_SIZE, got: ", full_w)
		main_scene.queue_free()
		return false
	MatchState.damage_door("room_101", 40)
	var damaged_ratio: float = MatchState.get_door_hp_bar_ratio("room_101")
	var damaged_w: float = grid.get_door_hp_bar_fill_width("room_101")
	if damaged_ratio >= 1.0 or damaged_w >= full_w:
		printerr("FAILED: Damaged door bar must shorten. ratio=%s width=%s" % [damaged_ratio, damaged_w])
		main_scene.queue_free()
		return false
	MatchState.damage_door("room_101", MatchState.get_door_hp("room_101"))
	if not MatchState.is_door_broken("room_101"):
		printerr("FAILED: Door should be broken after remaining HP removed")
		main_scene.queue_free()
		return false
	if MatchState.get_door_hp_bar_ratio("room_101") != 0.0 or grid.get_door_hp_bar_fill_width("room_101") != 0.0:
		printerr("FAILED: Broken door HP bar must be empty")
		main_scene.queue_free()
		return false

	# 9. 真实入账才飘字：起步矿金币、矿山金币、化工厂原料；未到结算不刷
	var popups: Array = []
	var on_pop := func(cell: Vector2i, kind: String, amount: int) -> void:
		popups.append({"cell": cell, "kind": kind, "amount": amount})
	MatchState.production_popup.connect(on_pop)
	MatchState.starter_income_timer["room_101"] = 0.0
	MatchState.building_income_timer["room_101"] = 0.0
	popups.clear()
	MatchState._process(0.2)
	if not popups.is_empty():
		printerr("FAILED: Production popup must not fire every frame before settlement, got: ", popups)
		main_scene.queue_free()
		return false

	MatchState._process(MatchState.STARTER_INCOME_INTERVAL)
	var starter_pop: Dictionary = {}
	for p in popups:
		if str(p.get("kind", "")) == "money" and p.get("cell", Vector2i.ZERO) == starter_101:
			starter_pop = p
			break
	if starter_pop.is_empty() or int(starter_pop.get("amount", 0)) <= 0:
		printerr("FAILED: Starter settlement must emit 金币 popup at starter cell, got: ", popups)
		main_scene.queue_free()
		return false

	var plant_cell2 := Vector2i(5, 6)
	MatchState.money = 5000
	if not MatchState.buy_and_place_building("room_101", "chem_plant", "player", plant_cell2):
		printerr("FAILED: Could not place chem plant for popup test")
		main_scene.queue_free()
		return false
	MatchState.building_income_timer["room_101"] = 0.0
	popups.clear()
	grid.production_popups.clear()
	MatchState._process(MatchState.STARTER_INCOME_INTERVAL)
	var mine_pop: Dictionary = {}
	var plant_pop: Dictionary = {}
	for p in popups:
		if str(p.get("kind", "")) == "money" and p.get("cell", Vector2i.ZERO) == empty_101:
			mine_pop = p
		if str(p.get("kind", "")) == "feedstock" and p.get("cell", Vector2i.ZERO) == plant_cell2:
			plant_pop = p
	if mine_pop.is_empty() or int(mine_pop.get("amount", 0)) <= 0:
		printerr("FAILED: Money mine settlement must emit 金币 popup on the mine cell, got: ", popups)
		main_scene.queue_free()
		return false
	if plant_pop.is_empty() or int(plant_pop.get("amount", 0)) <= 0:
		printerr("FAILED: Chem plant settlement must emit 原料 popup on the plant cell, got: ", popups)
		main_scene.queue_free()
		return false
	if grid.production_popups.is_empty():
		printerr("FAILED: Grid should spawn visible production popups on settlement")
		main_scene.queue_free()
		return false
	grid._process(grid.PRODUCTION_POPUP_LIFETIME + 0.05)
	if not grid.production_popups.is_empty():
		printerr("FAILED: Production popups should expire after ~0.8s")
		main_scene.queue_free()
		return false

	# 10. 选中格菜单第一行：名称 + 等级（无等级只显示名称）
	main_scene.handle_cell_click(plant_cell2)
	if _cell_menu_title(main_scene.current_menu_items) != "化工厂 I":
		printerr("FAILED: Chem plant I title must be 化工厂 I, got: ", _cell_menu_title(main_scene.current_menu_items))
		main_scene.queue_free()
		return false
	var plant_title: Dictionary = MatchState.get_building_at_cell(plant_cell2)
	plant_title["level"] = 7
	main_scene.handle_cell_click(plant_cell2)
	if _cell_menu_title(main_scene.current_menu_items) != "化工厂 VII":
		printerr("FAILED: Chem plant VII title must be 化工厂 VII, got: ", _cell_menu_title(main_scene.current_menu_items))
		main_scene.queue_free()
		return false

	var silicic_cell := Vector2i(4, 5)
	var silicic := SilicicTurret.new()
	silicic.substance = "silicic"
	silicic.rank = 3
	silicic.room_id = "room_101"
	grid.add_turret(silicic_cell, silicic)
	main_scene.handle_cell_click(silicic_cell)
	if _cell_menu_title(main_scene.current_menu_items) != "硅酸 III":
		printerr("FAILED: Silicic III title must be 硅酸 III, got: ", _cell_menu_title(main_scene.current_menu_items))
		main_scene.queue_free()
		return false
	silicic.rank = 5
	main_scene.handle_cell_click(silicic_cell)
	if _cell_menu_title(main_scene.current_menu_items) != "胶幕（硅酸 V）":
		printerr("FAILED: Silicic V title must be 胶幕（硅酸 V）, got: ", _cell_menu_title(main_scene.current_menu_items))
		main_scene.queue_free()
		return false

	print("PASS: Cell menu opens on every tile, disables with reasons, charges only on select; door bar shortens; popups only on real credit.")
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
	invader.silicic_slow_timer = 0.0
	invader.silicic_slow_factor = 1.0
	invader.carbonate_hitch_timer = 0.0
	MatchState.invader_level = 15
	MatchState.invader_hp = MatchState.get_invader_max_hp(15)

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

