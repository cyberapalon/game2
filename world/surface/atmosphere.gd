extends Node2D
## Slow visual drift only, independent from world physics and input.

@onready var mist: Sprite2D = $Mist

var _elapsed: float = 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	mist.position.x = -90.0 + sin(_elapsed * 0.09) * 45.0
	mist.modulate.a = 0.7 + sin(_elapsed * 0.16) * 0.2
