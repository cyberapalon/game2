extends Node2D
## Coordinates the small route. One player survives every room replacement.

const Dialogue = preload("res://world/interactions/dialogue.gd")
const ROOMS: Dictionary[StringName, PackedScene] = {
	&"surface": preload("res://world/surface/surface_landscape.tscn"),
	&"landing": preload("res://world/roots/landing.tscn"),
	&"junction": preload("res://world/roots/junction.tscn"),
	&"hollow": preload("res://world/roots/hollow.tscn"),
	&"seal": preload("res://world/roots/seal.tscn"),
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


func _ready() -> void:
	_install_room(&"surface", &"start")
	if OS.has_feature("web"):
		_web_e2e = JavaScriptBridge.eval(
			"new URLSearchParams(location.search).get('e2e') === '1'"
		)
	print("DEPTH_SURFACE_READY")


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	var trigger: Area2D = nearest_interaction()
	hud.show_prompt(trigger.prompt if trigger != null and not is_busy() else "")
	if Input.is_action_just_pressed("interact") and not transitioning and _cooldown <= 0.0:
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
	return transitioning or dialogue.is_active() or _reading_note


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
	if is_busy() or _cooldown > 0.0 or not ROOMS.has(target):
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


func _publish_web_state(trigger: Area2D) -> void:
	# Opt-in read-only observation, without JavaScript commands or teleport API.
	var state: Dictionary = {
		"x": player.position.x, "y": player.position.y,
		"screen_x": player.get_global_transform_with_canvas().origin.x,
		"screen_y": player.get_global_transform_with_canvas().origin.y,
		"vx": player.velocity.x, "vy": player.velocity.y,
		"grounded": player.is_on_floor(),
		"depth_km": room.depth_km, "depth_text": hud.depth_label.text,
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
	}
	if room.room_id == &"surface":
		state["background_screen_x"] = room.get_node("Sky/Panorama").get_global_transform_with_canvas().origin.x
		state["ruins_screen_x"] = room.get_node("Ruins/Architecture").get_global_transform_with_canvas().origin.x
		state["foreground_screen_x"] = room.get_node("Foreground/Debris").get_global_transform_with_canvas().origin.x
	JavaScriptBridge.eval("window.__depthE2E = " + JSON.stringify(state))
