class_name Grid
extends Node2D

signal grid_changed

enum HoverMode {
	NONE,
	PLACE_VALID,
	PLACE_INVALID,
	REMOVE,
}

const TILE_SIZE := 64
const GRID_WIDTH := 16
const GRID_HEIGHT := 10
const EMPTY := 0
const BLOCKED := 1
const ATTACKER := 2
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]
const INVALID_FLASH_DURATION := 0.18

@warning_ignore("integer_division")
var spawn: Vector2i = Vector2i(0, GRID_HEIGHT / 2)
@warning_ignore("integer_division")
var goal: Vector2i = Vector2i(GRID_WIDTH - 1, GRID_HEIGHT / 2)
var hovered_cell: Vector2i = Vector2i(-1, -1)
var hovered_in_bounds: bool = false
var hover_mode: HoverMode = HoverMode.NONE
var round_active: bool = false
var debug_path: Array[Vector2i] = []
var invalid_flash_time: float = 0.0
var game: Game # reference to Main
var pressed_cell: Vector2i = Vector2i(-1, -1)
var is_pressing: bool = false
var pressed_button: int = -1
var tower_scene := preload("res://scenes/tower/tower.tscn")
var barrier_definition := preload("res://resources/tower/definitions/barrier.tres")
var attacker_definition := preload("res://resources/tower/definitions/basic_attacker.tres")
var towers_by_cell: Dictionary[Vector2i, Tower] = { }

@onready var overlay: GridOverlay = $GridOverlay


func _ready():
	debug_path = get_grid_path()
	overlay.grid = self


func _process(delta: float):
	if invalid_flash_time > 0.0:
		invalid_flash_time = maxf(0.0, invalid_flash_time - delta)
		if invalid_flash_time == 0.0:
			overlay.queue_redraw()


func _input(event):
	if event is InputEventMouseMotion:
		_update_hover()
		return

	if event is InputEventMouseButton and (
		event.button_index == MOUSE_BUTTON_LEFT
		or event.button_index == MOUSE_BUTTON_RIGHT
	):
		_update_hover()

		if event.pressed:
			_handle_mouse_press(event)
		else:
			_handle_mouse_release(event)


func _draw():
	var base_empty := Color(0.15, 0.15, 0.15)
	var grid_line := Color(0.0, 0.0, 0.0)
	var invalid_flash := invalid_flash_time > 0.0

	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var cell := Vector2i(x, y)
			var rect := Rect2(grid_to_local(cell), Vector2(TILE_SIZE, TILE_SIZE))

			var fill := base_empty
			if invalid_flash and hovered_in_bounds and cell == hovered_cell:
				fill = Color(0.8, 0.2, 0.2)

			draw_rect(rect, fill)
			draw_rect(rect, grid_line, false)

	# Spawn as portal
	var spawn_rect := Rect2(grid_to_local(spawn), Vector2(TILE_SIZE, TILE_SIZE))
	var outer_color := Color(0.25, 0.05, 0.4)
	var mid_color := Color(0.5, 0.15, 0.8)
	var inner_color := Color(0.75, 0.35, 1.0)
	var core_color := Color(1.0, 0.7, 1.0)
	draw_rect(spawn_rect, outer_color)
	draw_rect(spawn_rect.grow(-6), mid_color)
	draw_rect(spawn_rect.grow(-10), inner_color)
	draw_rect(spawn_rect.grow(-16), core_color)
	draw_rect(spawn_rect.grow(-1), Color(0.6, 0.2, 0.9), false, 2.0)

	# Goal as wizard tower
	var goal_rect := Rect2(grid_to_local(goal), Vector2(TILE_SIZE, TILE_SIZE))

	var tower_base_color := Color(0.28, 0.28, 0.34)
	var tower_mid_color := Color(0.38, 0.38, 0.46)
	var tower_top_color := Color(0.5, 0.5, 0.6)
	var window_color := Color(0.3, 0.9, 1.0)
	var crystal_color := Color(0.8, 0.95, 1.0)

	# foundation
	draw_rect(goal_rect, tower_base_color)

	# main shaft
	var shaft_width := TILE_SIZE * 0.45
	var shaft_height := TILE_SIZE * 0.58
	var shaft_pos := goal_rect.position + Vector2(
		(TILE_SIZE - shaft_width) / 2.0,
		TILE_SIZE * 0.28,
	)
	var shaft_rect := Rect2(shaft_pos, Vector2(shaft_width, shaft_height))
	draw_rect(shaft_rect, tower_mid_color)

	# battlement top
	var top_width := TILE_SIZE * 0.72
	var top_height := TILE_SIZE * 0.16
	var top_pos := goal_rect.position + Vector2(
		(TILE_SIZE - top_width) / 2.0,
		TILE_SIZE * 0.18,
	)
	var top_rect := Rect2(top_pos, Vector2(top_width, top_height))
	draw_rect(top_rect, tower_top_color)

	# crenellations
	var crenel_width := TILE_SIZE * 0.12
	var crenel_height := TILE_SIZE * 0.08
	for i in 3:
		var crenel_x := top_rect.position.x + TILE_SIZE * 0.06 + i * TILE_SIZE * 0.22
		var crenel_rect := Rect2(
			Vector2(crenel_x, top_rect.position.y - crenel_height),
			Vector2(crenel_width, crenel_height),
		)
		draw_rect(crenel_rect, tower_top_color)

	# glowing window
	var window_rect := Rect2(
		goal_rect.position + Vector2(TILE_SIZE * 0.42, TILE_SIZE * 0.48),
		Vector2(TILE_SIZE * 0.16, TILE_SIZE * 0.2),
	)
	draw_rect(window_rect, window_color)

	# crystal / beacon on top
	var crystal_rect := Rect2(
		goal_rect.position + Vector2(TILE_SIZE * 0.44, TILE_SIZE * 0.06),
		Vector2(TILE_SIZE * 0.12, TILE_SIZE * 0.12),
	)
	draw_rect(crystal_rect, crystal_color)

	# outline
	draw_rect(goal_rect.grow(-1), Color(0.1, 0.1, 0.15), false, 2.0)


func local_to_grid(pos: Vector2) -> Vector2i:
	return Vector2i(pos / TILE_SIZE)


func grid_to_local(cell: Vector2i) -> Vector2:
	return Vector2(cell.x, cell.y) * TILE_SIZE


# TODO this is being called by Main because it's an easy way to update the grid overlay
func refresh_hover():
	_update_hover()


func get_grid_pixel_size() -> Vector2:
	return Vector2(GRID_WIDTH, GRID_HEIGHT) * TILE_SIZE


func get_grid_path() -> Array[Vector2i]:
	return get_grid_path_from(spawn)


func get_grid_path_from(start_cell: Vector2i) -> Array[Vector2i]:
	var visited: Dictionary = { }
	var queue: Array[Vector2i] = [start_cell]
	var came_from: Dictionary = { }

	visited[start_cell] = true

	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()

		if current == goal:
			return _reconstruct_path(came_from, current)

		for dir in DIRS:
			var next_cell: Vector2i = current + dir

			if not _in_bounds(next_cell):
				continue

			if visited.has(next_cell):
				continue

			if get_tower_definition(next_cell) != null:
				continue

			visited[next_cell] = true
			came_from[next_cell] = current
			queue.append(next_cell)

	return [] # no path (shouldn't happen if your placement rules are correct)


func get_tower_definition(cell: Vector2i) -> TowerDefinition:
	var tower: Tower = towers_by_cell.get(cell)
	if tower == null:
		return null
	return tower.definition


func _handle_mouse_press(event: InputEventMouseButton) -> void:
	if is_pressing:
		return

	if not hovered_in_bounds:
		return

	is_pressing = true
	pressed_button = event.button_index
	pressed_cell = hovered_cell


func _handle_mouse_release(event: InputEventMouseButton) -> void:
	if not is_pressing:
		return

	if event.button_index != pressed_button:
		return

	if not hovered_in_bounds or hovered_cell != pressed_cell:
		_clear_press_state()
		return

	var cell: Vector2i = hovered_cell
	_clear_press_state()

	if cell == spawn or cell == goal:
		_trigger_invalid_feedback()
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click(cell)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_handle_right_click(cell)


func _clear_press_state() -> void:
	is_pressing = false
	pressed_button = -1
	pressed_cell = Vector2i(-1, -1)


func _handle_left_click(cell: Vector2i) -> void:
	var current_tower_definition := get_tower_definition(cell)

	if current_tower_definition == attacker_definition:
		_trigger_invalid_feedback()
	elif current_tower_definition == barrier_definition:
		if _can_place(attacker_definition, cell):
			_set_tower_definition(attacker_definition, cell)
			game.spend_mana(attacker_definition.mana_cost)
			_after_grid_changed()
		else:
			_trigger_invalid_feedback()
	elif _can_place(barrier_definition, cell):
		_set_tower_definition(barrier_definition, cell)
		game.spend_mana(barrier_definition.mana_cost)
		_after_grid_changed()
	else:
		_trigger_invalid_feedback()


func _handle_right_click(cell: Vector2i) -> void:
	var current_tower_definition := get_tower_definition(cell)

	if current_tower_definition == attacker_definition:
		_set_tower_definition(barrier_definition, cell)
		game.queue_mana_refund(attacker_definition.mana_cost)
		_after_grid_changed()
	elif current_tower_definition == barrier_definition:
		_set_tower_definition(null, cell)
		game.queue_mana_refund(barrier_definition.mana_cost)
		_after_grid_changed()
	else:
		_trigger_invalid_feedback()


func _set_tower_definition(definition: TowerDefinition, cell: Vector2i) -> void:
	var existing_tower: Tower = towers_by_cell.get(cell)

	if definition == null:
		if existing_tower != null:
			towers_by_cell.erase(cell)
			existing_tower.queue_free()
		return

	if existing_tower == null:
		var tower: Tower = tower_scene.instantiate()
		add_child(tower)
		tower.position = grid_to_local(cell)
		tower.setup(cell, definition)
		towers_by_cell[cell] = tower
	else:
		existing_tower.set_definition(definition)


func _after_grid_changed():
	_update_hover()
	debug_path = get_grid_path()
	overlay.queue_redraw()
	emit_signal("grid_changed")


func _update_hover() -> void:
	var local_pos: Vector2 = to_local(get_global_mouse_position())
	var cell: Vector2i = local_to_grid(local_pos)

	hovered_cell = cell
	hovered_in_bounds = _in_bounds(cell)
	hover_mode = HoverMode.NONE

	if not hovered_in_bounds:
		overlay.queue_redraw()
		return

	if cell == spawn or cell == goal:
		hover_mode = HoverMode.PLACE_INVALID
		overlay.queue_redraw()
		return

	if get_tower_definition(cell) != null:
		hover_mode = HoverMode.REMOVE
		overlay.queue_redraw()
		return

	if _can_place(barrier_definition, cell):
		hover_mode = HoverMode.PLACE_VALID
	else:
		hover_mode = HoverMode.PLACE_INVALID

	overlay.queue_redraw()


func _can_place(definition: TowerDefinition, cell: Vector2i) -> bool:
	if not game.can_afford_mana_cost(definition.mana_cost):
		return false

	if not _in_bounds(cell):
		return false

	if cell == spawn or cell == goal:
		return false

	var current_tower_definition = get_tower_definition(cell)

	if current_tower_definition == attacker_definition:
		return false

	if _is_cell_occupied_by_enemy(cell):
		return false

	_set_tower_definition(barrier_definition, cell)
	var valid := true
	if not _path_exists_from(spawn):
		valid = false
	else:
		for enemy in _get_active_enemies():
			var anchor_cell: Vector2i = enemy.get_repath_anchor_cell()
			if not _path_exists_from(anchor_cell):
				valid = false
				break

	_set_tower_definition(current_tower_definition, cell)
	return valid


func _is_cell_occupied_by_enemy(cell: Vector2i) -> bool:
	for enemy in _get_active_enemies():
		for occupied_cell in enemy.get_occupied_cells():
			if occupied_cell == cell:
				return true
	return false


func _get_active_enemies() -> Array:
	var enemies: Array = []

	for child in get_children():
		if child.has_method("get_occupied_cells") and child.has_method("get_repath_anchor_cell"):
			enemies.append(child)

	return enemies


func _trigger_invalid_feedback():
	invalid_flash_time = INVALID_FLASH_DURATION
	overlay.queue_redraw()


func _path_exists_from(start_cell: Vector2i) -> bool:
	return not get_grid_path_from(start_cell).is_empty()


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_WIDTH and cell.y >= 0 and cell.y < GRID_HEIGHT


func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]

	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)

	return path
