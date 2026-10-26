extends RefCounted
## One encounter, three lines. No branching, quest state or dialogue framework.

const LINES: PackedStringArray = [
	"Здесь ветер повторяет чужие шаги. Свои я давно перестал считать.",
	"За сломанной аркой осталась шахта. Корни ещё держат её стены.",
	"Если внизу услышишь стук — подожди. Иногда земля отвечает."
]

var index: int = -1


func advance() -> String:
	index += 1
	return LINES[index] if index < LINES.size() else ""


func is_active() -> bool:
	return index >= 0 and index < LINES.size()


func restart() -> void:
	index = -1
