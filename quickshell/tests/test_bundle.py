"""Offline checks for the paths used by a new install."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1] / 'pond-shell/codexbar'


class BundleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='codexbar-bundle-test-')
        self.base = Path(self.temp.name)
        self.module = self.base / 'module'
        self.module.mkdir()
        for name in ['codexbar-helper.mjs', 'codexbar-resilience.mjs']:
            shutil.copy2(MODULE / name, self.module / name)
        self.env = dict(os.environ, HOME=str(self.base), CODEXBAR_CLI='codexbar', CODEXBAR_NATIVE_CLI='',
                        XDG_CONFIG_HOME=str(self.base / 'config'), XDG_CACHE_HOME=str(self.base / 'cache'))

    def tearDown(self):
        self.temp.cleanup()

    def helper(self, args, stdin=None):
        result = subprocess.run(['node', str(self.module / 'codexbar-helper.mjs'), *args], env=self.env,
                                input=stdin, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_opt_in_update_can_bootstrap_a_missing_managed_cli(self):
        fake_cli = '#!/usr/bin/env node\nconsole.log(JSON.stringify([{provider:"openai",usage:{primary:{usedPercent:40}}}]));\n'
        updater = '''import fs from "node:fs";
import path from "node:path";
export async function updateIfNeeded(options) {
  fs.mkdirSync(options.targetDir, {recursive:true});
  fs.writeFileSync(path.join(options.targetDir,"codexbar"), %s, {mode:0o700});
  return {ok:true,updated:true};
}
''' % json.dumps(fake_cli)
        (self.module / 'codexbar-cli-updater.mjs').write_text(updater)
        snapshot = self.helper(['--providers-stdin', 'true', '--auto-update', 'true', '--cost', 'false', '--status', 'false'],
                               json.dumps([{'provider': 'openai', 'source': 'api'}]))
        self.assertTrue(snapshot['ok'], snapshot)
        self.assertTrue(snapshot['cliUpdate']['updated'])
        self.assertEqual(snapshot['entries'][0]['rows'][0]['percentLeft'], 60)

    def test_the_bundled_native_helper_precedes_an_old_managed_copy(self):
        marker = self.base / 'selected.txt'
        for path, label in [(self.module / 'codexbar-plasmoid', 'bundled'),
                            (self.base / '.local/share/codexbar-plasmoid/bin/codexbar-plasmoid', 'old')]:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('#!/usr/bin/env node\nrequire("node:fs").writeFileSync(' + json.dumps(str(marker)) + ',' + json.dumps(label) + ');\n')
            path.chmod(0o700)
        result = self.helper(['--provider', 'antigravity', '--auth-action', 'logout'])
        self.assertTrue(result['ok'], result)
        self.assertEqual(marker.read_text(), 'bundled')
