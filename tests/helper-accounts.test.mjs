import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {execFileSync, spawn} from "node:child_process";
import http from "node:http";
import test from "node:test";
import * as Accounts from "../plasmoid/contents/code/codexbar-accounts.mjs";

test("legacy account settings migrate without losing selected names", () => {
  assert.equal(Accounts.mode({account: "work@example.com"}), "selected");
  assert.deepEqual(Accounts.selected({account: "work@example.com"}), ["work@example.com"]);
  const config = Accounts.selection({account: "work@example.com"}, "selected");
  assert.deepEqual(config.accounts, ["work@example.com"]);
  const all = Accounts.selection(config, "all");
  assert.equal(Accounts.mode(all), "all");
  assert.deepEqual(Accounts.selection(all, "selected").accounts, config.accounts);
  assert.deepEqual(Accounts.names([" Work ", "work", "home", null]), ["Work", "home"]);
  assert.equal(Accounts.expand(Accounts.selection(config, "selected", []))[0]._accountSelectionError,
    "Select at least one account");
  assert.deepEqual(Accounts.candidates(config, [{provider: "codex", account: "masked", accountAnonymized: true}]),
    ["work@example.com"]);
});

for (const helper of ["plasmoid/contents/code/codexbar-plasmoid-helper.mjs",
  "quickshell/pond-shell/codexbar/codexbar-helper.mjs"]) {
  test(`${helper} applies each remote account profile after one provider fetch`, async () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), "codexbar-remote-accounts-"));
    let requests = 0;
    const server = http.createServer((request, response) => {
      requests++;
      response.setHeader("Content-Type", "application/json");
      response.end(JSON.stringify({ok: true, entries: ["home@example.com", "work@example.com"].map(account => ({
        provider: "grok", source: "remote", account, rows: [],
      }))}));
    });
    await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
    try {
      const run = configs => new Promise((resolve, reject) => {
        const pond = helper.startsWith("quickshell");
        const args = [path.resolve(helper), "--cli", "/bin/true", "--nativeCli", "/bin/true",
          "--provider", "all", "--cost", "false", "--auto-update", "false", "--status", "false",
          "--sync-url", `http://127.0.0.1:${server.address().port}`,
          ...(pond ? ["--providers-stdin", "true"] : ["--providers", JSON.stringify(configs)])];
        const child = spawn(process.execPath, args, {timeout: 15000, env: {...process.env, HOME: directory,
          XDG_CONFIG_HOME: path.join(directory, "config"), XDG_CACHE_HOME: path.join(directory, "cache")}});
        let output = "", error = "";
        child.stdout.on("data", value => { output += value; });
        child.stderr.on("data", value => { error += value; });
        child.on("error", reject);
        child.on("close", code => {
          if (code !== 0) { reject(new Error(error)); return; }
          try { resolve(JSON.parse(output)); } catch (error) { reject(error); }
        });
        child.stdin.end(pond ? JSON.stringify(configs) : "");
      });
      const base = {provider: "grok", source: "remote"};
      let result = await run([{...base, accountIndex: 1}, {...base, accountIndex: 2}]);
      assert.deepEqual(result.entries.map(entry => entry.account), ["home@example.com", "work@example.com"]);
      assert.equal(requests, 1);
      result = await run([{...base, accountIndex: 1}, {...base, accounts: ["work@example.com"]}]);
      assert.equal(result.entries.length, 2);
      assert.equal(requests, 2);
      result = await run([{...base, accountMode: "selected", accounts: []}, {...base, account: "work@example.com"}]);
      assert.equal(result.entries.length, 2);
      assert.ok(result.entries[0].error);
      assert.equal(result.entries[1].account, "work@example.com");
      result = await run([{...base, accountIndex: 1, profileName: "Home"},
        {...base, accountIndex: 2, profileName: "Work"}]);
      assert.deepEqual(result.entries.map(entry => entry.account), ["Home", "Work"]);
    } finally {
      await new Promise(resolve => server.close(resolve));
      fs.rmSync(directory, {recursive: true, force: true});
    }
  });
  test(`${helper} keeps selected accounts, errors and stable identities`, () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), "codexbar-accounts-"));
    try {
      const cli = path.join(directory, "cli.mjs");
      const capture = path.join(directory, "calls.jsonl");
      fs.writeFileSync(cli, `#!/usr/bin/env node
import fs from "node:fs";
const args = process.argv.slice(2);
fs.appendFileSync(${JSON.stringify(capture)}, JSON.stringify(args) + "\\n");
const provider = args[args.indexOf("--provider") + 1];
const source = args[args.indexOf("--source") + 1];
if (args[0] === "cost") {
  console.log(JSON.stringify([{provider: "grok", sessionCostUSD: 7, last30DaysCostUSD: 21}]));
  process.exit(0);
}
let names = ["home@example.com", "work@example.com"];
if (process.env.REVERSE_ACCOUNTS) names.reverse();
const payload = names.map(account => ({provider, source, account, usage: {primary: {usedPercent: 20}},
  ...(process.env.FAIL_ACCOUNT === account ? {error: {message: "Login expired"}} : {})}));
console.log(JSON.stringify(payload));
`, {mode: 0o700});
      const run = (configs, extraEnv = {}, anonymize = false, cost = false) => {
        const args = [path.resolve(helper), "--provider", "all", "--cli", cli, "--nativeCli", cli,
          "--timeout", "5", "--retry-attempts", "1", "--cost", String(cost), "--status", "false",
          "--auto-update", "false", "--anonymize-emails", String(anonymize), "--force", "true"];
        const pond = helper.startsWith("quickshell");
        args.push(...(pond ? ["--providers-stdin", "true"] : ["--providers", JSON.stringify(configs)]));
        return JSON.parse(execFileSync(process.execPath, args, {encoding: "utf8", timeout: 15000,
          input: pond ? JSON.stringify(configs) : undefined,
          env: {...process.env, HOME: directory, XDG_CONFIG_HOME: path.join(directory, "config"),
            XDG_CACHE_HOME: path.join(directory, "cache"), ...extraEnv}}));
      };
      const selected = {provider: "grok", source: "native", accounts: ["work@example.com"], accountMode: "selected"};
      const canonicalAll = run([{...selected, account: "work@example.com", allAccounts: true}]);
      assert.equal(canonicalAll.entries.length, 2);
      const maskedProfile = run([{provider: "grok", source: "native", profileName: "person@example.com"}], {}, true);
      assert.ok(!JSON.stringify(maskedProfile).includes("person@example.com"));
      const one = run([selected]);
      assert.deepEqual(one.entries.map(entry => entry.account), ["work@example.com"]);
      const both = run([{...selected, accounts: ["work@example.com", "home@example.com"]}]);
      assert.equal(both.entries.length, 2);
      const partial = run([{...selected, accounts: ["work@example.com", "home@example.com"]}],
        {FAIL_ACCOUNT: "work@example.com"});
      assert.equal(partial.entries.length, 2);
      assert.ok(partial.entries.find(entry => entry.account === "work@example.com").error);
      assert.equal(partial.entries.find(entry => entry.account === "home@example.com").error, null);
      const withCost = run([{...selected, accounts: ["work@example.com", "home@example.com"]}], {}, false, true);
      assert.equal(withCost.entries.filter(entry => entry.tokenUsage).length, 1);
      assert.equal(withCost.entries.reduce((sum, entry) => sum + (entry.tokenUsage?.sessionCostUSD || 0), 0), 7);
      assert.equal(withCost.entries.find(entry => entry.tokenUsage).tokenUsage.sessionLabel, "Provider today");
      const missing = run([{...selected, accounts: ["missing@example.com"]}]);
      assert.equal(missing.entries.length, 1);
      assert.ok(missing.entries[0].error);
      const empty = run([{...selected, accounts: []}]);
      assert.match(empty.entries[0].error.message, /Select at least one/);
      const all = {provider: "grok", source: "native", allAccounts: true};
      const ids = run([all]).entries.map(entry => entry.id).sort();
      assert.deepEqual(run([all], {REVERSE_ACCOUNTS: "1"}, true).entries.map(entry => entry.id).sort(), ids);
      const oauth = run([{...selected, provider: "claude", source: "oauth"}]);
      assert.deepEqual(oauth.entries.map(entry => entry.account), ["work@example.com"]);
      const profiles = run([{provider: "grok", source: "native", profileName: "Home", account: "home@example.com"},
        {provider: "grok", source: "native", profileName: "Work", account: "work@example.com"}]);
      assert.deepEqual(profiles.entries.map(entry => entry.account), ["Home", "Work"]);
      assert.equal(new Set(profiles.entries.map(entry => entry.id)).size, 2);
      const calls = fs.readFileSync(capture, "utf8").trim().split("\n").map(line => JSON.parse(line));
      assert.ok(calls.some(args => args.includes("--anonymize-emails") && args.includes("false")));
      assert.ok(calls.filter(args => args.includes("oauth")).every(args => !args.includes("--account")));
    } finally { fs.rmSync(directory, {recursive: true, force: true}); }
  });
}
