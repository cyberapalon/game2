extends CanvasLayer

signal play_requested
signal pause_requested
signal resume_requested
signal restart_requested

var screen: StringName = &"title"


func _ready() -> void:
	$Screen/Panel/Rows/Primary.pressed.connect(_primary)
	$Screen/Panel/Rows/Restart.pressed.connect(func() -> void: restart_requested.emit())
	show_screen(&"title")


func show_screen(kind: StringName) -> void:
	screen = kind
	$Screen.visible = kind != &"playing"
	if kind == &"playing":
		return
	$Screen/Panel/Rows/Restart.visible = kind == &"pause"
	match kind:
		&"title":
			$Screen/Panel/Rows/Title.text = "Г Л У Б И Н А"
			$Screen/Panel/Rows/Subtitle.text = "ЭПИЗОД I · ПАМЯТЬ ПОЧВЫ"
			$Screen/Panel/Rows/Description.text = "Наверху остался пепел.\nВнизу ещё бьётся что-то живое.\n\nНайдите путь сквозь Корни и разбудите их Сердце."
			$Screen/Panel/Rows/Primary.text = "Играть  ·  Enter"
		&"pause":
			$Screen/Panel/Rows/Title.text = "ТИШИНА"
			$Screen/Panel/Rows/Subtitle.text = "ПАУЗА"
			$Screen/Panel/Rows/Description.text = "A / D или ← / → — идти\nПробел — прыжок; удерживайте для высокой дуги\nJ / X — удар на земле и в воздухе\nE — говорить / войти · M — звук\nShift — рывок после победы над Сердцем"
			$Screen/Panel/Rows/Primary.text = "Продолжить  ·  Esc"
		&"victory":
			$Screen/Panel/Rows/Title.text = "СВЕТ ПОД КОРНЯМИ"
			$Screen/Panel/Rows/Subtitle.text = "ЭПИЗОД I ЗАВЕРШЁН · 1.86 км"
			$Screen/Panel/Rows/Description.text = "Стук затих. Корни отпустили дорогу.\nВнизу светятся грани, не знавшие солнца.\n\nСпуск продолжится."
			$Screen/Panel/Rows/Primary.text = "Начать заново  ·  Enter"
	$Screen/Panel/Rows/Primary.grab_focus()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_ESCAPE:
		if screen == &"playing":
			pause_requested.emit()
		elif screen == &"pause":
			resume_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_ENTER and screen != &"playing":
		_primary()
		get_viewport().set_input_as_handled()


func _primary() -> void:
	match screen:
		&"title": play_requested.emit()
		&"pause": resume_requested.emit()
		&"victory": restart_requested.emit()
