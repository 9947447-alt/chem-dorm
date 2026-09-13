extends CanvasLayer

signal cell_menu_item_chosen(index: int)
signal cell_menu_closed

@onready var label_countdown: Label = $TopBar/Margin/HBox/CountdownLabel
@onready var label_money: Label = $TopBar/Margin/HBox/MoneyLabel
@onready var label_feedstock: Label = $TopBar/Margin/HBox/FeedstockLabel
@onready var label_door_hp: Label = $TopBar/Margin/HBox/DoorHpLabel
@onready var label_invader_hp: Label = $TopBar/Margin/HBox/InvaderHpLabel
@onready var label_room: Label = $TopBar/Margin/HBox/RoomLabel
@onready var label_outcome: Label = $OutcomeLabel
@onready var label_hint: Label = $BottomBar/Margin/HBox/HintLabel

var cell_popup: PopupMenu
var _ignore_popup_hide: bool = false

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

	cell_popup = PopupMenu.new()
	cell_popup.name = "CellPopup"
	add_child(cell_popup)
	cell_popup.id_pressed.connect(_on_cell_popup_id_pressed)
	cell_popup.popup_hide.connect(_on_cell_popup_hide)

	label_hint.text = "WASD 移动，左键选格开菜单，站起步格占房"
	_update_hud_display()

func show_cell_menu(items: Array, screen_pos: Vector2) -> void:
	if cell_popup == null:
		return
	_ignore_popup_hide = true
	cell_popup.hide()
	_ignore_popup_hide = false
	cell_popup.clear()
	for i in items.size():
		var it: Dictionary = items[i]
		var text: String = str(it.get("label", ""))
		if str(it.get("action", "")) == "title" or str(it.get("id", "")) == "cell_title":
			cell_popup.add_separator(text)
			continue
		if not it.get("enabled", false):
			var reason: String = str(it.get("reason", ""))
			if reason != "":
				text = "%s（%s）" % [text, reason]
		cell_popup.add_item(text, i)
		cell_popup.set_item_disabled(i, not it.get("enabled", false))
	cell_popup.position = Vector2i(int(screen_pos.x), int(screen_pos.y))
	cell_popup.popup()

func hide_cell_menu() -> void:
	if cell_popup != null and cell_popup.visible:
		_ignore_popup_hide = true
		cell_popup.hide()
		_ignore_popup_hide = false

func _on_cell_popup_id_pressed(id: int) -> void:
	cell_menu_item_chosen.emit(id)

func _on_cell_popup_hide() -> void:
	if _ignore_popup_hide:
		return
	cell_menu_closed.emit()

func _update_hud_display() -> void:
	_update_money_label(MatchState.money)
	_update_feedstock_label(MatchState.chem_feedstock)
	_update_countdown_label(MatchState.countdown_remaining)
	_update_room_label(MatchState.player_room_id)
	_update_door_hp_display()
	_update_invader_hp_display(MatchState.invader_hp, MatchState.get_invader_max_hp())
	_update_outcome_display()

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
	_update_invader_hp_display(MatchState.invader_hp, MatchState.get_invader_max_hp())

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
