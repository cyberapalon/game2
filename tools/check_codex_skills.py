#!/usr/bin/env python3
"""Verify repository skills with Codex's real loader, without model calls."""
import argparse
import json
import os
from pathlib import Path
import queue
import shutil
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    "godot-gdscript",
    "godot-2d-gameplay",
    "godot-2d-art-animation",
    "godot-testing",
}


def verify():
    executable = shutil.which("codex")
    if not executable:
        raise RuntimeError("codex CLI is required; file enumeration is not a loader check")
    version = subprocess.check_output(
        [executable, "--version"], text=True, stderr=subprocess.DEVNULL, timeout=10
    ).strip()
    work = ROOT / "work"
    work.mkdir(exist_ok=True)
    # The prepared Cloud's usual Codex configuration directory is read-only.
    # Give this child an isolated configuration directory; preserve the parent
    # process environment and never copy user credentials into the probe.
    with tempfile.TemporaryDirectory(prefix="codex-skills-", dir=work) as task_config_dir, \
            (work / "codex-skills-stderr.log").open("w") as errors:
        task_environment = {**os.environ, "CODEX_HOME": task_config_dir}
        process = subprocess.Popen(
            [executable, "app-server", "--listen", "stdio://"],
            cwd=ROOT, env=task_environment, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=errors, text=True, bufsize=1,
        )
        messages = queue.Queue()

        def read_lines():
            for line in process.stdout:
                messages.put(line)
            messages.put(None)

        reader = threading.Thread(target=read_lines, daemon=True)
        reader.start()

        def send(message):
            process.stdin.write(json.dumps(message) + "\n")
            process.stdin.flush()

        def receive(request_id):
            deadline = time.monotonic() + 30
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise RuntimeError("Codex skills/list timed out")
                try:
                    line = messages.get(timeout=remaining)
                except queue.Empty as exc:
                    raise RuntimeError("Codex skills/list timed out") from exc
                if line is None:
                    raise RuntimeError("Codex app-server exited before its response")
                data = json.loads(line)
                if data.get("id") == request_id:
                    if "error" in data:
                        raise RuntimeError(f"Codex RPC failed: {data['error'].get('code')}")
                    return data["result"]

        try:
            send({"id": 1, "method": "initialize", "params": {
                "clientInfo": {"name": "godot-skill-check", "version": "1.0.0"}
            }})
            receive(1)
            send({"method": "initialized", "params": {}})
            send({"id": 2, "method": "skills/list", "params": {
                "cwds": [str(ROOT)], "forceReload": True
            }})
            result = receive(2)
        finally:
            process.stdin.close()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
            reader.join(timeout=1)

    entry = next((item for item in result["data"] if item["cwd"] == str(ROOT)), None)
    if entry is None:
        raise RuntimeError("Codex did not return the requested repository")
    if entry.get("errors"):
        raise RuntimeError(f"Codex reported {len(entry['errors'])} skill loading error(s)")
    skill_root = ROOT / ".agents" / "skills"
    local = [s for s in entry["skills"] if Path(s["path"]).is_relative_to(skill_root)]
    if len(local) != len(EXPECTED) or {s["name"] for s in local} != EXPECTED:
        raise RuntimeError("Repository skills missing, duplicated, or unexpectedly added")
    for skill in local:
        expected_path = skill_root / skill["name"] / "SKILL.md"
        if (Path(skill["path"]) != expected_path or skill["scope"] != "repo"
                or not skill["enabled"] or not skill["description"]):
            raise RuntimeError(f"Incorrect metadata or disabled skill: {skill['name']}")
    return {
        "codex_version": version,
        "method": "skills/list",
        "force_reload": True,
        "isolated_child_config": True,
        "model_turn_started": False,
        "cwd": str(ROOT),
        "skills": [{k: s[k] for k in ("name", "path", "scope", "enabled")}
                   for s in sorted(local, key=lambda s: s["name"])],
        "errors": [],
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Optional JSON evidence path")
    args = parser.parse_args()
    try:
        evidence = verify()
    except (RuntimeError, OSError, ValueError, subprocess.SubprocessError) as exc:
        raise SystemExit(str(exc)) from exc
    output = json.dumps(evidence, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output, encoding="utf-8")
    print(output, end="")
