extends CanvasLayer
## Presents room progress. Jump height is deliberately unrelated to depth.

@onready var depth_label: Label = $Margin/Rows/Depth
@onready var room_label: Label = $Margin/Rows/Room
@onready var prompt_label: Label = $Prompt
@onready var dialogue_panel: PanelContainer = $Dialogue
@onready var dialogue_label: Label = $Dialogue/Rows/Line
@onready var fade: Control = $Fade
@onready var travel_label: Label = $Fade/Travel


func show_depth(depth_km: float) -> void:
	depth_label.text = "Глубина: %.2f км" % depth_km


func show_room(title: String, depth_km: float) -> void:
	room_label.text = title
	show_depth(depth_km)
	$Chapter.text = "ПРОЛОГ / 01\nПЕПЕЛЬНЫЙ ПРИЛИВ" if is_zero_approx(depth_km) else "КОРНИ / 02\nПАМЯТЬ ПОЧВЫ"


func show_prompt(text: String) -> void:
	prompt_label.text = text


func show_dialogue(text: String, speaker: String = "СМОТРИТЕЛЬ ПЕПЛА") -> void:
	dialogue_panel.visible = not text.is_empty()
	$Dialogue/Rows/Speaker.text = speaker
	dialogue_label.text = text
