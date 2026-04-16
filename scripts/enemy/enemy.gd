class_name Enemy
extends Node2D

signal died
signal reached_goal

const HIT_FLASH_DURATION := 0.1

var path: Array[Vector2i] = []
var path_index: int = 0
var tile_size: int = 64
var hit_flash_time: float = 0.0
var health: int
var definition: EnemyDefinition


func _ready():
	if path.size() > 0:
		position = cell_to_world_center(path[0])
		path_index = 1


func _process(delta: float) -> void:
	if hit_flash_time > 0.0:
		hit_flash_time = maxf(0.0, hit_flash_time - delta)
		queue_redraw()


func _physics_process(delta: float) -> void:
	if path_index >= path.size():
		emit_signal("reached_goal")
		queue_free()
		return

	var target_cell: Vector2i = path[path_index]
	var target_pos: Vector2 = cell_to_world_center(target_cell)

	position = position.move_toward(target_pos, definition.move_speed * delta)

	if position.is_equal_approx(target_pos):
		position = target_pos
		path_index += 1

		if path_index >= path.size():
			emit_signal("reached_goal")
			queue_free()
			return

	queue_redraw()


func _draw():
	var body_color := definition.color
	if hit_flash_time > 0.0:
		body_color = Color(1.0, 0.9, 0.9)

	draw_circle(Vector2.ZERO, tile_size * 0.25, body_color)

	var bar_width := tile_size * 0.5
	var bar_height := 6.0
	var bar_x := -bar_width / 2.0
	var bar_y := -tile_size * 0.45

	var bg_rect := Rect2(bar_x, bar_y, bar_width, bar_height)
	draw_rect(bg_rect, Color(0.15, 0.15, 0.15))

	var health_fraction := float(health) / float(definition.max_health)

	var inset := 1.0
	var fill_rect := Rect2(
		bar_x + inset,
		bar_y + inset,
		(bar_width - inset * 2.0) * health_fraction,
		bar_height - inset * 2.0,
	)
	draw_rect(fill_rect, Color(0.2, 0.9, 0.2))

	draw_rect(bg_rect, Color.BLACK, false, 2.0)


func setup(p_definition: EnemyDefinition, p_path: Array[Vector2i]) -> void:
	definition = p_definition
	path = p_path

	health = definition.max_health


func get_current_cell() -> Vector2i:
	return Vector2i(
		int(position.x / tile_size),
		int(position.y / tile_size),
	)


func repath(new_path: Array[Vector2i]):
	if new_path.is_empty():
		return

	path = new_path
	path_index = 0


func cell_to_world_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x, cell.y) * tile_size + Vector2(tile_size, tile_size) * 0.5


func get_repath_anchor_cell() -> Vector2i:
	if path_index < path.size():
		return path[path_index]

	if path.size() > 0:
		return path[path.size() - 1]

	return Vector2i.ZERO


func get_occupied_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []

	var current_cell := get_current_cell()
	cells.append(current_cell)

	var anchor_cell := get_repath_anchor_cell()
	if anchor_cell != current_cell:
		cells.append(anchor_cell)

	return cells


func take_damage(amount: int):
	if amount <= 0:
		return

	hit_flash_time = HIT_FLASH_DURATION
	queue_redraw()

	var was_alive := health > 0
	health = clampi(health - amount, 0, definition.max_health)
	if was_alive and health == 0:
		die()


func die():
	emit_signal("died")
	queue_free()


func _on_damage_timer_timeout() -> void:
	take_damage(1)
