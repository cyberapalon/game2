extends Node2D
## Hand-authored room data. Spawn markers belong to the room, never to the HUD.

@export var room_id: StringName
@export var title: String
@export var depth_km: float = 0.0
@export var width: int = 1280


func spawn_position(entry: StringName) -> Vector2:
	var marker: Marker2D = get_node_or_null("Spawns/" + String(entry))
	assert(marker != null, "Missing entrance %s in %s" % [entry, room_id])
	return marker.position


func has_entry(entry: StringName) -> bool:
	return get_node_or_null("Spawns/" + String(entry)) is Marker2D
