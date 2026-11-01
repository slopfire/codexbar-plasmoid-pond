// Shared account selection for the helpers and both settings screens.
export function names(value) {
  if (typeof value === "string") {
    try { value = JSON.parse(value); } catch (error) { value = []; }
  }
  const seen = new Set();
  return (Array.isArray(value) ? value : []).filter(value => typeof value === "string")
    .map(value => value.trim()).filter(value => {
      const key = value.toLowerCase();
      if (!value || seen.has(key)) return false;
      seen.add(key); return true;
    });
}

export function mode(config) {
  if (config?.allAccounts === true) return "all";
  if (["active", "all", "selected", "index"].includes(config?.accountMode)) return config.accountMode;
  if (names(config?.accounts).length) return "selected";
  if (String(config?.account || "").trim()) return "selected";
  return Number(config?.accountIndex) > 0 ? "index" : "active";
}

export function selected(config) {
  const list = names(config?.accounts);
  return list.length ? list : names([config?.account]);
}

export function selection(config, nextMode, accounts) {
  return Object.assign({}, config, {
    accountMode: nextMode,
    accounts: names(accounts === undefined ? selected(config) : accounts),
    account: "",
    accountIndex: nextMode === "index" ? Math.max(1, Math.floor(Number(config?.accountIndex) || 1)) : 0,
    allAccounts: nextMode === "all",
  });
}

export function candidates(config, entries) {
  const provider = normalizeProvider(config?.provider);
  return names(selected(config).concat((entries || [])
    .filter(entry => normalizeProvider(entry.provider) === provider && !entry.error && !entry.accountAnonymized)
    .map(entry => entry.account)));
}

export function normalizeProvider(value) {
  const id = String(value || "").toLowerCase().replace(/[-_]/g, "");
  return ({alibabacodingplan: "alibaba", groqcloud: "groq", abacusai: "abacus"})[id] || id;
}

export function expand(config) {
  if (["devin", "demo"].includes(normalizeProvider(config.provider))) return [config];
  const currentMode = mode(config);
  if (currentMode !== "selected") return [Object.assign({}, config, {
    account: "", accountIndex: currentMode === "index" ? config.accountIndex : 0,
    allAccounts: currentMode === "all",
  })];
  const list = selected(config);
  if (!list.length) return [Object.assign({}, config, {_accountSelectionError: "Select at least one account"})];
  return list.map(account => Object.assign({}, config, {account, accounts: [], allAccounts: false, accountIndex: 0}));
}

export function identity(item) {
  return String(item?.account || item?.usage?.accountEmail || item?.usage?.identity?.accountEmail || "").trim();
}

// Sources that ignore account flags must never substitute a different account.
export function matchingPayload(config, payload, filterIndex) {
  const list = Array.isArray(payload) ? payload : payload ? [payload] : [];
  if (list.length && list.every(item => item.error && !identity(item))) return list;
  const wanted = String(config?.account || "").trim().toLowerCase();
  if (wanted) return list.filter(item => identity(item).toLowerCase() === wanted);
  if (filterIndex && Number(config?.accountIndex) > 0) return list.slice(config.accountIndex - 1, config.accountIndex);
  return list;
}
