"""Installer tests use disposable Pond files and an inert Linux helper."""
import argparse
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

SOURCE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SOURCE))
import integrate
import manage

SIDEBAR = '''import QtQuick
import Quickshell
PanelWindow {
  id: root
  readonly property bool panelOpen: wifiPanel.opened || audioPanel.opened || bluetoothPanel.opened
  readonly property var activePanel: wifiPanel.opened ? wifiPanel : audioPanel.opened ? audioPanel
      : bluetoothPanel.opened ? bluetoothPanel : null
  readonly property var panels: ({wifi: wifiPanel, audio: audioPanel, bluetooth: bluetoothPanel})
  property string custom: "keep this local change"
  function togglePopup(name) { popup = name; }
  Region {
    regions: [timeCard.blurRegion, notificationCard.blurRegion]
  }
  implicitWidth: Math.ceil(Math.max(Theme.sidebarOuterMargin + 156,
      wifiPanel.visible ? panelX + wifiPanel.width + 67 : 0,
      bluetoothPanel.visible ? panelX + bluetoothPanel.width + 67 : 0))
  mask: Region {
    width: Math.ceil(Math.max(root.cardWidth, mediaCard.width) + 8)
  }
  Column {
    id: mainStack
    Minimap.Map {
      id: workspacesCard
      maximumHeight: Math.max(64, bottomStack.y - timeCard.height
          - notificationCard.height - Theme.sidebarCardGap * 2)
    }
    Installs.SidebarCard { id: installsCard }
  }
  Column {
    id: bottomStack
  }
}
'''
SHELL = '''import QtQuick
import Quickshell
import Quickshell.Io
ShellRoot {
  property string localSetting: "preserve me"
  Variants { model: Quickshell.screens }
}
'''


class IntegrationTests(unittest.TestCase):
    def test_hooks_are_complete_idempotent_and_preserve_local_code(self):
        sidebar = integrate.integrate_sidebar(SIDEBAR)
        shell = integrate.integrate_shell(SHELL)
        self.assertEqual(integrate.integrate_sidebar(sidebar), sidebar)
        self.assertEqual(integrate.integrate_shell(shell), shell)
        self.assertIn('property string custom: "keep this local change"', sidebar)
        self.assertIn('property string localSetting: "preserve me"', shell)
        for token in ['id: codexbarCard', 'id: codexbarPanel', 'onSettingsRequested']:
            self.assertEqual(sidebar.count(token), 1)
        self.assertIn('codexbarCard.height - Theme.sidebarCardGap', sidebar)
        self.assertIn('function settings()', shell)

    def test_older_integration_gets_a_settings_output_predicate(self):
        sidebar = integrate.integrate_sidebar(SIDEBAR)
        sidebar = sidebar.replace('  readonly property bool codexbarCommandOutput: root.screen.name === (NiriMsg.focusedOutputName\n      || Quickshell.screens[0]?.name || "")\n', '')
        sidebar = sidebar.replace('    function onSettingsRequested() {\n      if (!root.codexbarCommandOutput) return;\n      if (!codexbarPanel.opened) root.togglePanel("codexbar");\n      codexbarPanel.openSettings();\n    }\n', '')
        adopted = integrate.integrate_sidebar(sidebar)
        self.assertEqual(adopted.count('property bool codexbarCommandOutput:'), 1)
        self.assertIn('onSettingsRequested', adopted)
        self.assertEqual(integrate.integrate_sidebar(adopted), adopted)

    def test_balancing_ignores_comments_and_quoted_braces(self):
        source = '({name: "}", nested: [1, 2] /* ) */}) tail'
        self.assertEqual(source[integrate.closing(source, 0)], ')')
        self.assertEqual(integrate.closing(source, 0), source.index(' tail') - 1)

    def test_unknown_host_layout_fails(self):
        with self.assertRaises(integrate.IntegrationError):
            integrate.integrate_sidebar(SIDEBAR.replace('maximumHeight:', 'differentHeight:'))


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='codexbar-install-test-')
        self.base = Path(self.temp.name)
        self.pond = self.base / "config/quickshell/pond's shell"
        self.pond.mkdir(parents=True)
        for name in manage.host_files():
            (self.pond / name).write_text('import QtQuick\nItem {}\n')
        (self.pond / 'assets').mkdir()
        (self.pond / 'assets/settings.svg').write_text('<svg/>')
        (self.pond / 'shell.qml').write_text(SHELL)
        (self.pond / 'Sidebar.qml').write_text(SIDEBAR)
        (self.pond / 'shell.qml').chmod(0o600)
        self.settings = self.base / 'config/codexbar-plasmoid/config.json'
        self.settings.parent.mkdir()
        self.private_settings = b'{"apiKey":"fixture-only","otherClient":true}\n'
        self.settings.write_bytes(self.private_settings)
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        fake_qs = self.bin / 'quickshell'
        fake_qs.write_text('#!/bin/sh\nprintf "fixture quickshell\\n"\n')
        fake_qs.chmod(0o755)
        self.native = self.base / 'native-helper'
        self.native.write_text('#!/bin/sh\nexit 0\n')
        self.native.chmod(0o755)
        self.args = argparse.Namespace(pond_dir=self.pond, bin_dir=self.bin, native_binary=self.native,
                                       skip_build=True, dry_run=False)
        self.environment = mock.patch.dict(os.environ, {
            'HOME': str(self.base), 'XDG_STATE_HOME': str(self.base / 'state'),
            'XDG_CONFIG_HOME': str(self.base / 'config'),
            'PATH': str(self.bin) + os.pathsep + os.environ['PATH'],
        })
        self.environment.start()
        self.output = io.StringIO()
        self.capture = contextlib.redirect_stdout(self.output)
        self.capture.__enter__()

    def tearDown(self):
        self.capture.__exit__(None, None, None)
        self.environment.stop()
        self.temp.cleanup()

    def backup(self):
        return next((self.base / 'state/codexbar-plasmoid/quickshell/backups').glob('*'))

    def test_install_update_restore_and_launcher(self):
        manage.install(self.args)
        self.assertEqual(self.settings.read_bytes(), self.private_settings)
        self.assertEqual((self.pond / 'shell.qml').stat().st_mode & 0o777, 0o600)
        support = self.pond / 'codexbar/codexbar-resilience.mjs'
        self.assertTrue(support.is_file())
        self.assertFalse(support.is_symlink())
        self.assertEqual(support.read_bytes(), (SOURCE / 'pond-shell/codexbar/codexbar-resilience.mjs').read_bytes())
        result = subprocess.run([str(self.bin / 'codexbar-pond'), 'doctor'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(str(self.pond), result.stdout)
        backup = self.backup()
        manage.install(self.args)
        self.assertIn('already up to date', self.output.getvalue())
        self.assertEqual(len(list(backup.parent.iterdir())), 1)
        manage.restore(argparse.Namespace(backup=backup))
        self.assertEqual((self.pond / 'shell.qml').read_text(), SHELL)
        self.assertEqual((self.pond / 'Sidebar.qml').read_text(), SIDEBAR)
        self.assertFalse((self.bin / 'codexbar-pond').exists())
        self.assertFalse(support.exists())
        self.assertEqual(self.settings.read_bytes(), self.private_settings)

    def test_restore_refuses_to_overwrite_newer_local_edits(self):
        manage.install(self.args)
        (self.pond / 'Sidebar.qml').write_text('new local changes')
        with self.assertRaisesRegex(ValueError, 'changed since installation'):
            manage.restore(argparse.Namespace(backup=self.backup()))
        self.assertTrue((self.bin / 'codexbar-pond').exists())
        self.assertEqual((self.pond / 'Sidebar.qml').read_text(), 'new local changes')

    def test_failed_write_rolls_back_files(self):
        original = manage.atomic_write
        count = 0
        def fail_once(*args, **kwargs):
            nonlocal count
            count += 1
            if count == 6:
                raise OSError('fixture write failure')
            return original(*args, **kwargs)
        with mock.patch.object(manage, 'atomic_write', side_effect=fail_once):
            with self.assertRaisesRegex(OSError, 'fixture write failure'):
                manage.install(self.args)
        self.assertEqual((self.pond / 'Sidebar.qml').read_text(), SIDEBAR)
        self.assertEqual((self.pond / 'shell.qml').read_text(), SHELL)
        self.assertFalse((self.bin / 'codexbar-pond').exists())
        self.assertEqual([p for p in (self.pond / 'codexbar').rglob('*') if p.is_file()], [])
        self.assertEqual(self.settings.read_bytes(), self.private_settings)

    def test_dry_run_does_not_write(self):
        self.args.dry_run = True
        manage.install(self.args)
        self.assertFalse((self.pond / 'codexbar').exists())
        self.assertFalse((self.base / 'state').exists())

    def test_unknown_layout_does_not_write(self):
        (self.pond / 'Sidebar.qml').write_text(SIDEBAR.replace('id: workspacesCard', 'id: renamedCard'))
        with self.assertRaises(integrate.IntegrationError):
            manage.install(self.args)
        self.assertFalse((self.pond / 'codexbar').exists())
        self.assertFalse((self.base / 'state').exists())

    def test_unrelated_launcher_is_preserved(self):
        (self.bin / 'codexbar-pond').write_text('an unrelated command')
        with self.assertRaisesRegex(ValueError, 'unrelated command'):
            manage.install(self.args)
        self.assertEqual((self.bin / 'codexbar-pond').read_text(), 'an unrelated command')

    def test_symlink_parent_cannot_write_outside_the_module(self):
        outside = self.base / 'outside'
        outside.mkdir()
        (self.pond / 'codexbar').mkdir()
        (self.pond / 'codexbar/assets').symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            manage.install(self.args)
        self.assertEqual(list(outside.iterdir()), [])
        self.assertEqual((self.pond / 'shell.qml').read_text(), SHELL)

    def test_internal_symlink_cannot_overwrite_host_assets(self):
        (self.pond / 'assets/refresh.svg').write_text('custom host icon')
        (self.pond / 'codexbar').mkdir()
        (self.pond / 'codexbar/assets').symlink_to(self.pond / 'assets', target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            manage.install(self.args)
        self.assertEqual((self.pond / 'assets/refresh.svg').read_text(), 'custom host icon')
        self.assertFalse((self.pond / 'codexbar/State.qml').exists())


if __name__ == '__main__':
    unittest.main()
