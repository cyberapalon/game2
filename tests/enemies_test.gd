extends GdUnitTestSuite

const Route: PackedScene = preload("res://world/surface/surface.tscn")
const Kornevik: PackedScene = preload("res://game/enemies/kornevik.tscn")
const Sporon: PackedScene = preload("res://game/enemies/sporon.tscn")
var _route: Node2D
var _player: CharacterBody2D


func before_test() -> void:
	_route = auto_free(Route.instantiate())
	get_tree().root.add_child(_route)
	_route.start_game()
	_player = _route.player
	await _frames(5)


func test_kornevik_patrol_detect_warn_attack_recover_and_die() -> void:
	var enemy: CharacterBody2D = _enemy(Kornevik, Vector2(700, 402))
	await _frames(20)
	assert_float(enemy.position.x).is_less(700.0)
	_player.position = enemy.position - Vector2(55, 4)
	await _frames(3)
	assert_str(enemy.state).is_equal("windup")
	assert_bool(enemy.get_node("Warning").visible).is_true()
	assert_int(_player.health).is_equal(6)
	await _frames(56)
	assert_int(_player.health).is_equal(5)
	assert_int(enemy.attacks).is_equal(1)
	assert_str(enemy.state).is_equal("recover")
	assert_bool(enemy.take_damage(30, _player.position)).is_true()
	assert_int(enemy.health).is_equal(0)
	assert_str(enemy.sprite.animation).is_equal("death")
	assert_bool(enemy.take_damage(2, Vector2.ZERO)).is_false()


func test_sporon_keeps_distance_warns_and_fires_slow_spore() -> void:
	var enemy: CharacterBody2D = _enemy(Sporon, Vector2(540, 387))
	await _frames(5)
	assert_str(enemy.state).is_equal("windup")
	assert_int(enemy.shots).is_equal(0)
	await _frames(65)
	assert_int(enemy.shots).is_equal(1)
	var spores: Array[Node] = get_tree().get_nodes_in_group(&"hostile_projectiles")
	assert_int(spores.size()).is_equal(1)
	assert_float(spores[0].speed).is_equal(110.0)
	assert_float(spores[0].direction.x).is_less(0.0)
	enemy.state = &"patrol"
	_player.position = enemy.position - Vector2(70, 0)
	var x: float = enemy.position.x
	await _frames(5)
	assert_float(enemy.position.x).is_greater(x)


func test_hit_interrupts_normal_enemy_telegraph() -> void:
	var enemy: CharacterBody2D = _enemy(Kornevik, Vector2(370, 402))
	await _frames(5)
	assert_str(enemy.state).is_equal("windup")
	enemy.take_damage(2, _player.position)
	assert_str(enemy.state).is_equal("recover")
	assert_bool(enemy.get_node("Warning").visible).is_false()
	assert_int(enemy.health).is_equal(4)


func test_both_checkpoints_restore_health_and_respawn_without_surface_restart() -> void:
	_route._install_room(&"landing", &"surface")
	_player.position = Vector2(285, 438)
	_player.health = 2
	await _frames(6)
	assert_str(_route.checkpoint_id).is_equal("landing")
	assert_int(_player.health).is_equal(6)
	_route._install_room(&"junction", &"landing")
	_player.position = Vector2(1180, 438)
	await _frames(6)
	assert_str(_route.checkpoint_id).is_equal("junction")
	assert_int(_route.activated_checkpoints.size()).is_equal(2)
	_player.invulnerable_left = 0.0
	_player.take_damage(10, Vector2.ZERO)
	await _frames(90)
	assert_bool(_player.dead).is_false()
	assert_int(_player.health).is_equal(6)
	assert_str(_route.room.room_id).is_equal("junction")
	assert_int(_route.respawn_count).is_equal(1)
	assert_float(_player.position.x).is_equal_approx(1180.0, 0.1)


func _enemy(scene: PackedScene, at: Vector2) -> CharacterBody2D:
	var enemy: CharacterBody2D = scene.instantiate()
	enemy.patrol_min = 80.0
	enemy.patrol_max = 1450.0
	_route.room.add_child(enemy)
	enemy.position = at
	enemy.target = _player
	return enemy


func _frames(count: int) -> void:
	for tick: int in count:
		await get_tree().physics_frame
		await get_tree().process_frame
