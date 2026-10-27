extends Area2D
## Slow painted projectile; world, lifetime and hurt all terminate it once.

@export var speed: float = 110.0
@export var damage: int = 1
var direction: Vector2 = Vector2.LEFT
var life: float = 5.0
var consumed: bool = false


func _ready() -> void:
	add_to_group(&"hostile_projectiles")
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	life -= delta
	$Painting.rotation += delta * 1.2
	if life <= 0.0:
		queue_free()


func _on_body(body: Node2D) -> void:
	if consumed:
		return
	consumed = true
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
	queue_free()
