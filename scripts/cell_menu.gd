class_name CellMenu
extends RefCounted

const BUILD_IDS: Array[String] = [
	"silicic_turret_1",
	"iron_mine",
	"tungsten_mine",
	"molybdenum_mine",
	"sulfur_mine",
	"antimony_mine",
	"gold_mine",
	"uranium_mine",
	"chem_plant",
	"catalytic_column",
	"focus_lens",
	"robotic_arm",
	"regulator_stack",
]

static func items_for_cell(cell: Vector2i, grid: GridMapManager, actor_id: String = "player") -> Array:
	if grid == null:
		return [_item("noop", "无法操作", false, "无效格子", "noop")]

	if grid.turrets.has(cell):
		return _turret_items(cell, grid, actor_id)

	var existing: Dictionary = MatchState.get_building_at_cell(cell)
	if not existing.is_empty():
		if str(existing.get("id", "")) == "chem_plant":
			return _chem_plant_items(cell, grid, actor_id, existing)
		return _occupied_items(existing)

	var cell_type: int = grid.cells.get(cell, GridMapManager.CellType.VOID)
	if cell_type == GridMapManager.CellType.DOOR:
		return _door_items(cell, grid, actor_id)
	if cell_type == GridMapManager.CellType.STARTER:
		return _starter_items(cell, grid, actor_id)
	return _build_items(cell, grid, actor_id, cell_type)

static func _item(id: String, label: String, enabled: bool, reason: String, action: String, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {
		"id": id,
		"label": label,
		"enabled": enabled,
		"reason": "" if enabled else reason,
		"action": action,
	}
	for k in extra.keys():
		d[k] = extra[k]
	return d

static func _catalog_cost(item_id: String) -> int:
	if not MatchState.BUILD_CATALOG.has(item_id):
		return 0
	return int(MatchState.BUILD_CATALOG[item_id].get("cost_money", 0))

static func _catalog_name(item_id: String) -> String:
	if not MatchState.BUILD_CATALOG.has(item_id):
		return item_id
	return str(MatchState.BUILD_CATALOG[item_id].get("name", item_id))

static func _ownership_reason(cell: Vector2i, grid: GridMapManager, actor_id: String) -> String:
	var owned_room: String = ""
	if actor_id == "player":
		owned_room = MatchState.get_player_owned_room_id()
	else:
		for r_id in MatchState.room_owners.keys():
			if str(MatchState.room_owners[r_id]) == actor_id:
				owned_room = str(r_id)
				break
	if owned_room == "":
		return "未占房"
	var room: RoomData = grid.get_room_at_cell(cell)
	if room == null:
		room = grid.get_room_by_starter_cell(cell)
	if room == null or MatchState.get_room_owner(room.room_id) != actor_id:
		return "非己房"
	return ""

static func _site_reason(cell_type: int) -> String:
	match cell_type:
		GridMapManager.CellType.CORRIDOR, GridMapManager.CellType.ENTRANCE:
			return "走廊不能建造"
		GridMapManager.CellType.WALL:
			return "墙格不能建造"
		GridMapManager.CellType.VOID:
			return "无效格子"
		GridMapManager.CellType.DOOR:
			return "门格不能建造"
		GridMapManager.CellType.STARTER:
			return "起步矿不能建造"
	return ""

static func _build_items(cell: Vector2i, grid: GridMapManager, actor_id: String, cell_type: int) -> Array:
	var items: Array = []
	var site_reason: String = _site_reason(cell_type)
	var own_reason: String = _ownership_reason(cell, grid, actor_id)
	for item_id in BUILD_IDS:
		var cost: int = _catalog_cost(item_id)
		var label: String = "%s ($%d)" % [_catalog_name(item_id), cost]
		var reason: String = ""
		if site_reason != "":
			reason = site_reason
		elif own_reason != "":
			reason = own_reason
		elif grid.has_building_at(cell):
			reason = "该格已有建筑"
		elif MatchState.get_actor_money(actor_id) < cost:
			reason = "钱不够"
		else:
			if item_id != "silicic_turret_1":
				var room: RoomData = grid.get_room_at_cell(cell)
				if room != null:
					var check: Dictionary = MatchState.can_build(room.room_id, item_id, actor_id, cell)
					if not check.get("success", false):
						reason = _short_reason(str(check.get("reason", "无法建造")))
			else:
				var room_t: RoomData = grid.get_room_at_cell(cell)
				if room_t == null or not room_t.is_cell_interior(cell) or room_t.is_cell_starter(cell) or cell == room_t.door_cell:
					reason = "该格不能建造"
		var extra: Dictionary = {"item_id": item_id, "cost_money": cost}
		var action: String = "build_turret" if item_id == "silicic_turret_1" else "build_item"
		items.append(_item("build:%s" % item_id, label, reason == "", reason, action, extra))
	return items

static func _door_items(cell: Vector2i, grid: GridMapManager, actor_id: String) -> Array:
	var room: RoomData = grid.get_room_at_cell(cell)
	var own_reason: String = _ownership_reason(cell, grid, actor_id)
	var cost: int = 0
	var reason: String = own_reason
	if room != null:
		var check: Dictionary = MatchState.can_upgrade_door(room.room_id, actor_id)
		cost = int(check.get("cost_money", MatchState.get_door_upgrade_cost(MatchState.get_door_kind(room.room_id), MatchState.get_door_rank(room.room_id))))
		if reason == "":
			if not check.get("success", false):
				reason = _short_reason(str(check.get("reason", "无法升级")))
	else:
		if reason == "":
			reason = "无效格子"
	var label: String = "升级舱门 ($%d)" % cost
	return [_item("upgrade_door", label, reason == "", reason, "upgrade_door", {"cost_money": cost})]

static func _starter_items(cell: Vector2i, grid: GridMapManager, actor_id: String) -> Array:
	var room: RoomData = grid.get_room_by_starter_cell(cell)
	var own_reason: String = _ownership_reason(cell, grid, actor_id)
	var cost: int = 0
	var reason: String = own_reason
	if room != null:
		cost = MatchState.get_starter_upgrade_cost(room.room_id)
		if reason == "":
			if MatchState.get_starter_hp(room.room_id) <= 0:
				reason = "起步矿已毁"
			elif MatchState.get_actor_money(actor_id) < cost:
				reason = "钱不够"
	else:
		if reason == "":
			reason = "无效格子"
	var label: String = "升级起步矿 ($%d)" % cost
	return [_item("upgrade_starter", label, reason == "", reason, "upgrade_starter", {"cost_money": cost})]

static func _chem_plant_items(cell: Vector2i, grid: GridMapManager, actor_id: String, plant: Dictionary) -> Array:
	var own_reason: String = _ownership_reason(cell, grid, actor_id)
	var room_id: String = str(plant.get("room_id", ""))
	var check: Dictionary = MatchState.can_upgrade_chem_plant(room_id, actor_id, cell)
	var cost: int = int(check.get("cost_money", MatchState.get_chem_plant_upgrade_cost(int(plant.get("level", 1)))))
	var reason: String = own_reason
	if reason == "" and not check.get("success", false):
		reason = _short_reason(str(check.get("reason", "无法升级")))
	var label: String = "升级化工厂 ($%d)" % cost
	return [_item("upgrade_chem_plant", label, reason == "", reason, "upgrade_chem_plant", {"cost_money": cost})]

static func _occupied_items(existing: Dictionary) -> Array:
	var name: String = str(existing.get("name", existing.get("id", "建筑")))
	return [_item("occupied", "%s（已建成）" % name, false, "不能升级", "noop")]

static func _turret_items(cell: Vector2i, grid: GridMapManager, actor_id: String) -> Array:
	var turret: SilicicTurret = grid.turrets[cell]
	var own_reason: String = _ownership_reason(cell, grid, actor_id)
	var items: Array = []
	if turret.substance == "carbonate" and turret.rank >= 5 and turret.branch_line == "":
		items.append(_branch_item(turret, actor_id, own_reason, "line_a", "换线 A 次氯酸"))
		items.append(_branch_item(turret, actor_id, own_reason, "line_b", "换线 B 盐酸"))
		return items
	var check: Dictionary = MatchState.can_upgrade_turret(turret)
	var cost: int = int(check.get("cost_money", 0))
	var reason: String = own_reason
	if reason == "" and not check.get("success", false):
		reason = _short_reason(str(check.get("reason", "无法升级")))
	elif reason == "" and MatchState.get_actor_money(actor_id) < cost:
		reason = "钱不够"
	var label: String = "升级炮台 ($%d)" % cost
	items.append(_item("upgrade_turret", label, reason == "", reason, "upgrade_turret", {"cost_money": cost}))
	return items

static func _branch_item(turret: SilicicTurret, actor_id: String, own_reason: String, branch: String, title: String) -> Dictionary:
	var check: Dictionary = MatchState.can_upgrade_turret(turret, branch)
	var cost: int = int(check.get("cost_money", 500))
	var reason: String = own_reason
	if reason == "" and not check.get("success", false):
		reason = _short_reason(str(check.get("reason", "无法换线")))
	elif reason == "" and MatchState.get_actor_money(actor_id) < cost:
		reason = "钱不够"
	var label: String = "%s ($%d)" % [title, cost]
	return _item("switch_line:%s" % branch, label, reason == "", reason, "switch_line", {"branch": branch, "cost_money": cost})

static func _short_reason(raw: String) -> String:
	if raw.contains("未占房"):
		return "未占房"
	if raw.contains("只能在自己") or raw.contains("只能升级自己") or raw.contains("非己房"):
		return "非己房"
	if raw.contains("金钱不足") or raw.contains("钱不够"):
		return "钱不够"
	if raw.contains("无厂"):
		return "无厂不能换线"
	if raw.contains("封顶") or raw.contains("终极物质") or raw.contains("已达最高"):
		return "已封顶"
	if raw.contains("已破"):
		return "已破不能升"
	if raw.contains("原料不足"):
		return "原料不足"
	return raw
