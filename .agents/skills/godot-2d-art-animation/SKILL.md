---
name: godot-2d-art-animation
description: Use for original 2D art integration, sprite sheets, texture import, SpriteFrames, AnimatedSprite2D, AnimationPlayer, visual layers, and animation review in Godot 4.6.3. Excludes gameplay authority and generic image generation; does not require external art services or plugins.
---

# 2D art и анимация

Сверь задачу с визуальным направлением PRD: мрачный оригинальный мир,
выразительный силуэт и читаемое действие. Hollow Knight — ориентир настроения,
не источник персонажей, музыки или ассетов. Pixel art в PRD **не закреплён**.

1. До создания/импорта ассета укажи назначение, формат, размеры кадра,
   pivot, прозрачность, имена клипов, FPS/длительности и loop/one-shot.
   Размеры и стиль согласуй с существующим art direction; не назначай всем
   изображениям nearest filtering автоматически.
2. Сохраняй источник/лицензию/автора и разрешённое использование рядом с
   ассетом или в каталоге лицензий. Для сгенерированного арта сохраняй
   происхождение и параметры. Генерация только при задаче на ассеты;
   отдельный сервис, API-ключ или платный инструмент по умолчанию не нужен.
3. Проверяй sheet: сетка без обрезанных кадров, одинаковые canvas/pivot,
   alpha без ореолов, padding против bleeding, корректный порядок кадров.
   Для анализа доступны `magick identify <file>` и FFmpeg. Результат должен
   быть проверяем в Godot, а не только в исходном PNG.
4. Для покадровых клипов используй `AnimatedSprite2D` + `SpriteFrames`.
   Для property/method tracks — `AnimationPlayer`; `AnimationTree` добавляй
   только при необходимости смешивания/сложных переходов.
   У одного свойства должен быть один владелец: код, трек или Tween.
5. Не вызывай `advance()` у `AnimatedSprite2D`: в 4.6.3 метода нет.
   `AnimationPlayer.advance(0)` существует, но нужен только при обоснованном
   синхронном применении треков. У AnimatedSprite2D `animation_finished`
   относится к one-shot, `animation_looped` — к loop; для сохранения
   frame progress используй `set_frame_and_progress()`.
6. Проверь RESET/начальную позу, разворот влево/вправо, отмену/перезапуск
   one-shot и возврат в idle. Атака и смерть не должны зависнуть на ожидании
   сигнала от looping-клипа. Не анимируй авторитетное перемещение тела в
   render tick; физические треки синхронизируй с physics при их использовании.
7. Отделяй фон/параллакс, мир и HUD; для нового параллакса используй `Parallax2D`.
   Проверь читаемость силуэта, земли, опасностей и UI на реальном viewport.
   Дорогие lights/shaders вводи после проверки Compatibility/Web.
8. Импорт и наличие клипов/ссылок проверяются автоматически; внешний вид,
   timing и ввод — в экспортированном Web Chromium по `docs/validation.md`.
   Headless Godot с dummy rendering не даёт визуального доказательства.

Официальные источники:

- [Импорт изображений](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/importing_images.html).
- [2D sprite animation](https://docs.godotengine.org/en/4.6/tutorials/2d/2d_sprite_animation.html).
- [AnimatedSprite2D](https://docs.godotengine.org/en/4.6/classes/class_animatedsprite2d.html),
  [SpriteFrames](https://docs.godotengine.org/en/4.6/classes/class_spriteframes.html).
- [AnimationPlayer](https://docs.godotengine.org/en/4.6/classes/class_animationplayer.html),
  [animation tracks](https://docs.godotengine.org/en/4.6/tutorials/animation/animation_track_types.html).
- [Parallax2D](https://docs.godotengine.org/en/4.6/classes/class_parallax2d.html).
