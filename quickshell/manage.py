#!/usr/bin/env python3
"""Install, run and check the CodexBar integration for Pond."""
import argparse
import contextlib
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import time

from integrate import IntegrationError, integrate_shell, integrate_sidebar

HERE = Path(__file__).resolve().parent
CHECKOUT = (HERE / "pond-shell/codexbar").is_dir()
PAYLOAD = HERE / "pond-shell" if CHECKOUT else HERE.parent
REPO = HERE.parent if CHECKOUT else None
LAUNCHER_MARKER = "# CodexBar Pond launcher"


def config_home():
    return Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))


def default_pond():
    return Path(os.environ.get("CODEXBAR_POND_DIR", str(config_home() / "quickshell/pond-shell")))


def sha(data):
    return hashlib.sha256(data).hexdigest()


def require_program(name):
    value = shutil.which(name)
    if not value:
        raise ValueError("Missing program: " + name)
    return value


def qs():
    return shutil.which("quickshell") or require_program("qs")


def host_files():
    return json.loads((PAYLOAD / "codexbar/host-files.json").read_text())


def validate_pond(pond, integration=False):
    required = host_files() + ["assets/settings.svg"]
    if integration:
        required += ["shell.qml", "Sidebar.qml"]
    missing = [name for name in required if not (pond / name).is_file()]
    if missing:
        raise ValueError("Pond is missing required files in " + str(pond) + ": " + ", ".join(missing)
                         + ". Install Pond first, or pass --pond-dir PATH.")


def safe_target(root, relative):
    relative = Path(relative)
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError("Invalid install path: " + str(relative))
    target = root / relative
    current = root
    for part in relative.parts:
        current = current / part
        if current.is_symlink():
            raise ValueError("Refusing to write through a symlink: " + str(current))
    if not target.resolve().is_relative_to(root):
        raise ValueError("Refusing to write through a symlink: " + str(target))
    return target


def atomic_write(target, data, mode=0o644):
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=target.parent, prefix="." + target.name + ".", delete=False) as stream:
            stream.write(data)
            temporary = Path(stream.name)
        temporary.chmod(mode)
        temporary.replace(target)
    finally:
        if temporary and temporary.exists():
            temporary.unlink()


def launcher(pond):
    runner = str(pond / "codexbar/manage.py")
    return ("#!/usr/bin/env python3\n" + LAUNCHER_MARKER + "\n"
            + "import os, runpy, sys\n"
            + "os.environ.setdefault('CODEXBAR_POND_DIR', " + repr(str(pond)) + ")\n"
            + "sys.path.insert(0, " + repr(str(pond / "codexbar")) + ")\n"
            + "runpy.run_path(" + repr(runner) + ", run_name='__main__')\n").encode()


def native_binary(args, pond):
    if args.native_binary:
        path = Path(args.native_binary).expanduser().resolve()
    elif not args.skip_build:
        subprocess.run([str(REPO / "scripts/build-native-cli.sh")], check=True)
        path = REPO / "plasmoid/contents/code/codexbar-plasmoid"
    else:
        candidates = [REPO / "plasmoid/contents/code/codexbar-plasmoid", pond / "codexbar/codexbar-plasmoid",
                      Path.home() / ".local/share/codexbar-plasmoid/bin/codexbar-plasmoid"]
        path = next((item for item in candidates if item.is_file()), None)
        if not path:
            raise ValueError("No built Linux helper found. Omit --skip-build or pass --native-binary PATH.")
    if not path.is_file() or not os.access(path, os.X_OK):
        raise ValueError("The Linux helper is not executable: " + str(path))
    return path


def payload_files():
    files = {}
    for path in (PAYLOAD / "codexbar").rglob("*"):
        if path.is_file() and "__pycache__" not in path.parts:
            files[path.relative_to(PAYLOAD)] = path.read_bytes()
    files[Path("codexbar-preview.qml")] = (PAYLOAD / "codexbar-preview.qml").read_bytes()
    files[Path("codexbar/manage.py")] = (HERE / "manage.py").read_bytes()
    files[Path("codexbar/integrate.py")] = (HERE / "integrate.py").read_bytes()
    files[Path("codexbar/README.md")] = (HERE / "README.md").read_bytes()
    return files


def install(args):
    if not CHECKOUT:
        raise ValueError("Run the install command from the Git checkout to update CodexBar.")
    pond = args.pond_dir.expanduser().resolve()
    bin_dir = args.bin_dir.expanduser().resolve()
    validate_pond(pond, integration=True)
    # Validate every host edit before building or writing anything.
    shell = integrate_shell((pond / "shell.qml").read_text())
    sidebar = integrate_sidebar((pond / "Sidebar.qml").read_text())
    target_launcher = bin_dir / "codexbar-pond"
    if target_launcher.exists() and LAUNCHER_MARKER not in target_launcher.read_text():
        raise ValueError("Refusing to replace an unrelated command: " + str(target_launcher))
    require_program("node")
    qs()
    if args.dry_run:
        print("Would install CodexBar in " + str(pond / "codexbar"))
        print("Would add validated hooks to Sidebar.qml and shell.qml.")
        print("Would install command " + str(target_launcher))
        print("Settings and credentials stay unchanged.")
        return
    native = native_binary(args, pond)
    roots = {"pond": pond, "bin": bin_dir}
    files = [("pond", str(name), data, 0o644) for name, data in payload_files().items()]
    files += [("pond", "codexbar/codexbar-plasmoid", native.read_bytes(), 0o755),
              ("pond", "shell.qml", shell.encode(), stat.S_IMODE((pond / "shell.qml").stat().st_mode)),
              ("pond", "Sidebar.qml", sidebar.encode(), stat.S_IMODE((pond / "Sidebar.qml").stat().st_mode)),
              ("bin", "codexbar-pond", launcher(pond), 0o755)]
    changed = []
    for root, relative, data, mode in files:
        target = safe_target(roots[root], relative)
        if target.is_symlink():
            raise ValueError("Refusing to replace a symlink: " + str(target))
        if target.exists() and target.read_bytes() == data and stat.S_IMODE(target.stat().st_mode) == mode:
            continue
        changed.append((root, relative, data, mode))
    if not changed:
        print("CodexBar is already up to date in " + str(pond))
        return
    state_home = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
    backup_root = state_home / "codexbar-plasmoid/quickshell/backups"
    backup_root.mkdir(parents=True, exist_ok=True, mode=0o700)
    backup = Path(tempfile.mkdtemp(prefix=datetime.datetime.now().strftime("%Y%m%d-%H%M%S-"), dir=backup_root))
    manifest = {"version": 1, "roots": {key: str(value) for key, value in roots.items()}, "files": []}
    for root, relative, data, mode in changed:
        target = safe_target(roots[root], relative)
        existed = target.exists()
        record = {"root": root, "path": relative, "existed": existed, "after": sha(data), "mode": mode}
        if existed:
            original = target.read_bytes()
            record["before"] = sha(original)
            record["before_mode"] = stat.S_IMODE(target.stat().st_mode)
            atomic_write(backup / "before" / root / relative, original, 0o600)
        manifest["files"].append(record)
    atomic_write(backup / "manifest.json", (json.dumps(manifest, indent=2) + "\n").encode(), 0o600)
    # A failed write restores this transaction's files. The backup remains available.
    applied = []
    try:
        for record, (_, _, data, mode) in zip(manifest["files"], changed):
            target = safe_target(roots[record["root"]], record["path"])
            if record["existed"] and (not target.exists() or sha(target.read_bytes()) != record["before"]):
                raise ValueError("File changed during installation: " + str(target))
            if not record["existed"] and target.exists():
                raise ValueError("File appeared during installation: " + str(target))
            atomic_write(target, data, mode)
            applied.append(record)
    except BaseException:
        for record in reversed(applied):
            target = safe_target(roots[record["root"]], record["path"])
            if sha(target.read_bytes()) != record["after"]:
                continue
            if record["existed"]:
                atomic_write(target, (backup / "before" / record["root"] / record["path"]).read_bytes(), record["before_mode"])
            else:
                target.unlink()
        raise
    print("Installed CodexBar in " + str(pond))
    print("Command: " + str(target_launcher))
    print("Backup: " + str(backup))
    print("Open settings: codexbar-pond settings")
    print("Start Pond if it is not running: codexbar-pond start")


def restore(args):
    backup = args.backup.expanduser().resolve()
    manifest = json.loads((backup / "manifest.json").read_text())
    if manifest.get("version") != 1 or set(manifest.get("roots", {})) != {"pond", "bin"}:
        raise ValueError("Unsupported backup manifest")
    roots = {key: Path(value) for key, value in manifest["roots"].items()}
    if any(not root.is_absolute() or root.resolve() != root for root in roots.values()):
        raise ValueError("An installation directory moved or became a symlink. Restore stopped.")
    for record in manifest["files"]:
        relative = Path(record["path"])
        if relative.is_absolute() or ".." in relative.parts or record["root"] not in roots:
            raise ValueError("Invalid backup path")
        target = safe_target(roots[record["root"]], relative)
        if target.is_symlink() or not target.is_file() or sha(target.read_bytes()) != record["after"]:
            raise ValueError("File changed since installation. Restore stopped: " + str(target))
        if record["existed"]:
            previous = backup / "before" / record["root"] / relative
            if sha(previous.read_bytes()) != record["before"]:
                raise ValueError("The backup is incomplete: " + str(previous))
    for record in reversed(manifest["files"]):
        target = safe_target(roots[record["root"]], record["path"])
        if record["existed"]:
            atomic_write(target, (backup / "before" / record["root"] / record["path"]).read_bytes(), record["before_mode"])
        else:
            target.unlink()
    print("Restored the files changed by installation. Settings were not changed.")


@contextlib.contextmanager
def preview_tree(pond):
    validate_pond(pond)
    with tempfile.TemporaryDirectory(prefix="codexbar-pond-") as temporary:
        stage = Path(temporary)
        for name in host_files():
            shutil.copy2(pond / name, stage / name)
        shutil.copytree(pond / "assets", stage / "assets")
        shutil.copytree(PAYLOAD / "codexbar", stage / "codexbar", ignore=shutil.ignore_patterns("__pycache__"))
        shutil.copy2(PAYLOAD / "codexbar-preview.qml", stage / "codexbar-preview.qml")
        yield stage


def virtual_status():
    result = subprocess.run([require_program("virt-shot"), "--status"], capture_output=True, text=True)
    return dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)


@contextlib.contextmanager
def virtual_session():
    state = virtual_status()
    owned = state.get("WAYLAND_DISPLAY") != "wayland-virt-shot"
    if owned:
        subprocess.run(["virt-shot", "--keep", "--no-wait-content"], check=True, stdout=subprocess.DEVNULL)
        state = virtual_status()
    try:
        if state.get("WAYLAND_DISPLAY") != "wayland-virt-shot" or not state.get("DBUS_SESSION_BUS_ADDRESS"):
            raise ValueError("The isolated KWin session did not start")
        yield dict(os.environ, WAYLAND_DISPLAY=state["WAYLAND_DISPLAY"],
                   DBUS_SESSION_BUS_ADDRESS=state["DBUS_SESSION_BUS_ADDRESS"], QT_QPA_PLATFORM="wayland")
    finally:
        if owned:
            subprocess.run(["virt-shot", "--stop"], check=False, stdout=subprocess.DEVNULL)


def check(args):
    require_program("node")
    qs()
    module = PAYLOAD / "codexbar"
    for test in ["model.test.mjs", "settings.test.mjs"]:
        subprocess.run(["node", str(module / "tests" / test)], check=True)
    subprocess.run([sys.executable, str(module / "tests/runtime.test.py")], check=True)
    if args.ui:
        with preview_tree(args.pond_dir.expanduser().resolve()) as stage, virtual_session() as env:
            env["CODEXBAR_QS_SOURCE"] = str(stage)
            subprocess.run([sys.executable, str(module / "tests/ui.test.py")], env=env, check=True)
    print("Quickshell checks passed.")


def preview(args):
    with preview_tree(args.pond_dir.expanduser().resolve()) as stage:
        command = [qs(), "-p", str(stage / "codexbar-preview.qml")]
        if args.virtual:
            if virtual_status().get("WAYLAND_DISPLAY") == "wayland-virt-shot":
                raise ValueError("An isolated session is already running. Stop it before creating a preview.")
            output = args.output.expanduser().resolve()
            output.parent.mkdir(parents=True, exist_ok=True)
            with virtual_session() as env:
                # virt-shot owns only this isolated session; no host window is opened.
                subprocess.run(["virt-shot", "--keep", "--settle", "1", "--out", str(output), "--", *command], env=env, check=True)
        else:
            subprocess.run(command, check=True)


def doctor(args):
    pond = args.pond_dir.expanduser().resolve()
    validate_pond(pond, integration=True)
    subprocess.run([qs(), "--version"], check=True)
    subprocess.run([require_program("node"), "--version"], check=True)
    print("Pond: " + str(pond))
    print("CodexBar: " + ("installed" if (pond / "codexbar/State.qml").is_file() else "not installed"))
    print("Settings: " + str(config_home() / "codexbar-plasmoid/config.json"))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ["install", "start", "toggle", "refresh", "settings", "preview", "check", "doctor"]:
        sub = commands.add_parser(name)
        sub.add_argument("--pond-dir", type=Path, default=default_pond(), help="Pond shell directory")
        if name == "install":
            sub.add_argument("--bin-dir", type=Path, default=Path.home() / ".local/bin")
            sub.add_argument("--native-binary", type=Path, help="use an existing Linux helper instead of building")
            sub.add_argument("--skip-build", action="store_true", help="use an existing built or installed Linux helper")
            sub.add_argument("--dry-run", action="store_true", help="validate the target and print planned actions")
        elif name == "preview":
            sub.add_argument("--virtual", action="store_true", help="capture in isolated KWin with no host window")
            sub.add_argument("--output", type=Path, default=Path("/tmp/codexbar-pond-preview.png"))
        elif name == "check":
            sub.add_argument("--ui", action="store_true", help="also run pointer and layout checks in isolated KWin")
    sub = commands.add_parser("restore", help="restore files from an install backup")
    sub.add_argument("backup", type=Path)
    args = parser.parse_args(argv or sys.argv[1:] or ["toggle"])
    if args.command == "install":
        install(args)
    elif args.command == "restore":
        restore(args)
    elif args.command == "check":
        check(args)
    elif args.command == "preview":
        preview(args)
    elif args.command == "doctor":
        doctor(args)
    else:
        pond = args.pond_dir.expanduser().resolve()
        validate_pond(pond, integration=True)
        if args.command == "start":
            subprocess.run([qs(), "--no-duplicate", "-p", str(pond / "shell.qml")], check=True)
        else:
            result = subprocess.run([qs(), "-p", str(pond / "shell.qml"), "ipc", "call", "codexbar", args.command])
            if result.returncode:
                raise ValueError("Pond did not accept the command. Start it with codexbar-pond start, or rerun the installer.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, IntegrationError, OSError, subprocess.SubprocessError) as error:
        print("codexbar-pond: " + str(error), file=sys.stderr)
        sys.exit(1)
