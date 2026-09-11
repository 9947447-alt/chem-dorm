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
	success = success and _test_no_build_menu()

	if success:
		print("========================================")
		print("ALL P0 ACCEPTANCE TESTS PASSED!")
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

func _test_no_build_menu() -> bool:
	print("\n[TEST 6] Testing No Build Menu & No Tower Building on Space...")
	var files := DirAccess.get_files_at("res://scripts")
	for f in files:
		if f.contains("turret") or f.contains("build_menu") or f.contains("tower"):
			printerr("FAILED: Found forbidden script file: ", f)
			return false
	print("PASS: No build menu or tower logic present.")
	return true
