#!/usr/bin/env python3
"""Check hover, navigation and measured layouts in the virt-shot session."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

source = Path(os.environ.get("CODEXBAR_QS_SOURCE", Path(__file__).resolve().parents[2]))
status = subprocess.run(["virt-shot", "--status"], capture_output=True, text=True, check=True)
session = dict(line.split("=", 1) for line in status.stdout.splitlines() if "=" in line)
if session.get("WAYLAND_DISPLAY") != "wayland-virt-shot":
    raise SystemExit("Start an isolated session with: virt-shot --keep --no-wait-content")
with tempfile.TemporaryDirectory(prefix="codexbar-ui-test-") as temporary:
    base = Path(temporary)
    for name in json.loads((source / "codexbar/host-files.json").read_text()):
        shutil.copy2(source / name, base / name)
    shutil.copytree(source / "codexbar", base / "codexbar")
    shutil.copytree(source / "assets", base / "assets")
    template = (source / "codexbar-preview.qml").read_text()
    template = template.replace("import QtQuick", "import QtQuick\nimport QtTest", 1)
    template = template.replace("  id: root\n", '  id: root\n  TestCase { id: input; name: "CodexBarInput"; when: false }\n', 1)
    template = template.replace("    function focusRow() {", '''    function hoverRow() {
      function walk(node) {
        if ("gauges" in node) { input.mouseMove(node, 10, 10); return true; }
        for (const child of node.children || []) if (walk(child)) return true;
        return false;
      }
      walk(card);
    }
    function clickRow() {
      function walk(node) {
        if ("gauges" in node) { input.mouseClick(node, 10, 10); return true; }
        for (const child of node.children || []) if (walk(child)) return true;
        return false;
      }
      walk(card);
    }
    function clickSettings() {
      function walk(node) {
        if (node.objectName === "openSettings") { input.mouseClick(node, 16, 16); return true; }
        for (const child of node.children || []) if (walk(child)) return true;
        return false;
      }
      walk(drawer);
    }
    function focusRow() {''')
    config = base / "shell.qml"
    config.write_text(template)
    env = dict(os.environ, WAYLAND_DISPLAY=session["WAYLAND_DISPLAY"],
               DBUS_SESSION_BUS_ADDRESS=session["DBUS_SESSION_BUS_ADDRESS"], QT_QPA_PLATFORM="wayland",
               HOME=str(base), XDG_CONFIG_HOME=str(base / ".config"), XDG_CACHE_HOME=str(base / ".cache"))
    env.pop("DISPLAY", None)
    command = ["quickshell", "-p", str(config)]
    log_path = base / "ui.log"
    with log_path.open("w") as log:
        process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
        def call(method, *args):
            result = subprocess.run(command + ["ipc", "call", "review", method, *map(str, args)],
                                    env=env, capture_output=True, text=True, timeout=3)
            return result.stdout.strip()
        def wait_for(predicate, seconds=5):
            until = time.monotonic() + seconds
            value = None
            while time.monotonic() < until:
                if process.poll() is not None:
                    raise AssertionError(log_path.read_text())
                try:
                    value = json.loads(call("report"))
                    if predicate(value):
                        return value
                except (ValueError, subprocess.TimeoutExpired):
                    pass
                time.sleep(0.04)
            raise AssertionError(f"Timed out: {value}\n{log_path.read_text()}")
        def check_sections(report):
            windows = [item for item in report["pages"] if item.get("section") == "usageWindow"]
            assert len(windows) == 2, windows
            assert windows[1]["y"] >= windows[0]["y"] + windows[0]["height"] + 10, windows
            bars = next(item for item in report["pages"] if item.get("section") == "usageWindows")
            spend = next(item for item in report["pages"] if item.get("section") == "spendSection")
            assert spend["y"] >= bars["y"] + bars["height"] + 10, report
        try:
            wait_for(lambda report: len(report["tree"]) > 0)
            call("hoverRow")
            for _ in range(5):
                report = wait_for(lambda report: True)
                row = next(item for item in report["tree"] if "alpha" in item)
                assert row["alpha"] <= 0.05, row
                if row["alpha"] > 0:
                    assert row["background"].endswith("ffffff"), row
                time.sleep(0.04)
            print("ok - pointer hover stays translucent throughout the color animation")
            call("list")
            report = wait_for(lambda report: report["page"] == "drawer" and not report["transitioning"])
            check_sections(report)
            print("ok - dashboard reset captions and spend sections do not overlap")
            call("clickRow")
            report = wait_for(lambda report: report["page"] == "provider" and not report["transitioning"])
            check_sections(report)
            print("ok - pointer click opens a provider page with non-overlapping sections")
            call("list")
            wait_for(lambda report: report["page"] == "drawer" and not report["transitioning"])
            call("clickSettings")
            wait_for(lambda report: report["page"] == "settings" and not report["transitioning"])
            print("ok - the dashboard settings button opens the settings page")
            call("editProvider", 2)
            report = wait_for(lambda report: any(item.get("keyField") and item["masked"] for item in report["pages"]))
            print("ok - API provider setup has a masked credential field")
            errors = [line for line in log_path.read_text().splitlines()
                      if any(token in line for token in ("ERROR", "ReferenceError", "TypeError", "Binding loop"))]
            assert not errors, errors
        finally:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
