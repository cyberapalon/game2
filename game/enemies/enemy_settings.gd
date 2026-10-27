class_name EnemySettings
extends Resource

@export_enum("kornevik", "sporon") var species: String = "kornevik"
@export var max_health: int = 6
@export var patrol_speed: float = 32.0
@export var chase_speed: float = 74.0
@export var detection_range: float = 270.0
@export var windup: float = 0.6
@export var recovery: float = 1.0
@export var damage: int = 1
