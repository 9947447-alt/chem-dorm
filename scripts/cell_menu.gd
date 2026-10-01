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
	"particle_accelerator",
	"atm",
]

static func items_for_cell(cell: Vector2i, grid: GridMapManager, actor_id: String = "player") -> Array:
	var items: Array = []
	if grid == null:
		items = [_item("noop", "无法操作", false, "无效格子", "noop")]
	elif grid.turrets.has(cell):
		items = _turret_items(cell, grid, actor_id)
	else:
		var existing: Dictionary = MatchState.get_building_at_cell(cell)
		if not existing.is_empty():
			if str(existing.get("id", "")) == "chem_plant":
				items = _chem_plant_items(cell, grid, actor_id, existing)
			elif str(existing.get("category", "")) == "mine":
				items = _mine_items(cell, grid, actor_id, existing)
			else:
				items = _occupied_items(cell, grid, actor_id, existing)
		else:
			var cell_type: int = grid.cells.get(cell, GridMapManager.CellType.VOID)
			if cell_type == GridMapManager.CellType.DOOR:
				items = _door_items(cell, grid, actor_id)
			elif cell_type == GridMapManager.CellType.STARTER:
				items = _starter_items(cell, grid, actor_id)
			else:
				items = _build_items(cell, grid, actor_id, cell_type)
	items.push_front(_item("cell_title", title_for_cell(cell, grid), false, "", "title"))
	return items

static func title_for_cell(cell: Vector2i, grid: GridMapManager) -> String:
	if grid == null:
		return "无法操作"
	if grid.turrets.has(cell):
		var turret: SilicicTurret = grid.turrets[cell]
		return MatchState.get_turret_cell_title(turret.substance, turret.rank)
	var existing: Dictionary = MatchState.get_building_at_cell(cell)
	if not existing.is_empty():
		if str(existing.get("id", "")) == "chem_plant":
			return "化工厂 %s" % MatchState.get_roman_numeral(int(existing.get("level", 1)))
		return str(existing.get("name", existing.get("id", "建筑")))
	var cell_type: int = grid.cells.get(cell, GridMapManager.CellType.VOID)
	match cell_type:
		GridMapManager.CellType.DOOR:
			var room: RoomData = grid.get_room_at_cell(cell)
			if room != null:
				return MatchState.get_door_display_name(room.room_id)
			return "舱门"
		GridMapManager.CellType.STARTER:
			var s_room: RoomData = grid.get_room_by_starter_cell(cell)
			if s_room != null:
				return "起步矿 %s" % MatchState.get_roman_numeral(MatchState.get_starter_level(s_room.room_id))
			return "起步矿"
		GridMapManager.CellType.CORRIDOR, GridMapManager.CellType.ENTRANCE:
			return "走廊"
		GridMapManager.CellType.WALL:
			return "墙"
		GridMapManager.CellType.ROOM_FLOOR:
			return "空地"
		_:
			return "空地"

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

static func _catalog_feedstock_cost(item_id: String) -> int:
	if not MatchState.BUILD_CATALOG.has(item_id):
		return 0
	return int(MatchState.BUILD_CATALOG[item_id].get("cost_feedstock", 0))

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
		var cost_m: int = _catalog_cost(item_id)
		var cost_f: int = _catalog_feedstock_cost(item_id)
		var name_str: String = _catalog_name(item_id)
		var label: String = ""
		if item_id == "particle_accelerator":
			label = "粒子加速器 效果：增加炮台50%%等攻速 价格：原料%d" % cost_f
		elif item_id == "atm":
			label = "取款机 效果：每周期产出高额金币 价格：金钱%d，原料%d" % [cost_m, cost_f]
		elif cost_f > 0 and cost_m > 0:
			label = "%s ($%d, 原料%d)" % [name_str, cost_m, cost_f]
		elif cost_f > 0:
			label = "%s (原料%d)" % [name_str, cost_f]
		else:
			label = "%s ($%d)" % [name_str, cost_m]

		var reason: String = ""
		if site_reason != "":
			reason = site_reason
		elif own_reason != "":
			reason = own_reason
		elif grid.has_building_at(cell):
			reason = "该格已有建筑"
		elif MatchState.get_actor_money(actor_id) < cost_m:
			reason = "钱不够"
		elif MatchState.get_actor_feedstock(actor_id) < cost_f:
			reason = "原料不足"
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
		var extra: Dictionary = {"item_id": item_id, "cost_money": cost_m, "cost_feedstock": cost_f}
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
	var label: String = "-升级：金钱%d" % cost
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
	var label: String = "-升级：金钱%d" % cost
	return [_item("upgrade_starter", label, reason == "", reason, "upgrade_starter", {"cost_money": cost})]

static func _chem_plant_items(cell: Vector2i, grid: GridMapManager, actor_id: String, plant: Dictionary) -> Array:
	var own_reason: String = _ownership_reason(cell, grid, actor_id)
	var room_id: String = str(plant.get("room_id", ""))
	var check: Dictionary = MatchState.can_upgrade_chem_plant(room_id, actor_id, cell)
	var cost: int = int(check.get("cost_money", MatchState.get_chem_plant_upgrade_cost(int(plant.get("level", 1)))))
	var reason: String = own_reason
	if reason == "" and not check.get("success", false):
		reason = _short_reason(str(check.get("reason", "无法升级")))
	var label: String = "-升级：金钱%d" % cost
	var items: Array = [_item("upgrade_chem_plant", label, reason == "", reason, "upgrade_chem_plant", {"cost_money": cost})]
	items.append(_demolish_item(cell, grid, actor_id))
	return items

static func _mine_items(cell: Vector2i, grid: GridMapManager, actor_id: String, existing: Dictionary) -> Array:
	var items: Array = []
	var room: RoomData = grid.get_room_at_cell(cell) if grid != null else null
	var r_id: String = room.room_id if room != null else ""
	var check: Dictionary = MatchState.can_upgrade_mine(r_id, actor_id, cell)
	var own_reason: String = _ownership_reason(cell, grid, actor_id)
	var reason: String = own_reason
	var cost: int = int(check.get("cost_money", 0))
	var next_id: String = str(check.get("next_id", ""))
	var next_name: String = str(MatchState.BUILD_CATALOG.get(next_id, {}).get("name", "高级矿"))
	if reason == "" and not check.get("success", false):
		reason = _short_reason(str(check.get("reason", "无法升级")))
	var label: String = "-升级：金钱%d (升级为 %s)" % [cost, next_name] if next_id != "" else "已达最高级"
	items.append(_item("upgrade_mine", label, reason == "", reason, "upgrade_mine", {"cost_money": cost}))
	items.append(_demolish_item(cell, grid, actor_id))
	return items

static func _occupied_items(cell: Vector2i, grid: GridMapManager, actor_id: String, existing: Dictionary) -> Array:
	var b_id: String = str(existing.get("id", ""))
	var name: String = str(existing.get("name", existing.get("id", "建筑")))
	var desc: String = "已建成"
	if b_id == "particle_accelerator":
		desc = "效果：增加炮台50%等攻速"
	elif b_id == "atm":
		desc = "效果：每周期产出高额金币"
	elif b_id == "regulator_stack":
		desc = "效果：全房经济+15%，炮台射速+15%"
	elif b_id == "catalytic_column":
		desc = "效果：相邻炮台射速+25%"
	elif b_id == "focus_lens":
		desc = "效果：相邻炮台射程+1.0"
	elif b_id == "robotic_arm":
		desc = "效果：相邻矿山产出+35%"

	var items: Array = [_item("occupied", "%s（%s）" % [name, desc], false, "不能升级", "noop")]
	items.append(_demolish_item(cell, grid, actor_id))
	return items

static func _demolish_item(cell: Vector2i, grid: GridMapManager, actor_id: String) -> Dictionary:
	var room: RoomData = grid.get_room_at_cell(cell) if grid != null else null
	var r_id: String = room.room_id if room != null else ""
	var check: Dictionary = MatchState.can_demolish(r_id, actor_id, cell, grid)
	var own_reason: String = _ownership_reason(cell, grid, actor_id)
	var reason: String = own_reason
	if reason == "" and not check.get("success", false):
		reason = _short_reason(str(check.get("reason", "不可拆除")))
	var refund_m: int = int(check.get("refund_money", 0))
	var refund_f: int = int(check.get("refund_feedstock", 0))
	var label: String = ""
	if refund_f > 0:
		label = "-摧毁：回收金钱%d，原料%d" % [refund_m, refund_f]
	else:
		label = "-摧毁：回收金钱%d" % refund_m
	return _item("demolish", label, reason == "", reason, "demolish", {"refund_money": refund_m, "refund_feedstock": refund_f})

static func _turret_items(cell: Vector2i, grid: GridMapManager, actor_id: String) -> Array:
	var turret: SilicicTurret = grid.turrets[cell]
	var own_reason: String = _ownership_reason(cell, grid, actor_id)
	var items: Array = []
	if turret.substance == "carbonate" and turret.rank >= 5 and turret.branch_line == "":
		items.append(_branch_item(turret, actor_id, own_reason, "line_a", "次氯酸"))
		items.append(_branch_item(turret, actor_id, own_reason, "line_b", "盐酸"))
		items.append(_demolish_item(cell, grid, actor_id))
		return items
	var check: Dictionary = MatchState.can_upgrade_turret(turret)
	var cost_m: int = int(check.get("cost_money", 0))
	var cost_f: int = int(check.get("cost_feedstock", 0))
	var reason: String = own_reason
	if reason == "" and not check.get("success", false):
		reason = _short_reason(str(check.get("reason", "无法升级")))
	elif reason == "" and MatchState.get_actor_money(actor_id) < cost_m:
		reason = "钱不够"
	elif reason == "" and MatchState.get_actor_feedstock(actor_id) < cost_f:
		reason = "原料不足"
	var label: String = ""
	if cost_f > 0:
		label = "-升级：金钱%d，化学原料%d" % [cost_m, cost_f]
	else:
		label = "-升级：金钱%d" % cost_m
	items.append(_item("upgrade_turret", label, reason == "", reason, "upgrade_turret", {"cost_money": cost_m, "cost_feedstock": cost_f}))
	items.append(_demolish_item(cell, grid, actor_id))
	return items

static func _branch_item(turret: SilicicTurret, actor_id: String, own_reason: String, branch: String, title: String) -> Dictionary:
	var check: Dictionary = MatchState.can_upgrade_turret(turret, branch)
	var cost_m: int = int(check.get("cost_money", 500))
	var cost_f: int = int(check.get("cost_feedstock", 20))
	var reason: String = own_reason
	if reason == "" and not check.get("success", false):
		reason = _short_reason(str(check.get("reason", "无法换线")))
	elif reason == "" and MatchState.get_actor_money(actor_id) < cost_m:
		reason = "钱不够"
	elif reason == "" and MatchState.get_actor_feedstock(actor_id) < cost_f:
		reason = "原料不足"
	var label: String = "-升级换线为 %s：金钱%d，化学原料%d" % [title, cost_m, cost_f]
	return _item("switch_line:%s" % branch, label, reason == "", reason, "switch_line", {"branch": branch, "cost_money": cost_m, "cost_feedstock": cost_f})

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
