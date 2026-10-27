extends Node
## Local session music and cues. Surface presentation owns gesture and mute.

@export var roots_music: AudioStream
@export var heart_music: AudioStream
@export var sounds: Dictionary[StringName, AudioStream]
@export var presentation: Node2D
@export var route: Node2D
@onready var music: AudioStreamPlayer = $Music
@onready var cues: AudioStreamPlayer = $Cues
@onready var resonance: AudioStreamPlayer = $Resonance
var theme: StringName = &"surface"
var music_switches: int = 0


func _ready() -> void:
	music.finished.connect(func() -> void:
		if theme != &"surface":
			music.play()
	)


func _process(_delta: float) -> void:
	var next: StringName = &"surface" if route.room.room_id == &"surface" else (&"boss" if route.boss_active else &"roots")
	if theme != next:
		theme = next
		music_switches += 1
		music.stop()
		music.stream = heart_music if theme == &"boss" else roots_music
	if presentation.started and theme != &"surface" and not music.playing:
		music.play()
	music.volume_db = -80.0 if presentation.muted else -13.0
	cues.volume_db = -80.0 if presentation.muted else -7.0
	resonance.volume_db = -80.0 if presentation.muted else -12.0
	presentation.ambience.volume_db = -80.0 if presentation.muted else (-14.0 if theme == &"surface" else -23.0)


func play_event(kind: StringName, _point: Vector2 = Vector2.ZERO) -> void:
	if not sounds.has(kind) or not presentation.started or presentation.muted:
		return
	var voice: AudioStreamPlayer = resonance if kind == &"gate" else cues
	voice.stream = sounds[kind]
	voice.play()
