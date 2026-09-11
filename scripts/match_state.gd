extends Node

signal countdown_tick(remaining: float)
signal phase_changed(new_phase: int)
signal room_claimed(room_id: String, actor_id: String)
signal player_room_changed(room_id: String)
signal money_changed(new_amount: int)
signal game_over(result: int)
signal door_hp_changed(room_id: String, current_hp: int, max_hp: int)
signal starter_hp_changed(room_id: String, current_hp: int, max_hp: int)
signal invader_hp_changed(current_hp: int, max_hp: int)

enum Phase {
	COUNTDOWN,
	INVADING
}

enum GameResult {
	NONE,
	VICTORY,
	DEFEAT
}

# --- 常数定义集中区（V0 规范） ---
# 起步矿经济常数
const STARTER_INCOME_INTERVAL: float = 1.0
const STARTER_INCOME_AMOUNT: int = 10
const STARTER_MAX_HP: int = 100

# 硅酸炮台 I 常数（仅此一档，纯伤害）
const TURRET_COST: int = 100
const TURRET_RANGE: float = 4.0
const TURRET_FIRE_INTERVAL: float = 0.8
const TURRET_DAMAGE: int = 25

# 舱门常数
const DOOR_MAX_HP: int = 100

# 敌人常数
const INVADER_MAX_HP: int = 200
const INVADER_ATTACK_DAMAGE: int = 20
const INVADER_ATTACK_INTERVAL: float = 1.0

var current_phase: Phase = Phase.COUNTDOWN
var countdown_remaining: float = 25.0
var money: int = 0
var room_owners: Dictionary = {} # String (room_id) -> String (actor_id)
var room_locked: Dictionary = {} # String (room_id) -> bool
var room_display_names: Dictionary = {} # String (room_id) -> String (display_name)
var player_room_id: String = "" # "" represents corridor/outside

# V0 对局运行时状态
var game_result: GameResult = GameResult.NONE
var door_hp: Dictionary = {} # String (room_id) -> int
var starter_hp: Dictionary = {} # String (room_id) -> int
var door_broken: Dictionary = {} # String (room_id) -> bool
var starter_income_timer: Dictionary = {} # String (room_id) -> float
var invader_hp: int = INVADER_MAX_HP
var invader_target_room_id: String = ""

func _ready() -> void:
	reset_match()

func reset_match(countdown_duration: float = 25.0) -> void:
	current_phase = Phase.COUNTDOWN
	countdown_remaining = countdown_duration
	money = 0
	room_owners.clear()
	room_locked.clear()
	room_display_names.clear()
	player_room_id = ""
	game_result = GameResult.NONE
	door_hp.clear()
	starter_hp.clear()
	door_broken.clear()
	starter_income_timer.clear()
	invader_hp = INVADER_MAX_HP
	invader_target_room_id = ""

func register_room(room_id: String, display_name: String = "") -> void:
	if not room_owners.has(room_id):
		room_owners[room_id] = ""
		room_locked[room_id] = false
		door_hp[room_id] = DOOR_MAX_HP
		starter_hp[room_id] = STARTER_MAX_HP
		door_broken[room_id] = false
		starter_income_timer[room_id] = 0.0
	if display_name != "":
		room_display_names[room_id] = display_name
	elif not room_display_names.has(room_id):
		room_display_names[room_id] = room_id

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

func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)

func spend_money(amount: int) -> bool:
	if money >= amount:
		money -= amount
		money_changed.emit(money)
		return true
	return false

func get_door_hp(room_id: String) -> int:
	return door_hp.get(room_id, DOOR_MAX_HP)

func is_door_broken(room_id: String) -> bool:
	return door_broken.get(room_id, false)

func damage_door(room_id: String, damage: int) -> int:
	if not door_hp.has(room_id):
		door_hp[room_id] = DOOR_MAX_HP
	var hp: int = max(0, door_hp[room_id] - damage)
	door_hp[room_id] = hp
	if hp <= 0:
		door_broken[room_id] = true
	door_hp_changed.emit(room_id, hp, DOOR_MAX_HP)
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
	invader_hp_changed.emit(invader_hp, INVADER_MAX_HP)
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

	# 起步矿产钱（只要房间有主且起步矿未被破坏）
	for r_id in room_owners.keys():
		var owner: String = room_owners[r_id]
		if owner != "" and starter_hp.get(r_id, STARTER_MAX_HP) > 0:
			var timer: float = starter_income_timer.get(r_id, 0.0) + delta
			if timer >= STARTER_INCOME_INTERVAL:
				timer -= STARTER_INCOME_INTERVAL
				if owner == "player":
					add_money(STARTER_INCOME_AMOUNT)
			starter_income_timer[r_id] = timer
