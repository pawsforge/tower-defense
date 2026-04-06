extends Node2D

signal reached_goal

var path: Array[Vector2i] = []
var path_index: int = 0
var speed: float = 120.0
var tile_size: int = 64

func _ready():
	if path.size() > 0:
		position = grid_to_local(path[0])
		path_index = 1

func _process(delta: float):
	if path_index >= path.size():
		emit_signal("reached_goal")
		queue_free()
		return

	var target_cell: Vector2i = path[path_index]
	var target_pos: Vector2 = grid_to_local(target_cell)

	var direction: Vector2 = target_pos - position
	var distance: float = direction.length()

	if distance < 2.0:
		position = target_pos
		path_index += 1

		if path_index >= path.size():
			emit_signal("reached_goal")
			queue_free()
			return
	else:
		position += direction.normalized() * speed * delta

	queue_redraw()

func get_current_cell() -> Vector2i:
	return Vector2i(position / tile_size)

func repath(new_path: Array[Vector2i]):
	if new_path.is_empty():
		return

	path = new_path

	var first_pos: Vector2 = grid_to_local(path[0])
	if position.distance_to(first_pos) < 2.0:
		path_index = 1
	else:
		path_index = 0

func grid_to_local(cell: Vector2i) -> Vector2:
	return Vector2(cell.x, cell.y) * tile_size + Vector2(tile_size, tile_size) * 0.5

func _draw():
	draw_circle(Vector2.ZERO, tile_size * 0.25, Color(1.0, 0.2, 0.2))
