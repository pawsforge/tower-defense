extends Node2D

const ENEMIES_PER_ROUND := 5

var round_active: bool = false
var EnemyScene := preload("res://scenes/enemy/enemy.tscn")
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

	$Grid.round_active = true
	$Grid.queue_redraw()

	print("Round started")

	_spawn_enemy()
	enemies_spawned += 1

	if enemies_spawned < ENEMIES_PER_ROUND:
		$RoundSpawnTimer.start()


func end_round():
	round_active = false
	$Grid.round_active = false
	$Grid.debug_path = $Grid.get_grid_path()
	$Grid.queue_redraw()
	$RoundSpawnTimer.stop()

	print("Round ended")


func _spawn_enemy():
	current_round_path = $Grid.get_grid_path()

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
	var spawn_path: Array[Vector2i] = $Grid.get_grid_path()
	$Grid.debug_path = spawn_path
	$Grid.queue_redraw()

	current_round_path = spawn_path

	if not round_active:
		return

	for child in $Grid.get_children():
		if child.has_method("get_repath_anchor_cell") and child.has_method("repath"):
			var anchor_cell: Vector2i = child.get_repath_anchor_cell()
			var new_path: Array[Vector2i] = $Grid.get_grid_path_from(anchor_cell)
			child.repath(new_path)
