import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {spawnSync} from "node:child_process";
import {fileURLToPath} from "node:url";
import * as Settings from "../CodexBarSettings.mjs";
import * as RingLayout from "../RingLayout.mjs";

const source = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "codexbar-settings-test-"));
const env = Object.assign({}, process.env, {HOME: temporary, XDG_CONFIG_HOME: path.join(temporary, ".config"),
  XDG_CACHE_HOME: path.join(temporary, ".cache"), OPENAI_API_KEY: "old-environment-key", ANTHROPIC_ADMIN_KEY: "old-admin-key", DEEPGRAM_API_KEY: "old-deepgram-key"});
let passed = 0;
function test(name, body) { body(); passed++; console.log("ok - " + name); }
const file = path.join(temporary, ".config/codexbar-plasmoid/config.json");
function save(request) {
  const result = spawnSync(process.execPath, [path.join(source, "settings-store.mjs"), file],
    {env, input: JSON.stringify(request), encoding: "utf8"});
  return {status: result.status, result: JSON.parse(result.stdout)};
}
function helper(input, extra = []) {
  return spawnSync(process.execPath, [path.join(source, "codexbar-helper.mjs"),
    "--provider", "all", "--providers-stdin", "true", "--cost", "false", "--status", "false",
    "--auto-update", "false", "--timeout", "5", ...extra],
    {env, input: typeof input === "string" ? input : JSON.stringify(input), encoding: "utf8", timeout: 8000});
}
try {
  test("catalog keeps KDE Linux sources and explicit empty provider lists", () => {
    assert.equal(Settings.catalog.length, 47);
    assert.equal(Settings.newProvider("grok").source, "native");
    assert.equal(Settings.newProvider("codex").source, "cli");
    assert.deepEqual(Settings.providerRows({providerConfigs: []}, ["codex"]), []);
    assert.deepEqual(Settings.providerRows({providers: ["claude"]}, ["codex"]).map(r => r.provider), ["claude"]);
    assert.throws(() => Settings.validate({refreshIntervalSeconds: 1}));
    assert.throws(() => Settings.validate({providerConfigs: [{provider: "cli", source: "auto"}]}));
  });
  test("fetch controls accept bounds and reject invalid settings", () => {
    for (const [key, min, max] of [["refreshIntervalSeconds",60,86400], ["timeoutSeconds",5,300],
      ["costRefreshIntervalSeconds",300,604800], ["providerRetryAttempts",1,4],
      ["failureCooldownSeconds",30,3600], ["costScanTimeoutSeconds",60,1800]]) {
      for (const value of [min, max]) assert.equal(Settings.validate({[key]: value})[key], value);
      for (const value of [min - 1, max + 1, min + 0.5, String(min), null])
        assert.throws(() => Settings.validate({[key]: value}), key + " " + value);
    }
    for (const key of ["includeStatus", "shareProviderFetches"]) {
      for (const value of [true, false]) assert.equal(Settings.validate({[key]: value})[key], value);
      for (const value of [0, 1, "false", null]) assert.throws(() => Settings.validate({[key]: value}));
    }
    for (const value of ["position", "bar", "provider", "theme", "gaps", "off"])
      assert.equal(Settings.validate({paceIndicatorStyle: value}).paceIndicatorStyle, value);
    for (const value of ["unknown", "", null, true])
      assert.throws(() => Settings.validate({paceIndicatorStyle: value}));
  });
  test("ring settings validate types, bounds and layout choices", () => {
    for (const [key, min, max] of [["ringSize", 24, 44], ["ringWidth", 1, 5], ["ringGap", 0, 4]]) {
      for (const value of [min, max]) assert.equal(Settings.validate({[key]: value})[key], value);
      for (const value of [min - 1, max + 1, min + 0.5, String(min), null])
        assert.throws(() => Settings.validate({[key]: value}));
    }
    for (const [key, values] of [["ringLayout", ["separate", "nested"]], ["nestedRingWidth", ["equal", "decreasing"]]]) {
      for (const value of values) assert.equal(Settings.validate({[key]: value})[key], value);
      for (const value of ["invalid", "", null, true]) assert.throws(() => Settings.validate({[key]: value}));
    }
    for (const key of ["showProviderIcon", "showProviderName", "showRingValues", "showWindowLabels", "showRingTrack"]) {
      for (const value of [true, false]) assert.equal(Settings.validate({[key]: value})[key], value);
      for (const value of [0, "false", null]) assert.throws(() => Settings.validate({[key]: value}));
    }
  });
  test("nested rings fit the center with equal or decreasing widths and no overlap", () => {
    assert.equal(RingLayout.diameter({}), 28);
    assert.equal(RingLayout.diameter({ringLayout: "nested"}), 40);
    assert.deepEqual(RingLayout.nestedRings(0, 40, 2, 1, "equal", 16), []);
    for (const size of [24, 28, 40, 44]) for (const count of [1, 2, 3, 4, 5, 6])
      for (const width of [1, 2, 5]) for (const gap of [0, 1, 4])
        for (const style of ["equal", "decreasing"]) for (const center of [2, 14, 16]) {
          const rings = RingLayout.nestedRings(count, size, width, gap, style, center);
          assert.equal(rings.length, count);
          assert.ok(rings.every(ring => ring.size > 0 && ring.stroke > 0));
          assert.ok(rings[0].size <= size);
          assert.ok(rings.at(-1).size - 2 * rings.at(-1).stroke >= center - 1e-9);
          for (let i = 1; i < count; i++) {
            assert.ok(rings[i].size <= rings[i - 1].size - 2 * rings[i - 1].stroke + 1e-9);
            if (style === "equal") assert.equal(rings[i].stroke, rings[0].stroke);
            else assert.ok(rings[i].stroke < rings[i - 1].stroke);
          }
        }
  });
  test("settings save atomically with private permissions and retain unknown keys", () => {
    fs.mkdirSync(path.dirname(file), {recursive: true});
    fs.writeFileSync(file, JSON.stringify({otherClient: {value: 7}}));
    const result = save({patch: {providerConfigs: [Object.assign(Settings.newProvider("openai"), {apiKey: "test-key"})]}, base: {otherClient: {value: 7}}});
    assert.equal(result.result.ok, true);
    assert.equal(fs.statSync(file).mode & 0o777, 0o600);
    assert.equal(JSON.parse(fs.readFileSync(file)).otherClient.value, 7);
    assert.deepEqual(fs.readdirSync(path.dirname(file)), ["config.json"]);
    assert.ok(!JSON.stringify(result).includes("test-key"));
  });
  test("an external edit prevents stale settings from overwriting the file", () => {
    const original = fs.readFileSync(file, "utf8");
    const result = save({patch: {credits: false}, base: {}});
    assert.equal(result.result.ok, false);
    assert.equal(fs.readFileSync(file, "utf8"), original);
    fs.writeFileSync(file, "{broken");
    assert.equal(save({patch: {credits: false}}).result.ok, false);
    assert.equal(fs.readFileSync(file, "utf8"), "{broken");
  });
  test("all-disabled providers do no CLI work even with an invalid CLI path", () => {
    const result = helper([{provider: "codex", enabled: false}], ["--cli", "/missing-cli"]);
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout).entries, []);
    assert.equal(JSON.parse(result.stdout).ok, true);
  });
  test("invalid stdin is an error instead of provider auto-detection", () => {
    for (const input of ["{broken", "{}", "null"]) {
      const result = helper(input);
      assert.equal(JSON.parse(result.stdout).ok, false);
    }
  });
  test("the selected key reaches the CLI environment and stays out of argv", () => {
    const cli = path.join(temporary, "fake-cli.mjs");
    const capture = path.join(temporary, "captured.json");
    fs.writeFileSync(cli, `#!/usr/bin/env node
import fs from "node:fs";
fs.writeFileSync(${JSON.stringify(capture)}, JSON.stringify({args: process.argv, key: process.env[({openai: "OPENAI_API_KEY", claude: "ANTHROPIC_ADMIN_KEY", deepgram: "DEEPGRAM_API_KEY"})[process.argv[process.argv.indexOf("--provider") + 1]]]}));
console.log(JSON.stringify([{provider: process.argv[process.argv.indexOf("--provider") + 1], usage: {primary: {usedPercent: 26, windowMinutes: 300}}}]));
`, {mode: 0o700});
    for (const provider of ["openai", "claude", "deepgram"]) {
    const config = Object.assign(Settings.newProvider(provider), {source: "api", apiKey: "selected-test-key"});
    const result = helper([config], ["--cli", cli, "--nativeCli", cli]);
    assert.equal(result.status, 0, result.stderr);
    const captured = JSON.parse(fs.readFileSync(capture));
    assert.equal(captured.key, "selected-test-key");
    assert.ok(!JSON.stringify(captured.args).includes("selected-test-key"));
    assert.ok(!result.stdout.includes("selected-test-key") && !result.stderr.includes("selected-test-key"));
    assert.equal(JSON.parse(result.stdout).entries[0].rows[0].percentLeft, 74);
    }
  });
  test("Antigravity auth delegates only the requested action to the native CLI", () => {
    const capture = path.join(temporary, "auth-args.json");
    const cli = path.join(temporary, "fake-auth.mjs");
    fs.writeFileSync(cli, `#!/usr/bin/env node
import fs from "node:fs";
fs.writeFileSync(${JSON.stringify(capture)}, JSON.stringify(process.argv.slice(2)));
`, {mode: 0o700});
    for (const action of ["login", "logout"]) {
      const result = spawnSync(process.execPath, [path.join(source, "codexbar-helper.mjs"),
        "--provider", "antigravity", "--auth-action", action, "--nativeCli", cli], {env, encoding: "utf8"});
      assert.equal(JSON.parse(result.stdout).ok, true, result.stderr);
      assert.deepEqual(JSON.parse(fs.readFileSync(capture)), action === "login"
        ? ["login", "--provider", "antigravity", "--timeout", "300"]
        : ["logout", "--provider", "antigravity", "--all"]);
    }
  });
  test("the detached cost worker receives the same provider list through stdin", () => {
    const capture = path.join(temporary, "worker-args.jsonl");
    const cli = path.join(temporary, "fake-cost.mjs");
    fs.writeFileSync(cli, `#!/usr/bin/env node
import fs from "node:fs";
fs.appendFileSync(${JSON.stringify(capture)}, JSON.stringify(process.argv.slice(2)) + "\\n");
console.log(JSON.stringify([{provider: "claude", usage: {primary: {usedPercent: 5}}, totals: {costUSD: 1}, daily: []}]));
`, {mode: 0o700});
    const result = helper([Settings.newProvider("claude")], ["--cli", cli, "--nativeCli", cli,
      "--cost", "true", "--cache-seconds", "60", "--cost-cache-seconds", "3600"]);
    assert.equal(JSON.parse(result.stdout).ok, true, result.stderr);
    const deadline = Date.now() + 5000;
    let calls = [];
    while (Date.now() < deadline) {
      calls = fs.existsSync(capture) ? fs.readFileSync(capture, "utf8").trim().split("\n").filter(Boolean).map(JSON.parse) : [];
      if (calls.some(args => args[0] === "cost")) break;
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 40);
    }
    assert.ok(calls.some(args => args[0] === "cost" && args.includes("claude")), calls);
  });
  console.log("\n" + passed + " settings checks passed");
} finally {
  fs.rmSync(temporary, {recursive: true, force: true});
}
