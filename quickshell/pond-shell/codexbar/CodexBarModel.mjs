// CodexBar's JSON snapshot, reduced to the values the Pond widget draws.
//
// The helper (codexbar-helper.mjs) owns fetching, retries, and caching. This
// module owns presentation rules only: which providers count, which provider
// leads, what a provider's headline number is, and the palette. Every function
// is pure and returns a new value, so the QML can call it from a binding without
// side effects.
//
// Shapes come from the helper; see docs in the codexbar-plasmoid repo
// (tests/model.test.mjs covers this module). Nullable fields are treated as null here and
// never as false or zero.

const NAMES = {
  codex: "Codex",
  openai: "OpenAI",
  azureopenai: "Azure OpenAI",
  claude: "Claude",
  clinepass: "ClinePass",
  gemini: "Gemini",
  antigravity: "Antigravity",
  cursor: "Cursor",
  opencode: "OpenCode",
  opencodego: "OpenCode Go",
  alibaba: "Alibaba Coding",
  alibabatokenplan: "Alibaba Token",
  zai: "z.ai",
  factory: "Factory",
  copilot: "Copilot",
  minimax: "MiniMax",
  manus: "Manus",
  vertexai: "Vertex AI",
  kilo: "Kilo",
  kiro: "Kiro",
  augment: "Augment",
  jetbrains: "JetBrains",
  kimi: "Kimi",
  kimik2: "Kimi K2",
  moonshot: "Moonshot",
  amp: "Amp",
  t3chat: "T3 Chat",
  ollama: "Ollama",
  synthetic: "Synthetic",
  openrouter: "OpenRouter",
  elevenlabs: "ElevenLabs",
  warp: "Warp",
  windsurf: "Windsurf",
  perplexity: "Perplexity",
  mimo: "MiMo",
  doubao: "Doubao",
  abacus: "Abacus",
  mistral: "Mistral",
  deepseek: "DeepSeek",
  codebuff: "Codebuff",
  crof: "Crof",
  venice: "Venice",
  codebuddy: "CodeBuddy",
  commandcode: "Command Code",
  stepfun: "StepFun",
  bedrock: "Bedrock",
  grok: "Grok",
  groq: "Groq",
  llmproxy: "LLM Proxy",
  deepgram: "Deepgram",
  devin: "Devin",
  demo: "Demo",
};

const COLORS = {
  codex: "#4b929b",
  openai: "#398979",
  azureopenai: "#397fb7",
  claude: "#b57861",
  clinepass: "#5a8fd6",
  codebuddy: "#00bc90",
  commandcode: "#a1579c",
  gemini: "#8972b5",
  antigravity: "#55976b",
  cursor: "#3c9487",
  opencode: "#477fc2",
  opencodego: "#477fc2",
  alibaba: "#bd7434",
  alibabatokenplan: "#bd7434",
  zai: "#b96170",
  factory: "#bd6e4c",
  copilot: "#8c68b7",
  minimax: "#bd684e",
  vertexai: "#4c7fb8",
  kilo: "#b87243",
  kiro: "#b57b32",
  augment: "#666db0",
  jetbrains: "#ae628a",
  moonshot: "#4b72b4",
  perplexity: "#438f8b",
  deepseek: "#5879b8",
  grok: "#3d8d76",
  groq: "#b86c55",
  openrouter: "#4d88ad",
  llmproxy: "#4a9173",
  devin: "#6769ad",
  demo: "#8b766e",
};

const SITES = {
  codex: "https://chatgpt.com/codex/cloud/settings/analytics",
  openai: "https://platform.openai.com/usage",
  claude: "https://platform.claude.com/settings/billing",
  clinepass: "https://app.cline.bot/dashboard/subscription?personal=true",
  gemini: "https://aistudio.google.com/usage",
  antigravity: "https://antigravity.google/",
  cursor: "https://cursor.com/dashboard",
  opencode: "https://opencode.ai/",
  opencodego: "https://opencode.ai/",
  alibaba: "https://bailian.console.aliyun.com/?tab=model#/efm/usage",
  alibabatokenplan: "https://bailian.console.aliyun.com/?tab=model#/efm/usage",
  zai: "https://open.bigmodel.cn/console/overview",
  abacus: "https://abacus.ai/app",
  copilot: "https://github.com/settings/copilot",
  minimax: "https://platform.minimax.io/subscribe",
  manus: "https://manus.im/app#settings/usage",
  vertexai: "https://console.cloud.google.com/vertex-ai",
  kilo: "https://app.kilo.ai/profile",
  kiro: "https://app.kiro.dev/",
  augment: "https://app.augmentcode.com/",
  factory: "https://app.factory.ai/",
  jetbrains: "https://account.jetbrains.com/licenses",
  kimi: "https://www.kimi.com/code/console",
  kimik2: "https://platform.kimi.com/console",
  moonshot: "https://platform.kimi.com/console",
  amp: "https://ampcode.com/settings",
  t3chat: "https://t3.chat/",
  ollama: "https://ollama.com/settings/keys",
  synthetic: "https://api.synthetic.new/v2/quotas",
  openrouter: "https://openrouter.ai/activity",
  elevenlabs: "https://elevenlabs.io/app/developers/analytics/usage",
  warp: "https://app.warp.dev/usage",
  windsurf: "https://windsurf.com/subscription/usage",
  perplexity: "https://www.perplexity.ai/settings/api",
  mimo: "https://platform.xiaomimimo.com/#/console/balance",
  doubao: "https://console.volcengine.com/ark/region:ark+cn-beijing/overview",
  mistral: "https://console.mistral.ai/usage",
  deepseek: "https://platform.deepseek.com/usage",
  codebuff: "https://codebuff.com/",
  crof: "https://crof.ai/usage_api/",
  venice: "https://venice.ai/settings/api",
  codebuddy: "https://www.codebuddy.ai/",
  commandcode: "https://commandcode.ai/",
  stepfun: "https://platform.stepfun.com/interface-key",
  bedrock: "https://console.aws.amazon.com/bedrock/",
  grok: "https://grok.com/?_s=usage",
  groq: "https://console.groq.com/dashboard/usage",
  deepgram: "https://console.deepgram.com/projects",
  devin: "https://app.devin.ai/settings/billing",
};

// Providers with a bundled icon under assets/providers/. Must match the files.
const ICONS = [
  "abacus", "alibaba", "amp", "antigravity", "augment", "bedrock", "claude",
  "clinepass", "codebuddy", "codebuff", "codex", "commandcode", "copilot", "crof",
  "cursor", "deepgram", "deepseek", "demo", "devin", "doubao", "elevenlabs",
  "factory", "gemini", "grok", "groq", "jetbrains", "kilo", "kimi", "kiro",
  "llmproxy", "manus", "mimo", "minimax", "mistral", "ollama", "opencode",
  "opencodego", "openrouter", "perplexity", "stepfun", "synthetic", "t3chat",
  "venice", "vertexai", "warp", "windsurf", "zai",
];

const ALIASES = {
  alibabacodingplan: "alibaba",
  abacusai: "abacus",
  groqcloud: "groq",
};

export const accentFallback = "#4b929b";

export function normalizeId(provider) {
  const key = String(provider || "").trim().toLowerCase().replace(/[-_.]/g, "");
  return ALIASES[key] || key;
}

const SHORT = {
  antigravity: "Antigrav",
  commandcode: "Command",
  opencodego: "OpenCode",
  alibabatokenplan: "Alibaba",
  azureopenai: "Azure",
  clinepass: "Cline",
};

/** Name short enough for a 62 px tile: one word, trimmed at 8 characters. */
export function shortName(provider) {
  const id = normalizeId(provider);
  if (SHORT[id]) return SHORT[id];
  const first = (NAMES[id] || String(provider || "?")).split(/\s+/)[0];
  return first.length > 8 ? first.slice(0, 7) + "." : first;
}

/** One or two letters for a provider badge: CO, CL, AN, GR, CU, OC, CB, CC. */
const TAGS = {
  codex: "CO",
  openai: "CO",
  claude: "CL",
  anthropic: "CL",
  antigravity: "AN",
  gemini: "GE",
  grok: "GR",
  cursor: "CU",
  opencode: "OC",
  opencodego: "OC",
  codebuddy: "CB",
  commandcode: "CC",
  openrouter: "OR",
  copilot: "CP",
  windsurf: "WS",
  jetbrains: "JB",
  kiro: "KI",
  augment: "AU",
  factory: "FA",
  devin: "DE",
  kimi: "KI",
  moonshot: "MO",
  zai: "ZA",
  minimax: "MM",
  ollama: "OL",
  demo: "DE",
};

export function tag(provider) {
  const id = normalizeId(provider);
  if (TAGS[id]) return TAGS[id];
  const name = NAMES[id] || String(provider || "?");
  return name.slice(0, 2).toUpperCase();
}

/** Screen-reader sentence for a tile. */
export function accessibleLabel(tile, nowMs) {
  if (!tile || !tile.entry) return "CodexBar";
  const name = providerName(tile.entry.provider);
  if (isErrorOnly(tile.entry)) return `${name}, error`;
  const rings = (tile.rings || []).map(r => r.row && Number.isFinite(nowMs)
    ? windowDescription(r.row, nowMs) : r.text).join(", ");
  const status = stateText(tile.entry);
  return [name, status, rings || "no usage"].filter(Boolean).join(", ");
}

/** Keep visual hints short. The accessible label retains the full sentence. */
export function providerTooltip(tile, nowMs) {
  if (!tile?.entry) return "";
  const entry = tile.entry;
  const parts = [];
  const status = stateText(entry);
  if (status) parts.push(status);
  for (const ring of tile.rings || []) {
    if (ring.row) parts.push(windowTooltip(ring.row, nowMs));
    else parts.push(`${ring.text} ${ring.kind === "resets" ? "resets available" : "credits left"}`);
  }
  if (entry.error || entry.lastAttemptError) parts.push(errorText(entry));
  return parts.join("\n\n") || "No usage limits";
}

export function windowTooltip(row, nowMs, locale) {
  if (!row) return "";
  const lines = [`${row.title || windowLabel(row)} · ${Math.round(row.percentLeft)}% left`];
  const time = windowLeft(row, nowMs);
  const timing = [resetText(row, nowMs, locale)];
  if (time >= 0) timing.push(`${Math.round(time * 100)}% of window left`);
  if (timing.filter(Boolean).length) lines.push(timing.filter(Boolean).join(" · "));
  const verdict = paceVerdict(row);
  if (verdict) lines.push(verdict === "lasts" ? "Lasts until reset"
    : verdict === "runs dry" ? "May run out before reset" : "Little reserve before reset");
  return lines.join("\n");
}

export function providerName(provider) {
  const id = normalizeId(provider);
  return NAMES[id] || String(provider || "CodexBar");
}

export function providerColor(provider, fallback) {
  return COLORS[normalizeId(provider)] || fallback || accentFallback;
}

/** Bundled icon for a provider, or "" when the provider has no icon. */
export function providerIcon(provider) {
  const id = normalizeId(provider);
  return ICONS.includes(id) ? `assets/providers/${id}.svg` : "";
}

export function providerSite(entry) {
  if (!entry) {
    return "";
  }
  const discovered = String(entry.siteUrl || "");
  if (discovered.startsWith("https://")
      || /^http:\/\/(127\.0\.0\.1|localhost|\[::1\])/.test(discovered)) {
    return discovered;
  }
  return SITES[normalizeId(entry.provider)] || "";
}

// Repeater modelData wraps nested arrays as QML sequences, not JS arrays.
function listOf(value) {
  return value && typeof value === "object" && Number.isInteger(value.length)
    ? Array.from(value) : [];
}

/** Rows worth drawing. Entries without usage have none. */
export function rowsOf(entry) {
  const rows = listOf(entry ? entry.rows : null);
  return rows.filter(row => row
    && (typeof row.percentLeft === "number"
      || typeof row.percentLeft === "string" && row.percentLeft.trim() !== "")
    && Number.isFinite(Number(row.percentLeft)))
    .map(row => Object.assign({}, row, { percentLeft: Math.max(0, Math.min(100, Number(row.percentLeft))) }));
}

/** Credits left, or null. Zero is a real value. */
export function creditsOf(entry) {
  const credits = entry ? entry.creditsRemaining : null;
  return typeof credits === "number" && Number.isFinite(credits) ? credits : null;
}

/** Spend summary ({sessionCostUSD, last30DaysCostUSD, ...}) or null. */
export function spendOf(entry) {
  const usage = entry ? entry.tokenUsage : null;
  if (!usage || typeof usage !== "object") {
    return null;
  }
  const hasNumber = [usage.sessionCostUSD, usage.last30DaysCostUSD]
    .some((value) => typeof value === "number" && Number.isFinite(value));
  return hasNumber ? usage : null;
}

/** Monthly reset credits left ({availableCount, nextExpiresAt}) or null. */
export function resetCreditsOf(entry) {
  const credits = entry ? entry.limitResetCredits : null;
  const raw = credits?.availableCount;
  const count = typeof raw === "number" || typeof raw === "string" && raw.trim() !== "" ? Number(raw) : NaN;
  return Number.isFinite(count) && count >= 0 ? credits : null;
}

/** A failed provider row: an error and nothing else to draw. */
export function isErrorOnly(entry) {
  return !!entry && !!entry.error && rowsOf(entry).length === 0
    && spendOf(entry) === null && creditsOf(entry) === null && resetCreditsOf(entry) === null;
}

/** The lowest remaining percent across an entry's windows, or null. */
export function tightestRow(entry) {
  const rows = rowsOf(entry);
  let best = null;
  for (const row of rows) {
    if (best === null || Number(row.percentLeft) < Number(best.percentLeft)) {
      best = row;
    }
  }
  return best;
}

/**
 * One-line status: the lowest remaining percent, else monthly limit resets,
 * else credits, else today's spend, else null.
 */
export function headline(entry) {
  if (!entry) {
    return null;
  }
  if (isErrorOnly(entry)) {
    return { kind: "error", value: 0, text: "Error" };
  }
  const row = tightestRow(entry);
  if (row) {
    const value = Number(row.percentLeft);
    return { kind: "percent", value, text: `${Math.round(value)}%` };
  }
  const resets = resetCreditsOf(entry);
  if (resets) {
    const count = Math.round(Number(resets.availableCount));
    return { kind: "resets", value: count, text: count === 1 ? "1 reset" : `${count} resets` };
  }
  const credits = creditsOf(entry);
  if (credits !== null) {
    return { kind: "credits", value: credits, text: compactNumber(credits) };
  }
  const spend = spendOf(entry);
  if (spend) {
    const value = Number(spend.sessionCostUSD ?? spend.last30DaysCostUSD ?? 0);
    return { kind: "spend", value, text: money(value) };
  }
  return null;
}

/**
 * Providers to list, worst first. Failed providers go last in their stable
 * order, because a retrying provider should not reshuffle the list.
 */
export function rank(entries) {
  const list = listOf(entries).filter(entry => entry && entry.provider);
  const live = list.filter((entry) => !isErrorOnly(entry));
  const failed = list.filter((entry) => isErrorOnly(entry));
  const urgency = (entry) => {
    const summary = headline(entry);
    if (!summary) {
      return 10000;
    }
    if (summary.kind === "percent") {
      return summary.value;
    }
    // No usage windows ranks after any percent, before a failed provider.
    return 1000 + (100 - Math.min(99, Number(summary.value) || 0));
  };
  live.sort((a, b) => urgency(a) - urgency(b));
  return live.concat(failed);
}

/**
 * First `count` rings for a provider: its usage windows worst first, then the
 * monthly reset credits and the credit balance as pseudo-rows, so a provider
 * with three windows and two resets still reads in one tile. Pseudo-rows carry
 * text only and are never paced.
 */
export function rings(entry, count) {
  const limit = Math.max(1, Number(count) || 1);
  const list = [];
  const sorted = rowsOf(entry).slice().sort((a, b) => Number(a.percentLeft) - Number(b.percentLeft));
  for (const row of sorted) {
    if (list.length >= limit) break;
    list.push({ kind: "window", row, value: Number(row.percentLeft), text: `${Math.round(Number(row.percentLeft))}%` });
  }
  const resets = resetCreditsOf(entry);
  if (resets && list.length < limit) {
    const value = Number(resets.availableCount);
    // Resets are counted in units, not a percent: a full ring per reset, capped.
    list.push({ kind: "resets", row: null, value: value > 0 ? 100 : 0, text: String(Math.round(value)) });
  }
  const credits = creditsOf(entry);
  if (credits !== null && list.length < limit) {
    list.push({ kind: "credits", row: null, value: credits > 0 ? 100 : 0, text: compactNumber(credits) });
  }
  return list;
}

/**
 * Tile colour: brand colour while the provider is comfortable, then the
 * remaining palette, then red for a failed provider. Brand colours are muted,
 * so the urgent state must outrank them or nothing catches the eye.
 */
export function ringColor(entry, row, theme) {
  if (isErrorOnly(entry)) {
    return theme.red;
  }
  const verdict = paceVerdict(row);
  if (verdict === "runs dry") {
    return theme.red;
  }
  const percent = row ? Number(row.percentLeft) : 100;
  if (percent <= 25 || verdict === "tight") {
    return percentColor(percent, theme);
  }
  return providerColor(entry ? entry.provider : "");
}

/** Sidebar windows keep their duration order when usage changes. */
export function sidebarRings(entry, count) {
  const limit = Math.max(1, Math.floor(Number(count) || 1));
  const rows = rowsOf(entry).sort((a, b) =>
    (Number(a.windowMinutes) > 0 ? Number(a.windowMinutes) : Infinity)
      - (Number(b.windowMinutes) > 0 ? Number(b.windowMinutes) : Infinity));
  if (rows.length > 0) {
    return rows.slice(0, limit).map(row => ({
      kind: "window", row, value: row.percentLeft,
      text: `${Math.round(row.percentLeft)}% ${windowLabel(row)} left`,
      label: windowLabel(row)
    }));
  }
  return rings(entry, limit).map(ring => Object.assign({}, ring, { label: ring.kind === "resets" ? "resets" : "credits" }));
}

export function windowLabel(row) {
  const minutes = Number(row?.windowMinutes);
  if (Number.isFinite(minutes) && minutes > 0) {
    if (minutes >= 40320 && minutes <= 44640) return "1mo";
    if (minutes % 1440 === 0) return `${minutes / 1440}d`;
    if (minutes % 60 === 0) return `${minutes / 60}h`;
    return `${minutes}m`;
  }
  return String(row?.label || row?.title || row?.id || "Usage");
}

export function sidebarRingColor(entry, row, theme) {
  if (isErrorOnly(entry) || row && (row.percentLeft <= 20 || paceVerdict(row) === "runs dry"))
    return theme.red;
  if (row && paceVerdict(row) === "tight") return theme.yellow;
  return theme.ink;
}

/** The provider the compact bar shows: the tightest live one, else the first failed. */
export function lead(entries) {
  const ranked = rank(entries);
  return ranked.length > 0 ? ranked[0] : null;
}

/** Compact bar text for the lead provider, for example "Codex 5%". */
export function compactLabel(entry) {
  const summary = headline(entry);
  if (!entry || !summary) {
    return "CodexBar";
  }
  if (summary.kind === "error") {
    return providerName(entry.provider);
  }
  return `${providerName(entry.provider)} ${summary.text}`;
}

/** Sum of the 30-day spend of every live provider, for the card footer. */
export function totalSpend(entries) {
  let total = 0;
  for (const entry of listOf(entries)) {
    if (isErrorOnly(entry)) continue;
    const spend = spendOf(entry);
    if (spend && typeof spend.last30DaysCostUSD === "number") {
      total += spend.last30DaysCostUSD;
    }
  }
  return total;
}

/** A one-word state for a provider row: "", "Error", "Stale", "Limits unavailable". */
export function stateText(entry) {
  if (!entry) {
    return "";
  }
  if (isErrorOnly(entry)) {
    return "Error";
  }
  if (entry.stale) {
    return "Stale";
  }
  if (entry.usageUnavailable || entry.error) {
    return "Limits unavailable";
  }
  const indicator = entry.status && entry.status.indicator;
  if (indicator && indicator !== "none") {
    return indicator === "maintenance" ? "Maintenance" : "Status issue";
  }
  return "";
}

/** Body text for a failed provider: the error message, clipped. */
export function errorText(entry, limit) {
  const error = entry && (entry.error || entry.lastAttemptError);
  const message = String((error && (error.message || error.description)) || "Could not read usage");
  const max = limit || 160;
  return message.length > max ? `${message.slice(0, max - 1)}…` : message;
}

/**
 * Pace verdict for a row: "runs dry", "tight", "lasts", or "" when the CLI has
 * no projection or the window is too young to project.
 */
export function paceVerdict(row) {
  const pace = row ? row.pace : null;
  if (!pace || typeof pace.willLastToReset !== "boolean"
      && !(typeof pace.deltaPercent === "number" && Number.isFinite(pace.deltaPercent))) {
    return "";
  }
  const expected = pace.expectedUsedPercent === null ? NaN : Number(pace.expectedUsedPercent);
  if (Number.isFinite(expected) && expected < 10) {
    return "";
  }
  if (pace.willLastToReset === false) {
    return "runs dry";
  }
  const delta = pace.deltaPercent === null ? NaN : Number(pace.deltaPercent);
  if (Number.isFinite(delta) && delta > -10) {
    return "tight";
  }
  return "lasts";
}

/** Fraction of the window still ahead, 0..1, or -1 when unknown. */
export function windowLeft(row, nowMs) {
  if (!row || !row.resetsAt || !Number.isFinite(nowMs)) {
    return -1;
  }
  const minutes = Number(row.windowMinutes);
  if (!Number.isFinite(minutes) || minutes <= 0) {
    return -1;
  }
  const resetMs = Date.parse(row.resetsAt);
  if (!Number.isFinite(resetMs)) {
    return -1;
  }
  const left = (resetMs - nowMs) / (minutes * 60000);
  if (!(left <= 1)) {
    return -1;
  }
  return Math.max(0, left);
}

/** A ring and its time marker both measure the remaining part of a window. */
export function windowDescription(row, nowMs, locale) {
  if (!row) return "";
  const parts = [`${row.title || windowLabel(row)} window`, `${Math.round(row.percentLeft)}% remaining`];
  const time = windowLeft(row, nowMs);
  if (time >= 0) parts.push(`${Math.round(time * 100)}% of window remaining`);
  const reset = resetText(row, nowMs, locale);
  if (reset) parts.push(reset);
  const verdict = paceVerdict(row);
  if (verdict) parts.push(verdict === "lasts" ? "Lasts until reset"
    : verdict === "runs dry" ? "Projected to run out before reset" : "Little reserve before reset");
  return parts.join(", ");
}

export function paceMarkerColor(row, entry, style, theme, nowMs) {
  if (style === "bar") return sidebarRingColor(entry, row, theme);
  if (style === "provider") return providerColor(entry?.provider);
  if (style === "theme" || style === "gaps") return theme.ink;
  return percentColor(windowLeft(row, nowMs) * 100, theme);
}

/** Split an arc at the time marker so the marker stays clear of the fill. */
export function ringArcs(value, timeLeft, halfGap = 12) {
  const end = ringSweep(value);
  if (end <= 0) return [];
  if (!Number.isFinite(timeLeft) || timeLeft < 0 || timeLeft > 1) return [{start: 0, sweep: end}];
  const marker = timeLeft * 360;
  const cuts = [-360, 0, 360].map(offset => [marker + offset - halfGap, marker + offset + halfGap]);
  const arcs = [];
  let cursor = 0;
  for (const [left, right] of cuts) {
    if (right <= 0 || left >= end) continue;
    if (left > cursor) arcs.push({start: cursor, sweep: left - cursor});
    cursor = Math.max(cursor, right);
  }
  if (cursor < end) arcs.push({start: cursor, sweep: end - cursor});
  return arcs;
}

/** "resets in 3h 10m", or "resets Nov 27" for windows longer than a day. */
export function resetText(row, nowMs, locale) {
  if (!row || !row.resetsAt) {
    return "";
  }
  const resetMs = Date.parse(row.resetsAt);
  if (!Number.isFinite(resetMs)) {
    return "";
  }
  const minutes = Number(row.windowMinutes);
  if (Number.isFinite(minutes) && minutes > 1440) {
    let date = "";
    try {
      date = new Date(resetMs).toLocaleDateString(locale, "MMM d");
    } catch (error) {
      // Qt and JS locale names differ; the day is still useful without one.
      date = new Date(resetMs).toLocaleDateString("en-US", "MMM d");
    }
    return `resets ${date}`;
  }
  const seconds = Math.max(0, (resetMs - nowMs) / 1000);
  const hours = Math.floor(seconds / 3600);
  if (hours >= 1) {
    return `resets in ${hours}h ${Math.floor((seconds % 3600) / 60)}m`;
  }
  return `resets in ${Math.max(0, Math.floor(seconds / 60))}m`;
}

/** Remaining-percent colour: ink above 55%, yellow at 55%, red by 10%. */
export function percentColor(percentLeft, theme) {
  const value = Number(percentLeft);
  const t = (Number.isFinite(value) ? Math.max(0, Math.min(100, value)) : 0) / 100;
  if (t <= 0.1) {
    return theme.red;
  }
  if (t >= 0.55) {
    return mix(theme.yellow, theme.ink, (t - 0.55) / 0.45);
  }
  return mix(theme.red, theme.yellow, (t - 0.1) / 0.45);
}

/** Bar fill for a row. Running dry is red, tight is yellow, else percentColor. */
export function barColor(row, theme) {
  const verdict = paceVerdict(row);
  if (verdict === "runs dry") {
    return theme.red;
  }
  if (verdict === "tight") {
    return theme.yellow;
  }
  return percentColor(row ? row.percentLeft : 0, theme);
}

/** Arc sweep for a ring: 100% stops just short of the round-cap seam. */
export function ringSweep(value) {
  const percent = Number.isFinite(Number(value)) ? Math.max(0, Math.min(100, Number(value))) : 0;
  return 359.9 * percent / 100;
}

/** Last 30 local days as bar heights 0..1 (1 = the busiest day). */
export function historyBars(entry) {
  const days = historyPoints(entry);
  if (days.length === 0) {
    return [];
  }
  const metric = days.some(day => Number(day?.costUSD) > 0) ? "costUSD" : "totalTokens";
  const values = days.map(day => {
    const number = Number(day?.[metric]);
    return Number.isFinite(number) ? Math.max(0, number) : 0;
  });
  const peak = values.reduce((best, value) => Math.max(best, value), 0);
  return values.map((value) => (peak > 0 ? value / peak : 0));
}

export function historyPoints(entry) {
  return listOf(entry?.dailyUsage).filter(day => day && typeof day === "object");
}

/** Plain text works in both a tooltip and a screen reader. */
export function historyTooltip(point) {
  if (!point) return "";
  const lines = [String(point.dayKey || "Day")];
  const amounts = item => {
    const parts = [];
    if (typeof item.costUSD === "number" && Number.isFinite(item.costUSD) && item.costUSD > 0)
      parts.push(money(item.costUSD));
    if (typeof item.totalTokens === "number" && Number.isFinite(item.totalTokens) && item.totalTokens > 0)
      parts.push(`${compactNumber(item.totalTokens)} tokens`);
    return parts.join(" · ");
  };
  lines.push(amounts(point) || "No usage");
  for (const model of listOf(point.models).filter(Boolean))
    lines.push([String(model.name || model.modelName || "Model"), amounts(model)].filter(Boolean).join(": "));
  for (const reset of listOf(point.limitResets).filter(Boolean)) {
    const left = typeof reset.percentLeft === "number" && Number.isFinite(reset.percentLeft)
      ? `${Math.round(reset.percentLeft)}% unused` : "Unused limit reset";
    lines.push([String(reset.title || "Limit"), left, reset.resetsAt || ""].filter(Boolean).join(" · "));
  }
  return lines.join("\n");
}

export function money(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) {
    return "—";
  }
  if (number === 0) {
    return "$0";
  }
  if (Math.abs(number) < 0.01) {
    return "<$0.01";
  }
  return `$${number.toFixed(number < 10 ? 2 : 1)}`;
}

export function compactNumber(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) {
    return "—";
  }
  if (Math.abs(number) >= 1000000) {
    return `${(number / 1000000).toFixed(1)}M`;
  }
  if (Math.abs(number) >= 1000) {
    return `${(number / 1000).toFixed(1)}k`;
  }
  return Number.isInteger(number) ? String(number) : number.toFixed(1);
}

/** Relative age of a snapshot: "now", "4m", "2h". */
export function ageText(iso, nowMs) {
  const then = Date.parse(iso);
  if (!Number.isFinite(then)) {
    return "";
  }
  const seconds = Math.max(0, Math.round((nowMs - then) / 1000));
  if (seconds < 60) {
    return "now";
  }
  if (seconds < 3600) {
    return `${Math.floor(seconds / 60)}m`;
  }
  return `${Math.floor(seconds / 3600)}h`;
}

// Qt.rgba cannot be called from an .mjs string colour, so mix in plain sRGB.
function mix(from, to, amount) {
  const t = Math.max(0, Math.min(1, amount));
  const a = parseHex(from);
  const b = parseHex(to);
  if (!a || !b) {
    return from;
  }
  const channel = (index) => Math.round(a[index] + (b[index] - a[index]) * t);
  return `#${[channel(0), channel(1), channel(2)]
    .map((part) => part.toString(16).padStart(2, "0")).join("")}`;
}

function parseHex(value) {
  const text = String(value || "").replace("#", "");
  if (text.length !== 6) {
    return null;
  }
  const parts = [0, 2, 4].map((offset) => parseInt(text.slice(offset, offset + 2), 16));
  return parts.every((part) => Number.isFinite(part)) ? parts : null;
}
