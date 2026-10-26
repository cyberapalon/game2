---
name: godot-gdscript
description: Use for Godot 4.6.3 GDScript implementation, scene architecture, typed Resources, signals, lifecycle bugs, parser errors, and code review in this project. Excludes gameplay tuning, art import, and test orchestration, which have separate skills.
---

# GDScript и сцены Godot 4.6.3

Прочитай `AGENTS.md` и затронутые сцены/скрипты. До появления `project.godot`
подготавливай только явно запрошенную конфигурацию.

1. Найди владельца поведения: локальная сцена, `Resource` с данными или
   обоснованный общий сервис. Сначала переиспользуй существующий контракт.
   Укажи входы, сигналы и зависимости; не начинай с нового Autoload.
2. Пиши типизированные функции и сигналы, используй `@export` для данных,
   `@onready` для стабильных ссылок. `class_name`, если нужен, идёт перед
   `extends`; не регистрируй глобально каждый вспомогательный скрипт.
3. Соединяй сигналы через `object.signal_name.connect(callable)`; контролируй
   повторное подключение. Проверь, кто освобождает узел и может ли он исчезнуть
   до продолжения `await`. Не сохраняй устаревшие ссылки на комнату.
4. При `PackedScene.instantiate()` не требуй обязательных аргументов `_init()`.
   После ручного `add_child()` назначай `owner` нужному узлу, если дочерний узел
   должен сериализоваться в PackedScene; проверь повторную загрузку сцены.
5. Для общего `.tres` отделяй неизменяемые настройки от состояния экземпляра.
   Когда ресурс действительно должен изменяться локально, явно реши вопрос
   `duplicate()`/вложенных ресурсов или `resource_local_to_scene`.
6. Проверь API по **4.6**, а не по `stable`/`latest`. Для спорного метода
   используй локальный ClassDB или минимальный технический probe в `work/`.
   Не переноси Godot 3 API (`KinematicBody2D`, `yield`, старый `connect`).
7. После изменения выполни целевую проверку скрипта и связанную suite по
   `docs/validation.md`. Перед окончанием используй полный набор оттуда.

Критерий: контракт сцены понятен без чтения всего дерева, изменённые скрипты
компилируются в закреплённом движке, нет новых engine errors.

Официальные источники:

- [GDScript basics, 4.6](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/gdscript_basics.html).
- [Статическая типизация](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/static_typing.html).
- [Организация сцен](https://docs.godotengine.org/en/4.6/tutorials/best_practices/scene_organization.html).
- [Resource](https://docs.godotengine.org/en/4.6/classes/class_resource.html),
  [Node и owner](https://docs.godotengine.org/en/4.6/classes/class_node.html),
  [сигналы](https://docs.godotengine.org/en/4.6/getting_started/step_by_step/signals.html).
