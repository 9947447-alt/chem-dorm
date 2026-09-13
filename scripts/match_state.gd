extends Node

signal countdown_tick(remaining: float)
signal phase_changed(new_phase: int)
signal room_claimed(room_id: String, actor_id: String)
signal player_room_changed(room_id: String)
signal money_changed(new_amount: int)
signal feedstock_changed(new_amount: int)
signal building_added(room_id: String, building_data: Dictionary)
signal starter_upgraded(room_id: String, new_level: int)
signal game_over(result: int)
signal door_hp_changed(room_id: String, current_hp: int, max_hp: int)
signal starter_hp_changed(room_id: String, current_hp: int, max_hp: int)
signal invader_hp_changed(current_hp: int, max_hp: int)
signal invader_level_up(character: String, new_level: int)
signal invader_level_changed(new_level: int)
signal production_popup(cell: Vector2i, kind: String, amount: int)

enum Phase {
	COUNTDOWN,
	INVADING
}

enum GameResult {
	NONE,
	VICTORY,
	DEFEAT
}

# --- 常数定义集中区 ---
# 起步矿经济常数
const STARTER_INCOME_INTERVAL: float = 1.0
const STARTER_INCOME_AMOUNT: int = 10
const STARTER_MAX_HP: int = 100

# 建造表（统一供玩家与盟友使用）
const BUILD_CATALOG: Dictionary = {
	"iron_mine": {
		"id": "iron_mine",
		"name": "铁矿",
		"category": "mine",
		"cost_money": 60,
		"cost_feedstock": 0,
		"income_money": 5,
		"income_feedstock": 0,
		"max_per_room": 999
	},
	"tungsten_mine": {
		"id": "tungsten_mine",
		"name": "钨矿",
		"category": "mine",
		"cost_money": 150,
		"cost_feedstock": 0,
		"income_money": 15,
		"income_feedstock": 0,
		"max_per_room": 999
	},
	"molybdenum_mine": {
		"id": "molybdenum_mine",
		"name": "钼矿",
		"category": "mine",
		"cost_money": 300,
		"cost_feedstock": 0,
		"income_money": 35,
		"income_feedstock": 0,
		"max_per_room": 999
	},
	"sulfur_mine": {
		"id": "sulfur_mine",
		"name": "硫矿",
		"category": "mine",
		"cost_money": 600,
		"cost_feedstock": 0,
		"income_money": 75,
		"income_feedstock": 0,
		"max_per_room": 999
	},
	"antimony_mine": {
		"id": "antimony_mine",
		"name": "锑矿",
		"category": "mine",
		"cost_money": 1200,
		"cost_feedstock": 0,
		"income_money": 160,
		"income_feedstock": 0,
		"max_per_room": 999
	},
	"gold_mine": {
		"id": "gold_mine",
		"name": "金矿",
		"category": "mine",
		"cost_money": 2500,
		"cost_feedstock": 0,
		"income_money": 350,
		"income_feedstock": 0,
		"max_per_room": 999
	},
	"uranium_mine": {
		"id": "uranium_mine",
		"name": "铀矿",
		"category": "mine",
		"cost_money": 5000,
		"cost_feedstock": 0,
		"income_money": 800,
		"income_feedstock": 0,
		"max_per_room": 1 # 铀一房一座
	},
	"chem_plant": {
		"id": "chem_plant",
		"name": "化工厂",
		"category": "chem_plant",
		"cost_money": 200,
		"cost_feedstock": 0,
		"income_money": 0,
		"income_feedstock": 5, # I 档基础原料；升级只加快此项
		"max_per_room": 999
	},
	"silicic_turret_1": {
		"id": "silicic_turret_1",
		"name": "硅酸炮台 I",
		"category": "turret",
		"cost_money": 100,
		"cost_feedstock": 0,
		"income_money": 0,
		"income_feedstock": 0,
		"max_per_room": 999
	},
	"catalytic_column": {
		"id": "catalytic_column",
		"name": "催化柱",
		"category": "high_tech",
		"cost_money": 800,
		"cost_feedstock": 0,
		"income_money": 0,
		"income_feedstock": 0,
		"max_per_room": 999
	},
	"focus_lens": {
		"id": "focus_lens",
		"name": "聚焦镜",
		"category": "high_tech",
		"cost_money": 600,
		"cost_feedstock": 0,
		"income_money": 0,
		"income_feedstock": 0,
		"max_per_room": 999
	},
	"robotic_arm": {
		"id": "robotic_arm",
		"name": "机械臂",
		"category": "high_tech",
		"cost_money": 1000,
		"cost_feedstock": 0,
		"income_money": 0,
		"income_feedstock": 0,
		"max_per_room": 999
	},
	"regulator_stack": {
		"id": "regulator_stack",
		"name": "稳压堆",
		"category": "high_tech",
		"cost_money": 2000,
		"cost_feedstock": 0,
		"income_money": 0,
		"income_feedstock": 0,
		"max_per_room": 1 # 稳压堆一房一座
	}
}

# 硅酸炮台 I 常数（基础数值）
const TURRET_COST: int = 100
const TURRET_RANGE: float = 4.0
const TURRET_FIRE_INTERVAL: float = 0.8
const TURRET_DAMAGE: int = 25

# 舱门常数
const DOOR_MAX_HP: int = 100

# 化工厂 I–XV（原地、花钱、只加快化学原料）
const CHEM_PLANT_MAX_LEVEL: int = 15
const CHEM_PLANT_BASE_FEEDSTOCK: int = 5
const ROMAN_NUMERALS: Array[String] = [
	"", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX",
	"X", "XI", "XII", "XIII", "XIV", "XV"
]

# 敌人常数
# 生命曲线：1 级 400；每升 1 级 max += 80（15 级 1520）。升级时当前 HP 同步加上限增量（满血则 current = 新 max，不按缺口比例回满）。
const INVADER_MAX_HP: int = 400
const INVADER_HP_PER_LEVEL: int = 80
const INVADER_LEVEL_CAP: int = 15
const INVADER_ATTACK_DAMAGE: int = 20
const INVADER_ATTACK_INTERVAL: float = 1.0
# 15 级基础拆伤必须在扣装甲后仍高于离子栅 V 回血：
# ion V armor 225 + regen 52 * interval 0.6 = 256.2；360 - 225 = 135，DPS 225，净 173
const INVADER_LV15_ATTACK_DAMAGE: int = 360
const INVADER_LV15_ATTACK_INTERVAL: float = 0.6

var current_phase: Phase = Phase.COUNTDOWN
var countdown_remaining: float = 25.0
var money: int = 0
var chem_feedstock: int = 0
var actor_resources: Dictionary = {} # actor_id -> {"money": int, "feedstock": int}
var room_owners: Dictionary = {} # String (room_id) -> String (actor_id)
var room_locked: Dictionary = {} # String (room_id) -> bool
var room_display_names: Dictionary = {} # String (room_id) -> String (display_name)
var room_interior: Dictionary = {} # String (room_id) -> Rect2i
var room_starter_cells: Dictionary = {} # String (room_id) -> Array (Vector2i)
var player_room_id: String = "" # "" represents corridor/outside

# 经济与建筑运行时状态
var starter_level: Dictionary = {} # room_id -> int
var room_buildings: Dictionary = {} # room_id -> Array[Dictionary]
var cell_to_building: Dictionary = {} # Vector2i -> Dictionary
var building_income_timer: Dictionary = {} # room_id -> float

# 舱门三十档运行时状态
var door_kind: Dictionary = {} # room_id -> String
var door_rank: Dictionary = {} # room_id -> int
var door_max_hp: Dictionary = {} # room_id -> int
var door_regen: Dictionary = {} # room_id -> int
var door_armor: Dictionary = {} # room_id -> int
var door_regen_timer: Dictionary = {} # room_id -> float

# V0 对局运行时状态
var game_result: GameResult = GameResult.NONE
var door_hp: Dictionary = {} # String (room_id) -> int
var starter_hp: Dictionary = {} # String (room_id) -> int
var door_broken: Dictionary = {} # String (room_id) -> bool
var starter_income_timer: Dictionary = {} # String (room_id) -> float
var invader_hp: int = INVADER_MAX_HP
var invader_target_room_id: String = ""
var invader_character: String = "rock_corroder"
var invader_level: int = 1
var invader_xp: int = 0
var invader_status_text: String = "" # 可选 HUD：胶滞 / 沸断

func _ready() -> void:
	reset_match()

func reset_match(countdown_duration: float = 25.0) -> void:
	current_phase = Phase.COUNTDOWN
	countdown_remaining = countdown_duration
	money = 0
	chem_feedstock = 0
	actor_resources.clear()
	room_owners.clear()
	room_locked.clear()
	room_display_names.clear()
	room_interior.clear()
	room_starter_cells.clear()
	player_room_id = ""
	game_result = GameResult.NONE
	door_hp.clear()
	starter_hp.clear()
	door_broken.clear()
	starter_income_timer.clear()
	starter_level.clear()
	room_buildings.clear()
	cell_to_building.clear()
	building_income_timer.clear()
	door_kind.clear()
	door_rank.clear()
	door_max_hp.clear()
	door_regen.clear()
	door_armor.clear()
	door_regen_timer.clear()
	invader_hp = INVADER_MAX_HP
	invader_target_room_id = ""
	
	# 四角色真正随机抽取一个 (rock_corroder, mist_walker, fire_quencher, oxygen_burster)
	const ROSTER: Array[String] = ["rock_corroder", "mist_walker", "fire_quencher", "oxygen_burster"]
	invader_character = ROSTER[randi() % ROSTER.size()]
	invader_level = 1
	invader_xp = 0
	invader_status_text = ""

func register_room(room_id: String, display_name: String = "", interior: Rect2i = Rect2i(), starter_cells: Array = []) -> void:
	if not room_owners.has(room_id):
		room_owners[room_id] = ""
		room_locked[room_id] = false
		door_kind[room_id] = "honeycomb"
		door_rank[room_id] = 1
		door_max_hp[room_id] = DOOR_MAX_HP
		door_regen[room_id] = 0
		door_armor[room_id] = 0
		door_regen_timer[room_id] = 0.0
		door_hp[room_id] = DOOR_MAX_HP
		starter_hp[room_id] = STARTER_MAX_HP
		door_broken[room_id] = false
		starter_income_timer[room_id] = 0.0
		starter_level[room_id] = 1
		room_buildings[room_id] = []
		building_income_timer[room_id] = 0.0
	if display_name != "":
		room_display_names[room_id] = display_name
	elif not room_display_names.has(room_id):
		room_display_names[room_id] = room_id
	if interior.size.x > 0 and interior.size.y > 0:
		room_interior[room_id] = interior
	if not starter_cells.is_empty():
		room_starter_cells[room_id] = starter_cells.duplicate()

func get_roman_numeral(n: int) -> String:
	if n >= 1 and n < ROMAN_NUMERALS.size():
		return ROMAN_NUMERALS[n]
	return str(n)

func is_cell_in_room(room_id: String, cell: Vector2i) -> bool:
	if not room_interior.has(room_id):
		return false
	var rect: Rect2i = room_interior[room_id]
	return rect.has_point(cell)

func get_room_display_name(room_id: String) -> String:
	return room_display_names.get(room_id, room_id)

func claim_room(room_id: String, actor_id: String) -> bool:
	if not room_owners.has(room_id):
		register_room(room_id)
	
	if room_locked.get(room_id, false):
		return false
	
	var current_owner: String = room_owners.get(room_id, "")
	if current_owner != "":
		return false
	
	room_owners[room_id] = actor_id
	room_locked[room_id] = true
	room_claimed.emit(room_id, actor_id)
	return true

func is_room_locked(room_id: String) -> bool:
	return room_locked.get(room_id, false)

func get_room_owner(room_id: String) -> String:
	return room_owners.get(room_id, "")

func get_player_owned_room_id() -> String:
	for r_id in room_owners.keys():
		if room_owners[r_id] == "player":
			return r_id
	return ""

func can_actor_enter_room(room_id: String, actor_id: String) -> bool:
	if not is_room_locked(room_id):
		return true
	if actor_id == "invader":
		return is_door_broken(room_id)
	return get_room_owner(room_id) == actor_id

func set_player_room(room_id: String) -> void:
	if player_room_id != room_id:
		player_room_id = room_id
		player_room_changed.emit(player_room_id)

# --- 资源管理 ---
func get_money() -> int:
	return money

func get_feedstock() -> int:
	return chem_feedstock

func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)

func spend_money(amount: int) -> bool:
	if money >= amount:
		money -= amount
		money_changed.emit(money)
		return true
	return false

func add_feedstock(amount: int) -> void:
	chem_feedstock += amount
	feedstock_changed.emit(chem_feedstock)

func spend_feedstock(amount: int) -> bool:
	if chem_feedstock >= amount:
		chem_feedstock -= amount
		feedstock_changed.emit(chem_feedstock)
		return true
	return false

func get_actor_money(actor_id: String) -> int:
	if actor_id == "player":
		return money
	if not actor_resources.has(actor_id):
		actor_resources[actor_id] = {"money": 0, "feedstock": 0}
	return int(actor_resources[actor_id]["money"])

func add_actor_money(actor_id: String, amount: int) -> void:
	if actor_id == "player":
		add_money(amount)
	else:
		if not actor_resources.has(actor_id):
			actor_resources[actor_id] = {"money": 0, "feedstock": 0}
		actor_resources[actor_id]["money"] += amount

func set_actor_money(actor_id: String, amount: int) -> void:
	if actor_id == "player":
		money = amount
		money_changed.emit(money)
	else:
		if not actor_resources.has(actor_id):
			actor_resources[actor_id] = {"money": 0, "feedstock": 0}
		actor_resources[actor_id]["money"] = amount

func spend_actor_money(actor_id: String, amount: int) -> bool:
	if actor_id == "player":
		return spend_money(amount)
	if not actor_resources.has(actor_id):
		actor_resources[actor_id] = {"money": 0, "feedstock": 0}
	if actor_resources[actor_id]["money"] >= amount:
		actor_resources[actor_id]["money"] -= amount
		return true
	return false

func get_actor_feedstock(actor_id: String) -> int:
	if actor_id == "player":
		return chem_feedstock
	if not actor_resources.has(actor_id):
		actor_resources[actor_id] = {"money": 0, "feedstock": 0}
	return int(actor_resources[actor_id]["feedstock"])

func add_actor_feedstock(actor_id: String, amount: int) -> void:
	if actor_id == "player":
		add_feedstock(amount)
	else:
		if not actor_resources.has(actor_id):
			actor_resources[actor_id] = {"money": 0, "feedstock": 0}
		actor_resources[actor_id]["feedstock"] += amount

func spend_actor_feedstock(actor_id: String, amount: int) -> bool:
	if actor_id == "player":
		return spend_feedstock(amount)
	if not actor_resources.has(actor_id):
		actor_resources[actor_id] = {"money": 0, "feedstock": 0}
	if actor_resources[actor_id]["feedstock"] >= amount:
		actor_resources[actor_id]["feedstock"] -= amount
		return true
	return false

# --- 起步矿升级 ---
func get_starter_level(room_id: String) -> int:
	return starter_level.get(room_id, 1)

func get_starter_upgrade_cost(room_id: String) -> int:
	var lvl: int = get_starter_level(room_id)
	return lvl * 50

func upgrade_starter(room_id: String, actor_id: String) -> bool:
	if room_owners.get(room_id, "") != actor_id:
		return false
	if starter_hp.get(room_id, STARTER_MAX_HP) <= 0:
		return false
	var cost: int = get_starter_upgrade_cost(room_id)
	if spend_actor_money(actor_id, cost):
		starter_level[room_id] = get_starter_level(room_id) + 1
		starter_upgraded.emit(room_id, starter_level[room_id])
		return true
	return false

# --- 建造与矿山/化工厂管理 ---
func get_room_buildings(room_id: String) -> Array:
	return room_buildings.get(room_id, [])

func get_building_at_cell(cell: Vector2i) -> Dictionary:
	return cell_to_building.get(cell, {})

func count_building_type_in_room(room_id: String, item_id: String) -> int:
	var count: int = 0
	var b_list: Array = room_buildings.get(room_id, [])
	for b in b_list:
		if b.get("id", "") == item_id:
			count += 1
	return count

func has_chem_plant(room_id: String) -> bool:
	return count_building_type_in_room(room_id, "chem_plant") > 0

func has_regulator_stack(room_id: String) -> bool:
	return count_building_type_in_room(room_id, "regulator_stack") > 0

func has_adjacent_high_tech(cell: Vector2i, item_id: String) -> bool:
	var neighbors := [
		cell + Vector2i(1, 0),
		cell + Vector2i(-1, 0),
		cell + Vector2i(0, 1),
		cell + Vector2i(0, -1)
	]
	for n in neighbors:
		if cell_to_building.has(n):
			if cell_to_building[n].get("id", "") == item_id:
				return true
	return false

func can_build(room_id: String, item_id: String, actor_id: String, cell: Vector2i) -> Dictionary:
	if room_owners.get(room_id, "") != actor_id:
		return {"success": false, "reason": "只能在自己占领的房间建造"}
	if not BUILD_CATALOG.has(item_id):
		return {"success": false, "reason": "未知建筑类型"}
	if not is_cell_in_room(room_id, cell):
		return {"success": false, "reason": "格子不属于该房间"}
	if cell_to_building.has(cell):
		return {"success": false, "reason": "该格已有建筑"}
	
	var item: Dictionary = BUILD_CATALOG[item_id]
	var max_limit: int = item.get("max_per_room", 999)
	if count_building_type_in_room(room_id, item_id) >= max_limit:
		return {"success": false, "reason": "该建筑在房间内已达上限 (如铀矿一房一座)"}
	
	var cost_m: int = item.get("cost_money", 0)
	var cost_f: int = item.get("cost_feedstock", 0)
	if get_actor_money(actor_id) < cost_m:
		return {"success": false, "reason": "金钱不足 (需要 %d)" % cost_m}
	if get_actor_feedstock(actor_id) < cost_f:
		return {"success": false, "reason": "原料不足 (需要 %d)" % cost_f}
	
	return {"success": true, "reason": ""}

func buy_and_place_building(room_id: String, item_id: String, actor_id: String, cell: Vector2i) -> bool:
	var check: Dictionary = can_build(room_id, item_id, actor_id, cell)
	if not check.get("success", false):
		print("建造失败: ", check.get("reason", ""))
		return false
	
	var item: Dictionary = BUILD_CATALOG[item_id]
	var cost_m: int = item.get("cost_money", 0)
	var cost_f: int = item.get("cost_feedstock", 0)
	
	if not spend_actor_money(actor_id, cost_m):
		return false
	if cost_f > 0 and not spend_actor_feedstock(actor_id, cost_f):
		# 退回金钱
		add_actor_money(actor_id, cost_m)
		return false
	
	var b_data: Dictionary = {
		"id": item_id,
		"name": item.get("name", ""),
		"category": item.get("category", ""),
		"cell": cell,
		"room_id": room_id,
		"income_money": item.get("income_money", 0),
		"income_feedstock": item.get("income_feedstock", 0)
	}
	if item_id == "chem_plant":
		b_data["level"] = 1
		b_data["name"] = "化工厂 %s" % get_roman_numeral(1)
		b_data["income_feedstock"] = get_chem_plant_income_for_level(1)
	if not room_buildings.has(room_id):
		room_buildings[room_id] = []
	room_buildings[room_id].append(b_data)
	cell_to_building[cell] = b_data
	building_added.emit(room_id, b_data)
	print("建造成功: 在 %s 建造 %s" % [cell, b_data.get("name", item.get("name", ""))])
	return true

func get_chem_plant_income_for_level(level: int) -> int:
	var lvl: int = clampi(level, 1, CHEM_PLANT_MAX_LEVEL)
	return CHEM_PLANT_BASE_FEEDSTOCK * lvl

func get_chem_plant_upgrade_cost(level: int) -> int:
	return 50 + level * 30

func get_chem_plant_in_room(room_id: String) -> Dictionary:
	var b_list: Array = room_buildings.get(room_id, [])
	for b in b_list:
		if b.get("id", "") == "chem_plant":
			return b
	return {}

func can_upgrade_chem_plant(room_id: String, actor_id: String, cell: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	if room_owners.get(room_id, "") != actor_id:
		return {"success": false, "reason": "只能升级自己房间的化工厂"}
	var plant: Dictionary = {}
	if cell != Vector2i(-1, -1):
		plant = get_building_at_cell(cell)
		if plant.get("id", "") != "chem_plant" or plant.get("room_id", "") != room_id:
			return {"success": false, "reason": "该格没有化工厂"}
	else:
		plant = get_chem_plant_in_room(room_id)
	if plant.is_empty():
		return {"success": false, "reason": "房间内没有化工厂"}
	var lvl: int = int(plant.get("level", 1))
	if lvl >= CHEM_PLANT_MAX_LEVEL:
		return {"success": false, "reason": "化工厂已达 XV 封顶"}
	var cost: int = get_chem_plant_upgrade_cost(lvl)
	if get_actor_money(actor_id) < cost:
		return {"success": false, "reason": "金钱不足 (需要 %d)" % cost}
	return {
		"success": true,
		"reason": "",
		"cost_money": cost,
		"next_level": lvl + 1,
		"plant": plant
	}

func upgrade_chem_plant(room_id: String, actor_id: String, cell: Vector2i = Vector2i(-1, -1)) -> bool:
	var check: Dictionary = can_upgrade_chem_plant(room_id, actor_id, cell)
	if not check.get("success", false):
		print("化工厂升级失败: ", check.get("reason", ""))
		return false
	var cost: int = int(check.get("cost_money", 0))
	if not spend_actor_money(actor_id, cost):
		return false
	var plant: Dictionary = check.get("plant", {})
	var next_lvl: int = int(check.get("next_level", 1))
	plant["level"] = next_lvl
	plant["income_feedstock"] = get_chem_plant_income_for_level(next_lvl)
	plant["name"] = "化工厂 %s" % get_roman_numeral(next_lvl)
	print("化工厂升级成功: %s" % [plant["name"]])
	return true

# --- 酸树体系与换线规则 ---
const SUBSTANCE_NAMES: Dictionary = {
	"silicic": "硅酸",
	"carbonate": "碳酸",
	"hypochlorous": "次氯酸",
	"hydrosulfuric": "氢硫酸",
	"hydrofluoric": "氢氟酸",
	"hydrochloric": "盐酸",
	"sulfuric": "硫酸",
	"perchloric": "高氯酸",
	"fluoroantimonic": "氟锑酸"
}

const CAPSTONE_NAMES: Dictionary = {
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

func get_turret_display_name(substance: String, rank: int) -> String:
	var s_name: String = SUBSTANCE_NAMES.get(substance, substance)
	var roman_list: Array[String] = ["", "I", "II", "III", "IV", "V"]
	var r_str: String = roman_list[rank] if rank >= 1 and rank <= 5 else str(rank)
	if rank >= 5:
		var cap: String = CAPSTONE_NAMES.get(substance, "")
		return "%s V (冠名: %s)" % [s_name, cap]
	return "%s %s" % [s_name, r_str]

func get_turret_cell_title(substance: String, rank: int) -> String:
	var s_name: String = SUBSTANCE_NAMES.get(substance, substance)
	var r_str: String = get_roman_numeral(rank)
	if rank >= 5:
		var cap: String = CAPSTONE_NAMES.get(substance, "")
		if cap != "":
			return "%s（%s %s）" % [cap, s_name, r_str]
	return "%s %s" % [s_name, r_str]

func get_invader_max_hp(level: int = -1) -> int:
	var lvl: int = invader_level if level < 1 else level
	lvl = clampi(lvl, 1, INVADER_LEVEL_CAP)
	return INVADER_MAX_HP + (lvl - 1) * INVADER_HP_PER_LEVEL

func apply_invader_level_up_hp(old_level: int, new_level: int) -> void:
	var old_max: int = get_invader_max_hp(old_level)
	var new_max: int = get_invader_max_hp(new_level)
	var delta: int = new_max - old_max
	if delta <= 0:
		return
	invader_hp = mini(new_max, invader_hp + delta)
	invader_hp_changed.emit(invader_hp, new_max)

func get_turret_stats(substance: String, rank: int) -> Dictionary:
	var t_range: float = 4.0
	var t_interval: float = 0.8
	var t_damage: int = 25

	match substance:
		"silicic":
			t_range = 4.0
			t_interval = 0.8
			t_damage = 25 + (rank - 1) * 15 # 25..85
		"carbonate":
			t_range = 4.5
			t_interval = 0.75
			t_damage = 110 + (rank - 1) * 25 # 110..210
		"hypochlorous":
			t_range = 5.0
			t_interval = 0.7
			t_damage = 240 + (rank - 1) * 40 # 240..400 (减速拆门)
		"hydrosulfuric":
			t_range = 5.5
			t_interval = 0.65
			t_damage = 420 + (rank - 1) * 60 # 420..660 (地面水洼DoT)
		"hydrofluoric":
			t_range = 6.0
			t_interval = 0.6
			t_damage = 700 + (rank - 1) * 100 # 700..1100 (破门增伤)
		"hydrochloric":
			t_range = 7.5 # 超长射程
			t_interval = 0.35 # 超快射速
			t_damage = 180 + (rank - 1) * 35 # 180..320
		"sulfuric":
			t_range = 6.0
			t_interval = 0.6
			t_damage = 380 + (rank - 1) * 60 # 380..620 (剥离抗性)
		"perchloric":
			t_range = 6.5
			t_interval = 0.5 # 爆发连射
			t_damage = 450 + (rank - 1) * 70 # 450..730
		"fluoroantimonic":
			t_range = 8.0 # 隔门穿透
			t_interval = 0.5
			t_damage = 800 + (rank - 1) * 150 # 800..1400

	return {
		"range": t_range,
		"interval": t_interval,
		"damage": t_damage
	}

# 硅酸 I–V / 胶幕：同一条减速，V 只加长加深度，factor 恒 < 1。
func get_silicic_slow_params(rank: int) -> Dictionary:
	var r: int = clampi(rank, 1, 5)
	return {
		"duration": 1.25 + 0.25 * float(r),
		"factor": 0.70 - 0.05 * float(r)
	}

# 碳酸 I–V / 沸泉：同一条拆门/进房硬直，V 只加长。
func get_carbonate_hitch_duration(rank: int) -> float:
	var r: int = clampi(rank, 1, 5)
	return 0.6 + 0.2 * float(r)

func get_next_turret_upgrade(substance: String, rank: int, current_branch: String, chosen_branch: String = "") -> Dictionary:
	if (substance == "hydrofluoric" or substance == "fluoroantimonic") and rank >= 5:
		return {"can_upgrade": false, "reason": "已达终极物质封顶"}

	var next_substance: String = substance
	var next_rank: int = rank + 1
	var next_branch: String = current_branch
	var cost_m: int = 0
	var cost_f: int = 0

	if rank < 5:
		cost_m = 50 + rank * 30
		if current_branch != "":
			cost_f = 5 * rank
	else:
		# rank == 5, 晋级到下一物质 I
		next_rank = 1
		if substance == "silicic":
			next_substance = "carbonate"
			cost_m = 250
			cost_f = 0
		elif substance == "carbonate":
			# 换线分支节点
			if chosen_branch == "":
				return {
					"can_upgrade": false,
					"reason": "请选择换线路线: line_a 或 line_b",
					"is_branch_point": true
				}
			if chosen_branch == "line_a":
				next_substance = "hypochlorous"
				next_branch = "line_a"
				cost_m = 500
				cost_f = 20
			elif chosen_branch == "line_b":
				next_substance = "hydrochloric"
				next_branch = "line_b"
				cost_m = 500
				cost_f = 20
			else:
				return {"can_upgrade": false, "reason": "未知分支路线"}
		elif substance == "hypochlorous":
			next_substance = "hydrosulfuric"
			cost_m = 900
			cost_f = 40
		elif substance == "hydrosulfuric":
			next_substance = "hydrofluoric"
			cost_m = 1600
			cost_f = 80
		elif substance == "hydrochloric":
			next_substance = "sulfuric"
			cost_m = 900
			cost_f = 40
		elif substance == "sulfuric":
			next_substance = "perchloric"
			cost_m = 1600
			cost_f = 80
		elif substance == "perchloric":
			next_substance = "fluoroantimonic"
			cost_m = 2800
			cost_f = 150

	return {
		"can_upgrade": true,
		"next_substance": next_substance,
		"next_rank": next_rank,
		"next_branch": next_branch,
		"cost_money": cost_m,
		"cost_feedstock": cost_f,
		"is_branch_point": (substance == "carbonate" and rank >= 5)
	}

func can_upgrade_turret(turret: SilicicTurret, chosen_branch: String = "") -> Dictionary:
	if turret == null:
		return {"success": false, "reason": "炮台不存在"}

	# 检查是否在换线节点且房间无化工厂
	if turret.substance == "carbonate" and turret.rank >= 5:
		if not has_chem_plant(turret.room_id):
			return {"success": false, "reason": "无厂则酸树停在碳酸 V，不能换线"}

	# 换线后不能回头
	if turret.branch_line != "":
		if chosen_branch != "" and chosen_branch != turret.branch_line:
			return {"success": false, "reason": "换线后不能回头"}

	var up_info: Dictionary = get_next_turret_upgrade(turret.substance, turret.rank, turret.branch_line, chosen_branch)
	if not up_info.get("can_upgrade", false):
		return {"success": false, "reason": up_info.get("reason", "无法升级")}

	var owner: String = get_room_owner(turret.room_id)
	if owner == "":
		owner = "player"
	var cost_m: int = up_info.get("cost_money", 0)
	var cost_f: int = up_info.get("cost_feedstock", 0)

	if get_actor_money(owner) < cost_m:
		return {"success": false, "reason": "金钱不足 (需要 %d)" % cost_m}
	if get_actor_feedstock(owner) < cost_f:
		return {"success": false, "reason": "原料不足 (需要 %d)" % cost_f}

	up_info["success"] = true
	return up_info

func upgrade_turret(turret: SilicicTurret, chosen_branch: String = "") -> bool:
	var check: Dictionary = can_upgrade_turret(turret, chosen_branch)
	if not check.get("success", false):
		print("炮台升级失败: ", check.get("reason", ""))
		return false

	var owner: String = get_room_owner(turret.room_id)
	if owner == "":
		owner = "player"

	var cost_m: int = check.get("cost_money", 0)
	var cost_f: int = check.get("cost_feedstock", 0)

	if not spend_actor_money(owner, cost_m):
		return false
	if cost_f > 0 and not spend_actor_feedstock(owner, cost_f):
		add_actor_money(owner, cost_m)
		return false

	turret.substance = check.get("next_substance", turret.substance)
	turret.rank = check.get("next_rank", turret.rank)
	turret.branch_line = check.get("next_branch", turret.branch_line)
	turret.apply_stats()
	print("炮台升级成功: %s" % [get_turret_display_name(turret.substance, turret.rank)])
	return true


# --- 舱门三十档体系 ---
const HATCH_KINDS: Array[String] = [
	"honeycomb",    # 蜂巢闸
	"iris",         # 虹膜锁
	"ln2_curtain",  # 液氮帘 (中段起微量回血)
	"zeolite_flap", # 沸石瓣
	"lattice_lock", # 晶格锁
	"ion_gate"      # 离子栅 (终局封顶)
]

const HATCH_KIND_NAMES: Dictionary = {
	"honeycomb": "蜂巢闸",
	"iris": "虹膜锁",
	"ln2_curtain": "液氮帘",
	"zeolite_flap": "沸石瓣",
	"lattice_lock": "晶格锁",
	"ion_gate": "离子栅"
}

func get_door_kind(room_id: String) -> String:
	return door_kind.get(room_id, "honeycomb")

func get_door_rank(room_id: String) -> int:
	return door_rank.get(room_id, 1)

func get_door_max_hp(room_id: String) -> int:
	return door_max_hp.get(room_id, DOOR_MAX_HP)

func get_door_regen_rate(room_id: String) -> int:
	return door_regen.get(room_id, 0)

func get_door_display_name(room_id: String) -> String:
	var kind: String = get_door_kind(room_id)
	var rank: int = get_door_rank(room_id)
	var k_name: String = HATCH_KIND_NAMES.get(kind, kind)
	var roman_list: Array[String] = ["", "I", "II", "III", "IV", "V"]
	var r_str: String = roman_list[rank] if rank >= 1 and rank <= 5 else str(rank)
	return "%s %s" % [k_name, r_str]

func get_hatch_stats(kind: String, rank: int) -> Dictionary:
	var max_h: int = 100
	var reg: int = 0
	var arm: int = 0
	match kind:
		"honeycomb":
			max_h = 100 + (rank - 1) * 75 # 100..400
			reg = 0
			arm = 0
		"iris":
			max_h = 500 + (rank - 1) * 150 # 500..1100
			reg = 0
			arm = 0
		"ln2_curtain":
			# 中段起微量回血与基础护甲
			max_h = 1400 + (rank - 1) * 350 # 1400..2800
			reg = 3 + (rank - 1) * 2 # 3, 5, 7, 9, 11 HP/s
			arm = 8 * rank # 8..40
		"zeolite_flap":
			max_h = 3400 + (rank - 1) * 700 # 3400..6200
			reg = 14 + (rank - 1) * 2 # 14, 16, 18, 20, 22 HP/s
			arm = 16 * rank # 16..80
		"lattice_lock":
			max_h = 7500 + (rank - 1) * 1500 # 7500..13500
			reg = 25 + (rank - 1) * 3 # 25, 28, 31, 34, 37 HP/s
			arm = 28 * rank # 28..140
		"ion_gate":
			# 终局封顶。装甲仍克制 1–14 级；15 级基础伤见 INVADER_LV15_ATTACK_DAMAGE
			max_h = 16000 + (rank - 1) * 3500 # 16000..30000
			reg = 40 + (rank - 1) * 3 # 40, 43, 46, 49, 52 HP/s
			arm = 45 * rank # 45..225
	return {"max_hp": max_h, "regen": reg, "armor": arm}

func get_door_upgrade_cost(kind: String, rank: int) -> int:
	var kind_idx: int = HATCH_KINDS.find(kind)
	if kind_idx < 0:
		kind_idx = 0
	var global_rank: int = kind_idx * 5 + (rank - 1)
	return 60 + global_rank * 45 + int(pow(float(global_rank), 1.4) * 15.0)

func can_upgrade_door(room_id: String, actor_id: String = "player") -> Dictionary:
	if room_owners.get(room_id, "") != actor_id:
		return {"success": false, "reason": "只能升级自己房间的门"}
	if is_door_broken(room_id) or get_door_hp(room_id) <= 0:
		return {"success": false, "reason": "已破不能升"}

	var cur_kind: String = get_door_kind(room_id)
	var cur_rank: int = get_door_rank(room_id)

	if cur_kind == "ion_gate" and cur_rank >= 5:
		return {"success": false, "reason": "舱门已达终局封顶 离子栅 V"}

	var next_kind: String = cur_kind
	var next_rank: int = cur_rank + 1
	if cur_rank >= 5:
		var kind_idx: int = HATCH_KINDS.find(cur_kind)
		if kind_idx + 1 < HATCH_KINDS.size():
			next_kind = HATCH_KINDS[kind_idx + 1]
			next_rank = 1
		else:
			return {"success": false, "reason": "已达最高等级"}

	var cost: int = get_door_upgrade_cost(cur_kind, cur_rank)
	if get_actor_money(actor_id) < cost:
		return {"success": false, "reason": "金钱不足 (需要 %d)" % cost}

	return {
		"success": true,
		"next_kind": next_kind,
		"next_rank": next_rank,
		"cost_money": cost
	}

func upgrade_door(room_id: String, actor_id: String = "player") -> bool:
	var check: Dictionary = can_upgrade_door(room_id, actor_id)
	if not check.get("success", false):
		print("舱门升级失败: ", check.get("reason", ""))
		return false

	var cost: int = check.get("cost_money", 0)
	if not spend_actor_money(actor_id, cost):
		return false

	var next_kind: String = check["next_kind"]
	var next_rank: int = check["next_rank"]
	door_kind[room_id] = next_kind
	door_rank[room_id] = next_rank

	var stats: Dictionary = get_hatch_stats(next_kind, next_rank)
	var old_max: int = door_max_hp.get(room_id, DOOR_MAX_HP)
	var new_max: int = stats.max_hp
	door_max_hp[room_id] = new_max
	door_regen[room_id] = stats.regen
	door_armor[room_id] = stats.armor

	var old_hp: int = door_hp.get(room_id, old_max)
	var hp_delta: int = new_max - old_max
	door_hp[room_id] = min(new_max, old_hp + hp_delta)

	door_hp_changed.emit(room_id, door_hp[room_id], new_max)
	print("舱门升级成功: %s" % [get_door_display_name(room_id)])
	return true

func get_door_hp(room_id: String) -> int:
	return door_hp.get(room_id, get_door_max_hp(room_id))

func get_door_hp_bar_ratio(room_id: String) -> float:
	if is_door_broken(room_id):
		return 0.0
	var max_h: int = get_door_max_hp(room_id)
	if max_h <= 0:
		return 0.0
	return clampf(float(get_door_hp(room_id)) / float(max_h), 0.0, 1.0)

func get_door_armor(room_id: String) -> int:
	return door_armor.get(room_id, 0)

func reduce_door_armor(room_id: String, amount: int) -> int:
	var cur: int = get_door_armor(room_id)
	var new_arm: int = max(0, cur - amount)
	door_armor[room_id] = new_arm
	return new_arm

func get_effective_door_damage(raw_damage: int, armor: int) -> int:
	return max(1, raw_damage - armor)

func is_door_broken(room_id: String) -> bool:
	return door_broken.get(room_id, false)

func damage_door(room_id: String, damage: int, ignore_armor: bool = false) -> int:
	var max_h: int = get_door_max_hp(room_id)
	if not door_hp.has(room_id):
		door_hp[room_id] = max_h
	var arm: int = 0 if ignore_armor else get_door_armor(room_id)
	var eff_dmg: int = get_effective_door_damage(damage, arm)
	var hp: int = max(0, door_hp[room_id] - eff_dmg)
	door_hp[room_id] = hp
	if hp <= 0:
		door_broken[room_id] = true
	door_hp_changed.emit(room_id, hp, max_h)
	return hp

func get_starter_hp(room_id: String) -> int:
	return starter_hp.get(room_id, STARTER_MAX_HP)

func damage_starter(room_id: String, damage: int) -> int:
	if not starter_hp.has(room_id):
		starter_hp[room_id] = STARTER_MAX_HP
	var hp: int = max(0, starter_hp[room_id] - damage)
	starter_hp[room_id] = hp
	starter_hp_changed.emit(room_id, hp, STARTER_MAX_HP)
	if hp <= 0:
		if room_owners.get(room_id, "") == "player":
			set_game_result(GameResult.DEFEAT)
	return hp

func damage_invader(damage: int) -> int:
	invader_hp = max(0, invader_hp - damage)
	invader_hp_changed.emit(invader_hp, get_invader_max_hp())
	if invader_hp <= 0:
		set_game_result(GameResult.VICTORY)
	return invader_hp

func set_game_result(result: GameResult) -> void:
	if game_result == GameResult.NONE:
		game_result = result
		game_over.emit(game_result)

func _process(delta: float) -> void:
	if game_result != GameResult.NONE:
		return

	if current_phase == Phase.COUNTDOWN:
		countdown_remaining = maxf(0.0, countdown_remaining - delta)
		countdown_tick.emit(countdown_remaining)
		if countdown_remaining <= 0.0:
			current_phase = Phase.INVADING
			phase_changed.emit(current_phase)

	# 经济产出与舱门回血
	for r_id in room_owners.keys():
		var owner: String = room_owners[r_id]
		if owner == "":
			continue

		# 1. 起步矿产钱（起步矿未被破坏）
		if starter_hp.get(r_id, STARTER_MAX_HP) > 0:
			var timer: float = starter_income_timer.get(r_id, 0.0) + delta
			if timer >= STARTER_INCOME_INTERVAL:
				timer -= STARTER_INCOME_INTERVAL
				var lvl: int = get_starter_level(r_id)
				var payout: int = STARTER_INCOME_AMOUNT * lvl
				add_actor_money(owner, payout)
				var s_cells: Array = room_starter_cells.get(r_id, [])
				if not s_cells.is_empty() and payout > 0:
					production_popup.emit(s_cells[0], "money", payout)
			starter_income_timer[r_id] = timer

		# 2. 房间内其他建筑（矿山、化工厂）产出
		var b_list: Array = room_buildings.get(r_id, [])
		if not b_list.is_empty():
			var b_timer: float = building_income_timer.get(r_id, 0.0) + delta
			if b_timer >= STARTER_INCOME_INTERVAL:
				b_timer -= STARTER_INCOME_INTERVAL
				var has_reg: bool = has_regulator_stack(r_id)
				for b in b_list:
					var m_inc: int = b.get("income_money", 0)
					var f_inc: int = b.get("income_feedstock", 0)
					var b_cell: Vector2i = b.get("cell", Vector2i.ZERO)
					var has_arm: bool = has_adjacent_high_tech(b_cell, "robotic_arm")
					var mult: float = 1.0
					if has_arm:
						mult += 0.35
					if has_reg:
						mult += 0.15
					if m_inc > 0:
						var money_gain: int = int(ceil(float(m_inc) * mult))
						add_actor_money(owner, money_gain)
						if money_gain > 0:
							production_popup.emit(b_cell, "money", money_gain)
					if f_inc > 0:
						var feed_gain: int = int(ceil(float(f_inc) * mult))
						add_actor_feedstock(owner, feed_gain)
						if feed_gain > 0:
							production_popup.emit(b_cell, "feedstock", feed_gain)
			building_income_timer[r_id] = b_timer

		# 3. 舱门中段微量回血（未破损状态下自动恢复）
		if not is_door_broken(r_id) and starter_hp.get(r_id, STARTER_MAX_HP) > 0:
			var reg_rate: int = get_door_regen_rate(r_id)
			var max_h: int = get_door_max_hp(r_id)
			var cur_h: int = get_door_hp(r_id)
			if reg_rate > 0 and cur_h < max_h:
				var reg_timer: float = door_regen_timer.get(r_id, 0.0) + delta
				if reg_timer >= 1.0:
					reg_timer -= 1.0
					var healed: int = min(max_h, cur_h + reg_rate)
					door_hp[r_id] = healed
					door_hp_changed.emit(r_id, healed, max_h)
				door_regen_timer[r_id] = reg_timer


