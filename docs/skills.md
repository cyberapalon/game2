# Выбор и проверка навыков

Проверено 26 октября 2026 года. В исходном checkout не было project skills;
системные навыки текущей сессии не покрывали Godot/GDScript. Установленных
проектных наборов для переиспользования не обнаружено.

## Результат отбора

| Локальный навык | Уникальная зона ответственности | Основные источники |
| --- | --- | --- |
| `godot-gdscript` | Типы, lifecycle, сигналы, ресурсы, композиция сцен | Официальные Godot 4.6 GDScript/Resource/Node docs |
| `godot-2d-gameplay` | Физика и ввод, контракт боя, комнаты и прогресс PRD | Godot 4.6 CharacterBody2D/Area2D/Input/TileMapLayer |
| `godot-2d-art-animation` | Оригинальный арт, импорт, sheets, анимация и presentation | Godot 4.6 images/SpriteFrames/AnimatedSprite2D/AnimationPlayer |
| `godot-testing` | Выбор test layer, GdUnit4, Web E2E и release checks | Godot 4.6 CLI/Web, GdUnit4 v6.2.2, Playwright |

Skills написаны для этого репозитория, не скопированы из community packages.
Конкретные официальные ссылки находятся в каждом `SKILL.md`. Это проверенные
инструкции в рамках доступной среды, **не официальные skills Godot Foundation
и не сертификат качества**. Игровое применение будет проверено при реализации.

## Что исследовано снаружи

- [Game-Dev-Agentic-Skills](https://github.com/thedivergentai/Game-Dev-Agentic-Skills/tree/db004d74c40686ca2f7a35fe067b119a9cda593e),
  commit `db004d74c40686ca2f7a35fe067b119a9cda593e`: прочитаны
  `godot-gdscript-mastery`, `godot-2d-animation`, `godot-testing-patterns`.
  Не устанавливаем набор: он заявляет Godot 4.7+, ссылается на множество
  обязательных соседних scripts/skills и добавляет лишние направления.
  В animation skill найден вызов `AnimatedSprite2D.advance(0)`, отсутствующий
  в 4.6.3. Это проверено локально через `ClassDB.class_has_method`; такой
  рецепт не переносим. Testing skill также не учитывает необходимый в нашем
  runner `--ignoreHeadlessMode`. Отдельные хорошие идеи не являются основанием
  считать весь набор совместимым с нашей версией.
- [NPGameDev companion skills v1.1.0](https://github.com/NPGameDev/godot-mcp-toolkit/blob/c22ddb4be5f45c1e01b86866356935bbd8643dd9/addons/godot_mcp_toolkit/docs/companion-skills.md):
  рассмотрены роли `godot-mcp-toolkit` и `mcp-extension-creator` по документации
  автора. Они учат управлять именно MCP, не заменяют GDScript/gameplay/art/test.
  Первый можно повторно оценить после подключения MCP, второй сейчас не нужен.
  Полный набор references нужно сохранять при возможном будущем переносе;
  только описание навыков не является проверкой их поведения.

Marketplace badges, число звёзд и слова «verified» в каталогах не принимались
за доказательство совместимости. Community installers не выполнялись.

## Как избегаем дублирования

`AGENTS.md` содержит общие обязательные правила и маршрутизацию; каждый skill —
узкую процедуру. Все команды тестов и экспорта живут в `validation.md`, pins —
в `toolchain-lock.json`, MCP — в `godot-mcp.md`. Art skill не реализует бой,
gameplay skill не управляет импортом ассетов, testing skill не изобретает
архитектуру. Новый skill добавляется только при появлении новой повторяемой
задачи, которую нельзя точнее включить в существующую область.

## Обнаружение в Codex

Формат: `.agents/skills/<name>/SKILL.md` с YAML `name`/`description`.
Сканируется каталог репозитория; установка в домашний каталог не требуется.
Повторная проверка:

```bash
python3 tools/check_codex_skills.py --output work/skills-discovery.json
```

Скрипт обращается к реальному loader Codex, а не имитирует обнаружение через
`find` или самописный YAML parser. Подробности и границы результата — в
[validation.md](validation.md), свидетельство запуска — в
[setup-report.md](setup-report.md). Формат и repository scope сверены с
[официальной документацией Codex skills](https://developers.openai.com/codex/skills/).
