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
  test("provider appearance inherits defaults and keeps overrides separate", () => {
    const settings = {ringWidth: 2, ringGap: 1, showProviderIcon: true,
      providerAppearance: {codex: {ringWidth: 5, ringGap: 0, showProviderIcon: false}}};
    assert.deepEqual(Settings.appearance(settings, "codex"), {ringWidth: 5, ringGap: 0, showProviderIcon: false});
    assert.equal(Settings.appearance(settings, "claude").ringWidth, 2);
    settings.ringWidth = 3;
    assert.equal(Settings.appearance(settings, "claude").ringWidth, 3);
    assert.equal(Settings.appearance(settings, "codex").ringWidth, 5);
    Settings.appearance(settings, "codex").ringWidth = 1;
    assert.equal(settings.providerAppearance.codex.ringWidth, 5);
    delete settings.providerAppearance.codex;
    assert.deepEqual(Settings.appearance(settings, "codex"), Settings.appearance(settings, "claude"));
    for (const [configured, reported] of [["alibaba-coding-plan", "alibaba"], ["groqcloud", "groq"],
      ["abacusai", "abacus"], ["azure-openai", "azureopenai"]]) {
      settings.providerAppearance = {[configured]: {ringWidth: 5}};
      assert.equal(Settings.appearance(settings, reported).ringWidth, 5);
    }
  });
  test("provider appearance accepts only valid appearance fields", () => {
    const values = {cardBars: 6, ringSize: 44, ringWidth: 5, ringGap: 0, ringLayout: "nested",
      nestedRingWidth: "decreasing", showProviderIcon: false, showProviderName: false,
      showRingValues: false, showWindowLabels: false, showRingTrack: false, paceIndicatorStyle: "off"};
    Settings.validate({providerAppearance: {codex: values, claude: {}}});
    for (const invalid of [null, [], "nested", {unknown: {}}, {codex: null}, {codex: []},
      {codex: {ringWidth: 0}}, {codex: {ringGap: 5}}, {codex: {ringSize: 23}}, {codex: {cardBars: 7}},
      {codex: {showProviderIcon: "false"}}, {codex: {ringLayout: "invalid"}},
      {codex: {paceIndicatorStyle: "invalid"}}, {codex: {cliPath: "/tmp/cli"}}])
      assert.throws(() => Settings.validate({providerAppearance: invalid}));
    const result = save({patch: {providerAppearance: {codex: values}}});
    assert.equal(result.result.ok, true);
    assert.deepEqual(JSON.parse(fs.readFileSync(file)).providerAppearance.codex, values);
    assert.equal(save({patch: {providerAppearance: {}}}).result.ok, true);
    assert.deepEqual(JSON.parse(fs.readFileSync(file)).providerAppearance, {});
  });
  test("provider refresh and retry overrides validate and inherit global values", () => {
    for (const [key, min, max] of [["refreshIntervalSeconds", 60, 86400],
      ["providerRetryAttempts", 1, 4], ["failureCooldownSeconds", 30, 3600]]) {
      for (const value of [undefined, 0, min, max])
        Settings.validate({providerConfigs: [{...Settings.newProvider("opencode"), [key]: value}]});
      for (const value of [-1, min + 0.5, max + 1, String(min), null])
        assert.throws(() => Settings.validate({providerConfigs: [{...Settings.newProvider("opencode"), [key]: value}]}));
    }
    const settings = {refreshIntervalSeconds: 150, providerConfigs: [
      {...Settings.newProvider("opencode"), refreshIntervalSeconds: 600},
      {...Settings.newProvider("gemini"), refreshIntervalSeconds: 60, enabled: false}
    ]};
    assert.equal(Settings.refreshInterval(settings, []), 600);
    settings.providerConfigs[1].enabled = true;
    assert.equal(Settings.refreshInterval(settings, []), 60);
    settings.providerConfigs[1].refreshIntervalSeconds = 0;
    assert.equal(Settings.refreshInterval(settings, []), 150);
    assert.equal(Settings.refreshInterval({}, ["codex"]), 150);
  });
  test("OpenCode monthly limits retain zero percent and their reset time", () => {
    const cli = path.join(temporary, "monthly-cli.mjs");
    fs.writeFileSync(cli, `#!/usr/bin/env node
console.log(JSON.stringify([{provider: "opencode", source: "native", usage: {
  primary: {usedPercent: 0, windowMinutes: 300}, secondary: {usedPercent: 10, windowMinutes: 10080},
  tertiary: {usedPercent: 100, windowMinutes: 43200, resetsAt: "2026-11-02T13:14:20Z"}
}}]));
`, {mode: 0o700});
    const result = helper([Settings.newProvider("opencode")], ["--cli", cli, "--nativeCli", cli]);
    assert.equal(result.status, 0, result.stderr);
    const rows = JSON.parse(result.stdout).entries[0].rows;
    assert.equal(rows.length, 3);
    assert.deepEqual([rows[2].id, rows[2].title, rows[2].percentLeft, rows[2].resetsAt],
      ["tertiary", "Monthly Usage", 0, "2026-11-02T13:14:20Z"]);
  });
  test("providers keep separate refresh intervals, retry attempts and cooldowns", () => {
    const cli = path.join(temporary, "policy-cli.mjs");
    const calls = path.join(temporary, "policy-calls.json");
    const mode = path.join(temporary, "policy-fail");
    fs.writeFileSync(cli, `#!/usr/bin/env node
import fs from "node:fs";
const provider = process.argv[process.argv.indexOf("--provider") + 1];
const file = ${JSON.stringify(calls)};
const counts = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file)) : {};
counts[provider] = (counts[provider] || 0) + 1;
fs.writeFileSync(file, JSON.stringify(counts));
console.log(JSON.stringify([{provider, source: "api", ...(fs.existsSync(${JSON.stringify(mode)})
  ? {error: {message: "HTTP 503 Service Unavailable"}}
  : {usage: {primary: {usedPercent: 20, windowMinutes: 300}}})}]));
`, {mode: 0o700});
    const configs = [{...Settings.newProvider("openai"), refreshIntervalSeconds: 60, providerRetryAttempts: 1, failureCooldownSeconds: 30},
      {...Settings.newProvider("gemini"), refreshIntervalSeconds: 600, providerRetryAttempts: 3, failureCooldownSeconds: 60}];
    const flags = ["--cli", cli, "--cache-seconds", "0", "--retry-attempts", "4"];
    const run = extra => {
      const result = helper(configs, flags.concat(extra || []));
      assert.equal(result.status, 0, result.stderr);
      return JSON.parse(result.stdout);
    };
    run(); run();
    assert.deepEqual(JSON.parse(fs.readFileSync(calls)), {openai: 1, gemini: 1});
    const cache = path.join(env.XDG_CACHE_HOME, "codexbar-plasmoid/provider-cache");
    for (const file of fs.readdirSync(cache).filter(name => name.startsWith("pond-usage-") && !name.includes(".state."))) {
      const full = path.join(cache, file); const value = JSON.parse(fs.readFileSync(full));
      value.storedAt = Date.now() - 120000; fs.writeFileSync(full, JSON.stringify(value));
    }
    run();
    assert.deepEqual(JSON.parse(fs.readFileSync(calls)), {openai: 2, gemini: 1});
    run(["--force", "true"]);
    assert.deepEqual(JSON.parse(fs.readFileSync(calls)), {openai: 3, gemini: 2});
    fs.writeFileSync(mode, "fail");
    const stale = run(["--force", "true"]);
    assert.ok(stale.entries.every(entry => entry.stale));
    assert.deepEqual(JSON.parse(fs.readFileSync(calls)), {openai: 4, gemini: 5});
    const states = fs.readdirSync(cache).filter(name => name.startsWith("pond-usage-") && name.includes(".state."))
      .map(name => JSON.parse(fs.readFileSync(path.join(cache, name))));
    assert.ok(states.every(state => state.cooldownUntilMs - state.lastAttemptAt <= 30000));
    run(["--force", "true"]);
    assert.deepEqual(JSON.parse(fs.readFileSync(calls)), {openai: 5, gemini: 8});
    const capped = fs.readdirSync(cache).filter(name => name.startsWith("pond-usage-") && name.includes(".state."))
      .map(name => JSON.parse(fs.readFileSync(path.join(cache, name))))
      .map(state => state.cooldownUntilMs - state.lastAttemptAt).sort((a, b) => a - b);
    assert.deepEqual(capped, [30000, 60000]);
    run();
    assert.deepEqual(JSON.parse(fs.readFileSync(calls)), {openai: 5, gemini: 8});
    fs.unlinkSync(mode);
    // An inherited interval must still apply when the shell polls for a faster provider.
    const inherited = [{...Settings.newProvider("openai"), providerRetryAttempts: 1},
      {...Settings.newProvider("gemini"), refreshIntervalSeconds: 60}];
    for (let index = 0; index < 2; index++) {
      const result = helper(inherited, flags.concat(["--refresh-interval-seconds", "600"]));
      assert.equal(result.status, 0, result.stderr);
    }
    const before = JSON.parse(fs.readFileSync(calls));
    for (const file of fs.readdirSync(cache).filter(name => name.startsWith("pond-usage-") && !name.includes(".state."))) {
      const full = path.join(cache, file); const value = JSON.parse(fs.readFileSync(full));
      value.storedAt = Date.now() - 120000; fs.writeFileSync(full, JSON.stringify(value));
    }
    const result = helper(inherited, flags.concat(["--refresh-interval-seconds", "600"]));
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(fs.readFileSync(calls)), {...before, gemini: before.gemini + 1});
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
    const result = save({patch: {providerConfigs: [Object.assign(Settings.newProvider("openai"), {apiKey: "test-key", refreshIntervalSeconds: 600, providerRetryAttempts: 3, failureCooldownSeconds: 60})]}, base: {otherClient: {value: 7}}});
    assert.equal(result.result.ok, true);
    assert.equal(fs.statSync(file).mode & 0o777, 0o600);
    assert.equal(JSON.parse(fs.readFileSync(file)).otherClient.value, 7);
    assert.equal(JSON.parse(fs.readFileSync(file)).providerConfigs[0].refreshIntervalSeconds, 600);
    assert.equal(JSON.parse(fs.readFileSync(file)).providerConfigs[0].providerRetryAttempts, 3);
    assert.equal(JSON.parse(fs.readFileSync(file)).providerConfigs[0].failureCooldownSeconds, 60);
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
        "--provider", "antigravity", "--auth-action", action, "--account", "work@example.com", "--nativeCli", cli], {env, encoding: "utf8"});
      assert.equal(JSON.parse(result.stdout).ok, true, result.stderr);
      assert.deepEqual(JSON.parse(fs.readFileSync(capture)), action === "login"
        ? ["login", "--provider", "antigravity", "--timeout", "300"]
        : ["logout", "--provider", "antigravity", "--account", "work@example.com"]);
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
