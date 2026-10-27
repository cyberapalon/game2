extends Area2D

signal activated(point: Area2D)

@export var point_id: StringName
var active: bool = false


func _physics_process(_delta: float) -> void:
	if active:
		return
	for body: Node2D in get_overlapping_bodies():
		if body.is_in_group(&"player") and not body.dead and not body.control_locked:
			set_active(true)
			activated.emit(self)
			return


func set_active(value: bool) -> void:
	active = value
	$Painting.modulate = Color(1.25, 1.05, 0.75) if active else Color(0.5, 0.65, 0.72)
	$Caption.text = "ПАМЯТЬ СОХРАНЕНА" if active else "ОЧАГ ПАМЯТИ"
