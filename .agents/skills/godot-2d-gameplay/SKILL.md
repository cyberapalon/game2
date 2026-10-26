---
name: godot-2d-gameplay
description: Use when implementing or reviewing 2D platformer movement, CharacterBody2D physics, melee hitboxes, damage, checkpoints, hand-authored room transitions, boss progression, and depth UI contracts for the Godot 4.6.3 game. Does not authorize new mechanics or define visual asset workflows.
---

# 2D gameplay для «Глубины»

Сначала найди конкретное требование в PRD и согласованный объём задачи.
Не превращай упомянутый ниже риск в поручение реализовать механику.

1. Опиши одно наблюдаемое поведение и границы состояния: вход, результат,
   допустимые переходы, отмена/смерть. Не добавляй coyote time, jump buffer,
   новые способности или параметры баланса молча: это отдельные решения.
2. Для кинематического героя используй `CharacterBody2D`. Меняй `velocity`
   в `_physics_process(delta)`, затем вызывай Godot 4 `move_and_slide()` без
   аргументов. `velocity` задаётся в единицах в секунду: не умножай её на
   `delta` перед `move_and_slide`; ускорение интегрируется с `delta`.
   Проверяй floor/wall flags с учётом последнего перемещения.
3. Ввод оформляй действиями InputMap; gameplay не привязывай к keycode.
   Для проверок логики отделяй намерение игрока от браузерной доставки клавиш.
   Фокус canvas, отпускание клавиш и потеря фокуса проверяются через Web E2E.
4. Перед коллизиями зафиксируй небольшую таблицу layer/mask (мир, тело,
   hurtbox, hitbox и прочее только по необходимости). Для триггеров используй
   `Area2D`; учитывай deferred-изменения во время physics callbacks.
5. Для боя явно определи, когда цель может получить урон и сколько раз за
   одну атаку. Состояние здоровья/неуязвимости принадлежит gameplay; анимация
   отображает его. Проверь прерывание атаки, смерть и удаление комнаты.
6. Комнаты создаются вручную; для тайлов предпочитай `TileMapLayer`.
   Переход указывает целевую комнату и вход. Не создавай procedural generator.
   Контрольная точка должна восстанавливать согласованное состояние без
   дублирования игрока, сигналов и наград за босса.
7. Событие победы над боссом, выдача способности и разрешение спуска должны
   быть идемпотентны. Глубину передавай UI как данные, не вычисляй её из
   случайной вертикальной координаты. Геология условна по PRD.
8. Подбирай регрессии по изменению: прыжок/приземление и край платформы;
   один урон за удар; смерть/respawn; room transition; повторное событие босса.
   Используй `godot-testing` и команды из `docs/validation.md`.

Не оценивай отзывчивость управления по одному headless smoke. Зафиксируй,
что проверено автоматикой и что требует ручной игры в браузере.

Официальные источники:

- [CharacterBody2D](https://docs.godotengine.org/en/4.6/classes/class_characterbody2d.html).
- [Physics processing](https://docs.godotengine.org/en/4.6/tutorials/scripting/idle_and_physics_processing.html).
- [Input examples](https://docs.godotengine.org/en/4.6/tutorials/inputs/input_examples.html).
- [Area2D](https://docs.godotengine.org/en/4.6/classes/class_area2d.html),
  [TileMapLayer](https://docs.godotengine.org/en/4.6/classes/class_tilemaplayer.html).
