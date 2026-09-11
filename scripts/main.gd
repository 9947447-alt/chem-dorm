class_name MainGame
extends Node2D

@onready var grid_manager: GridMapManager = $GridMapManager
@onready var actors_container: Node2D = $Actors
@onready var camera: Camera2D = $Camera2D

var player: PlayerActor
var allies: Array[AllyBot] = []
var invader: InvaderActor

func _ready() -> void:
	_setup_camera()
	_spawn_all_actors()

func _setup_camera() -> void:
	# Center camera to display the whole dormitory (approx 38x28 tiles)
	var center_x: float = (GridMapManager.GRID_WIDTH * GridMapManager.TILE_SIZE) * 0.5
	var center_y: float = (GridMapManager.GRID_HEIGHT * GridMapManager.TILE_SIZE) * 0.5
	camera.position = Vector2(center_x, center_y)
	camera.zoom = Vector2(0.8, 0.8)

func _spawn_all_actors() -> void:
	# 1. Spawn Player
	player = PlayerActor.new()
	player.name = "Player"
	actors_container.add_child(player)
	player.init_actor("player", "玩家", Color(0.15, 0.85, 1.0), Vector2i(8, 13), grid_manager)

	# 2. Spawn 5 Ally Bots
	var ally_start_cells: Array[Vector2i] = [
		Vector2i(10, 13),
		Vector2i(12, 13),
		Vector2i(14, 13),
		Vector2i(10, 14),
		Vector2i(12, 14)
	]
	var ally_colors: Array[Color] = [
		Color(0.2, 0.85, 0.35),
		Color(0.3, 0.90, 0.45),
		Color(0.2, 0.80, 0.55),
		Color(0.4, 0.95, 0.30),
		Color(0.15, 0.75, 0.40)
	]

	allies.clear()
	for i in range(5):
		var bot := AllyBot.new()
		bot.name = "Ally_%d" % (i + 1)
		actors_container.add_child(bot)
		bot.init_actor(
			"ally_%d" % (i + 1),
			"盟友%d" % (i + 1),
			ally_colors[i],
			ally_start_cells[i],
			grid_manager
		)
		allies.append(bot)

	# 3. Spawn Invader (inactive/hidden until countdown ends)
	invader = InvaderActor.new()
	invader.name = "Invader"
	actors_container.add_child(invader)
	invader.init_actor(
		"invader",
		"入侵者",
		Color(0.95, 0.22, 0.22),
		grid_manager.invader_spawn_cell,
		grid_manager
	)

	# Start Ally AIs
	for bot in allies:
		bot.start_ai()
