extends Control
## Presentation only: ascending shaft ribs suggest the traveller moving down.

var travel: bool = false
var elapsed: float = 0.0


func _process(delta: float) -> void:
	if visible and travel:
		elapsed += delta
		queue_redraw()


func _draw() -> void:
	if not travel:
		return
	for side: float in [300.0, 660.0]:
		draw_line(Vector2(side, 0), Vector2(side, 540), Color(0.2, 0.23, 0.2), 3.0)
	for rib: int in 9:
		var y: float = fposmod(float(rib) * 90.0 - elapsed * 180.0, 720.0) - 90.0
		draw_line(Vector2(300, y), Vector2(660, y + 28), Color(0.14, 0.18, 0.16), 5.0)
