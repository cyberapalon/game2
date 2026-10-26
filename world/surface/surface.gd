extends Node2D

const SURFACE_DEPTH_KM: float = 0.0

@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $DepthHud

var _web_e2e: bool = false


func _ready() -> void:
	hud.show_depth(SURFACE_DEPTH_KM)
	if OS.has_feature("web"):
		_web_e2e = JavaScriptBridge.eval(
			"new URLSearchParams(location.search).get('e2e') === '1'"
		)
	print("DEPTH_SURFACE_READY")


func _physics_process(_delta: float) -> void:
	if _web_e2e:
		# Opt-in, read-only observation of real physics; never accepts test input.
		var state: Dictionary = {
			"x": player.position.x,
			"y": player.position.y,
			"screen_x": player.get_global_transform_with_canvas().origin.x,
			"screen_y": player.get_global_transform_with_canvas().origin.y,
			"vx": player.velocity.x,
			"vy": player.velocity.y,
			"grounded": player.is_on_floor(),
			"depth_km": SURFACE_DEPTH_KM,
			"depth_text": hud.depth_label.text,
		}
		JavaScriptBridge.eval("window.__depthE2E = " + JSON.stringify(state))
