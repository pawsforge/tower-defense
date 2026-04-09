class_name GridOverlay
extends Node2D

var grid: Grid = null


func _draw() -> void:
	if grid == null:
		return

	# Debug path only during build phase
	if not grid.round_active:
		for cell in grid.debug_path:
			var center := grid.grid_to_local(cell) + Vector2(grid.TILE_SIZE, grid.TILE_SIZE) * 0.5
			draw_circle(center, 6.0, Color(1.0, 1.0, 0.2))

	if grid.hovered_in_bounds:
		var hover_rect := Rect2(
			grid.grid_to_local(grid.hovered_cell),
			Vector2(grid.TILE_SIZE, grid.TILE_SIZE),
		)

		match grid.hover_mode:
			grid.HoverMode.REMOVE:
				draw_rect(hover_rect, Color(1.0, 0.85, 0.2, 0.22))
				draw_rect(hover_rect, Color(1.0, 0.85, 0.2), false, 3.0)
			grid.HoverMode.PLACE_VALID:
				draw_rect(hover_rect, Color(0.3, 1.0, 0.3, 0.2))
				draw_rect(hover_rect, Color(0.3, 1.0, 0.3), false, 3.0)
			grid.HoverMode.PLACE_INVALID:
				draw_rect(hover_rect, Color(1.0, 0.3, 0.3, 0.25))
				draw_rect(hover_rect, Color(1.0, 0.3, 0.3), false, 3.0)
			grid.HoverMode.NONE:
				pass

	if grid.invalid_flash_time > 0.0 and grid.hovered_in_bounds:
		var flash_rect := Rect2(
			grid.grid_to_local(grid.hovered_cell),
			Vector2(grid.TILE_SIZE, grid.TILE_SIZE),
		)
		draw_rect(flash_rect, Color(0.8, 0.2, 0.2))
