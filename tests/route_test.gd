extends GdUnitTestSuite

const RouteScene: PackedScene = preload("res://world/surface/surface.tscn")
const Dialogue = preload("res://world/interactions/dialogue.gd")

var _route: Node2D
var _player: CharacterBody2D


func before_test() -> void:
	_release_input()
	_route = auto_free(RouteScene.instantiate())
	get_tree().root.add_child(_route)
	_route.start_game()
	_player = _route.player
	await _frames(5)


func after_test() -> void:
	_release_input()


func test_dialogue_has_three_lines_closes_and_can_restart() -> void:
	var encounter = Dialogue.new()
	assert_bool(encounter.is_active()).is_false()
	for index: int in 3:
		assert_str(encounter.advance()).is_not_empty()
		assert_bool(encounter.is_active()).is_true()
	assert_str(encounter.advance()).is_empty()
	assert_bool(encounter.is_active()).is_false()
	encounter.restart()
	assert_str(encounter.advance()).is_equal(Dialogue.LINES[0])


func test_npc_prompt_requires_proximity_and_dialogue_restores_control() -> void:
	assert_object(_route.nearest_interaction()).is_null()
	await _press_e()
	assert_bool(_route.dialogue.is_active()).is_false()
	_player.position = Vector2(650, 398)
	await _frames(4)
	assert_str(_route.hud.prompt_label.text).contains("заговорить")
	await _press_e()
	assert_bool(_route.dialogue.is_active()).is_true()
	assert_bool(_player.control_locked).is_true()
	Input.action_press("move_right")
	await _frames(5)
	assert_float(_player.position.x).is_equal(650.0)
	Input.action_release("move_right")
	for line: int in 3:
		await _press_e()
	assert_bool(_route.dialogue.is_active()).is_false()
	assert_bool(_player.control_locked).is_false()
	Input.action_press("move_left")
	await _frames(5)
	assert_float(_player.position.x).is_less(650.0)


func test_every_portal_has_existing_target_entry_and_return_connection() -> void:
	for id: StringName in _route.ROOMS:
		var room: Node2D = _route.ROOMS[id].instantiate()
		for child: Node in room.get_children():
			if child is Area2D and child.has_method("contains_player") and child.kind == "portal":
				assert_bool(_route.ROOMS.has(child.target_room)).is_true()
				var destination: Node2D = _route.ROOMS[child.target_room].instantiate()
				assert_bool(destination.has_entry(child.target_entry)).is_true()
				var has_return: bool = false
				for back: Node in destination.get_children():
					if back is Area2D and back.has_method("contains_player") and back.kind in ["portal", "seal"] and back.target_room == id:
						has_return = true
				assert_bool(has_return).is_true()
				destination.free()
		room.free()


func test_transition_rejects_invalid_destinations_and_duplicate_requests() -> void:
	assert_bool(_route.request_transition(&"missing", &"entry")).is_false()
	assert_bool(_route.request_transition(&"landing", &"missing")).is_false()
	assert_bool(_route.request_transition(&"landing", &"surface")).is_true()
	assert_bool(_route.request_transition(&"landing", &"surface")).is_false()
	assert_bool(_route.request_transition(&"junction", &"landing")).is_false()
	await _settle_transition()
	assert_int(_route.transition_count).is_equal(1)
	assert_int(_route.get_node("RoomHost").get_child_count()).is_equal(1)
	assert_bool(_player.control_locked).is_false()


func test_all_room_spawns_settle_without_overlap_and_keep_single_player() -> void:
	var identity: int = _player.get_instance_id()
	for id: StringName in _route.ROOMS:
		var data: Node2D = _route.ROOMS[id].instantiate()
		var entries: Array[StringName] = []
		for entry: Node in data.get_node("Spawns").get_children():
			entries.append(entry.name)
		data.free()
		for entry: StringName in entries:
			assert_bool(_route.request_transition(id, entry)).is_true()
			await _settle_transition()
			assert_bool(_player.is_on_floor()).is_true()
			assert_float(_player.position.y).is_less(461.0)
			assert_float(_player.position.x).is_greater(12.0)
			assert_float(_player.position.x).is_less(float(_route.room.width) - 12.0)
			assert_int(_player.get_instance_id()).is_equal(identity)
			assert_int(_route.find_children("Player", "CharacterBody2D", true, false).size()).is_equal(1)
			assert_int(_route.get_node("RoomHost").get_child_count()).is_equal(1)


func test_depth_tracks_room_in_both_directions_and_ignores_jump() -> void:
	await _go(&"landing", &"surface")
	assert_str(_route.hud.depth_label.text).is_equal("Глубина: 0.12 км")
	Input.action_press("jump")
	await _frames(8)
	Input.action_release("jump")
	assert_float(_player.position.y).is_less(420.0)
	assert_str(_route.hud.depth_label.text).is_equal("Глубина: 0.12 км")
	await _frames(50)
	await _go(&"junction", &"landing")
	assert_str(_route.hud.depth_label.text).is_equal("Глубина: 0.24 км")
	await _go(&"seal", &"junction")
	assert_str(_route.hud.depth_label.text).is_equal("Глубина: 0.42 км")
	await _go(&"junction", &"seal")
	assert_str(_route.hud.depth_label.text).is_equal("Глубина: 0.24 км")
	await _go(&"landing", &"junction")
	await _go(&"surface", &"shaft")
	assert_str(_route.hud.depth_label.text).is_equal("Глубина: 0.00 км")


func test_optional_find_survives_return_and_sealed_exit_never_transitions() -> void:
	await _go(&"hollow", &"junction")
	_player.position = Vector2(980, 350)
	await _frames(5)
	await _press_e()
	assert_bool(_route.secret_found).is_true()
	assert_bool(_player.control_locked).is_true()
	await _press_e()
	assert_bool(_player.control_locked).is_false()
	await _go(&"junction", &"hollow")
	await _go(&"hollow", &"junction")
	assert_bool(_route.secret_found).is_true()
	assert_float(_route.room.get_node("Memory/Art").modulate.a).is_equal_approx(0.6, 0.001)
	await _go(&"seal", &"junction")
	_player.position = Vector2(1110, 438)
	await _frames(5)
	var count_before: int = _route.transition_count
	await _press_e()
	assert_bool(_route.hud.dialogue_panel.visible).is_true()
	assert_int(_route.transition_count).is_equal(count_before)
	await _press_e()
	assert_bool(_player.control_locked).is_false()
	assert_str(_route.room.room_id).is_equal("seal")
	Input.action_press("move_right")
	await _frames(40)
	assert_bool(_player.is_on_wall()).is_true()
	assert_float(_player.position.x).is_less(1129.0)


func _go(id: StringName, entry: StringName) -> void:
	assert_bool(_route.request_transition(id, entry)).is_true()
	await _settle_transition()


func _settle_transition() -> void:
	for tick: int in 240:
		await _frames(1)
		if not _route.transitioning:
			break
	assert_bool(_route.transitioning).is_false()
	await _frames(24)


func _press_e() -> void:
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(2)


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().physics_frame
		await get_tree().process_frame


func _release_input() -> void:
	for action: StringName in [&"move_left", &"move_right", &"jump", &"interact"]:
		Input.action_release(action)
