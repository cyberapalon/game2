extends GdUnitTestSuite

const SurfaceScene: PackedScene = preload("res://world/surface/surface.tscn")

var _surface: Node2D
var _player: CharacterBody2D


func before_test() -> void:
	_release()
	_surface = auto_free(SurfaceScene.instantiate())
	get_tree().root.add_child(_surface)
	_player = _surface.player
	await _frames(5)


func after_test() -> void:
	_release()


func test_tap_and_hold_have_distinct_bounded_apices() -> void:
	var short_height: float = await _jump_height(1)
	await _frames(4)
	var full_height: float = await _jump_height(30)
	assert_float(short_height).is_between(45.0, 55.0)
	assert_float(full_height).is_between(90.0, 100.0)
	assert_float(full_height - short_height).is_greater(35.0)


func test_releasing_later_preserves_more_ascent() -> void:
	var short_height: float = await _jump_height(1)
	var middle_height: float = await _jump_height(12)
	var full_height: float = await _jump_height(30)
	assert_float(middle_height).is_greater(short_height + 10.0)
	assert_float(full_height).is_greater(middle_height + 2.0)


func test_coyote_jump_after_walking_off_real_ledge() -> void:
	_player.position = Vector2(1080, 320)
	await _frames(6)
	Input.action_press("move_right")
	for tick: int in 30:
		await _frames(1)
		if not _player.is_on_floor():
			break
	Input.action_release("move_right")
	assert_bool(_player.is_on_floor()).is_false()
	await _frames(3)
	Input.action_press("jump")
	await _frames(1)
	assert_float(_player.velocity.y).is_less(-450.0)
	Input.action_release("jump")


func test_coyote_expires_and_air_press_does_not_jump() -> void:
	_player.position = Vector2(1080, 320)
	await _frames(6)
	Input.action_press("move_right")
	for tick: int in 30:
		await _frames(1)
		if not _player.is_on_floor():
			break
	Input.action_release("move_right")
	await _frames(7)
	var before: float = _player.velocity.y
	Input.action_press("jump")
	await _frames(1)
	assert_float(_player.velocity.y).is_greater(before)
	Input.action_release("jump")


func test_buffer_is_consumed_once_and_hold_does_not_repeat() -> void:
	await _fall_toward_floor()
	assert_bool(_player.is_on_floor()).is_false()
	Input.action_press("jump")
	var launches: int = 0
	var last_vy: float = _player.velocity.y
	for tick: int in 90:
		await _frames(1)
		if _player.velocity.y < -450.0 and last_vy >= 0.0:
			launches += 1
		last_vy = _player.velocity.y
	assert_int(launches).is_equal(1)
	assert_bool(_player.is_on_floor()).is_true()
	Input.action_release("jump")


func test_released_buffered_tap_is_short_and_focus_loss_clears_buffer() -> void:
	await _fall_toward_floor()
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	var minimum: float = 398.0
	var launched: bool = false
	for tick: int in 65:
		await _frames(1)
		launched = launched or _player.velocity.y < 0.0
		if launched:
			minimum = minf(minimum, _player.position.y)
	assert_bool(launched).is_true()
	assert_float(398.0 - minimum).is_between(40.0, 55.0)
	await _fall_toward_floor()
	Input.action_press("jump")
	_player.notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await _frames(40)
	assert_bool(_player.is_on_floor()).is_true()
	assert_float(_player.position.y).is_equal_approx(398.0, 0.2)


func _jump_height(held_frames: int) -> float:
	var floor_y: float = _player.position.y
	var minimum: float = floor_y
	Input.action_press("jump")
	for tick: int in 65:
		if tick == held_frames:
			Input.action_release("jump")
		await _frames(1)
		minimum = minf(minimum, _player.position.y)
	Input.action_release("jump")
	assert_bool(_player.is_on_floor()).is_true()
	return floor_y - minimum


func _frames(count: int) -> void:
	for tick: int in count:
		await get_tree().physics_frame
		await get_tree().process_frame


func _fall_toward_floor() -> void:
	# Expire old floor/coyote flags before testing a genuinely buffered landing.
	_player.position = Vector2(320, 260)
	_player.velocity = Vector2.ZERO
	await _frames(22)


func _release() -> void:
	for action: StringName in [&"move_left", &"move_right", &"jump", &"interact"]:
		Input.action_release(action)
