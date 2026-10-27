class_name WandererVisual
extends Node2D
## Articulated AI-painted cutouts. No gameplay state or geometric drawing.
## The mask/torso are ONE immutable texture. Feet are solved from a ground
## contact trajectory; stance moves back exactly as far as the body advances.

signal foot_contact(world_sole: Vector2)

const BONE_LENGTH: float = 16.0
const HIP_Y: float = -7.0
const SOLE_Y: float = 22.0
const STANCE: float = 0.55
const REACH: float = 17.0
const STRIDE: float = REACH * 2.0 / STANCE

@export var front_sole_offset: float = 7.4
@export var back_sole_offset: float = 8.0

@onready var mirror: Node2D = $Mirror
@onready var body: Node2D = $Mirror/Body
@onready var scarf: Node2D = $Mirror/Scarf
@onready var cloak: Node2D = $Mirror/Cloak
@onready var front_thigh: Node2D = $Mirror/FrontThigh
@onready var front_shin: Node2D = $Mirror/FrontShin
@onready var front_boot: Node2D = $Mirror/FrontBoot
@onready var back_thigh: Node2D = $Mirror/BackThigh
@onready var back_shin: Node2D = $Mirror/BackShin
@onready var back_boot: Node2D = $Mirror/BackBoot

var animation: StringName = &"idle"
var frame: int = 0
var flip_h: bool = false
var phase: float = 0.2
var front_planted: bool = true
var back_planted: bool = true
var _clock: float = 0.0
var _blend_left: float = 0.0
var _front: Vector2 = Vector2(5, SOLE_Y)
var _back: Vector2 = Vector2(-5, SOLE_Y)
var _front_from: Vector2 = _front
var _back_from: Vector2 = _back


func _ready() -> void:
	_pose(0.0)


func play(clip: StringName) -> void:
	if animation == clip:
		return
	animation = clip
	_blend_left = 0.08
	_front_from = _front
	_back_from = _back
	if clip == &"run":
		phase = 0.2


func advance_motion(motion: Vector2, grounded: bool, delta: float) -> void:
	if animation == &"idle":
		return
	var contact: int = -1
	if animation == &"run" and grounded:
		var previous: float = phase
		phase = fposmod(phase + absf(motion.x) * delta / STRIDE, 1.0)
		if phase < previous:
			contact = 0
		elif previous < 0.5 and phase >= 0.5:
			contact = 1
		frame = int(phase * 24.0)
	_pose(delta)
	if contact >= 0:
		foot_contact.emit(front_sole_world() if contact == 0 else back_sole_world())


func _process(delta: float) -> void:
	_clock += delta
	if animation == &"idle":
		# Subpixel breathing, never a texture/scale switch. Soles stay fixed.
		_pose(delta)


func front_sole_world() -> Vector2:
	return mirror.to_global(_front)


func back_sole_world() -> Vector2:
	return mirror.to_global(_back)


func _pose(delta: float) -> void:
	if not is_node_ready():
		return
	mirror.scale.x = -1.0 if flip_h else 1.0
	var breathing: float = 0.12 * sin(_clock * TAU / 4.0)
	var bob: float = 0.35 * sin(phase * TAU * 2.0) if animation == &"run" else breathing
	body.position = Vector2(0.0, HIP_Y + bob)
	cloak.position = Vector2(-7, -24) + Vector2(0, bob)
	scarf.position = Vector2(-3, -28) + Vector2(0, bob)
	cloak.rotation = 0.010 * sin(_clock * 1.7)
	scarf.rotation = 0.018 * sin(_clock * 2.0)
	var target_front: Vector2 = Vector2(5, SOLE_Y)
	var target_back: Vector2 = Vector2(-5, SOLE_Y)
	front_planted = animation == &"idle"
	back_planted = front_planted
	var front_angle: float = 0.0
	var back_angle: float = 0.0
	if animation == &"run":
		target_front = _run_foot(phase)
		var back_phase: float = fposmod(phase + 0.5, 1.0)
		target_back = _run_foot(back_phase)
		front_planted = phase < STANCE
		back_planted = back_phase < STANCE
		front_angle = _boot_angle(phase)
		back_angle = _boot_angle(back_phase)
		scarf.rotation += 0.035 * sin(phase * TAU)
		cloak.rotation += 0.020 * sin(phase * TAU + 0.8)
	elif animation == &"jump":
		target_front = Vector2(7, 12)
		target_back = Vector2(-8, 15)
		front_angle = -0.08
		back_angle = 0.12
		cloak.rotation = -0.05
	elif animation == &"fall":
		target_front = Vector2(6, 20)
		target_back = Vector2(-5, 18)
		front_angle = 0.03
		back_angle = 0.08
		cloak.rotation = 0.06
		front_planted = false
		back_planted = false
	_blend_left = maxf(0.0, _blend_left - delta)
	var blend: float = smoothstep(0.0, 1.0, 1.0 - _blend_left / 0.08)
	_front = _front_from.lerp(target_front, blend) if _blend_left > 0.0 else target_front
	_back = _back_from.lerp(target_back, blend) if _blend_left > 0.0 else target_back
	_leg(front_thigh, front_shin, front_boot, Vector2(0, HIP_Y + bob), _front, front_sole_offset, front_angle)
	_leg(back_thigh, back_shin, back_boot, Vector2(-1, HIP_Y + bob), _back, back_sole_offset, back_angle)


func _run_foot(cycle: float) -> Vector2:
	if cycle < STANCE:
		return Vector2(lerpf(REACH, -REACH, cycle / STANCE), SOLE_Y)
	var swing: float = (cycle - STANCE) / (1.0 - STANCE)
	return Vector2(lerpf(-REACH, REACH, smoothstep(0.0, 1.0, swing)), SOLE_Y - sin(swing * PI) * 10.0)


func _boot_angle(cycle: float) -> float:
	if cycle < STANCE:
		return 0.0
	var swing: float = (cycle - STANCE) / (1.0 - STANCE)
	return sin(swing * TAU) * 0.16


func _leg(thigh: Node2D, shin: Node2D, boot: Node2D, hip: Vector2,
		sole: Vector2, sole_offset: float, boot_angle: float) -> void:
	var ankle: Vector2 = sole - Vector2(0, sole_offset)
	var offset: Vector2 = ankle - hip
	var distance: float = clampf(offset.length(), 0.1, BONE_LENGTH * 2.0 - 0.01)
	var angle: float = offset.angle() - acos(distance / (BONE_LENGTH * 2.0))
	var knee: Vector2 = hip + Vector2.from_angle(angle) * BONE_LENGTH
	thigh.position = hip
	thigh.rotation = angle - PI / 2.0
	shin.position = knee
	shin.rotation = (ankle - knee).angle() - PI / 2.0
	boot.position = ankle
	boot.rotation = boot_angle
