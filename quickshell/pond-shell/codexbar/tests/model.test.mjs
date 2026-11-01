// Tests for CodexBarModel.mjs. The bundled snapshots are synthetic.
//
// Inputs copy the shapes the helper emits (see the plasmoid's contract doc):
// percentLeft is remaining, rows may be empty, errors carry only a message,
// dailyUsage is 30 padded days. The demo uses fixed test values.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import * as Model from "../CodexBarModel.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const demo = JSON.parse(readFileSync(path.join(here, "../demo/snapshot.json"), "utf8"));
const theme = { ink: "#FFFFFF", yellow: "#EBE075", red: "#FA6D80", track: "#303030" };
const now = Date.parse(demo.generatedAt);

let passed = 0;
function test(name, body) {
  body();
  passed += 1;
  console.log(`ok ${passed} - ${name}`);
}

const entry = (extra) => Object.assign({
  provider: "codex", account: null, plan: null, source: "cli", rows: [],
  creditsRemaining: null, limitResetCredits: null, tokenUsage: null,
  dailyUsage: [], error: null, stale: false, status: null,
}, extra);

test("headline uses the lowest remaining percent", () => {
  const item = entry({ rows: [{ percentLeft: 62 }, { percentLeft: 18 }] });
  assert.deepEqual(Model.headline(item), { kind: "percent", value: 18, text: "18%" });
});

test("headline ignores rows without a numeric percent", () => {
  const item = entry({ rows: [{ percentLeft: null }, { percentLeft: "44" }] });
  assert.equal(Model.headline(item).text, "44%");
});

test("headline falls back to reset credits, then credits, then spend", () => {
  assert.equal(Model.headline(entry({ limitResetCredits: { availableCount: 2 } })).text, "2 resets");
  assert.equal(Model.headline(entry({ creditsRemaining: 0 })).text, "0");
  assert.equal(Model.headline(entry({ tokenUsage: { sessionCostUSD: 1.5, last30DaysCostUSD: 9 } })).text, "$1.50");
});

test("an error without rows is error-only, rich errors with spend are not", () => {
  const bare = entry({ error: { message: "boom" } });
  assert.equal(Model.isErrorOnly(bare), true);
  const withSpend = entry({ error: { message: "boom" }, tokenUsage: { last30DaysCostUSD: 4 } });
  assert.equal(Model.isErrorOnly(withSpend), false);
});

test("rank puts the tightest provider first and failed providers last", () => {
  const ranked = Model.rank(demo.entries).map((item) => item.provider);
  assert.deepEqual(ranked.slice(0, 4), ["codex", "claude", "antigravity", "grok"]);
  assert.deepEqual(ranked.slice(-3), ["cursor", "jetbrains", "opencode"]);
});

test("compact label names the lead provider with its number", () => {
  assert.equal(Model.compactLabel(Model.lead(demo.entries)), "Codex 18%");
});

test("bar colour: ink when comfortable, yellow when tight, red when it runs dry", () => {
  assert.equal(Model.barColor({ percentLeft: 90, pace: null }, theme), Model.percentColor(90, theme));
  assert.equal(Model.barColor({ percentLeft: 90, pace: null }, theme), "#fbf8e0");
  assert.equal(Model.barColor({ percentLeft: 40, pace: { willLastToReset: true, deltaPercent: -5, expectedUsedPercent: 50 } }, theme), "#EBE075");
  assert.equal(Model.barColor({ percentLeft: 40, pace: { willLastToReset: false, deltaPercent: 5, expectedUsedPercent: 50 } }, theme), "#FA6D80");
});

test("a window too young to project keeps the percent colour", () => {
  const row = { percentLeft: 40, pace: { willLastToReset: false, deltaPercent: 5, expectedUsedPercent: 4 } };
  assert.equal(Model.paceVerdict(row), "");
  assert.equal(Model.barColor(row, theme), Model.percentColor(40, theme));
});

test("percent colour is red by 10 percent, ink by 55, and ordered between", () => {
  assert.equal(Model.percentColor(3, theme), "#FA6D80");
  assert.equal(Model.percentColor(10, theme), "#FA6D80");
  // The theme colours reach the mix in lower case, so at the hinge the result
  // is the lower-case yellow.
  assert.equal(Model.percentColor(55, theme), "#ebe075");
  assert.equal(Model.percentColor(100, theme), "#ffffff");
});

test("window marker is a fraction of the remaining window, or -1", () => {
  const row = { resetsAt: new Date(now + 50 * 60000).toISOString(), windowMinutes: 100 };
  assert.equal(Model.windowLeft(row, now), 0.5);
  assert.equal(Model.windowLeft({ ...row, windowMinutes: null }, now), -1);
  assert.equal(Model.windowLeft({ ...row, resetsAt: null }, now), -1);
});

test("reset text counts down for short windows and dates long ones", () => {
  const short = { resetsAt: new Date(now + 90 * 60000).toISOString(), windowMinutes: 300 };
  assert.equal(Model.resetText(short, now, "en_US"), "resets in 1h 30m");
  const monthly = { resetsAt: new Date(now + 20 * 86400000).toISOString(), windowMinutes: 43200 };
  // An unknown locale still yields a date, in the fallback format.
  assert.match(Model.resetText(monthly, now, "not a locale"), /^resets \S+$/);
});

test("history bars are normalised to the busiest day", () => {
  const bars = Model.historyBars(entry({ dailyUsage: [{ costUSD: 0 }, { costUSD: 5 }, { costUSD: 2.5 }] }));
  assert.deepEqual(bars, [0, 1, 0.5]);
  assert.deepEqual(Model.historyBars(entry({ dailyUsage: [] })), []);
});

test("money and counts stay short", () => {
  assert.equal(Model.money(0), "$0");
  assert.equal(Model.money(0.004), "<$0.01");
  assert.equal(Model.money(71.581895), "$71.6");
  // Number(null) is 0, so a missing amount reads as zero rather than unset.
  assert.equal(Model.money(null), "$0");
  assert.equal(Model.compactNumber(42.5), "42.5");
  assert.equal(Model.compactNumber(1240), "1.2k");
  assert.equal(Model.compactNumber(2800000), "2.8M");
});

test("state text names stale and unavailable providers", () => {
  assert.equal(Model.stateText(entry({ stale: true })), "Stale");
  assert.equal(Model.stateText(entry({ usageUnavailable: { message: "x" } })), "Limits unavailable");
  assert.equal(Model.stateText(entry({ status: { indicator: "minor" } })), "Status issue");
  assert.equal(Model.stateText(entry({ status: { indicator: "none" } })), "");
});

test("provider names, colours and icons survive odd ids", () => {
  assert.equal(Model.providerName("opencodego"), "OpenCode Go");
  assert.equal(Model.providerName("ZZZ"), "ZZZ");
  assert.equal(Model.providerColor("claude"), "#b57861");
  assert.equal(Model.providerColor("zzz", "#123456"), "#123456");
  assert.equal(Model.providerIcon("grok"), "assets/providers/grok.svg");
  assert.equal(Model.providerIcon("moonshot"), "");
});

test("age text covers now, minutes and hours", () => {
  const at = "2026-10-31T07:00:00Z";
  assert.equal(Model.ageText(at, Date.parse(at) + 30000), "now");
  assert.equal(Model.ageText(at, Date.parse(at) + 5 * 60000), "5m");
  assert.equal(Model.ageText(at, Date.parse(at) + 3 * 3600000), "3h");
});

test("invalid percentages are rejected and valid values stay within the gauge", () => {
  const item = entry({ rows: [null, { percentLeft: "" }, { percentLeft: " " },
    { percentLeft: false }, { percentLeft: true }, { percentLeft: undefined },
    { percentLeft: Infinity }, { percentLeft: -12 }, { percentLeft: "120" }] });
  assert.deepEqual(Model.rowsOf(item).map(row => row.percentLeft), [0, 100]);
  assert.deepEqual(Model.rings(item, 2).map(ring => ring.value), [0, 100]);
  assert.equal(item.rows.at(-1).percentLeft, "120");
});

test("sidebar columns retain duration order when the tightest window changes", () => {
  const item = entry({ rows: [
    { percentLeft: 26, windowMinutes: 10080 }, { percentLeft: 74, windowMinutes: 300 }
  ] });
  const rings = Model.sidebarRings(item, 2);
  assert.deepEqual(rings.map(ring => [ring.value, ring.label]), [[74, "5h"], [26, "7d"]]);
  assert.equal(Model.rings(item, 1)[0].value, 26);
});

test("an exhausted monthly limit stays visible in a two-window sidebar", () => {
  const item = entry({provider: "opencode", rows: [
    {id: "primary", percentLeft: 100, windowMinutes: 300},
    {id: "secondary", percentLeft: 90, windowMinutes: 10080},
    {id: "tertiary", title: "Monthly Usage", percentLeft: 0, windowMinutes: 43200}
  ]});
  assert.deepEqual(Model.sidebarRings(item, 2).map(ring => ring.row.id), ["primary", "tertiary"]);
  assert.equal(Model.sidebarRings(item, 1)[0].value, 0);
  assert.equal(Model.headline(item).text, "0%");
  assert.match(Model.accessibleLabel({entry: item, rings: Model.sidebarRings(item, 2)}, now), /Monthly Usage.*0%/);
  item.rows[0].percentLeft = 0;
  assert.deepEqual(Model.sidebarRings(item, 2).map(ring => ring.row.id), ["primary", "tertiary"]);
  item.rows[2].percentLeft = 80;
  assert.deepEqual(Model.sidebarRings(item, 2).map(ring => ring.row.id), ["primary", "secondary"]);
});

test("window labels distinguish minutes, days, months and named quotas", () => {
  for (const [minutes, label] of [[15, "15m"], [60, "1h"], [1440, "1d"], [43200, "1mo"]])
    assert.equal(Model.windowLabel({ windowMinutes: minutes }), label);
  assert.equal(Model.windowLabel({ id: "Bonus", windowMinutes: null }), "Bonus");
});

test("reset credits use a full ring and keep their count", () => {
  const rings = Model.sidebarRings(entry({ limitResetCredits: { availableCount: 1 } }), 2);
  assert.deepEqual(rings.map(ring => [ring.value, ring.text, ring.label]), [[100, "1", "resets"]]);
});

test("sidebar colour reserves red for low or exhausted budgets", () => {
  assert.equal(Model.sidebarRingColor(entry(), { percentLeft: 74 }, theme), theme.ink);
  assert.equal(Model.sidebarRingColor(entry(), { percentLeft: 18 }, theme), theme.red);
  assert.equal(Model.sidebarRingColor(entry(), { percentLeft: 60, pace: {
    expectedUsedPercent: 50, deltaPercent: 5, willLastToReset: false
  } }, theme), theme.red);
});

test("ring color modes use provider, remaining usage, pace or theme colors", () => {
  const row = {percentLeft: 40};
  const color = (mode, value = row) => Model.sidebarRingColor(entry(), value, theme, {ringColorMode: mode});
  assert.equal(color("provider"), Model.providerColor("codex"));
  assert.equal(color("theme", {percentLeft: 0}), theme.ink);
  assert.equal(color("threshold"), Model.percentColor(40, theme));
  assert.equal(color("pace"), Model.percentColor(40, theme));
  for (const [pace, expected] of [
    [{expectedUsedPercent: 50, deltaPercent: 5, willLastToReset: false}, theme.red],
    [{expectedUsedPercent: 50, deltaPercent: -5, willLastToReset: true}, theme.yellow],
    [{expectedUsedPercent: 50, deltaPercent: -20, willLastToReset: true}, theme.ink],
    [{expectedUsedPercent: 4, deltaPercent: 5, willLastToReset: false}, Model.percentColor(40, theme)]
  ]) assert.equal(color("pace", {...row, pace}), expected);
  for (const mode of ["auto", "provider", "threshold", "pace", "theme"]) {
    assert.equal(Model.sidebarRingColor(entry({error: {message: "Offline"}}), null, theme,
      {ringColorMode: mode}), theme.red);
    assert.ok(Model.sidebarRingColor(entry({creditsRemaining: 1}), null, theme, {ringColorMode: mode}));
  }
});

test("custom provider colors apply to rings and matching pace markers", () => {
  const settings = {ringColorMode: "provider", ringProviderColor: "#123aBC"};
  const row = {percentLeft: 18};
  assert.equal(Model.sidebarRingColor(entry(), row, theme, settings), "#123aBC");
  for (const style of ["bar", "provider"])
    assert.equal(Model.paceMarkerColor(row, entry(), style, theme, now, settings), "#123aBC");
  assert.equal(Model.paceMarkerColor(row, entry(), "theme", theme, now, settings), theme.ink);
  for (const invalid of ["", "red", "#123", "#12345678", "#gggggg", null])
    assert.equal(Model.ringProviderColor(entry(), theme, {ringProviderColor: invalid}), Model.providerColor("codex"));
});

test("accessible usage includes window labels and stale status", () => {
  const item = entry({ stale: true, rows: [{ percentLeft: 74, windowMinutes: 300 }] });
  assert.equal(Model.accessibleLabel({ entry: item, rings: Model.sidebarRings(item, 2) }),
    "Codex, Stale, 74% 5h left");
});

test("QML sequences retain usage windows and history", () => {
  const item = entry({rows: {0: {percentLeft: 74, windowMinutes: 300}, length: 1},
    dailyUsage: {0: {costUSD: 2}, 1: {costUSD: 4}, length: 2}});
  assert.equal(Model.sidebarRings(item, 2)[0].value, 74);
  assert.deepEqual(Model.historyBars(item), [0.5, 1]);
});



test("time markers reject invalid clocks and resets outside the window", () => {
  const row = {resetsAt: new Date(now + 60 * 60000).toISOString(), windowMinutes: 60};
  assert.equal(Model.windowLeft(row, now), 1);
  assert.equal(Model.windowLeft(row, now - 1), -1);
  assert.equal(Model.windowLeft(row, now + 60 * 60000), 0);
  assert.equal(Model.windowLeft(row, now + 90 * 60000), 0);
  assert.equal(Model.windowLeft(row, NaN), -1);
  for (const windowMinutes of [0, -1, Infinity, NaN])
    assert.equal(Model.windowLeft({...row, windowMinutes}, now), -1);
  assert.equal(Model.windowLeft({...row, resetsAt: "invalid"}, now), -1);
});

test("empty pace is unknown and a young window has no forecast", () => {
  for (const pace of [{}, {willLastToReset: null, deltaPercent: null}, null])
    assert.equal(Model.paceVerdict({percentLeft: 70, pace}), "");
  assert.equal(Model.paceVerdict({pace: {willLastToReset: false, expectedUsedPercent: 9}}), "");
  assert.equal(Model.paceVerdict({pace: {willLastToReset: true, deltaPercent: null}}), "lasts");
});

test("pace text compares remaining budget with remaining time", () => {
  const row = {title: "Session", percentLeft: 70, windowMinutes: 60,
    resetsAt: new Date(now + 30 * 60000).toISOString(),
    pace: {expectedUsedPercent: 50, deltaPercent: -20, willLastToReset: true}};
  const label = Model.accessibleLabel({entry: entry({rows: [row]}), rings: Model.sidebarRings(entry({rows: [row]}), 2)}, now);
  assert.match(label, /70% remaining, 50% of window remaining/);
  assert.match(label, /Lasts until reset/);
  assert.doesNotMatch(Model.windowDescription({percentLeft: 50}, now), /window remaining|Lasts/);
});

test("ring arcs leave a gap at the time marker, including across the seam", () => {
  assert.deepEqual(Model.ringArcs(0, 0.5), []);
  assert.deepEqual(Model.ringArcs(50, -1), [{start: 0, sweep: 179.95}]);
  assert.deepEqual(Model.ringArcs(100, 0), Model.ringArcs(100, 1));
  for (const value of [0, 10, 50, 100]) for (const time of [0, 0.02, 0.5, 0.98, 1]) {
    const arcs = Model.ringArcs(value, time);
    assert.ok(arcs.length <= 2);
    for (const arc of arcs) {
      assert.ok(arc.start >= 0 && arc.sweep > 0 && arc.start + arc.sweep <= Model.ringSweep(value));
      for (const offset of [-360, 0, 360]) {
        const marker = time * 360 + offset;
        assert.ok(arc.start + arc.sweep <= marker - 12 || arc.start >= marker + 12);
      }
    }
  }
});

test("history uses one unit for the series and preserves detailed points", () => {
  const days = [{dayKey: "2026-11-01", totalTokens: 200}, {dayKey: "2026-11-02", totalTokens: 100}];
  assert.deepEqual(Model.historyBars(entry({dailyUsage: days})), [1, 0.5]);
  assert.deepEqual(Model.historyPoints(entry({dailyUsage: days})), days);
  assert.deepEqual(Model.historyBars(entry({dailyUsage: [{costUSD: 2, totalTokens: 1}, {costUSD: 0, totalTokens: 500}]})), [1, 0]);
  assert.deepEqual(Model.historyBars(entry({dailyUsage: [{costUSD: Infinity, totalTokens: 0}, null]})), [0]);
  assert.match(Model.historyTooltip({...days[0], costUSD: 1.5,
    models: [{name: "demo", totalTokens: 100}], limitResets: [{title: "Session", percentLeft: 25}]}),
    /2026-11-01\n\$1.50 · 200 tokens\ndemo: 100 tokens\nSession · 25% unused/);
  assert.equal(Model.historyTooltip(null), "");
});

test("zero reset credits remain visible without a full availability ring", () => {
  const item = entry({limitResetCredits: {availableCount: 0}, error: {message: "partial failure"}});
  assert.equal(Model.resetCreditsOf(item).availableCount, 0);
  assert.equal(Model.isErrorOnly(item), false);
  assert.equal(Model.headline(item).text, "0 resets");
  assert.equal(Model.rings(item, 1)[0].value, 0);
  assert.equal(Model.resetCreditsOf(entry({limitResetCredits: {availableCount: null}})), null);
});

test("visual hints separate each window and preserve the full accessible label", () => {
  const item = entry({provider: "opencode", rows: [{title: "Rolling usage", percentLeft: 100},
    {title: "Weekly usage", percentLeft: 90, windowMinutes: 60, resetsAt: new Date(now + 30 * 60000).toISOString()}]});
  const tile = {entry: item, rings: Model.sidebarRings(item, 2)};
  const hint = Model.providerTooltip(tile, now);
  assert.match(hint, /Rolling usage · 100% left/);
  assert.match(hint, /Weekly usage · 90% left/);
  assert.match(hint, /50% of window left/);
  assert.ok(hint.includes("\n\n"));
  assert.match(Model.accessibleLabel(tile, now), /^OpenCode,/);
  assert.equal(Model.providerTooltip({entry: entry({creditsRemaining: 12}), rings: Model.rings(entry({creditsRemaining: 12}), 1)}, now), "12 credits left");
});

console.log(`\n${passed} tests passed`);
