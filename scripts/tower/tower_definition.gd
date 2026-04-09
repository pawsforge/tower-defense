# This is meant to act as shared config data.
# Don't put mutable per-tower state like cooldown progress in it.
class_name TowerDefinition
extends Resource

enum Role {
	ATTACKER,
	BLOCKER,
}

@export var role: Role
@export var mana_cost: int = 0
@export var blocks_pathing: bool = true
@export var tower_range: float = 0.0
@export var attack_damage: int = 0
@export var attack_cooldown: float = 0.0
