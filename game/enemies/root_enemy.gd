extends CharacterBody2D
## Shared damage/lifecycle, two deliberately different state machines.

signal defeated(identity: StringName)
signal combat_event(kind: StringName, point: Vector2)

const Spore: PackedScene = preload("res://game/enemies/spore.tscn")

@export var settings: EnemySettings
@export var patrol_min: float = 240.0
@export var patrol_max: float = 430.0
@export var encounter_id: StringName
@onready var sprite: AnimatedSprite2D = $Painting
@onready var attack_area: Area2D = $AttackArea

var target: CharacterBody2D
var health: int = 0
var state: StringName = &"patrol"
var state_left: float = 0.0
var direction: float = -1.0
var attacks: int = 0
var shots: int = 0
var _strike_spent: bool = false
var _hurt_left: float = 0.0
var _knockback: float = 0.0
var _hitstop: float = 0.0


func _ready() -> void:
	health = settings.max_health
	add_to_group(&"enemies")
	sprite.play(&"idle")
	$Health.max_value = settings.max_health
	$Health.value = health
	$Health.hide()


func _physics_process(delta: float) -> void:
	if state == &"dead":
		return
	if _hitstop > 0.0:
		_hitstop -= delta
		return
	_hurt_left = maxf(0.0, _hurt_left - delta)
	state_left = maxf(0.0, state_left - delta)
	velocity.y += 1400.0 * delta
	velocity.x = 0.0
	if is_instance_valid(target) and not target.dead and not target.control_locked:
		_act(delta)
	elif state != &"patrol":
		state = &"patrol"
		$Warning.hide()
	velocity.x += _knockback
	_knockback = move_toward(_knockback, 0.0, 850.0 * delta)
	if (position.x <= patrol_min and velocity.x < 0.0) or (position.x >= patrol_max and velocity.x > 0.0):
		velocity.x = 0.0
		direction *= -1.0
	move_and_slide()
	if is_on_wall() and state == &"patrol":
		direction *= -1.0
	sprite.flip_h = direction < 0.0
	if _hurt_left > 0.0:
		sprite.play(&"hurt")
	elif state == &"windup" or state == &"strike":
		sprite.animation = &"attack"
		sprite.pause()
		sprite.frame = (0 if state_left > settings.windup * 0.5 else 1) if state == &"windup" else 2
	else:
		sprite.play(&"move" if absf(velocity.x) > 1.0 else &"idle")


func _act(_delta: float) -> void:
	var offset: Vector2 = target.global_position - global_position
	match state:
		&"windup":
			if state_left <= 0.0:
				state = &"strike"
				state_left = 0.18
				_strike_spent = false
				attacks += 1
				$Warning.hide()
				combat_event.emit(&"enemy_attack", global_position)
				if settings.species == "sporon":
					_shoot(offset)
		&"strike":
			attack_area.position.x = direction * 38.0
			if not _strike_spent and settings.species == "kornevik" and attack_area.overlaps_body(target):
				_strike_spent = true
				target.take_damage(settings.damage, global_position)
			if state_left <= 0.0:
				state = &"recover"
				state_left = settings.recovery
		&"recover":
			if state_left <= 0.0:
				state = &"patrol"
		_:
			if offset.length() < settings.detection_range and absf(offset.y) < 125.0:
				direction = signf(offset.x) if not is_zero_approx(offset.x) else direction
				if settings.species == "kornevik":
					if absf(offset.x) < 74.0 and absf(offset.y) < 50.0:
						_warn()
					else:
						velocity.x = direction * settings.chase_speed
				else:
					if absf(offset.x) < 115.0:
						velocity.x = -direction * settings.chase_speed
					else:
						_warn()
			else:
				velocity.x = direction * settings.patrol_speed


func _warn() -> void:
	state = &"windup"
	state_left = settings.windup
	$Warning.show()
	combat_event.emit(&"enemy_warning", global_position)


func _shoot(offset: Vector2) -> void:
	var spore: Area2D = Spore.instantiate()
	get_parent().add_child(spore)
	spore.global_position = global_position + Vector2(direction * 26.0, -14.0)
	spore.direction = offset.normalized()
	shots += 1


func take_damage(amount: int, source: Vector2) -> bool:
	if health <= 0 or amount <= 0:
		return false
	health = maxi(0, health - amount)
	$Health.value = health
	$Health.show()
	_hurt_left = 0.25
	_hitstop = 0.045
	_knockback = signf(global_position.x - source.x) * 135.0
	# A hit cancels a normal enemy's warning, creating a reliable opening.
	state = &"recover"
	state_left = 0.48
	$Warning.hide()
	combat_event.emit(&"enemy_hurt", global_position)
	if health == 0:
		state = &"dead"
		velocity = Vector2.ZERO
		set_collision_layer_value(3, false)
		sprite.play(&"death")
		$Health.hide()
		combat_event.emit(&"enemy_death", global_position)
		defeated.emit(encounter_id)
	return true
