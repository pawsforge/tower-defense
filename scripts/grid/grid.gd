extends Node2D

signal grid_changed

const TILE_SIZE := 64
const GRID_WIDTH := 16
const GRID_HEIGHT := 10

const EMPTY := 0
const BLOCKED := 1

const DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

var grid: Array = []

var spawn: Vector2i = Vector2i(0, GRID_HEIGHT / 2)
var goal: Vector2i = Vector2i(GRID_WIDTH - 1, GRID_HEIGHT / 2)

var hovered_cell: Vector2i = Vector2i(-1, -1)
var hovered_in_bounds: bool = false
var hovered_can_place: bool = false

var building_enabled: bool = true

var debug_path: Array[Vector2i] = []

var invalid_flash_time: float = 0.0
const INVALID_FLASH_DURATION := 0.18

func _ready():
	_init_grid()
	debug_path = get_grid_path()

func _process(delta: float):
	if invalid_flash_time > 0.0:
		invalid_flash_time = maxf(0.0, invalid_flash_time - delta)

	queue_redraw()

func _input(event):
	if event is InputEventMouseMotion:
		_update_hover()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_update_hover()

		if not hovered_in_bounds:
			return

		var cell: Vector2i = hovered_cell

		if cell == spawn or cell == goal:
			_trigger_invalid_feedback()
			return

		if grid[cell.y][cell.x] == BLOCKED:
			grid[cell.y][cell.x] = EMPTY
			_update_hover()
			debug_path = get_grid_path()
			queue_redraw()
			emit_signal("grid_changed")
			return

		if not building_enabled:
			_trigger_invalid_feedback()
			return

		if _can_place(cell):
			grid[cell.y][cell.x] = BLOCKED
			_update_hover()
			debug_path = get_grid_path()
			queue_redraw()
			emit_signal("grid_changed")
		else:
			_trigger_invalid_feedback()

func _init_grid():
	grid.clear()
	for y in GRID_HEIGHT:
		var row: Array[int] = []
		for x in GRID_WIDTH:
			row.append(EMPTY)
		grid.append(row)

func _update_hover():
	var local_pos: Vector2 = to_local(get_global_mouse_position())
	var cell: Vector2i = local_to_grid(local_pos)

	hovered_cell = cell
	hovered_in_bounds = _in_bounds(cell)

	if not hovered_in_bounds:
		hovered_can_place = false
		queue_redraw()
		return

	if cell == spawn or cell == goal:
		hovered_can_place = false
		queue_redraw()
		return

	if grid[cell.y][cell.x] == BLOCKED:
		hovered_can_place = false
		queue_redraw()
		return

	hovered_can_place = _can_place(cell)
	queue_redraw()

func _can_place(cell: Vector2i) -> bool:
	grid[cell.y][cell.x] = BLOCKED
	var valid: bool = _path_exists()
	grid[cell.y][cell.x] = EMPTY
	return valid

func _trigger_invalid_feedback():
	invalid_flash_time = INVALID_FLASH_DURATION
	queue_redraw()

func _path_exists() -> bool:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [spawn]

	visited[spawn] = true

	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()

		if current == goal:
			return true

		for dir in DIRS:
			var next: Vector2i = current + dir

			if not _in_bounds(next):
				continue

			if visited.has(next):
				continue

			if grid[next.y][next.x] == BLOCKED:
				continue

			visited[next] = true
			queue.append(next)

	return false

func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_WIDTH and cell.y >= 0 and cell.y < GRID_HEIGHT

func local_to_grid(pos: Vector2) -> Vector2i:
	return Vector2i(pos / TILE_SIZE)

func grid_to_local(cell: Vector2i) -> Vector2:
	return Vector2(cell.x, cell.y) * TILE_SIZE

func get_grid_pixel_size() -> Vector2:
	return Vector2(GRID_WIDTH, GRID_HEIGHT) * TILE_SIZE

func _draw():
	var base_empty := Color(0.15, 0.15, 0.15)
	var base_blocked := Color(0.35, 0.35, 0.4)
	var grid_line := Color(0.0, 0.0, 0.0)
	var invalid_flash := invalid_flash_time > 0.0

	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var cell := Vector2i(x, y)
			var rect := Rect2(grid_to_local(cell), Vector2(TILE_SIZE, TILE_SIZE))

			var fill := base_empty
			if grid[y][x] == BLOCKED:
				fill = base_blocked

			if invalid_flash and hovered_in_bounds and cell == hovered_cell:
				fill = Color(0.8, 0.2, 0.2)

			draw_rect(rect, fill)
			draw_rect(rect, grid_line, false)

	# Spawn as portal
	var spawn_rect := Rect2(grid_to_local(spawn), Vector2(TILE_SIZE, TILE_SIZE))
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := (sin(t * 2.5) + 1.0) * 0.5

	var outer_color := Color(0.25, 0.05, 0.4)
	var mid_color := Color(0.5, 0.15, 0.8)
	var inner_color := Color(0.75, 0.35, 1.0)
	var core_color := Color(1.0, 0.7, 1.0)

	draw_rect(spawn_rect, outer_color)
	draw_rect(spawn_rect.grow(-6), mid_color)
	draw_rect(spawn_rect.grow(-10 - pulse * 2.0), inner_color)
	draw_rect(spawn_rect.grow(-16 - pulse * 3.0), core_color)
	draw_rect(spawn_rect, Color(0.6, 0.2, 0.9), false, 2.0)

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
		TILE_SIZE * 0.28
	)
	var shaft_rect := Rect2(shaft_pos, Vector2(shaft_width, shaft_height))
	draw_rect(shaft_rect, tower_mid_color)

	# battlement top
	var top_width := TILE_SIZE * 0.72
	var top_height := TILE_SIZE * 0.16
	var top_pos := goal_rect.position + Vector2(
		(TILE_SIZE - top_width) / 2.0,
		TILE_SIZE * 0.18
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
			Vector2(crenel_width, crenel_height)
		)
		draw_rect(crenel_rect, tower_top_color)

	# glowing window
	var window_rect := Rect2(
		goal_rect.position + Vector2(TILE_SIZE * 0.42, TILE_SIZE * 0.48),
		Vector2(TILE_SIZE * 0.16, TILE_SIZE * 0.2)
	)
	draw_rect(window_rect, window_color)

	# crystal / beacon on top
	var crystal_rect := Rect2(
		goal_rect.position + Vector2(TILE_SIZE * 0.44, TILE_SIZE * 0.06),
		Vector2(TILE_SIZE * 0.12, TILE_SIZE * 0.12)
	)
	draw_rect(crystal_rect, crystal_color)

	# outline
	draw_rect(goal_rect, Color(0.1, 0.1, 0.15), false, 2.0)
	
	# Debug path
	if building_enabled:
		for cell in debug_path:
			var center := grid_to_local(cell) + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
			draw_circle(center, 6.0, Color(1.0, 1.0, 0.2))

	# Hover overlay
	if building_enabled and hovered_in_bounds:
		var hover_rect := Rect2(grid_to_local(hovered_cell), Vector2(TILE_SIZE, TILE_SIZE))

		if hovered_cell == spawn or hovered_cell == goal:
			draw_rect(hover_rect, Color(1.0, 0.3, 0.3, 0.25))
			draw_rect(hover_rect, Color(1.0, 0.3, 0.3), false, 3.0)
		elif grid[hovered_cell.y][hovered_cell.x] == BLOCKED:
			draw_rect(hover_rect, Color(1.0, 0.9, 0.2, 0.2))
			draw_rect(hover_rect, Color(1.0, 0.9, 0.2), false, 3.0)
		elif hovered_can_place:
			draw_rect(hover_rect, Color(0.3, 1.0, 0.3, 0.2))
			draw_rect(hover_rect, Color(0.3, 1.0, 0.3), false, 3.0)
		else:
			draw_rect(hover_rect, Color(1.0, 0.3, 0.3, 0.25))
			draw_rect(hover_rect, Color(1.0, 0.3, 0.3), false, 3.0)

func get_grid_path() -> Array[Vector2i]:
	return get_grid_path_from(spawn)

func get_grid_path_from(start_cell: Vector2i) -> Array[Vector2i]:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start_cell]
	var came_from: Dictionary = {}

	visited[start_cell] = true

	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()

		if current == goal:
			return _reconstruct_path(came_from, current)

		for dir in DIRS:
			var next: Vector2i = current + dir

			if not _in_bounds(next):
				continue

			if visited.has(next):
				continue

			if grid[next.y][next.x] == BLOCKED:
				continue

			visited[next] = true
			came_from[next] = current
			queue.append(next)

	return []  # no path (shouldn't happen if your placement rules are correct)

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]

	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)

	return path
