class_name Tower
extends Node2D

const TILE_SIZE := 64

var grid_position: Vector2i
var definition: TowerDefinition
var cooldown_remaining: float


func _process(delta: float) -> void:
	if definition == null or definition.role != TowerDefinition.Role.ATTACKER:
		return

	cooldown_remaining = clampf(cooldown_remaining - delta, 0.0, definition.attack_cooldown)

	if cooldown_remaining > 0.0:
		return

	var target = _find_target()
	if target == null:
		return

	target.take_damage(definition.attack_damage)
	cooldown_remaining = definition.attack_cooldown


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
	cooldown_remaining = definition.attack_cooldown
	update_visuals()


func blocks_pathing() -> bool:
	return definition.blocks_pathing


func update_visuals() -> void:
	queue_redraw()


## Finds the closest target (if any) to the tower
func _find_target():
	var grid = get_parent()
	var best_target = null
	var best_distance := INF
	var range_pixels := definition.tower_range * TILE_SIZE

	for child in grid.get_children():
		if child == self:
			continue
		if not child.has_method("take_damage"):
			continue

		var distance := global_position.distance_to(child.global_position)
		if distance > range_pixels:
			continue

		if distance < best_distance:
			best_distance = distance
			best_target = child

	return best_target
