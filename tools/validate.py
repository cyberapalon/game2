#!/usr/bin/env python3
"""Project checks in the published Cloud environment; never installs tools."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
CLOUD = Path('/workspace/.godot-cloud')
GODOT = CLOUD / 'bin/godot'
RUN_ID = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
REPORT = ROOT / 'reports' / ('validation-' + RUN_ID)
BUILD = ROOT / 'build'
ERROR = re.compile(r'SCRIPT ERROR:|Parse Error:|^ERROR:', re.M)


def run(name, args, *, timeout=180, cwd=ROOT, env=None):
    result = subprocess.run([str(arg) for arg in args], cwd=cwd, env=env,
                            text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=timeout)
    (REPORT / (name + '.log')).write_text(result.stdout)
    if result.returncode or ERROR.search(result.stdout):
        raise RuntimeError(f'{name} failed (exit {result.returncode}):\n{result.stdout[-8000:]}')
    print(name + ': passed', flush=True)
    return result.stdout


def prerequisites():
    lock = json.loads((ROOT / 'docs/toolchain-lock.json').read_text())
    if os.environ.get('GODOT_CLOUD_ROOT') != str(CLOUD):
        raise RuntimeError('First source /workspace/.godot-cloud/env.sh')
    version = subprocess.check_output([GODOT, '--version'], text=True).strip()
    if version != lock['godot']['version']:
        raise RuntimeError('Godot version differs from toolchain-lock.json')
    for name, digest in lock['environment_owned_files_sha256'].items():
        if hashlib.sha256((CLOUD / name).read_bytes()).hexdigest() != digest:
            raise RuntimeError('Prepared environment file differs: ' + name)
    for archive, algorithm, digest in [
        ('Godot_v4.6.3-stable_linux.x86_64.zip', 'sha512', lock['godot']['binary_archive_sha512']),
        ('Godot_v4.6.3-stable_export_templates.tpz', 'sha512', lock['godot']['templates_archive_sha512']),
        ('gdUnit4-v6.2.2.zip', 'sha256', lock['gdunit']['archive_sha256']),
    ]:
        if hashlib.new(algorithm, (CLOUD / 'downloads' / archive).read_bytes()).hexdigest() != digest:
            raise RuntimeError('Pinned archive differs: ' + archive)
    plugin = (ROOT / 'addons/gdUnit4/plugin.cfg').read_text()
    if 'version="' + lock['gdunit']['version'] + '"' not in plugin:
        raise RuntimeError('GdUnit4 version differs')
    with zipfile.ZipFile(CLOUD / 'downloads/gdUnit4-v6.2.2.zip') as archive:
        for entry in archive.infolist():
            parts = Path(entry.filename).parts
            if 'addons' not in parts or entry.is_dir():
                continue
            relative = Path(*parts[parts.index('addons'):])
            if relative.parts[:2] == ('addons', 'gdUnit4'):
                if (ROOT / relative).read_bytes() != archive.read(entry):
                    raise RuntimeError('Vendored GdUnit4 differs from archive: ' + str(relative))
    browser_package = CLOUD / 'tools/browser/node_modules/@playwright/test/package.json'
    if json.loads(browser_package.read_text())['version'] != lock['playwright']:
        raise RuntimeError('Playwright version differs')
    chromium = subprocess.check_output([lock['chromium']['executable'], '--version'], text=True)
    if lock['chromium']['version'] not in chromium:
        raise RuntimeError('Chromium version differs')
    return version


def checks():
    # This is generated import state, never a source directory.
    shutil.rmtree(ROOT / '.godot', ignore_errors=True)
    run('skills', ['python3', ROOT / 'tools/check_codex_skills.py',
                   '--output', REPORT / 'skills.json'])
    run('project-check', ['python3', CLOUD / 'check_project.py', ROOT])
    run('main-smoke', [GODOT, '--headless', '--path', ROOT, '--quit-after', '60'], timeout=60)
    run('diff-check', ['git', 'diff', '--check'])


def unit(suite):
    relative = 'reports/gdunit-' + RUN_ID
    run('gdunit', [GODOT, '--headless', '--path', ROOT, '--script',
                  'res://addons/gdUnit4/bin/GdUnitCmdTool.gd',
                  '--ignoreHeadlessMode', '-a', suite, '-c', '-rd', relative], timeout=120)
    counts = dict.fromkeys(('tests', 'failures', 'errors', 'skipped'), 0)
    xml_files = list((ROOT / relative).rglob('results.xml'))
    if not xml_files:
        raise RuntimeError('Fresh GdUnit4 XML report missing')
    for path in xml_files:
        xml = ET.parse(path).getroot()
        for node in xml.iter('testsuite'):
            for key in counts:
                counts[key] += int(node.get(key, 0))
    if counts['tests'] == 0 or any(counts[k] for k in ('failures', 'errors', 'skipped')):
        raise RuntimeError('GdUnit4 did not pass: ' + repr(counts))
    print('GdUnit4:', counts, flush=True)
    return counts


def build():
    shutil.rmtree(BUILD, ignore_errors=True)
    BUILD.mkdir()
    (BUILD / '.gdignore').touch()
    for preset, output in [('Web', 'web/index.html'), ('Windows', 'windows/depth.exe'),
                           ('Linux', 'linux/depth.x86_64')]:
        destination = BUILD / output
        destination.parent.mkdir(parents=True, exist_ok=True)
        run('export-' + preset.lower(), [GODOT, '--headless', '--path', ROOT,
                                        '--export-release', preset, destination], timeout=240)
        if not destination.is_file() or destination.stat().st_size == 0:
            raise RuntimeError('Export artifact missing: ' + output)
    empty_project = BUILD / 'inspect'
    empty_project.mkdir()
    run('release-content', [GODOT, '--headless', '--path', empty_project,
                           '--script', ROOT / 'tools/check_export.gd', '--', BUILD / 'web/index.pck'])
    shutil.rmtree(empty_project)
    native = BUILD / 'linux/depth.x86_64'
    native.chmod(0o755)
    run('linux-smoke', [native, '--headless', '--quit-after', '60'], timeout=60)
    if 'DEPTH_SURFACE_READY' not in (REPORT / 'linux-smoke.log').read_text():
        raise RuntimeError('Linux export did not reach the surface')
    manifest = {
        'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'source_status': subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).splitlines(),
        'godot': prerequisites(),
        'toolchain': {key: json.loads((ROOT / 'docs/toolchain-lock.json').read_text())[key]
                      for key in ('platform', 'gdunit', 'playwright', 'chromium')},
        'created_at_utc': datetime.now(timezone.utc).isoformat(),
        'export_presets_sha256': hashlib.sha256((ROOT / 'export_presets.cfg').read_bytes()).hexdigest(),
        'commands': [f'godot --headless --path . --export-release {p} build/{o}' for p, o in
                     [('Web', 'web/index.html'), ('Windows', 'windows/depth.exe'), ('Linux', 'linux/depth.x86_64')]],
        'sha256': {str(p.relative_to(BUILD)): hashlib.sha256(p.read_bytes()).hexdigest()
                   for p in sorted(BUILD.rglob('*')) if p.is_file()},
    }
    (BUILD / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')


def e2e():
    env = dict(os.environ, GODOT_WEB_DIR=str(BUILD / 'web'))
    run('web-e2e', [CLOUD / 'tools/browser/node_modules/.bin/playwright', 'test',
                    '--config', ROOT / 'tests/web/playwright.config.cjs'], timeout=300, env=env)
    result = json.loads((ROOT / 'reports/web/results.json').read_text())
    stats = result['stats']
    if stats['expected'] < 2 or any(stats[k] for k in ('unexpected', 'skipped', 'flaky')):
        raise RuntimeError('Web E2E did not pass: ' + repr(stats))
    return stats


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['check', 'unit', 'build', 'e2e', 'all'])
    parser.add_argument('--suite', default='res://tests', help='GdUnit4 suite or directory')
    args = parser.parse_args()
    os.chdir(ROOT)
    REPORT.mkdir(parents=True)
    (ROOT / 'reports/.gdignore').touch()
    result = {'godot': prerequisites(), 'run_id': RUN_ID}
    if args.command in ('all', 'check'):
        checks()
    elif args.command in ('unit', 'build'):
        run('import', [GODOT, '--headless', '--editor', '--path', ROOT, '--import'])
    if args.command in ('all', 'unit'):
        result['gdunit'] = unit(args.suite)
    if args.command in ('all', 'build'):
        build()
    if args.command in ('all', 'e2e'):
        result['web_e2e'] = e2e()
    (REPORT / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
    print('Validation complete:', REPORT, flush=True)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
