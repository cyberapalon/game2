extends GdUnitTestSuite

const Route: PackedScene = preload("res://world/surface/surface.tscn")
var _route: Node2D
var _player: CharacterBody2D


func before_test() -> void:
	for action: StringName in [&"attack", &"jump", &"move_left", &"move_right", &"dash"]:
		Input.action_release(action)
	_route = auto_free(Route.instantiate())
	get_tree().root.add_child(_route)
	_player = _route.player
	_route.start_game()
	await _frames(5)


func after_test() -> void:
	get_tree().paused = false
	for action: StringName in [&"attack", &"jump", &"move_left", &"move_right", &"dash"]:
		Input.action_release(action)


func test_boss_telegraphs_two_attacks_and_only_open_heart_takes_damage() -> void:
	_route._install_room(&"seal", &"junction")
	var heart: CharacterBody2D = _route.room.get_node("Heart")
	assert_bool(heart.take_damage(2, Vector2.ZERO)).is_false()
	assert_bool(heart.awaken()).is_true()
	assert_bool(heart.awaken()).is_false()
	assert_str(heart.state).is_equal("windup_slam")
	assert_float(heart.state_left).is_greater(0.8)
	assert_bool(heart.take_damage(2, Vector2.ZERO)).is_false()
	await _until_state(heart, &"recover")
	assert_int(heart.slam_count).is_equal(1)
	assert_bool(heart.take_damage(2, Vector2.ZERO)).is_true()
	assert_int(heart.health).is_equal(94)
	await _until_state(heart, &"windup_storm")
	assert_float(heart.state_left).is_greater(0.9)
	await _until_state(heart, &"recover")
	assert_int(heart.storm_count).is_equal(1)


func test_phase_two_death_gives_dash_once_and_physically_opens_gate() -> void:
	_route._install_room(&"seal", &"junction")
	var heart: CharacterBody2D = _route.room.get_node("Heart")
	heart.awaken()
	await _until_state(heart, &"recover")
	heart.take_damage(54, Vector2.ZERO)
	assert_int(heart.phase).is_equal(2)
	heart.take_damage(100, Vector2.ZERO)
	assert_str(heart.state).is_equal("dead")
	assert_str(heart.sprite.animation).is_equal("death")
	assert_bool(_route.boss_defeated).is_false()
	await _frames(105)
	assert_bool(_route.boss_defeated).is_true()
	assert_bool(_player.dash_unlocked).is_true()
	assert_int(_route.dash_awards).is_equal(1)
	assert_int(_route.room.get_node("SealedBarrier").collision_layer).is_equal(0)
	assert_str(_route.room.get_node("Seal").target_room).is_equal("afterheart")
	_route._on_boss_defeated()
	assert_int(_route.dash_awards).is_equal(1)
	assert_bool(heart.take_damage(2, Vector2.ZERO)).is_false()


func test_dash_cooldown_and_jump_only_cannot_cross_final_gap() -> void:
	_route._install_room(&"afterheart", &"seal")
	_player.position = Vector2(320, 438)
	await _frames(4)
	Input.action_press("jump")
	Input.action_press("move_right")
	await _frames(100)
	Input.action_release("jump")
	Input.action_release("move_right")
	assert_int(_route.course_retries).is_greater(0)
	_player.position = Vector2(320, 438)
	_player.velocity = Vector2.ZERO
	_player.dash_unlocked = true
	await _frames(4)
	Input.action_press("jump")
	Input.action_press("move_right")
	await _frames(21)
	assert_bool(_player.start_dash()).is_true()
	assert_bool(_player.start_dash()).is_false()
	await _frames(36)
	Input.action_release("jump")
	Input.action_release("move_right")
	assert_float(_player.position.x).is_greater(638.0)
	await _frames(8)
	assert_bool(_player.is_on_floor()).is_true()
	assert_bool(_player.start_dash()).is_true()


func test_finish_rejects_early_calls_then_shows_victory_and_restart_resets_progress() -> void:
	assert_bool(_route.finish_episode()).is_false()
	_route._install_room(&"afterheart", &"seal")
	_player.position = Vector2(1150, 438)
	assert_bool(_route.finish_episode()).is_false()
	_route.boss_defeated = true
	_player.dash_unlocked = true
	_player.dash_count = 1
	assert_bool(_route.finish_episode()).is_true()
	assert_bool(_route.finish_episode()).is_false()
	await _frames(220)
	assert_str(_route.mode).is_equal("victory")
	assert_str(_route.hud.depth_label.text).is_equal("Глубина: 1.86 км")
	_route.restart_game()
	assert_str(_route.room.room_id).is_equal("surface")
	assert_bool(_route.boss_defeated).is_false()
	assert_bool(_player.dash_unlocked).is_false()
	assert_bool(_route.episode_complete).is_false()
	assert_int(_player.health).is_equal(6)


func test_boss_retry_resets_health_and_keeps_second_checkpoint() -> void:
	_route._install_room(&"junction", &"landing")
	_player.position = Vector2(1180, 438)
	await _frames(5)
	_route._install_room(&"seal", &"junction")
	_route.boss_active = true
	var heart: CharacterBody2D = _route.room.get_node("Heart")
	heart.awaken()
	await _until_state(heart, &"recover")
	heart.take_damage(20, Vector2.ZERO)
	_player.invulnerable_left = 0.0
	_player.take_damage(20, Vector2.ZERO)
	await _frames(90)
	assert_str(_route.room.room_id).is_equal("junction")
	assert_bool(_route.boss_active).is_false()
	assert_bool(_route.boss_defeated).is_false()
	_route._install_room(&"seal", &"junction")
	assert_int(_route.room.get_node("Heart").health).is_equal(96)
	assert_int(_route.dash_awards).is_equal(0)


func test_dash_avoids_damage_and_pause_restart_resets_the_session() -> void:
	_player.dash_unlocked = true
	_player.start_dash()
	assert_bool(_player.take_damage(1, Vector2.ZERO)).is_false()
	_route.set_paused(true)
	assert_bool(get_tree().paused).is_true()
	assert_str(_route.mode).is_equal("pause")
	_route.restart_game()
	assert_bool(get_tree().paused).is_false()
	assert_bool(_player.dash_unlocked).is_false()
	assert_str(_route.mode).is_equal("playing")


func _until_state(heart: CharacterBody2D, wanted: StringName) -> void:
	for tick: int in 300:
		if heart.state == wanted:
			return
		await _frames(1)
	assert_str(heart.state).is_equal(wanted)


func _frames(count: int) -> void:
	for tick: int in count:
		await get_tree().physics_frame
		await get_tree().process_frame
