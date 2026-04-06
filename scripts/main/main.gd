extends Node2D

var round_active: bool = false

var EnemyScene := preload("res://scenes/enemy/enemy.tscn")

const ENEMIES_PER_ROUND := 5

var enemies_spawned: int = 0
var enemies_finished: int = 0
var current_round_path: Array[Vector2i] = []

func _ready():
	var viewport_size: Vector2 = get_viewport_rect().size
	var grid_size: Vector2 = $Grid.get_grid_pixel_size()
	$Grid.position = (viewport_size - grid_size) / 2.0

	$RoundSpawnTimer.timeout.connect(_on_round_spawn_timer_timeout)
	$Grid.grid_changed.connect(_on_grid_changed)

func _process(_delta: float):
	if Input.is_action_just_pressed("start_round") and not round_active:
		start_round()

func start_round():
	current_round_path = $Grid.get_grid_path()
	if current_round_path.is_empty():
		print("No valid path, cannot start round")
		return

	round_active = true
	enemies_spawned = 0
	enemies_finished = 0

	$Grid.building_enabled = false
	$Grid.queue_redraw()

	print("Round started")

	_spawn_enemy()
	enemies_spawned += 1

	if enemies_spawned < ENEMIES_PER_ROUND:
		$RoundSpawnTimer.start()

func end_round():
	round_active = false
	$Grid.building_enabled = true
	$Grid.debug_path = $Grid.get_grid_path()
	$Grid.queue_redraw()
	$RoundSpawnTimer.stop()

	print("Round ended")

func _spawn_enemy():
	var enemy = EnemyScene.instantiate()
	enemy.path = current_round_path
	enemy.tile_size = $Grid.TILE_SIZE
	enemy.reached_goal.connect(_on_enemy_reached_goal)
	$Grid.add_child(enemy)

func _on_round_spawn_timer_timeout():
	if not round_active:
		$RoundSpawnTimer.stop()
		return

	if enemies_spawned >= ENEMIES_PER_ROUND:
		$RoundSpawnTimer.stop()
		return

	_spawn_enemy()
	enemies_spawned += 1

	if enemies_spawned >= ENEMIES_PER_ROUND:
		$RoundSpawnTimer.stop()

func _on_enemy_reached_goal():
	enemies_finished += 1
	print("Enemy reached tower: %d/%d" % [enemies_finished, ENEMIES_PER_ROUND])

	if enemies_finished >= ENEMIES_PER_ROUND:
		end_round()

func _on_grid_changed():
	$Grid.debug_path = $Grid.get_grid_path()
	$Grid.queue_redraw()

	if not round_active:
		return

	for child in $Grid.get_children():
		if child.has_method("get_current_cell") and child.has_method("repath"):
			var current_cell: Vector2i = child.get_current_cell()
			var new_path: Array[Vector2i] = $Grid.get_grid_path_from(current_cell)
			child.repath(new_path)
