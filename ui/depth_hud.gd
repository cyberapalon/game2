extends CanvasLayer
## Presents room progress. Jump height is deliberately unrelated to depth.

@onready var depth_label: Label = $Margin/Rows/Depth


func show_depth(depth_km: float) -> void:
	depth_label.text = "Глубина: %.2f км" % depth_km
