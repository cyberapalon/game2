extends CharacterBody2D
## Authoritative movement and combat. Presentation never controls collisions.

signal health_changed(current: int, maximum: int)
signal died
signal combat_event(kind: StringName, point: Vector2)

@export var settings: PlayerSettings
@export var combat: CombatSettings

@onready var visual: WandererVisual = $Visual
@onready var strike: Area2D = $Strike
@onready var combat_sprite: AnimatedSprite2D = $CombatSprite

var health: int = 6
var dead: bool = false
var invulnerable_left: float = 0.0
var attack_left: float = 0.0
var dash_unlocked: bool = false
var dash_left: float = 0.0
var dash_cooldown_left: float = 0.0
var hits_landed: int = 0
var damage_taken: int = 0
var dash_count: int = 0
var _hurt_left: float = 0.0
var _death_elapsed: float = 0.0
var _hitstop: float = 0.0
var _knockback: float = 0.0
var _attack_facing: float = 1.0
var _hit_targets: Array[int] = []

var control_locked: bool = false
var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _jump_active: bool = false
var _jump_cut_applied: bool = false
var _jump_origin_y: float = 0.0


func _ready() -> void:
	health = combat.max_health
	add_to_group(&"player")


func _physics_process(delta: float) -> void:
	if dead:
		_death_elapsed += delta
		combat_sprite.frame = mini(3, int(_death_elapsed * 4.0))
		return
	invulnerable_left = maxf(0.0, invulnerable_left - delta)
	dash_cooldown_left = maxf(0.0, dash_cooldown_left - delta)
	_hurt_left = maxf(0.0, _hurt_left - delta)
	if _hitstop > 0.0:
		_hitstop -= delta
		return
	if control_locked:
		return
	if Input.is_action_just_pressed("attack"):
		start_attack()
	if Input.is_action_just_pressed("dash"):
		start_dash()
	attack_left = maxf(0.0, attack_left - delta)
	strike.position.x = _attack_facing * 36.0
	if is_strike_active():
		for target: Node2D in strike.get_overlapping_bodies():
			if target.has_method("take_damage") and not _hit_targets.has(target.get_instance_id()):
				_hit_targets.append(target.get_instance_id())
				if target.take_damage(combat.strike_damage, global_position):
					hits_landed += 1
					_hitstop = 0.045
					combat_event.emit(&"hit", target.global_position)
	_coyote_left = maxf(0.0, _coyote_left - delta)
	_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)
	if is_on_floor():
		_coyote_left = settings.coyote_seconds
		_jump_active = false
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_left = settings.jump_buffer_seconds
	velocity.x = Input.get_axis("move_left", "move_right") * settings.move_speed + _knockback
	_knockback = move_toward(_knockback, 0.0, 1300.0 * delta)
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
	if dash_left > 0.0:
		dash_left = maxf(0.0, dash_left - delta)
		velocity = Vector2((-1.0 if visual.flip_h else 1.0) * combat.dash_speed, 0.0)
	move_and_slide()
	_update_visual(delta)
	_update_combat_visual()


func start_attack() -> bool:
	if dead or control_locked or attack_left > 0.0 or dash_left > 0.0:
		return false
	attack_left = combat.windup + combat.active_time + combat.recovery
	var intent: float = Input.get_axis("move_left", "move_right")
	_attack_facing = intent if not is_zero_approx(intent) else (-1.0 if visual.flip_h else 1.0)
	visual.flip_h = _attack_facing < 0.0
	_hit_targets.clear()
	combat_event.emit(&"attack", global_position)
	return true


func is_strike_active() -> bool:
	return attack_left > combat.recovery and attack_left <= combat.recovery + combat.active_time


func take_damage(amount: int, source: Vector2) -> bool:
	if dead or control_locked or invulnerable_left > 0.0 or dash_left > 0.0 or amount <= 0:
		return false
	health = maxi(0, health - amount)
	damage_taken += amount
	invulnerable_left = combat.invulnerability
	_hurt_left = 0.28
	attack_left = 0.0
	_hitstop = 0.065
	_knockback = (-1.0 if source.x >= global_position.x else 1.0) * 220.0
	health_changed.emit(health, combat.max_health)
	combat_event.emit(&"hurt", global_position)
	if health == 0:
		dead = true
		velocity = Vector2.ZERO
		_death_elapsed = 0.0
		combat_event.emit(&"death", global_position)
		died.emit()
	_update_combat_visual()
	return true


func restore_health() -> void:
	health = combat.max_health
	health_changed.emit(health, combat.max_health)


func respawn(at: Vector2) -> void:
	dead = false
	attack_left = 0.0
	dash_left = 0.0
	dash_cooldown_left = 0.0
	_hurt_left = 0.0
	_hitstop = 0.0
	_knockback = 0.0
	invulnerable_left = combat.invulnerability
	position = at
	set_control_locked(false)
	restore_health()
	_update_combat_visual()


func start_dash() -> bool:
	if not dash_unlocked or dead or control_locked or dash_cooldown_left > 0.0:
		return false
	var intent: float = Input.get_axis("move_left", "move_right")
	if not is_zero_approx(intent):
		visual.flip_h = intent < 0.0
	dash_left = combat.dash_duration
	dash_cooldown_left = combat.dash_cooldown
	attack_left = 0.0
	dash_count += 1
	combat_event.emit(&"dash", global_position)
	return true


func _update_combat_visual() -> void:
	var clip: StringName = &""
	if dead:
		clip = &"death"
	elif _hurt_left > 0.0:
		clip = &"hurt"
	elif attack_left > 0.0:
		clip = &"attack"
	visual.visible = clip == &""
	combat_sprite.visible = clip != &""
	combat_sprite.flip_h = _attack_facing < 0.0 if clip == &"attack" else visual.flip_h
	if clip != &"":
		combat_sprite.animation = clip
		if clip == &"attack":
			var total: float = combat.windup + combat.active_time + combat.recovery
			combat_sprite.frame = mini(3, int((total - attack_left) / total * 4.0))
		elif clip == &"hurt":
			combat_sprite.frame = mini(3, int((0.28 - _hurt_left) / 0.28 * 4.0))
	var tint: Color = Color(0.6, 0.85, 1.0) if dash_left > 0.0 else Color.WHITE
	tint.a = 0.45 if invulnerable_left > 0.0 and fmod(invulnerable_left, 0.16) < 0.08 else 1.0
	visual.modulate = tint
	combat_sprite.modulate = tint


func set_control_locked(locked: bool) -> void:
	control_locked = locked
	velocity = Vector2.ZERO
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	_jump_active = false
	if locked:
		attack_left = 0.0
		dash_left = 0.0
	if locked:
		visual.play(&"idle")


func _update_visual(delta: float) -> void:
	# Presentation reads the result of physics; no clip controls movement.
	if not is_zero_approx(velocity.x) and attack_left <= 0.0:
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
		for action: StringName in [&"move_left", &"move_right", &"jump", &"interact", &"attack", &"dash"]:
			Input.action_release(action)
