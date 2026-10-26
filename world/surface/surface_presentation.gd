extends Node2D
## Audio and dust read settled physics. This node never moves the player.

@export var player: CharacterBody2D
@export var sound_toggle: Button
@export var dust_frames: SpriteFrames
@export var step_sounds: Array[AudioStream]
@export var land_sound: AudioStream
@export var jump_sound: AudioStream

@onready var ambience: AudioStreamPlayer = $Ambience
@onready var footsteps: AudioStreamPlayer = $Footsteps
@onready var impacts: AudioStreamPlayer = $Impacts

var started: bool = false
var muted: bool = false
var step_count: int = 0
var land_count: int = 0
var _step_time: float = 0.0
var _was_grounded: bool = false
var _previous_velocity_y: float = 0.0
var _observed_floor: bool = false


func _ready() -> void:
	sound_toggle.toggled.connect(set_muted)
	set_muted(sound_toggle.button_pressed)


func _input(event: InputEvent) -> void:
	# A genuine user gesture also lets the browser resume its AudioContext.
	if event is InputEventKey and event.pressed and not event.echo:
		_start_audio()
		if event.physical_keycode == KEY_M:
			sound_toggle.button_pressed = not sound_toggle.button_pressed
	elif event is InputEventMouseButton and event.pressed:
		_start_audio()


func set_muted(value: bool) -> void:
	muted = value
	ambience.volume_db = -80.0 if muted else -14.0
	footsteps.volume_db = -80.0 if muted else -10.0
	impacts.volume_db = -80.0 if muted else -10.0
	sound_toggle.text = "ЗВУК ВЫКЛ · M" if muted else "ЗВУК ВКЛ · M"


func _start_audio() -> void:
	if not started:
		started = true
		ambience.play()


func _physics_process(delta: float) -> void:
	var grounded: bool = player.is_on_floor()
	if grounded:
		if _observed_floor and not _was_grounded and _previous_velocity_y > 40.0:
			land_count += 1
			_dust(&"land", 0.70)
			if started and not muted:
				impacts.stream = land_sound
				impacts.play()
		_observed_floor = true
		if absf(player.velocity.x) > 1.0:
			_step_time += delta
			if _step_time >= 0.25:
				_step_time = 0.0
				_dust(&"step", 0.40)
				if started and not muted:
					footsteps.stream = step_sounds[step_count % step_sounds.size()]
					footsteps.pitch_scale = 0.96 + float(step_count % 3) * 0.04
					footsteps.play()
				step_count += 1
		else:
			_step_time = 0.0
	elif _was_grounded and player.velocity.y < -100.0:
		if started and not muted:
			impacts.stream = jump_sound
			impacts.play()
	_was_grounded = grounded
	_previous_velocity_y = player.velocity.y


func _dust(clip: StringName, effect_scale: float) -> void:
	var effect: AnimatedSprite2D = AnimatedSprite2D.new()
	effect.sprite_frames = dust_frames
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	effect.scale = Vector2.ONE * effect_scale
	effect.modulate = Color(0.78, 0.86, 0.91, 0.65)
	effect.z_index = 2
	add_child(effect)
	# The source dust baseline is y=105 in a 128px frame, centered at y=64.
	effect.global_position = player.global_position + Vector2(0.0, 22.0 - 41.0 * effect_scale)
	effect.flip_h = player.velocity.x < 0.0
	effect.animation_finished.connect(effect.queue_free)
	effect.play(clip)
