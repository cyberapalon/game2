extends GdUnitTestSuite

const PLAYER_FRAMES: SpriteFrames = preload("res://game/player/player_frames.tres")
const SurfaceScene: PackedScene = preload("res://world/surface/surface.tscn")


func test_painted_frames_have_transparent_padding_and_stable_feet() -> void:
	for clip: StringName in PLAYER_FRAMES.get_animation_names():
		for frame: int in PLAYER_FRAMES.get_frame_count(clip):
			var texture: AtlasTexture = PLAYER_FRAMES.get_frame_texture(clip, frame) as AtlasTexture
			assert_object(texture).is_not_null()
			assert_str(texture.atlas.resource_path).contains("wanderer_atlas.png")
			var image: Image = texture.get_image()
			var top: int = 128
			var bottom: int = -1
			for y: int in image.get_height():
				for x: int in image.get_width():
					if image.get_pixel(x, y).a > 0.15:
						top = mini(top, y)
						bottom = maxi(bottom, y)
			assert_int(top).is_greater_equal(4)
			assert_int(bottom).is_between(106, 110)
			assert_float(image.get_pixel(0, 0).a).is_equal(0.0)
	assert_bool(PLAYER_FRAMES.get_animation_loop(&"jump")).is_false()
	assert_bool(PLAYER_FRAMES.get_animation_loop(&"fall")).is_false()


func test_painted_ground_fits_collision_and_audio_waits_for_gesture() -> void:
	var surface: Node2D = auto_free(SurfaceScene.instantiate())
	get_tree().root.add_child(surface)
	await get_tree().process_frame
	var ground: Sprite2D = surface.get_node("Floor/Earth")
	var ledge: Sprite2D = surface.get_node("RubblePlatform/Rubble")
	assert_vector(ground.texture.get_size()).is_equal(Vector2(1600, 140))
	assert_vector(ledge.texture.get_size()).is_equal(Vector2(180, 78))
	assert_vector(ground.global_position).is_equal(Vector2(0, 420))
	assert_vector(ledge.global_position).is_equal(Vector2(920, 342))
	var ambience: AudioStreamPlayer = surface.get_node("Presentation/Ambience")
	assert_bool(ambience.playing).is_false()
	var stream: AudioStreamWAV = ambience.stream as AudioStreamWAV
	assert_int(stream.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
