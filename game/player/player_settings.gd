class_name PlayerSettings
extends Resource
## Prototype values in pixels and seconds; shared, immutable during play.

@export var move_speed: float = 240.0
@export var jump_speed: float = 500.0
@export var gravity: float = 1400.0
@export_range(40.0, 60.0, 1.0) var short_jump_height: float = 50.0
@export var coyote_seconds: float = 0.1
@export var jump_buffer_seconds: float = 0.1
