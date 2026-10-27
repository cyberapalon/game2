extends CharacterBody2D
## Fixed alternating attacks. Every damaging interval follows its own warning.

signal defeated
signal combat_event(kind: StringName, point: Vector2)
signal status_changed(health: int, maximum: int, phase: int, warning: String)

const Spore: PackedScene = preload("res://game/enemies/spore.tscn")
@export var settings: HeartSettings
@onready var sprite: AnimatedSprite2D = $Painting
@onready var slam_area: Area2D = $Slam
var target: CharacterBody2D
var health: int = 0
var phase: int = 1
var state: StringName = &"dormant"
var state_left: float = 0.0
var attack_index: int = 0
var slam_count: int = 0
var storm_count: int = 0
var _hit_spent: bool = false
var _death_reported: bool = false
var _hit_flash: float = 0.0
var warning: String = ""


func _ready() -> void:
	health = settings.max_health
	sprite.play(&"idle")


func awaken() -> bool:
	if state != &"dormant":
		return false
	_begin_warning()
	return true


func _physics_process(delta: float) -> void:
	if state == &"dormant":
		return
	state_left = maxf(0.0, state_left - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	sprite.modulate = Color(1.5, 1.3, 1.0) if _hit_flash > 0.0 else Color.WHITE
	match state:
		&"dead":
			if state_left <= 0.0 and not _death_reported:
				_death_reported = true
				defeated.emit()
		&"windup_slam", &"windup_storm":
			sprite.frame = 0 if state_left > 0.5 else 1
			if state_left <= 0.0:
				_release_attack()
		&"slam":
			if not _hit_spent and is_instance_valid(target) and slam_area.overlaps_body(target):
				_hit_spent = true
				target.take_damage(settings.damage, Vector2(global_position.x, target.global_position.y))
			if state_left <= 0.0:
				_recover()
		&"storm":
			if state_left <= 0.0:
				_recover()
		&"recover":
			if state_left <= 0.0:
				attack_index += 1
				_begin_warning()


func _begin_warning() -> void:
	var slam: bool = attack_index % 2 == 0
	state = &"windup_slam" if slam else &"windup_storm"
	state_left = settings.slam_warning if slam else settings.storm_warning
	if phase == 2:
		state_left *= 0.82
	warning = "КОРНИ ВЗДЫМАЮТСЯ · ПРЫГАЙТЕ" if slam else "СЕМЕНА ПРОБУЖДАЮТСЯ · ИЩИТЕ ПРОСВЕТ"
	sprite.animation = &"slam" if slam else &"storm"
	sprite.pause()
	sprite.frame = 0
	$FloorWarning.visible = slam
	status_changed.emit(health, settings.max_health, phase, warning)
	combat_event.emit(&"boss_warning", global_position)


func _release_attack() -> void:
	var slam: bool = state == &"windup_slam"
	state = &"slam" if slam else &"storm"
	state_left = 0.26 if slam else 0.55
	_hit_spent = false
	sprite.frame = 2
	$FloorWarning.visible = slam
	$FloorWarning.modulate.a = 0.9 if slam else 0.35
	if slam:
		slam_count += 1
		combat_event.emit(&"boss_slam", Vector2(600, 450))
	else:
		storm_count += 1
		combat_event.emit(&"boss_storm", global_position)
		var count: int = 5 if phase == 2 else 3
		for index: int in count:
			var spore: Area2D = Spore.instantiate()
			get_parent().add_child(spore)
			spore.global_position = global_position + Vector2(-95, -65)
			spore.direction = (target.global_position - spore.global_position).normalized().rotated(lerpf(-0.38, 0.38, float(index) / float(count - 1)))
			spore.speed = 130.0 if phase == 2 else 100.0
			spore.life = 6.0


func _recover() -> void:
	state = &"recover"
	state_left = settings.phase_two_recovery if phase == 2 else settings.recovery
	warning = "СЕРДЦЕ ОТКРЫТО · АТАКУЙТЕ"
	sprite.play(&"hurt")
	$FloorWarning.hide()
	$FloorWarning.modulate.a = 0.35
	status_changed.emit(health, settings.max_health, phase, warning)


func take_damage(amount: int, _source: Vector2) -> bool:
	if state != &"recover" or health <= 0 or amount <= 0:
		return false
	health = maxi(0, health - amount)
	_hit_flash = 0.1
	combat_event.emit(&"boss_hurt", global_position + Vector2(-55, -50))
	if health <= settings.phase_two_health:
		phase = 2
	status_changed.emit(health, settings.max_health, phase, warning)
	if health == 0:
		state = &"dead"
		state_left = 1.6
		collision_layer = 0
		$FloorWarning.hide()
		sprite.play(&"death")
		combat_event.emit(&"boss_death", global_position)
		for projectile: Node in get_tree().get_nodes_in_group(&"hostile_projectiles"):
			projectile.queue_free()
	return true
