extends Area2D
## A local interaction trigger; the route owns dialogue and room lifecycle.

@export_enum("portal", "npc", "secret", "seal") var kind: String = "portal"
@export var prompt: String = "E — войти"
@export var target_room: StringName
@export var target_entry: StringName


func contains_player(player: CharacterBody2D) -> bool:
	return overlaps_body(player)
