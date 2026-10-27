extends CharacterBody2D
## Owns movement only. World and HUD do not modify velocity.

@export var settings: PlayerSettings

@onready var visual: WandererVisual = $Visual

var control_locked: bool = false
var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _jump_active: bool = false
var _jump_cut_applied: bool = false
var _jump_origin_y: float = 0.0


func _physics_process(delta: float) -> void:
	if control_locked:
		return
	_coyote_left = maxf(0.0, _coyote_left - delta)
	_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)
	if is_on_floor():
		_coyote_left = settings.coyote_seconds
		_jump_active = false
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_left = settings.jump_buffer_seconds
	velocity.x = Input.get_axis("move_left", "move_right") * settings.move_speed
	if not is_on_floor():
		velocity.y += settings.gravity * delta
	if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = -settings.jump_speed
		_jump_active = true
		_jump_cut_applied = false
		_jump_origin_y = position.y
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
	if _jump_active and not _jump_cut_applied and not Input.is_action_pressed("jump") and velocity.y < 0.0:
		# Keep a quick tap near 50px even when browser input arrives between
		# physics ticks. Release after that height ends the ascent immediately.
		var remaining_height: float = maxf(0.0, settings.short_jump_height - (_jump_origin_y - position.y))
		velocity.y = maxf(velocity.y, -sqrt(2.0 * settings.gravity * remaining_height))
		_jump_cut_applied = true
	move_and_slide()
	_update_visual(delta)


func set_control_locked(locked: bool) -> void:
	control_locked = locked
	velocity = Vector2.ZERO
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	_jump_active = false
	if locked:
		visual.play(&"idle")


func _update_visual(delta: float) -> void:
	# Presentation reads the result of physics; no clip controls movement.
	if not is_zero_approx(velocity.x):
		visual.flip_h = velocity.x < 0.0
	var clip: StringName = &"idle"
	if not is_on_floor():
		clip = &"jump" if velocity.y < 0.0 else &"fall"
	elif not is_zero_approx(velocity.x):
		clip = &"run"
	if visual.animation != clip:
		visual.play(clip)
	visual.advance_motion(velocity, is_on_floor(), delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
		# A lost key-up must not leave the character moving after tab switching.
		for action: StringName in [&"move_left", &"move_right", &"jump", &"interact"]:
			Input.action_release(action)
