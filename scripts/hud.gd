extends CanvasLayer

signal build_selection_changed(item_id: String)
signal upgrade_door_requested
signal upgrade_turret_requested

@onready var label_countdown: Label = $TopBar/Margin/HBox/CountdownLabel
@onready var label_money: Label = $TopBar/Margin/HBox/MoneyLabel
@onready var label_feedstock: Label = $TopBar/Margin/HBox/FeedstockLabel
@onready var label_door_hp: Label = $TopBar/Margin/HBox/DoorHpLabel
@onready var label_invader_hp: Label = $TopBar/Margin/HBox/InvaderHpLabel
@onready var label_room: Label = $TopBar/Margin/HBox/RoomLabel
@onready var label_outcome: Label = $OutcomeLabel

@onready var btn_upgrade_door: Button = $BottomBar/Margin/HBox/BtnUpgradeDoor
@onready var btn_build_turret: Button = $BottomBar/Margin/HBox/BtnBuildTurret
@onready var btn_build_iron_mine: Button = $BottomBar/Margin/HBox/BtnBuildIronMine
@onready var btn_build_chem_plant: Button = $BottomBar/Margin/HBox/BtnBuildChemPlant
@onready var btn_build_catalytic: Button = $BottomBar/Margin/HBox/BtnBuildCatalytic
@onready var btn_build_focus: Button = $BottomBar/Margin/HBox/BtnBuildFocus
@onready var btn_build_arm: Button = $BottomBar/Margin/HBox/BtnBuildArm
@onready var btn_build_regulator: Button = $BottomBar/Margin/HBox/BtnBuildRegulator
@onready var btn_upgrade_turret: Button = $BottomBar/Margin/HBox/BtnUpgradeTurret
@onready var btn_toggle_branch: Button = $BottomBar/Margin/HBox/BtnToggleBranch
@onready var label_selected: Label = $BottomBar/Margin/HBox/SelectedLabel

const MINE_IDS: Array[String] = [
	"iron_mine", "tungsten_mine", "molybdenum_mine",
	"sulfur_mine", "antimony_mine", "gold_mine", "uranium_mine"
]
var current_mine_idx: int = 0
var selected_branch_line: String = "line_a"
var current_selection: String = "turret"

func _ready() -> void:
	MatchState.countdown_tick.connect(_on_countdown_tick)
	MatchState.phase_changed.connect(_on_phase_changed)
	MatchState.player_room_changed.connect(_on_player_room_changed)
	MatchState.room_claimed.connect(_on_room_claimed)
	MatchState.money_changed.connect(_on_money_changed)
	MatchState.feedstock_changed.connect(_on_feedstock_changed)
	MatchState.door_hp_changed.connect(_on_door_hp_changed)
	MatchState.invader_hp_changed.connect(_on_invader_hp_changed)
	MatchState.invader_level_changed.connect(_on_invader_level_changed)
	MatchState.game_over.connect(_on_game_over)

	btn_upgrade_door.pressed.connect(_on_btn_upgrade_door_pressed)
	btn_build_turret.pressed.connect(func(): _select_build("turret", str(MatchState.BUILD_CATALOG.get("silicic_turret_1", {}).get("name", "硅酸炮台 I"))))
	btn_build_iron_mine.pressed.connect(_on_btn_cycle_mine_pressed)
	btn_build_chem_plant.pressed.connect(func(): _select_build("chem_plant", str(MatchState.BUILD_CATALOG.get("chem_plant", {}).get("name", "化工厂"))))
	btn_build_catalytic.pressed.connect(func(): _select_build("catalytic_column", str(MatchState.BUILD_CATALOG.get("catalytic_column", {}).get("name", "催化柱"))))
	btn_build_focus.pressed.connect(func(): _select_build("focus_lens", str(MatchState.BUILD_CATALOG.get("focus_lens", {}).get("name", "聚焦镜"))))
	btn_build_arm.pressed.connect(func(): _select_build("robotic_arm", str(MatchState.BUILD_CATALOG.get("robotic_arm", {}).get("name", "机械臂"))))
	btn_build_regulator.pressed.connect(func(): _select_build("regulator_stack", str(MatchState.BUILD_CATALOG.get("regulator_stack", {}).get("name", "稳压堆"))))
	btn_upgrade_turret.pressed.connect(_on_btn_upgrade_turret_pressed)
	btn_toggle_branch.pressed.connect(_on_btn_toggle_branch_pressed)

	_update_hud_display()

func _get_mine(idx: int) -> Dictionary:
	var id: String = MINE_IDS[idx]
	var item: Dictionary = MatchState.BUILD_CATALOG[id]
	return {
		"id": id,
		"name": item.get("name", id),
		"cost": int(item.get("cost_money", 0))
	}

func update_build_buttons() -> void:
	var t_cost: int = int(MatchState.BUILD_CATALOG.get("silicic_turret_1", {}).get("cost_money", 0))
	var t_name: String = str(MatchState.BUILD_CATALOG.get("silicic_turret_1", {}).get("name", "硅酸炮台 I"))
	btn_build_turret.text = "[2] %s ($%d)" % [t_name, t_cost]

	var mine: Dictionary = _get_mine(current_mine_idx)
	btn_build_iron_mine.text = "[3] %s ($%d)" % [mine["name"], mine["cost"]]

	var cp_cost: int = int(MatchState.BUILD_CATALOG.get("chem_plant", {}).get("cost_money", 0))
	var cp_name: String = str(MatchState.BUILD_CATALOG.get("chem_plant", {}).get("name", "化工厂"))
	btn_build_chem_plant.text = "[4] %s ($%d)" % [cp_name, cp_cost]

	var cat_cost: int = int(MatchState.BUILD_CATALOG.get("catalytic_column", {}).get("cost_money", 0))
	var cat_name: String = str(MatchState.BUILD_CATALOG.get("catalytic_column", {}).get("name", "催化柱"))
	btn_build_catalytic.text = "[5] %s ($%d)" % [cat_name, cat_cost]

	var foc_cost: int = int(MatchState.BUILD_CATALOG.get("focus_lens", {}).get("cost_money", 0))
	var foc_name: String = str(MatchState.BUILD_CATALOG.get("focus_lens", {}).get("name", "聚焦镜"))
	btn_build_focus.text = "[6] %s ($%d)" % [foc_name, foc_cost]

	var arm_cost: int = int(MatchState.BUILD_CATALOG.get("robotic_arm", {}).get("cost_money", 0))
	var arm_name: String = str(MatchState.BUILD_CATALOG.get("robotic_arm", {}).get("name", "机械臂"))
	btn_build_arm.text = "[7] %s ($%d)" % [arm_name, arm_cost]

	var reg_cost: int = int(MatchState.BUILD_CATALOG.get("regulator_stack", {}).get("cost_money", 0))
	var reg_name: String = str(MatchState.BUILD_CATALOG.get("regulator_stack", {}).get("name", "稳压堆"))
	btn_build_regulator.text = "[8] %s ($%d)" % [reg_name, reg_cost]

func _on_btn_cycle_mine_pressed() -> void:
	if current_selection == MINE_IDS[current_mine_idx]:
		current_mine_idx = (current_mine_idx + 1) % MINE_IDS.size()
	var mine: Dictionary = _get_mine(current_mine_idx)
	btn_build_iron_mine.text = "[3] %s ($%d)" % [mine["name"], mine["cost"]]
	_select_build(mine["id"], "%s ($%d)" % [mine["name"], mine["cost"]])

func _on_btn_toggle_branch_pressed() -> void:
	if selected_branch_line == "line_a":
		selected_branch_line = "line_b"
		btn_toggle_branch.text = "[0] 分支: B线 (盐酸)"
	else:
		selected_branch_line = "line_a"
		btn_toggle_branch.text = "[0] 分支: A线 (次氯)"

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_0:
				_on_btn_toggle_branch_pressed()
			KEY_1:
				_on_btn_upgrade_door_pressed()
			KEY_2:
				_select_build("turret", str(MatchState.BUILD_CATALOG.get("silicic_turret_1", {}).get("name", "硅酸炮台 I")))
			KEY_3:
				_on_btn_cycle_mine_pressed()
			KEY_4:
				_select_build("chem_plant", str(MatchState.BUILD_CATALOG.get("chem_plant", {}).get("name", "化工厂")))
			KEY_5:
				_select_build("catalytic_column", str(MatchState.BUILD_CATALOG.get("catalytic_column", {}).get("name", "催化柱")))
			KEY_6:
				_select_build("focus_lens", str(MatchState.BUILD_CATALOG.get("focus_lens", {}).get("name", "聚焦镜")))
			KEY_7:
				_select_build("robotic_arm", str(MatchState.BUILD_CATALOG.get("robotic_arm", {}).get("name", "机械臂")))
			KEY_8:
				_select_build("regulator_stack", str(MatchState.BUILD_CATALOG.get("regulator_stack", {}).get("name", "稳压堆")))
			KEY_9:
				_on_btn_upgrade_turret_pressed()

func _select_build(item_id: String, item_name: String) -> void:
	current_selection = item_id
	label_selected.text = "当前选择: %s" % item_name
	build_selection_changed.emit(item_id)

func _on_btn_upgrade_door_pressed() -> void:
	if upgrade_door_requested.get_connections().size() > 0:
		upgrade_door_requested.emit()
	else:
		var r_id: String = MatchState.get_player_owned_room_id()
		if r_id != "":
			MatchState.upgrade_door(r_id, "player")
			_update_door_hp_display()

func _on_btn_upgrade_turret_pressed() -> void:
	upgrade_turret_requested.emit()

func _update_hud_display() -> void:
	_update_money_label(MatchState.money)
	_update_feedstock_label(MatchState.chem_feedstock)
	_update_countdown_label(MatchState.countdown_remaining)
	_update_room_label(MatchState.player_room_id)
	_update_door_hp_display()
	_update_invader_hp_display(MatchState.invader_hp, MatchState.INVADER_MAX_HP)
	_update_outcome_display()
	update_build_buttons()

func _on_money_changed(amount: int) -> void:
	_update_money_label(amount)

func _update_money_label(amount: int) -> void:
	label_money.text = "金钱: %d" % amount

func _on_feedstock_changed(amount: int) -> void:
	_update_feedstock_label(amount)

func _update_feedstock_label(amount: int) -> void:
	label_feedstock.text = "化学原料: %d" % amount

func _on_countdown_tick(remaining: float) -> void:
	_update_countdown_label(remaining)

func _update_countdown_label(remaining: float) -> void:
	if MatchState.current_phase == MatchState.Phase.COUNTDOWN:
		label_countdown.text = "倒计时: %.1fs" % remaining
	else:
		label_countdown.text = "倒计时: 0.0s [敌人已进入走廊]"

func _on_phase_changed(new_phase: int) -> void:
	if new_phase == MatchState.Phase.INVADING:
		label_countdown.text = "倒计时: 0.0s [敌人已进入走廊]"

func _on_player_room_changed(room_id: String) -> void:
	_update_room_label(room_id)
	_update_door_hp_display()

func _on_room_claimed(_room_id: String, _actor_id: String) -> void:
	_update_room_label(MatchState.player_room_id)
	_update_door_hp_display()

func _on_door_hp_changed(_room_id: String, _hp: int, _max_hp: int) -> void:
	_update_door_hp_display()

func _update_door_hp_display() -> void:
	var r_id: String = MatchState.get_player_owned_room_id()
	if r_id == "":
		r_id = MatchState.invader_target_room_id
	
	if r_id != "":
		var d_name: String = MatchState.get_door_display_name(r_id)
		var max_h: int = MatchState.get_door_max_hp(r_id)
		var cur_h: int = MatchState.get_door_hp(r_id)
		var reg: int = MatchState.get_door_regen_rate(r_id)
		if MatchState.is_door_broken(r_id):
			label_door_hp.text = "舱门: %s 0/%d (破)" % [d_name, max_h]
		else:
			if reg > 0:
				label_door_hp.text = "舱门: %s %d/%d (+%d/s)" % [d_name, cur_h, max_h, reg]
			else:
				label_door_hp.text = "舱门: %s %d/%d" % [d_name, cur_h, max_h]
	else:
		label_door_hp.text = "舱门: 蜂巢闸 I 100/100"

func _on_invader_hp_changed(hp: int, max_hp: int) -> void:
	_update_invader_hp_display(hp, max_hp)

func _on_invader_level_changed(_level: int) -> void:
	_update_invader_hp_display(MatchState.invader_hp, MatchState.INVADER_MAX_HP)

func _update_invader_hp_display(hp: int, max_hp: int) -> void:
	var char_title: String = "入侵者"
	match MatchState.invader_character:
		"rock_corroder": char_title = "蚀岩"
		"mist_walker": char_title = "雾徙"
		"fire_quencher": char_title = "遏火"
		"oxygen_burster": char_title = "暴氧"
	var status: String = MatchState.invader_status_text
	if status != "":
		label_invader_hp.text = "敌人: %s (Lv.%d) %d/%d [%s]" % [char_title, MatchState.invader_level, hp, max_hp, status]
	else:
		label_invader_hp.text = "敌人: %s (Lv.%d) %d/%d" % [char_title, MatchState.invader_level, hp, max_hp]

func _on_game_over(_result: int) -> void:
	_update_outcome_display()

func _update_outcome_display() -> void:
	match MatchState.game_result:
		MatchState.GameResult.VICTORY:
			label_outcome.text = "胜利！敌人已被炮台消灭"
			label_outcome.modulate = Color(0.2, 1.0, 0.3)
		MatchState.GameResult.DEFEAT:
			label_outcome.text = "失败！基底矿被摧毁"
			label_outcome.modulate = Color(1.0, 0.2, 0.2)
		_:
			label_outcome.text = ""

func _update_room_label(room_id: String) -> void:
	if room_id == "":
		label_room.text = "当前位置: 走廊"
	else:
		var owner: String = MatchState.get_room_owner(room_id)
		var status_str: String = " [空闲]"
		if MatchState.is_room_locked(room_id):
			status_str = " [已锁: %s]" % owner
		label_room.text = "当前位置: %s%s" % [MatchState.get_room_display_name(room_id), status_str]
