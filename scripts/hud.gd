extends CanvasLayer

@onready var label_countdown: Label = $TopBar/Margin/HBox/CountdownLabel
@onready var label_money: Label = $TopBar/Margin/HBox/MoneyLabel
@onready var label_door_hp: Label = $TopBar/Margin/HBox/DoorHpLabel
@onready var label_invader_hp: Label = $TopBar/Margin/HBox/InvaderHpLabel
@onready var label_room: Label = $TopBar/Margin/HBox/RoomLabel
@onready var label_outcome: Label = $OutcomeLabel

func _ready() -> void:
	MatchState.countdown_tick.connect(_on_countdown_tick)
	MatchState.phase_changed.connect(_on_phase_changed)
	MatchState.player_room_changed.connect(_on_player_room_changed)
	MatchState.room_claimed.connect(_on_room_claimed)
	MatchState.money_changed.connect(_on_money_changed)
	MatchState.door_hp_changed.connect(_on_door_hp_changed)
	MatchState.invader_hp_changed.connect(_on_invader_hp_changed)
	MatchState.game_over.connect(_on_game_over)
	_update_hud_display()

func _update_hud_display() -> void:
	_update_money_label(MatchState.money)
	_update_countdown_label(MatchState.countdown_remaining)
	_update_room_label(MatchState.player_room_id)
	_update_door_hp_display()
	_update_invader_hp_display(MatchState.invader_hp, MatchState.INVADER_MAX_HP)
	_update_outcome_display()

func _on_money_changed(amount: int) -> void:
	_update_money_label(amount)

func _update_money_label(amount: int) -> void:
	label_money.text = "金钱: %d" % amount

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
		if MatchState.is_door_broken(r_id):
			label_door_hp.text = "门 HP: 0/%d (破)" % MatchState.DOOR_MAX_HP
		else:
			label_door_hp.text = "门 HP: %d/%d" % [MatchState.get_door_hp(r_id), MatchState.DOOR_MAX_HP]
	else:
		label_door_hp.text = "门 HP: %d/%d" % [MatchState.DOOR_MAX_HP, MatchState.DOOR_MAX_HP]

func _on_invader_hp_changed(hp: int, max_hp: int) -> void:
	_update_invader_hp_display(hp, max_hp)

func _update_invader_hp_display(hp: int, max_hp: int) -> void:
	label_invader_hp.text = "敌人 HP: %d/%d" % [hp, max_hp]

func _on_game_over(_result: int) -> void:
	_update_outcome_display()

func _update_outcome_display() -> void:
	match MatchState.game_result:
		MatchState.GameResult.VICTORY:
			label_outcome.text = "胜利！敌人已被消灭"
			label_outcome.modulate = Color(0.2, 1.0, 0.3)
		MatchState.GameResult.DEFEAT:
			label_outcome.text = "失败！起步矿被摧毁"
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
