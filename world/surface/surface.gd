extends Node2D
## Coordinates the small route. One player survives every room replacement.

const Dialogue = preload("res://world/interactions/dialogue.gd")
const ROOMS: Dictionary[StringName, PackedScene] = {
	&"surface": preload("res://world/surface/surface_landscape.tscn"),
	&"landing": preload("res://world/roots/landing.tscn"),
	&"junction": preload("res://world/roots/junction.tscn"),
	&"hollow": preload("res://world/roots/hollow.tscn"),
	&"seal": preload("res://world/roots/seal.tscn"),
	&"afterheart": preload("res://world/roots/afterheart.tscn"),
}

@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $DepthHud
@onready var camera: Camera2D = $Player/Camera2D

var room: Node2D
var transitioning: bool = false
var transition_count: int = 0
var secret_found: bool = false
var dialogue = Dialogue.new()
var _reading_note: bool = false
var _web_e2e: bool = false
var _cooldown: float = 0.0
var checkpoint_room: StringName = &"surface"
var checkpoint_position: Vector2 = Vector2(320, 398)
var checkpoint_id: StringName = &"surface"
var activated_checkpoints: Array[StringName] = []
var defeated_enemies: Array[StringName] = []
var respawn_count: int = 0
var boss_defeated: bool = false
var boss_active: bool = false
var dash_awards: int = 0
var episode_complete: bool = false
var course_retries: int = 0
var mode: StringName = &"title"
var _ending_depth: float = 0.56


func _ready() -> void:
	player.died.connect(_on_player_died)
	player.health_changed.connect(hud.show_health)
	player.combat_event.connect(_on_combat_event)
	_install_room(&"surface", &"start")
	hud.show_health(player.health, player.combat.max_health)
	$EpisodeMenu.play_requested.connect(start_game)
	$EpisodeMenu.pause_requested.connect(func() -> void: set_paused(true))
	$EpisodeMenu.resume_requested.connect(func() -> void: set_paused(false))
	$EpisodeMenu.restart_requested.connect(restart_game)
	player.set_control_locked(true)
	if OS.has_feature("web"):
		_web_e2e = JavaScriptBridge.eval(
			"new URLSearchParams(location.search).get('e2e') === '1'"
		)
	print("DEPTH_SURFACE_READY")


func _physics_process(delta: float) -> void:
	if room.room_id == &"afterheart" and player.position.y > 650.0 and not transitioning:
		course_retries += 1
		player.respawn(Vector2(285, 438))
		hud.notify("Память удержала вас. Удерживайте Пробел, затем Shift над пропастью.")
	_cooldown = maxf(0.0, _cooldown - delta)
	var trigger: Area2D = nearest_interaction()
	hud.show_prompt(trigger.prompt if trigger != null and not is_busy() else "")
	if Input.is_action_just_pressed("interact") and mode == &"playing" and not transitioning and not player.dead and _cooldown <= 0.0:
		if dialogue.is_active():
			_advance_dialogue()
		elif _reading_note:
			_reading_note = false
			hud.show_dialogue("")
			player.set_control_locked(false)
		elif trigger != null:
			_interact(trigger)
	if _web_e2e:
		_publish_web_state(trigger)


func is_busy() -> bool:
	return mode != &"playing" or transitioning or player.dead or dialogue.is_active() or _reading_note


func start_game() -> void:
	if mode != &"title":
		return
	mode = &"playing"
	$EpisodeMenu.show_screen(&"playing")
	player.set_control_locked(false)


func set_paused(value: bool) -> void:
	if value and (mode != &"playing" or transitioning or player.dead):
		return
	if not value and mode != &"pause":
		return
	mode = &"pause" if value else &"playing"
	$EpisodeMenu.show_screen(mode)
	player.set_control_locked(value or is_busy())
	get_tree().paused = value
	if _web_e2e:
		_publish_web_state(null)


func restart_game() -> void:
	if transitioning:
		return
	get_tree().paused = false
	mode = &"playing"
	boss_active = false
	boss_defeated = false
	episode_complete = false
	secret_found = false
	dash_awards = 0
	respawn_count = 0
	course_retries = 0
	transition_count = 0
	checkpoint_room = &"surface"
	checkpoint_id = &"surface"
	checkpoint_position = Vector2(320, 398)
	activated_checkpoints.clear()
	defeated_enemies.clear()
	dialogue = Dialogue.new()
	_reading_note = false
	hud.show_dialogue("")
	hud.end_ending()
	$EpisodeMenu.show_screen(&"playing")
	player.dash_unlocked = false
	player.dash_count = 0
	player.damage_taken = 0
	player.hits_landed = 0
	_install_room(&"surface", &"start")
	player.respawn(checkpoint_position)
	hud.notify("Снова под пепельным небом.")


func nearest_interaction() -> Area2D:
	var closest: Area2D = null
	var distance: float = INF
	for child: Node in room.get_children():
		if child is Area2D and child.has_method("contains_player") and child.contains_player(player):
			var current: float = player.position.distance_squared_to(child.position)
			if current < distance:
				closest = child
				distance = current
	return closest


func _interact(trigger: Area2D) -> void:
	match trigger.kind:
		"npc":
			dialogue.restart()
			player.set_control_locked(true)
			_advance_dialogue()
		"portal":
			request_transition(trigger.target_room, trigger.target_entry)
		"secret":
			secret_found = true
			trigger.get_node("Art").modulate = Color(0.45, 0.55, 0.5, 0.6)
			_show_note("В коре застряла керамическая пластинка. На ней — оттиск листа. Здесь когда-то помнили солнце.", "НАХОДКА / ОТПЕЧАТОК ЛИСТА")
		"seal":
			_show_note("Корни стянуты, словно узел. Из глубины идёт тяжёлый мерный стук. Пока он не стихнет, путь останется закрыт.", "ГЛУХОЙ ПРОХОД")
		"boss":
			if not boss_defeated and not boss_active:
				boss_active = room.get_node("Heart").awaken()
				room.get_node("ArenaWall").collision_layer = 1
				hud.notify("СЕРДЦЕ КОРНЕЙ\nПрыгайте через корневую волну. Бейте, когда сердце открыто.")
		"finish":
			finish_episode()


func _advance_dialogue() -> void:
	var line: String = dialogue.advance()
	hud.show_dialogue(line)
	if line.is_empty():
		player.set_control_locked(false)


func _show_note(text: String, title: String) -> void:
	_reading_note = true
	player.set_control_locked(true)
	hud.show_dialogue(text, title)


func request_transition(target: StringName, entry: StringName) -> bool:
	if is_busy() or boss_active or _cooldown > 0.0 or not ROOMS.has(target):
		return false
	var candidate: Node2D = ROOMS[target].instantiate()
	var valid: bool = candidate.has_entry(entry)
	candidate.free()
	if not valid:
		return false
	# Guard precedes deferral: two requests in one tick cannot duplicate a swap.
	transitioning = true
	player.set_control_locked(true)
	_run_transition.call_deferred(target, entry)
	return true


func _run_transition(target: StringName, entry: StringName) -> void:
	var vertical: bool = room.room_id == &"surface" or target == &"surface"
	hud.fade.travel = vertical
	hud.fade.elapsed = 0.0
	hud.fade.queue_redraw()
	hud.travel_label.text = "СПУСК В КОРНИ" if target == &"landing" else "ПОДЪЁМ К СВЕТУ"
	if not vertical:
		hud.travel_label.text = ""
	hud.fade.show()
	var tween: Tween = create_tween()
	tween.tween_property(hud.fade, "modulate:a", 1.0, 0.25)
	await tween.finished
	_install_room(target, entry)
	if vertical:
		hud.travel_label.text += "\n%.2f км" % room.depth_km
		await get_tree().create_timer(0.85).timeout
	# New broadphase and spawn settle while the screen is covered.
	await get_tree().physics_frame
	camera.reset_smoothing()
	var reveal: Tween = create_tween()
	reveal.tween_property(hud.fade, "modulate:a", 0.0, 0.3)
	await reveal.finished
	hud.fade.hide()
	transition_count += 1
	_cooldown = 0.3
	transitioning = false
	player.set_control_locked(false)


func _install_room(target: StringName, entry: StringName) -> void:
	if is_instance_valid(room):
		$RoomHost.remove_child(room)
		room.queue_free()
	room = ROOMS[target].instantiate()
	$RoomHost.add_child(room)
	player.position = room.spawn_position(entry)
	camera.limit_right = room.width
	camera.reset_smoothing()
	hud.show_room(room.title, room.depth_km)
	if target == &"hollow" and secret_found:
		room.get_node("Memory/Art").modulate = Color(0.45, 0.55, 0.5, 0.6)
	for actor: Node in room.get_children():
		if actor.is_in_group(&"enemies"):
			if defeated_enemies.has(actor.encounter_id):
				actor.queue_free()
			else:
				actor.target = player
				actor.defeated.connect(_on_enemy_defeated)
				actor.combat_event.connect(_on_combat_event)
		elif actor is Area2D and actor.has_signal("activated"):
			actor.activated.connect(_activate_checkpoint)
			actor.set_active(activated_checkpoints.has(actor.point_id))
	if target == &"seal":
		var heart: CharacterBody2D = room.get_node("Heart")
		heart.target = player
		heart.defeated.connect(_on_boss_defeated)
		heart.status_changed.connect(hud.show_boss)
		heart.combat_event.connect(_on_combat_event)
		if boss_defeated:
			heart.queue_free()
			_open_gate()
	else:
		hud.hide_boss()


func _on_boss_defeated() -> void:
	if boss_defeated:
		return
	boss_defeated = true
	boss_active = false
	player.dash_unlocked = true
	dash_awards += 1
	player.restore_health()
	hud.hide_boss()
	_open_gate()
	_on_combat_event(&"ability", player.global_position)
	_on_combat_event(&"gate", player.global_position)
	_show_note("Вы обрели РЫВОК. Shift — стремительно пронестись вперёд, даже в воздухе. Рывок даёт короткую неуязвимость. Между рывками — 0.7 секунды. За разорванным сводом ждёт разлом: прыгните и нажмите Shift над пропастью.", "НОВАЯ СПОСОБНОСТЬ / РЫВОК")


func _open_gate() -> void:
	room.get_node("SealedBarrier").collision_layer = 0
	room.get_node("ArenaWall").collision_layer = 0
	room.get_node("Seal/Art").hide()
	var gate: Area2D = room.get_node("Seal")
	gate.kind = "portal"
	gate.prompt = "E — за разорванный свод"
	gate.target_room = &"afterheart"
	gate.target_entry = &"seal"


func finish_episode() -> bool:
	if not boss_defeated or episode_complete or room.room_id != &"afterheart" or player.position.x < 1000.0 or player.dash_count == 0 or is_busy():
		return false
	episode_complete = true
	_finish_scene.call_deferred()
	return true


func _finish_scene() -> void:
	transitioning = true
	player.set_control_locked(true)
	hud.notify("Спуск продолжается. Внизу светится то, что не помнит солнца.")
	hud.begin_ending()
	var descent: Tween = create_tween()
	descent.tween_property(hud.get_node("Ending"), "modulate:a", 1.0, 1.0)
	_ending_depth = room.depth_km
	descent.parallel().tween_method(_show_final_depth, room.depth_km, 1.86, 3.5)
	await descent.finished
	mode = &"victory"
	transitioning = false
	$EpisodeMenu.show_screen(&"victory")



func _show_final_depth(value: float) -> void:
	_ending_depth = value
	hud.show_depth(value)


func _on_enemy_defeated(identity: StringName) -> void:
	if not defeated_enemies.has(identity):
		defeated_enemies.append(identity)


func _activate_checkpoint(point: Area2D) -> void:
	checkpoint_room = room.room_id
	checkpoint_position = point.position
	checkpoint_id = point.point_id
	if not activated_checkpoints.has(checkpoint_id):
		activated_checkpoints.append(checkpoint_id)
	player.restore_health()
	_on_combat_event(&"checkpoint", point.global_position)
	hud.notify("ОЧАГ ПАМЯТИ\nЗдоровье восстановлено. Здесь вы пробудитесь после гибели.")


func _on_player_died() -> void:
	_respawn_player.call_deferred()


func _respawn_player() -> void:
	transitioning = true
	boss_active = false
	hud.hide_boss()
	await get_tree().create_timer(1.25).timeout
	hud.notify("Фарфор треснул. Память осталась.")
	_install_room(checkpoint_room, &"surface" if checkpoint_room == &"landing" else (&"landing" if checkpoint_room == &"junction" else &"start"))
	player.respawn(checkpoint_position)
	camera.reset_smoothing()
	respawn_count += 1
	transitioning = false
	_cooldown = 0.3


func _on_combat_event(kind: StringName, point: Vector2) -> void:
	$EpisodeAudio.play_event(kind, point)
	if kind in [&"hit", &"hurt", &"enemy_death", &"boss_slam", &"boss_death", &"dash"]:
		var effect: AnimatedSprite2D = AnimatedSprite2D.new()
		effect.sprite_frames = $Presentation.dust_frames
		effect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		effect.position = point
		effect.scale = Vector2.ONE * (1.5 if kind == &"boss_death" else 0.5)
		effect.modulate = Color(0.7, 0.85, 1.0) if kind == &"dash" else Color(1.0, 0.82, 0.5)
		effect.z_index = 5
		add_child(effect)
		effect.animation_finished.connect(effect.queue_free)
		effect.play(&"land")


func _publish_web_state(trigger: Area2D) -> void:
	# Opt-in read-only observation, without JavaScript commands or teleport API.
	var state: Dictionary = {
		"x": player.position.x, "y": player.position.y,
		"screen_x": player.get_global_transform_with_canvas().origin.x,
		"screen_y": player.get_global_transform_with_canvas().origin.y,
		"vx": player.velocity.x, "vy": player.velocity.y,
		"grounded": player.is_on_floor(),
		"depth_km": _ending_depth if episode_complete else room.depth_km, "depth_text": hud.depth_label.text,
		"room": room.room_id, "transitioning": transitioning,
		"transition_count": transition_count,
		"player_count": find_children("Player", "CharacterBody2D", true, false).size(),
		"dialogue_index": dialogue.index, "dialogue_active": dialogue.is_active(),
		"note_active": _reading_note, "control_locked": player.control_locked,
		"secret_found": secret_found,
		"interaction": trigger.name if trigger != null else "",
		"prompt": hud.prompt_label.text,
		"animation": player.visual.animation, "frame": player.visual.frame,
		"facing_left": player.visual.flip_h,
		"front_planted": player.visual.front_planted,
		"back_planted": player.visual.back_planted,
		"front_sole_x": player.visual.front_sole_world().x,
		"back_sole_x": player.visual.back_sole_world().x,
		"front_sole_y": player.visual.front_sole_world().y,
		"back_sole_y": player.visual.back_sole_world().y,
		"body_y": player.visual.body.position.y,
		"gait_phase": player.visual.phase,
		"audio_started": $Presentation.started,
		"audio_muted": $Presentation.muted,
		"ambience_playing": $Presentation/Ambience.playing,
		"step_count": $Presentation.step_count,
		"land_count": $Presentation.land_count,
		"health": player.health, "max_health": player.combat.max_health,
		"dead": player.dead, "invulnerable": player.invulnerable_left > 0.0,
		"attack_left": player.attack_left, "strike_active": player.is_strike_active(),
		"combat_visible": player.combat_sprite.is_visible_in_tree(),
		"combat_frame": player.combat_sprite.frame, "combat_clip": player.combat_sprite.animation,
		"hits_landed": player.hits_landed, "damage_taken": player.damage_taken,
		"checkpoint": checkpoint_id, "respawn_count": respawn_count,
		"enemies_defeated": defeated_enemies.size(),
		"boss_active": boss_active, "boss_defeated": boss_defeated,
		"dash_unlocked": player.dash_unlocked, "dash_awards": dash_awards,
		"dash_left": player.dash_left, "dash_cooldown": player.dash_cooldown_left,
		"dash_count": player.dash_count, "episode_complete": episode_complete,
		"mode": mode, "course_retries": course_retries,
		"music": $EpisodeAudio.theme, "music_playing": $EpisodeAudio/Music.playing,
	}
	if room.has_node("Heart"):
		var heart: CharacterBody2D = room.get_node("Heart")
		state["boss"] = {"health": heart.health, "phase": heart.phase, "state": heart.state, "left": heart.state_left, "slams": heart.slam_count, "storms": heart.storm_count}
	var foes: Array[Dictionary] = []
	for actor: Node in room.get_children():
		if actor.is_in_group(&"enemies"):
			foes.append({"id": actor.encounter_id, "species": actor.settings.species, "x": actor.position.x, "y": actor.position.y, "health": actor.health, "state": actor.state, "shots": actor.shots})
	state["enemies"] = foes
	if room.room_id == &"surface":
		state["background_screen_x"] = room.get_node("Sky/Panorama").get_global_transform_with_canvas().origin.x
		state["ruins_screen_x"] = room.get_node("Ruins/Architecture").get_global_transform_with_canvas().origin.x
		state["foreground_screen_x"] = room.get_node("Foreground/Debris").get_global_transform_with_canvas().origin.x
	JavaScriptBridge.eval("window.__depthE2E = " + JSON.stringify(state))
