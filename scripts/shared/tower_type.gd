class_name TowerType
extends RefCounted

enum Type {
	ATTACKER,
	BARRIER,
	## EMPTY will be removed in favor of null when we transition to towers as nodes/scenes
	EMPTY,
}
