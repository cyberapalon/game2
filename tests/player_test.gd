extends GdUnitTestSuite

const SurfaceScene: PackedScene = preload("res://world/surface/surface.tscn")

var _surface: Node2D
var _player: CharacterBody2D


func before_test() -> void:
	_release_input()
	_surface = auto_free(SurfaceScene.instantiate())
	get_tree().root.add_child(_surface)
	_player = _surface.get_node("Player")
	await _frames(5)


func after_test() -> void:
	_release_input()


func test_spawn_settles_on_floor_without_drifting() -> void:
	var start: Vector2 = _player.position
	await _frames(15)
	assert_bool(_player.is_on_floor()).is_true()
	assert_float(_player.position.x).is_equal_approx(start.x, 0.1)
	assert_float(_player.position.y).is_equal_approx(398.0, 0.2)
	assert_vector(_player.velocity).is_equal(Vector2.ZERO)


func test_walks_both_directions_and_stops_on_release() -> void:
	var start_x: float = _player.position.x
	Input.action_press("move_right")
	await _frames(12)
	assert_float(_player.position.x).is_greater(start_x + 20.0)
	Input.action_release("move_right")
	await _frames(2)
	var stopped_x: float = _player.position.x
	await _frames(8)
	assert_float(_player.position.x).is_equal_approx(stopped_x, 0.1)
	Input.action_press("move_left")
	await _frames(12)
	assert_float(_player.position.x).is_less(stopped_x - 20.0)


func test_jump_rejects_air_jump_and_lands() -> void:
	var floor_y: float = _player.position.y
	Input.action_press("jump")
	await _frames(6)
	Input.action_release("jump")
	assert_bool(_player.is_on_floor()).is_false()
	assert_float(_player.position.y).is_less(floor_y - 20.0)
	var airborne_velocity: float = _player.velocity.y
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	assert_float(_player.velocity.y).is_greater(airborne_velocity)
	await _frames(65)
	assert_bool(_player.is_on_floor()).is_true()
	assert_float(_player.position.y).is_equal_approx(floor_y, 0.2)


func test_walls_keep_player_inside_room() -> void:
	_player.position.x = 20.0
	Input.action_press("move_left")
	await _frames(15)
	assert_bool(_player.is_on_wall()).is_true()
	assert_float(_player.position.x).is_greater_equal(11.9)
	Input.action_release("move_left")
	_player.position.x = 1580.0
	Input.action_press("move_right")
	await _frames(15)
	assert_bool(_player.is_on_wall()).is_true()
	assert_float(_player.position.x).is_less_equal(1588.1)


func test_walking_off_rubble_falls_to_ground() -> void:
	_player.position = Vector2(1080, 320)
	await _frames(8)
	assert_bool(_player.is_on_floor()).is_true()
	Input.action_press("move_right")
	await _frames(35)
	Input.action_release("move_right")
	await _frames(30)
	assert_bool(_player.is_on_floor()).is_true()
	assert_float(_player.position.y).is_equal_approx(398.0, 0.2)


func test_surface_depth_is_independent_of_jump_height() -> void:
	var label: Label = _surface.get_node("DepthHud/Margin/Rows/Depth")
	assert_str(label.text).is_equal("Глубина: 0.00 км")
	Input.action_press("jump")
	await _frames(8)
	assert_float(_player.position.y).is_less(398.0)
	assert_str(label.text).is_equal("Глубина: 0.00 км")


func test_focus_loss_releases_held_direction() -> void:
	Input.action_press("move_right")
	await _frames(3)
	assert_float(_player.velocity.x).is_greater(0.0)
	_player.notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await _frames(3)
	assert_float(_player.velocity.x).is_equal(0.0)
	assert_bool(Input.is_action_pressed("move_right")).is_false()


func test_input_map_has_physical_keyboard_bindings() -> void:
	var bindings: Dictionary[StringName, Array] = {
		&"move_left": [KEY_A, KEY_LEFT],
		&"move_right": [KEY_D, KEY_RIGHT],
		&"jump": [KEY_SPACE],
	}
	for action: StringName in bindings:
		assert_bool(InputMap.has_action(action)).is_true()
		var keys: Array[int] = []
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				keys.append(event.physical_keycode)
		for key: int in bindings[action]:
			assert_bool(keys.has(key)).is_true()


func test_visual_keeps_facing_when_stopped_and_animates_in_place() -> void:
	var visual: WandererVisual = _player.get_node("Visual")
	var initial_position: Vector2 = _player.position
	assert_str(visual.animation).is_equal("idle")
	var torso: Sprite2D = visual.get_node("Mirror/Body/Paint")
	var initial_texture: Texture2D = torso.texture
	var feet: Vector2 = visual.front_sole_world()
	await _frames(15)
	assert_object(torso.texture).is_same(initial_texture)
	assert_vector(visual.front_sole_world()).is_equal(feet)
	assert_vector(_player.position).is_equal(initial_position)
	Input.action_press("move_left")
	await _frames(4)
	assert_str(visual.animation).is_equal("run")
	assert_bool(visual.flip_h).is_true()
	Input.action_release("move_left")
	await _frames(3)
	assert_str(visual.animation).is_equal("idle")
	assert_bool(visual.flip_h).is_true()
	Input.action_press("move_right")
	await _frames(3)
	assert_bool(visual.flip_h).is_false()


func test_visual_follows_ascent_fall_and_landing() -> void:
	var visual: WandererVisual = _player.get_node("Visual")
	Input.action_press("jump")
	await _frames(6)
	Input.action_release("jump")
	assert_str(visual.animation).is_equal("jump")
	assert_float(_player.velocity.y).is_less(0.0)
	await _frames(18)
	assert_str(visual.animation).is_equal("fall")
	assert_float(_player.velocity.y).is_greater(0.0)
	await _frames(35)
	assert_str(visual.animation).is_equal("idle")
	assert_bool(_player.is_on_floor()).is_true()
	assert_float(_player.position.y).is_equal_approx(398.0, 0.2)


func test_jump_from_ground_reaches_existing_rubble() -> void:
	_player.position = Vector2(880, 398)
	await _frames(3)
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(20)
	Input.action_release("move_right")
	Input.action_release("jump")
	await _frames(35)
	assert_bool(_player.is_on_floor()).is_true()
	assert_float(_player.position.y).is_equal_approx(320.0, 0.2)


func test_art_parts_import_without_changing_collision() -> void:
	var visual: WandererVisual = _player.get_node("Visual")
	var parts: Array[Node] = visual.find_children("Paint", "Sprite2D", true, false)
	assert_int(parts.size()).is_equal(9)
	for part: Sprite2D in parts:
		assert_object(part.texture).is_not_null()
		assert_bool(part.texture.resource_path.ends_with(".png")).is_true()
	var collider: CollisionShape2D = _player.get_node("CollisionShape2D")
	assert_vector(collider.shape.size).is_equal(Vector2(24, 44))


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().physics_frame
		await get_tree().process_frame


func _release_input() -> void:
	for action: StringName in [&"move_left", &"move_right", &"jump"]:
		Input.action_release(action)
