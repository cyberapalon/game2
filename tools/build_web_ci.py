#!/usr/bin/env python3
"""Build the Pages artifact with the engine and templates pinned by this repo."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ENGINE_ERRORS = re.compile(r'SCRIPT ERROR:|Parse Error:|^ERROR:', re.M)


def checked_run(args, *, cwd, env, timeout=240):
    result = subprocess.run([str(arg) for arg in args], cwd=cwd, env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, timeout=timeout)
    print(result.stdout, end='', flush=True)
    if result.returncode or ENGINE_ERRORS.search(result.stdout):
        raise RuntimeError(f'Godot command failed: exit {result.returncode}')
    return result.stdout


def archive_file(directory, name, url, expected_sha512):
    directory.mkdir(parents=True, exist_ok=True)
    target = directory / name
    if not target.exists():
        print('Download ' + name, flush=True)
        temporary = target.with_suffix(target.suffix + '.partial')
        with urllib.request.urlopen(url, timeout=120) as response, temporary.open('wb') as output:
            shutil.copyfileobj(response, output, length=1024 * 1024)
        temporary.replace(target)
    with target.open('rb') as archive:
        digest = hashlib.file_digest(archive, 'sha512').hexdigest()
    if digest != expected_sha512:
        raise RuntimeError('Pinned archive checksum mismatch: ' + name)
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project-dir', type=Path, default=ROOT)
    parser.add_argument('--tool-dir', type=Path, default=ROOT / 'work/pages-toolchain')
    parser.add_argument('--archive-dir', type=Path)
    parser.add_argument('--output-dir', type=Path, default=ROOT / 'build/pages')
    args = parser.parse_args()
    project = args.project_dir.resolve()
    tools = args.tool_dir.resolve()
    output = args.output_dir.resolve()
    if output == project or output in project.parents or output == tools or output in tools.parents:
        raise RuntimeError('Output must be a dedicated build directory')
    lock = json.loads((project / 'docs/toolchain-lock.json').read_text())['godot']
    version = lock['version'].split('.stable.')[0]
    release = lock['release'].replace('/tag/', '/download/')
    downloads = (args.archive_dir or tools / 'downloads').resolve()
    engine_name = f'Godot_v{version}-stable_linux.x86_64'
    engine_archive = archive_file(downloads, engine_name + '.zip',
                                  release + '/' + engine_name + '.zip',
                                  lock['binary_archive_sha512'])
    templates_name = f'Godot_v{version}-stable_export_templates.tpz'
    templates = archive_file(downloads, templates_name, release + '/' + templates_name,
                             lock['templates_archive_sha512'])
    tools.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(engine_archive) as archive:
        with archive.open(engine_name) as source, (tools / 'godot').open('wb') as target:
            shutil.copyfileobj(source, target)
    engine = tools / 'godot'
    engine.chmod(0o755)
    template_dir = tools / 'data/godot/export_templates' / lock['templates']
    template_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(templates) as archive:
        # Pages uses the existing non-threaded, non-GDExtension release preset.
        for name in ['version.txt', 'web_nothreads_release.zip']:
            with archive.open('templates/' + name) as source, (template_dir / name).open('wb') as target:
                shutil.copyfileobj(source, target)
    env = dict(os.environ, XDG_DATA_HOME=str(tools / 'data'),
               XDG_CACHE_HOME=str(tools / 'cache'), XDG_CONFIG_HOME=str(tools / 'config'))
    actual_version = checked_run([engine, '--version'], cwd=project, env=env).strip()
    if actual_version != lock['version']:
        raise RuntimeError('Engine version differs from toolchain-lock.json')
    shutil.rmtree(output, ignore_errors=True)
    output.mkdir(parents=True)
    checked_run([engine, '--headless', '--editor', '--path', project, '--import'], cwd=project, env=env)
    checked_run([engine, '--headless', '--path', project, '--export-release', 'Web', output / 'index.html'],
                cwd=project, env=env)
    inspector = tools / 'inspect'
    inspector.mkdir(exist_ok=True)
    checked_run([engine, '--headless', '--path', inspector, '--script', project / 'tools/check_export.gd',
                 '--', output / 'index.pck'], cwd=inspector, env=env)
    if not (output / 'index.wasm').read_bytes().startswith(b'\x00asm'):
        raise RuntimeError('Invalid WebAssembly output')
    if 'const GODOT_THREADS_ENABLED = false' not in (output / 'index.html').read_text():
        raise RuntimeError('GitHub Pages requires the existing single-thread Web preset')
    html = output / 'index.html'
    html.write_text(html.read_text().replace('</title>', '</title>\n\t\t<link rel="icon" type="image/png" href="./index.png">', 1))
    (output / '.nojekyll').touch()
    metadata = {
        'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=project, text=True).strip(),
        'godot': actual_version,
        'preset': 'Web',
        'sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                   for p in sorted(output.iterdir()) if p.is_file()},
    }
    (output / 'build-info.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print('Pages artifact ready: ' + str(output), flush=True)


if __name__ == '__main__':
    main()
