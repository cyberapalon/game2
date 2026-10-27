extends GdUnitTestSuite

const SurfaceScene: PackedScene = preload("res://world/surface/surface.tscn")


func test_idle_keeps_one_torso_texture_proportions_and_planted_soles() -> void:
	var surface: Node2D = auto_free(SurfaceScene.instantiate())
	get_tree().root.add_child(surface)
	surface.start_game()
	await get_tree().process_frame
	for settle: int in 5:
		await get_tree().physics_frame
		await get_tree().process_frame
	var visual: WandererVisual = surface.player.visual
	var paint: Sprite2D = visual.get_node("Mirror/Body/Paint")
	var texture: Texture2D = paint.texture
	var scale_before: Vector2 = paint.scale
	var front: Vector2 = visual.front_sole_world()
	var back: Vector2 = visual.back_sole_world()
	for tick: int in 90:
		await get_tree().physics_frame
		await get_tree().process_frame
		assert_object(paint.texture).is_same(texture)
		assert_vector(paint.scale).is_equal(scale_before)
		assert_float(absf(visual.body.position.y + 7.0)).is_less_equal(0.13)
		assert_vector(visual.front_sole_world()).is_equal(front)
		assert_vector(visual.back_sole_world()).is_equal(back)


func test_stance_foot_stays_in_world_space_at_actual_run_speed() -> void:
	var surface: Node2D = auto_free(SurfaceScene.instantiate())
	get_tree().root.add_child(surface)
	surface.start_game()
	for tick: int in 5:
		await get_tree().physics_frame
		await get_tree().process_frame
	Input.action_press("move_right")
	var visual: WandererVisual = surface.player.visual
	var planted_samples: int = 0
	var previous_front: Vector2 = visual.front_sole_world()
	var previous_planted: bool = false
	var previous_phase: float = visual.phase
	for tick: int in 80:
		await get_tree().physics_frame
		await get_tree().process_frame
		var current: Vector2 = visual.front_sole_world()
		if tick > 8 and visual.front_planted and previous_planted and visual.phase >= previous_phase:
			assert_float(absf(current.x - previous_front.x)).is_less(0.2)
			assert_float(absf(current.y - previous_front.y)).is_less(0.1)
			planted_samples += 1
		previous_front = current
		previous_planted = visual.front_planted
		previous_phase = visual.phase
	Input.action_release("move_right")
	assert_int(planted_samples).is_greater(20)


func test_every_room_loads_painted_textures_without_active_svg() -> void:
	var surface: Node2D = auto_free(SurfaceScene.instantiate())
	get_tree().root.add_child(surface)
	surface.start_game()
	for key: StringName in surface.ROOMS:
		var room: Node2D = auto_free(surface.ROOMS[key].instantiate())
		get_tree().root.add_child(room)
		var count: int = 0
		for sprite: Sprite2D in room.find_children("*", "Sprite2D", true, false):
			assert_object(sprite.texture).is_not_null()
			assert_bool(sprite.texture.resource_path.ends_with(".png")).is_true()
			count += 1
		assert_int(count).is_greater(5)


func test_painted_ground_fits_collision_and_audio_waits_for_gesture() -> void:
	var surface: Node2D = auto_free(SurfaceScene.instantiate())
	get_tree().root.add_child(surface)
	surface.start_game()
	await get_tree().process_frame
	var ground: Sprite2D = surface.room.get_node("Floor/Earth")
	var ledge: Sprite2D = surface.room.get_node("RubblePlatform/Rubble")
	assert_vector(ground.texture.get_size()).is_equal(Vector2(1600, 140))
	assert_vector(ledge.texture.get_size()).is_equal(Vector2(180, 78))
	assert_vector(ground.global_position).is_equal(Vector2(0, 420))
	assert_vector(ledge.global_position).is_equal(Vector2(920, 342))
	var ambience: AudioStreamPlayer = surface.get_node("Presentation/Ambience")
	assert_bool(ambience.playing).is_false()
	var stream: AudioStreamWAV = ambience.stream as AudioStreamWAV
	assert_int(stream.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
