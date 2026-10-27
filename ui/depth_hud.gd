extends CanvasLayer
## Presents room progress. Jump height is deliberately unrelated to depth.

@onready var depth_label: Label = $Margin/Rows/Depth
@onready var room_label: Label = $Margin/Rows/Room
@onready var prompt_label: Label = $Prompt
@onready var dialogue_panel: PanelContainer = $Dialogue
@onready var dialogue_label: Label = $Dialogue/Rows/Line
@onready var fade: Control = $Fade
@onready var travel_label: Label = $Fade/Travel


func show_health(current: int, maximum: int) -> void:
	$Health.text = "ЦЕЛОСТНОСТЬ  %d / %d" % [current, maximum]
	$HealthBar.max_value = maximum
	$HealthBar.value = current


func notify(text: String) -> void:
	$Notice.text = text
	$Notice.modulate.a = 1.0
	if _notice_tween != null:
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_interval(4.0)
	_notice_tween.tween_property($Notice, "modulate:a", 0.0, 1.0)


var _notice_tween: Tween


func begin_ending() -> void:
	move_child($Ending, 0)
	$Ending.show()
	for item: String in ["Health", "HealthBar", "Controls", "SoundToggle", "Chapter"]:
		get_node(item).hide()
	room_label.text = "НЕИЗВЕСТНОСТЬ / КРИСТАЛЬНЫЙ СВЕТ"


func end_ending() -> void:
	$Ending.hide()
	$Ending.modulate.a = 0.0
	for item: String in ["Health", "HealthBar", "Controls", "SoundToggle", "Chapter"]:
		get_node(item).show()


func show_boss(current: int, maximum: int, phase: int, warning: String) -> void:
	$Boss.show()
	$Boss/Name.text = "СЕРДЦЕ КОРНЕЙ" + (" / ПРОБУЖДЕНИЕ" if phase == 2 else "")
	$Boss/Bar.max_value = maximum
	$Boss/Bar.value = current
	$Boss/Warning.text = warning


func hide_boss() -> void:
	$Boss.hide()


func show_depth(depth_km: float) -> void:
	depth_label.text = "Глубина: %.2f км" % depth_km


func show_room(title: String, depth_km: float) -> void:
	room_label.text = title
	show_depth(depth_km)
	$Chapter.text = "ПРОЛОГ / 01\nПЕПЕЛ И ФАРФОР" if is_zero_approx(depth_km) else "КОРНИ / 02\nПАМЯТЬ ПОЧВЫ"


func show_prompt(text: String) -> void:
	prompt_label.text = text


func show_dialogue(text: String, speaker: String = "СМОТРИТЕЛЬ ПЕПЛА") -> void:
	dialogue_panel.visible = not text.is_empty()
	$Dialogue/Rows/Speaker.text = speaker
	dialogue_label.text = text
