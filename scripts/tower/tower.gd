class_name Tower
extends Node2D

const TILE_SIZE := 64

var grid_position: Vector2i
var definition: TowerDefinition


func _draw() -> void:
	if definition == null:
		return

	var rect := Rect2(Vector2.ZERO, Vector2(TILE_SIZE, TILE_SIZE))

	match definition.role:
		TowerDefinition.Role.BLOCKER:
			draw_rect(rect, Color(0.35, 0.35, 0.4))
		TowerDefinition.Role.ATTACKER:
			draw_rect(rect, Color(0.6, 0.6, 0.3))

	draw_rect(rect, Color(0.0, 0.0, 0.0), false)


func setup(p_grid_position: Vector2i, p_definition: TowerDefinition) -> void:
	grid_position = p_grid_position
	set_definition(p_definition)


func set_definition(p_definition: TowerDefinition) -> void:
	definition = p_definition
	update_visuals()


func blocks_pathing() -> bool:
	return definition.blocks_pathing


func update_visuals() -> void:
	queue_redraw()
