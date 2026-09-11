extends CanvasLayer

@onready var label_countdown: Label = $TopBar/Margin/HBox/CountdownLabel
@onready var label_money: Label = $TopBar/Margin/HBox/MoneyLabel
@onready var label_room: Label = $TopBar/Margin/HBox/RoomLabel

func _ready() -> void:
	MatchState.countdown_tick.connect(_on_countdown_tick)
	MatchState.phase_changed.connect(_on_phase_changed)
	MatchState.player_room_changed.connect(_on_player_room_changed)
	MatchState.room_claimed.connect(_on_room_claimed)
	_update_hud_display()

func _update_hud_display() -> void:
	label_money.text = "金钱: %d" % MatchState.money
	_update_countdown_label(MatchState.countdown_remaining)
	_update_room_label(MatchState.player_room_id)

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

func _on_room_claimed(_room_id: String, _actor_id: String) -> void:
	_update_room_label(MatchState.player_room_id)

func _update_room_label(room_id: String) -> void:
	if room_id == "":
		label_room.text = "当前位置: 走廊"
	else:
		var owner: String = MatchState.get_room_owner(room_id)
		var status_str: String = " [空闲]"
		if MatchState.is_room_locked(room_id):
			status_str = " [已锁: %s]" % owner
		label_room.text = "当前位置: %s%s" % [MatchState.get_room_display_name(room_id), status_str]
