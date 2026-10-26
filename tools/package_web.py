#!/usr/bin/env python3
"""Package existing verified outputs; never builds or changes game sources."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'work/review-output'
DEST.mkdir(parents=True, exist_ok=True)


def archive(name, files):
    target = DEST / name
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as bundle:
        for path, relative in sorted(files, key=lambda item: item[1]):
            bundle.write(path, relative)
    with zipfile.ZipFile(target) as bundle:
        if bundle.testzip() is not None:
            raise RuntimeError('Corrupt package: ' + name)
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verification', type=Path,
                        help='Combined evidence when a failed step was rerun separately')
    args = parser.parse_args()
    manifest = ROOT / 'build/manifest.json'
    if not manifest.is_file():
        raise RuntimeError('Run the final validation before packaging')
    candidates = sorted((ROOT / 'reports').glob('validation-*/results.json'))
    results = [p for p in candidates if 'web_e2e' in json.loads(p.read_text()) and 'gdunit' in json.loads(p.read_text())]
    if not results and args.verification is None:
        raise RuntimeError('A completed full validation report is required')
    verification = json.loads((args.verification or results[-1]).read_text())
    if verification.get('source_commit', json.loads(manifest.read_text())['source_commit']) != json.loads(manifest.read_text())['source_commit']:
        raise RuntimeError('Verification and build refer to different game sources')
    if verification['gdunit']['tests'] == 0 or any(verification['gdunit'][k] for k in ('failures', 'errors', 'skipped')):
        raise RuntimeError('GdUnit4 evidence is not successful')
    if verification['web_e2e']['expected'] < 4 or any(verification['web_e2e'][k] for k in ('unexpected', 'skipped', 'flaky')):
        raise RuntimeError('Web evidence is not successful')
    (DEST / 'verification.json').write_text(json.dumps(verification, indent=2) + '\n')
    play = DEST / 'play.py'
    shutil.copyfile(ROOT / 'tools/play_web.py', play)
    readme = DEST / 'START-HERE.txt'
    readme.write_text('''ГЛУБИНА — фаза 3, Поверхность → Корни

1. Полностью распакуйте архив в обычную папку на своём компьютере.
2. Нужен Python 3. На Windows запустите START-WINDOWS.cmd двойным щелчком.
   На macOS/Linux откройте терминал в папке depth-web и выполните:
       python3 play.py
   На Windows из терминала можно выполнить: py -3 play.py
3. Браузер откроется автоматически. Если этого не произошло, откройте
   адрес, напечатанный в терминале (обычно http://127.0.0.1:8765/index.html).
4. Щёлкните по игре. A/D или стрелки — движение, Пробел — прыжок,
   E — поговорить, продолжить диалог, осмотреть предмет или пройти через вход.
5. Для остановки сервера нажмите Ctrl+C в его терминале.

Маршрут: пройдите вправо, поговорите со смотрителем, перепрыгните обломок
и найдите старую шахту. Под землёй ищите явные норы и подсказки E.
На развилке есть верхняя необязательная нора с находкой. Основной путь
ведёт вправо к закрытому сплетению корней. Можно вернуться на поверхность.
Секрет запоминается в текущей игровой сессии; после перезагрузки игра начинается заново.

Игра работает в браузере с WebGL2. Открытие index.html через file:// не подходит.
Python обслуживает только локальные файлы; устанавливать Godot для игры не нужно.
''')
    windows = DEST / 'START-WINDOWS.cmd'
    windows.write_bytes(b'@echo off\r\ncd /d "%~dp0"\r\nwhere py >nul 2>nul\r\nif errorlevel 1 (python play.py) else (py -3 play.py)\r\npause\r\n')
    files = [(p, 'depth-web/' + str(p.relative_to(ROOT / 'build/web'))) for p in (ROOT / 'build/web').rglob('*') if p.is_file()]
    files += [(play, 'depth-web/play.py'), (readme, 'depth-web/START-HERE.txt'),
              (windows, 'depth-web/START-WINDOWS.cmd'), (manifest, 'depth-web/manifest.json'),
              (DEST / 'verification.json', 'depth-web/verification.json')]
    web = archive('depth-phase-3-web.zip', files)
    artifacts = ROOT / 'reports/web/artifacts'
    evidence = [(p, 'screenshots/' + str(p.relative_to(artifacts)))
                for p in artifacts.rglob('*.png') if p.name != 'test-failed-1.png']
    evidence += [(p, p.name) for p in (ROOT / 'reports/web/artifacts').rglob('route-evidence.json')]
    evidence += [(ROOT / 'reports/web/results.json', 'playwright-results.json'), (DEST / 'verification.json', 'verification.json')]
    for report_key in ('native_validation_run', 'web_validation_run'):
        if report_key in verification:
            report = ROOT / 'reports' / verification[report_key]
            evidence += [(p, 'validation/' + report.name + '/' + p.name) for p in report.glob('*.log')]
    for xml in verification.get('gdunit_xml', []):
        path = ROOT / xml
        evidence.append((path, 'validation/' + str(path.relative_to(ROOT / 'reports'))))
    screenshots = archive('depth-phase-3-screenshots.zip', evidence)
    (DEST / 'SHA256SUMS.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + p.name + '\n' for p in [web, screenshots, DEST / 'verification.json']))
    print(json.dumps({'web_bytes': web.stat().st_size, 'screenshots_bytes': screenshots.stat().st_size,
                      'verification': verification, 'output': str(DEST)}, indent=2))


if __name__ == '__main__':
    main()
