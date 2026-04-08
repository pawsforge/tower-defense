class_name Game
extends Node2D

const TT = TowerType.Type
const ENEMIES_PER_ROUND := 5

var round_active: bool = false
var EnemyScene := preload("res://scenes/enemy/enemy.tscn")
var enemies_spawned: int = 0
var enemies_finished: int = 0
var current_round_path: Array[Vector2i] = []
# Mana and mana-related variables
var max_mana: float = 100.0
var available_mana: float = max_mana
var mana_pending_refund: float = 0.0
var mana_regen_rate: float = 5.0
var build_or_upgrade_cost: Dictionary[TT, int] = {
	TT.EMPTY: 0,
	TT.BARRIER: 10,
	TT.ATTACKER: 20,
}

@onready var mana_label: Label = $ManaLabel


func _ready():
	$Grid.game = self

	var viewport_size: Vector2 = get_viewport_rect().size
	var grid_size: Vector2 = $Grid.get_grid_pixel_size()
	$Grid.position = (viewport_size - grid_size) / 2.0

	$RoundSpawnTimer.timeout.connect(_on_round_spawn_timer_timeout)
	$Grid.grid_changed.connect(_on_grid_changed)

	_update_mana_label()


func _process(delta: float):
	if mana_pending_refund > 0.0:
		var to_refund := minf(mana_regen_rate * delta, mana_pending_refund)
		available_mana += to_refund
		mana_pending_refund -= to_refund
		available_mana = clampf(available_mana, 0.0, max_mana)

		if mana_pending_refund < 0.0001:
			available_mana += mana_pending_refund
			mana_pending_refund = 0.0
			available_mana = snappedf(available_mana, 0.001)

		if available_mana >= build_or_upgrade_cost[TT.BARRIER]:
			$Grid.refresh_hover()

		_update_mana_label()

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


func can_afford(tower_type: TT) -> bool:
	return available_mana + 0.0001 >= build_or_upgrade_cost[tower_type] # be tolerant of tiny float errors


func spend_mana(tower_type: TT) -> bool:
	if can_afford(tower_type):
		available_mana -= build_or_upgrade_cost[tower_type]
		_update_mana_label()
		return true
	return false


func queue_mana_refund(tower_type: TT):
	mana_pending_refund += build_or_upgrade_cost[tower_type]
	_update_mana_label()


func _spawn_enemy():
	current_round_path = $Grid.get_grid_path()

	var enemy = EnemyScene.instantiate()
	enemy.path = current_round_path
	enemy.tile_size = $Grid.TILE_SIZE
	enemy.died.connect(_on_enemy_died)
	enemy.reached_goal.connect(_on_enemy_reached_goal)
	$Grid.add_child(enemy)


func _update_mana_label():
	mana_label.text = "Mana: %d / %d (+%.1f)" % [
		int(available_mana),
		int(max_mana),
		mana_pending_refund,
	]


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


func _on_enemy_died():
	enemies_finished += 1
	print("Enemy died: %d/%d" % [enemies_finished, ENEMIES_PER_ROUND])

	if enemies_finished >= ENEMIES_PER_ROUND:
		end_round()


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
