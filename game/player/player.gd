extends CharacterBody2D
## Owns movement only. World and HUD do not modify velocity.

@export var settings: PlayerSettings

@onready var visual: AnimatedSprite2D = $Visual


func _physics_process(delta: float) -> void:
	velocity.x = Input.get_axis("move_left", "move_right") * settings.move_speed
	if not is_on_floor():
		velocity.y += settings.gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = -settings.jump_speed
	move_and_slide()
	_update_visual()


func _update_visual() -> void:
	# Presentation reads the result of physics; no clip controls movement.
	if not is_zero_approx(velocity.x):
		visual.flip_h = velocity.x < 0.0
	if not is_on_floor():
		visual.play(&"jump" if velocity.y < 0.0 else &"fall")
	elif not is_zero_approx(velocity.x):
		visual.play(&"run")
	else:
		visual.play(&"idle")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# A lost key-up must not leave the character moving after tab switching.
		for action: StringName in [&"move_left", &"move_right", &"jump"]:
			Input.action_release(action)
