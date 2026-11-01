#!/usr/bin/env python3
"""Check State.qml with a fake helper and disposable profiles. No network."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

source = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="codexbar-state-test-") as tmp:
    base = Path(tmp)
    module = base / "codexbar"
    module.mkdir()
    for name in ("State.qml", "CodexBarModel.mjs", "CodexBarSettings.mjs", "settings-store.mjs"):
        shutil.copy2(source / name, module / name)
    (base / ".claude").mkdir()
    config = base / ".config/codexbar-plasmoid"
    config.mkdir(parents=True)
    (config / "config.json").write_text(json.dumps({"expandedRows": 0, "cost": False}))
    (module / "codexbar-helper.mjs").write_text(r'''import fs from "node:fs";
const home = process.env.HOME;
const control = JSON.parse(fs.readFileSync(home + "/control.json", "utf8"));
fs.appendFileSync(home + "/calls.jsonl", JSON.stringify(process.argv.slice(2)) + "\n");
setTimeout(() => {
  if (control.fail) { console.log("bad data"); process.exitCode = 1; return; }
  console.log(JSON.stringify({ok: true, generatedAt: new Date().toISOString(), entries: [
    {id: "codex", provider: "codex", rows: [{id: "primary", percentLeft: control.value, windowMinutes: 300}]}
  ]}));
}, control.delay || 0);
''')
    (base / "control.json").write_text('{"value":74}')
    (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "codexbar" as Codexbar
ShellRoot {
  Codexbar.State { id: usage; wanted: Quickshell.env("TEST_DEMAND") === "1" }
  IpcHandler {
    target: "test"
    function report(): string {
      return JSON.stringify({loaded: usage.loaded, running: usage.running, failed: usage.failed,
        now: usage.nowMs, error: usage.lastError, entries: usage.entries, providers: usage.detectedProviders(),
        rows: usage.expandedRows, path: usage.settingsPath, failures: usage.failures,
        saving: usage.savingSettings, saveError: usage.settingsSaveError, credits: usage.includeCredits});
    }
    function refresh() {
      for (const child of usage.resources)
        if (child.interval === 500) child.interval = (usage.timeoutSeconds + 90) * 1000;
      usage.refreshSoon(true);
    }
    function configuredArgs(): string {
      const previous = usage.settings;
      usage.settings = Object.assign({}, previous, {includeStatus: false, shareProviderFetches: false,
        refreshIntervalSeconds: 86400, timeoutSeconds: 300, costRefreshIntervalSeconds: 604800,
        providerRetryAttempts: 4, failureCooldownSeconds: 3600, costScanTimeoutSeconds: 1800});
      const args = usage.command(usage.options(false));
      usage.settings = previous;
      return JSON.stringify(args);
    }
    function discover() { usage.discoverAccounts({provider: "codex", source: "cli"}); }
    function save() { usage.saveSettings({credits: false}, usage.settings); }
    function staleSave() { usage.saveSettings({credits: true}, {}); }
    function timeout() {
      for (const child of usage.resources)
        if (child.interval === (usage.timeoutSeconds + 90) * 1000) child.interval = 500;
      usage.refresh(false);
    }
  }
}
''')
    env = dict(os.environ, HOME=str(base), XDG_CONFIG_HOME=str(base / ".config"),
               XDG_CACHE_HOME=str(base / ".cache"), QT_QPA_PLATFORM="offscreen", WAYLAND_DISPLAY="", DISPLAY="",
               CODEXBAR_POND_DEMO="", CODEXBAR_POND_GALLERY="")
    cmd = ["quickshell", "-p", str(base / "shell.qml")]
    log_path = base / "runtime.log"
    log = log_path.open("w+")
    proc = subprocess.Popen(cmd, env=env, stdout=log, stderr=subprocess.STDOUT)
    def ipc(method):
        result = subprocess.run(cmd + ["ipc", "call", "test", method], env=env,
                                capture_output=True, text=True, timeout=3)
        return result.stdout.strip()
    def wait_for(predicate, seconds=5):
        until = time.monotonic() + seconds
        last = None
        while time.monotonic() < until:
            if proc.poll() is not None:
                raise AssertionError(log_path.read_text())
            try:
                last = json.loads(ipc("report"))
                if predicate(last):
                    return last
            except (ValueError, subprocess.TimeoutExpired):
                pass
            time.sleep(0.04)
        raise AssertionError(f"Timed out: {last}\n{log_path.read_text()}")
    def control(**values):
        (base / "control.json").write_text(json.dumps(values))
    try:
        state = wait_for(lambda s: s["providers"] == ["codex", "claude"])
        assert state["now"] > 1_700_000_000_000, state
        assert state["rows"] == 0 and state["path"] == str(config / "config.json"), state
        assert not state["loaded"] and state["entries"] == [], state
        print("ok - real clock, settings, directory discovery and no demo data on startup")
        ipc("refresh")
        state = wait_for(lambda s: s["loaded"] and not s["running"])
        assert state["entries"][0]["rows"][0]["percentLeft"] == 74, state
        args = json.loads((base / "calls.jsonl").read_text().splitlines()[0])
        for flag, value in {"--status": "true", "--cache-seconds": "150", "--cost-cache-seconds": "3600",
                            "--retry-attempts": "2", "--cooldown-cap-seconds": "180", "--cost-timeout": "300"}.items():
            assert args[args.index(flag) + 1] == value, args
        args = json.loads(ipc("configuredArgs"))
        for flag, value in {"--status": "false", "--cache-seconds": "0", "--cost-cache-seconds": "604800",
                            "--timeout": "300", "--retry-attempts": "4", "--cooldown-cap-seconds": "3600",
                            "--cost-timeout": "1800"}.items():
            assert args[args.index(flag) + 1] == value, args
        print("ok - helper output updates usage and fetch controls reach helper arguments")
        control(fail=True)
        ipc("refresh")
        state = wait_for(lambda s: s["failed"] and not s["running"])
        assert state["entries"][0]["rows"][0]["percentLeft"] == 74 and state["failures"] == 1, state
        print("ok - a failed refresh retains usage and starts backoff")
        control(value=26, delay=150)
        ipc("refresh")
        wait_for(lambda s: s["running"])
        ipc("refresh")
        state = wait_for(lambda s: not s["running"] and not s["failed"])
        assert state["entries"][0]["rows"][0]["percentLeft"] == 26, state
        calls = (base / "calls.jsonl").read_text().splitlines()
        assert len(calls) == 4, calls
        print("ok - a refresh during a run queues one complete next run")
        control(value=1, delay=10000)
        ipc("timeout")
        state = wait_for(lambda s: s["failed"] and not s["running"])
        assert state["error"] == "CodexBar did not answer in time", state
        assert state["entries"][0]["rows"][0]["percentLeft"] == 26, state
        print("ok - timeout retains usage and reports one failed run")
        control(value=82)
        ipc("refresh")
        state = wait_for(lambda s: not s["failed"] and not s["running"])
        assert state["entries"][0]["rows"][0]["percentLeft"] == 82, state
        print("ok - refresh recovers after timeout")
        before = len((base / "calls.jsonl").read_text().splitlines())
        ipc("discover")
        deadline = time.monotonic() + 3
        while len((base / "calls.jsonl").read_text().splitlines()) == before and time.monotonic() < deadline:
            time.sleep(0.04)
        args = json.loads((base / "calls.jsonl").read_text().splitlines()[-1])
        assert args[args.index("--status") + 1] == "false", args
        print("ok - account discovery disables status requests")
        proc.terminate()
        proc.wait(timeout=3)
        env["TEST_DEMAND"] = "1"
        proc = subprocess.Popen(cmd, env=env, stdout=log, stderr=subprocess.STDOUT)
        state = wait_for(lambda s: s["loaded"] and not s["running"])
        assert state["entries"][0]["rows"][0]["percentLeft"] == 82, state
        print("ok - sidebar demand loads usage at startup without opening the drawer")
        proc.terminate()
        proc.wait(timeout=3)
        demo = module / "demo"
        demo.mkdir()
        (demo / "snapshot.json").write_text(json.dumps({"ok": True, "entries": [
            {"id": "demo", "provider": "codex", "rows": [{"percentLeft": 63}]}]}))
        env["CODEXBAR_POND_DEMO"] = "1"
        count = len((base / "calls.jsonl").read_text().splitlines())
        proc = subprocess.Popen(cmd, env=env, stdout=log, stderr=subprocess.STDOUT)
        state = wait_for(lambda s: s["loaded"])
        ipc("refresh")
        time.sleep(0.1)
        assert len((base / "calls.jsonl").read_text().splitlines()) == count
        assert state["entries"][0]["rows"][0]["percentLeft"] == 63, state
        print("ok - demo mode loads its fixture and never invokes the helper")
        ipc("save")
        state = wait_for(lambda s: not s["saving"] and not s["credits"])
        assert state["saveError"] == "", state
        assert json.loads((config / "config.json").read_text())["credits"] is False
        assert (config / "config.json").stat().st_mode & 0o777 == 0o600
        print("ok - QML saves settings through stdin with private permissions")
        ipc("staleSave")
        state = wait_for(lambda s: not s["saving"] and s["saveError"] != "")
        assert state["credits"] is False, state
        print("ok - a failed settings save keeps the applied values")
        errors = [line for line in log_path.read_text().splitlines()
                  if any(token in line for token in ("ERROR", "ReferenceError", "TypeError", "Binding loop"))]
        assert not errors, errors
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
        log.close()
