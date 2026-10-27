extends GdUnitTestSuite

const Route: PackedScene = preload("res://world/surface/surface.tscn")

class Dummy:
	extends CharacterBody2D
	var health: int = 10
	func take_damage(amount: int, _source: Vector2) -> bool:
		health -= amount
		return true

var _route: Node2D
var _player: CharacterBody2D


func before_test() -> void:
	for action: StringName in [&"attack", &"move_left", &"move_right", &"jump", &"dash"]:
		Input.action_release(action)
	_route = auto_free(Route.instantiate())
	get_tree().root.add_child(_route)
	_route.start_game()
	_player = _route.player
	await _frames(5)


func test_swing_hits_only_front_once_and_only_in_active_window() -> void:
	var front: Dummy = _dummy(Vector2(360, 398))
	var behind: Dummy = _dummy(Vector2(280, 398))
	await _frames(3)
	assert_bool(_player.start_attack()).is_true()
	assert_bool(_player.start_attack()).is_false()
	assert_int(front.health).is_equal(10)
	await _frames(12)
	assert_int(front.health).is_equal(8)
	assert_int(behind.health).is_equal(10)
	await _frames(18)
	assert_int(front.health).is_equal(8)
	_player.visual.flip_h = true
	assert_bool(_player.start_attack()).is_true()
	await _frames(12)
	assert_int(behind.health).is_equal(8)


func test_air_attack_keeps_jump_and_input_responsive() -> void:
	Input.action_press("jump")
	await _frames(7)
	Input.action_release("jump")
	assert_bool(_player.is_on_floor()).is_false()
	assert_bool(_player.start_attack()).is_true()
	Input.action_press("move_right")
	var x: float = _player.position.x
	await _frames(6)
	Input.action_release("move_right")
	assert_float(_player.position.x).is_greater(x)
	assert_str(_player.combat_sprite.animation).is_equal("attack")


func test_damage_invulnerability_death_and_full_respawn() -> void:
	assert_bool(_player.take_damage(1, Vector2(400, 398))).is_true()
	assert_int(_player.health).is_equal(5)
	assert_bool(_player.take_damage(1, Vector2.ZERO)).is_false()
	await _frames(76)
	assert_bool(_player.take_damage(20, Vector2.ZERO)).is_true()
	assert_bool(_player.dead).is_true()
	assert_str(_player.combat_sprite.animation).is_equal("death")
	assert_bool(_player.start_attack()).is_false()
	_player.respawn(Vector2(320, 398))
	assert_bool(_player.dead).is_false()
	assert_int(_player.health).is_equal(6)
	assert_bool(_player.take_damage(1, Vector2.ZERO)).is_false()


func test_locked_controls_cancel_strike_and_dash_is_locked_until_reward() -> void:
	assert_bool(_player.start_dash()).is_false()
	_player.start_attack()
	_player.set_control_locked(true)
	assert_float(_player.attack_left).is_equal(0.0)
	assert_bool(_player.start_attack()).is_false()


func _dummy(at: Vector2) -> Dummy:
	var body: Dummy = auto_free(Dummy.new())
	body.collision_layer = 4
	body.collision_mask = 0
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(22, 36)
	collision.shape = shape
	body.add_child(collision)
	_route.add_child(body)
	body.position = at
	return body


func _frames(count: int) -> void:
	for tick: int in count:
		await get_tree().physics_frame
		await get_tree().process_frame
