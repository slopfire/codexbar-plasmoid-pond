pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "codexbar" as Codexbar
import "." as Pond
import "codexbar/CodexBarModel.mjs" as Model
import "codexbar/CodexBarSettings.mjs" as Preferences

ShellRoot {
  id: root
  function provider(id, a, b, minutes) {
    return { id: id, provider: id, account: "example@local.invalid", plan: "Pro", rows: [
      { id: "primary", title: "Session", percentLeft: a, windowMinutes: minutes || 300, resetsAt: new Date(Date.now() + 2 * 3600000).toISOString() },
      { id: "secondary", title: "Weekly", percentLeft: b, windowMinutes: minutes ? 43200 : 10080, resetsAt: new Date(Date.now() + 5 * 86400000).toISOString() }
    ] };
  }
  function inspect(item) {
    const out = [];
    function providerOf(node) {
      while (node) {
        if (node.entry?.provider) return node.entry.provider;
        node = node.parent;
      }
      return "";
    }
    function walk(node) {
      if ("interactive" in node && "pageState" in node && !node.interactive) return;
      for (const resource of node.resources || []) {
        if (resource.objectName === "pondToolTip") out.push({tooltip: true, visible: resource.visible,
          width: resource.width, height: resource.height, text: resource.text, heading: resource.heading,
          background: String(resource.background.color), radius: resource.background.radius,
          contentHeight: resource.contentItem.implicitHeight, availableHeight: resource.availableHeight});
      }
      if ("gauges" in node) out.push({gauges: node.gauges, provider: node.entry.provider,
        background: String(node.children[0].color), alpha: node.children[0].color.a});
      if ("hasMarker" in node) out.push({ring: true, provider: providerOf(node), value: node.value, timeLeft: node.timeLeft,
        marker: node.hasMarker, style: node.markerStyle, visible: node.visible, size: node.size,
        stroke: node.stroke, track: String(node.trackColor), extent: node.markerExtent});
      if (node.objectName === "ringStack") out.push({stack: true, provider: node.entry?.provider, visible: node.visible,
        geometry: node.geometry, count: node.rings.length, width: node.width, height: node.height});
      if (node.objectName === "sidebarProviderIcon") out.push({sidebarIcon: true, visible: node.visible});
      if (node.objectName === "nestedRingLabels") out.push({nestedLabels: true, visible: node.visible,
        height: node.height, rowHeight: node.parent.parent.height, text: node.text});
      if (node.objectName === "sidebarAccount") out.push({accountCaption: true, text: node.text, visible: node.visible});
      if (node.objectName === "historyDayDetails") out.push({dayDetails: true, text: node.text, visible: node.visible});
      if (node.objectName === "providerKey") out.push({keyField: true, masked: node.password && !node.revealed});
      if (node.objectName === "usageWindows" || node.objectName === "usageWindow" || node.objectName === "spendSection" || node.objectName === "providerNote" || node.objectName === "historySection" || node.objectName === "providerStatus" || node.objectName === "providerError" || node.objectName === "resetCredits")
        out.push({section: node.objectName, x: node.x, y: node.y, height: node.height, visible: node.visible, text: node.text || ""});
      if ("columns" in node) out.push({columns: node.columns, width: node.width, bars: node.bars});
      for (const child of node.children || []) walk(child);
    }
    walk(item);
    return out;
  }
  property var reference: [Object.assign(provider("codex", 99, 74), {
    tokenUsage: {sessionCostUSD: 1.79, last30DaysCostUSD: 54, sessionTokens: 120000, last30DaysTokens: 2800000, provenance: "listPriceEstimate"},
    dailyUsage: Array.from({length: 30}, (_, i) => ({dayKey: "2026-10-" + String(i + 1).padStart(2, "0"),
      costUSD: i > 20 ? (i % 5) + 1 : 0, totalTokens: (i + 1) * 1000,
      models: [{name: "demo-model", totalTokens: (i + 1) * 1000}],
      limitResets: i === 20 ? [{title: "Session", percentLeft: 40}] : []})),
    status: {indicator: "minor", description: "Demo partial outage", url: "https://status.example.invalid"},
    limitResetCredits: {availableCount: 2, nextExpiresAt: "2026-11-15T03:00:00Z"}
  }), provider("claude", 100, 9), provider("gemini", 63, 18, 1440)]
  QtObject {
    id: usage
    property bool loaded: true
    property bool running: false
    property bool failed: false
    property string lastError: ""
    property string costNote: ""
    property string generatedAt: new Date().toISOString()
    property real nowMs: Date.now()
    property real totalSpend: 0
    property string ageLabel: "now"
    property var entries: root.reference
    property var ordered: entries
    property var settings: ({providerConfigs: [Preferences.newProvider("codex"), Preferences.newProvider("claude"), Preferences.newProvider("gemini")]})
    property bool savingSettings: false
    property string settingsSaveError: ""
    property bool authenticating: false
    property string authMessage: ""
    function authenticate(action) { authMessage = "Preview only"; }
    property bool discoveringAccounts: false
    property string accountError: ""
    property var accountEntries: []
    property var accountRequest: ({})
    signal settingsSaved
    function detectedProviders() { return ["codex", "claude", "gemini"]; }
    function saveSettings(patch, base) { settings = Object.assign({}, settings, patch); settingsSaved(); }
    function discoverAccounts(config) { accountRequest = config; accountEntries = [{provider: config.provider, account: "preview@local.invalid"}]; }
    function noteDemand() {}
    function refreshSoon(force) {}
    function openSite(url) {}
  }
  IpcHandler {
    target: "review"
    function report(): string {
      return JSON.stringify({settings: usage.settings, tree: inspect(card), railTree: inspect(rail), pages: inspect(drawer), rowHeight: card.height, railHeight: rail.height, railWidth: rail.width,
        page: drawer.currentPage, depth: drawer.depth, selection: drawer.currentSelection,
        transitioning: drawer.transitionRunning});
    }
    function provider(index: int) { drawer.openProvider(usage.entries[index]); if (!drawer.opened) drawer.open(); }
    function settingsTab(index: int) {
      function walk(node) {
        if ("editing" in node && "draft" in node) { node.editing = -1; node.tab = index; return true; }
        for (const child of node.children || []) if (walk(child)) return true;
        return false;
      }
      walk(drawer);
    }
    function editProvider(index: int) {
      function walk(node) {
        if ("editing" in node && "draft" in node) { node.tab = 1; node.editing = index; return true; }
        for (const child of node.children || []) if (walk(child)) return true;
        return false;
      }
      walk(drawer);
    }
    function appearance(patch: string) { usage.settings = Object.assign({}, usage.settings, JSON.parse(patch)); }
    function markerStyle(style: string) { usage.settings = Object.assign({}, usage.settings, {paceIndicatorStyle: style}); }
    function historyDay(index: int) {
      function walk(node) {
        if (node.objectName === "historySection") {
          node.selectedIndex = index;
          function focus(child) {
            if ("hasReset" in child && child.index === index) { child.forceActiveFocus(); return true; }
            for (const item of child.children || []) if (focus(item)) return true;
            return false;
          }
          focus(node);
          return true;
        }
        for (const child of node.children || []) if (walk(child)) return true;
        return false;
      }
      walk(drawer);
    }
    function richError() {
      usage.entries = [Object.assign({}, root.reference[0], {stale: true, error: {message: "Demo refresh failed"},
        tokenUsage: Object.assign({}, root.reference[0].tokenUsage, {historyCoverageIsEstablished: false})})];
    }
    function historyVisible(value: bool) { usage.settings = Object.assign({}, usage.settings, {history: value}); }
    function configureFetch() {
      function walk(node) {
        if ("editing" in node && "draft" in node) {
          for (const [key, value] of Object.entries({includeStatus: false, shareProviderFetches: false,
            costRefreshIntervalSeconds: 7200, providerRetryAttempts: 3, failureCooldownSeconds: 300,
            costScanTimeoutSeconds: 600, paceIndicatorStyle: "theme", ringLayout: "nested", nestedRingWidth: "decreasing",
            ringSize: 40, ringWidth: 3, ringGap: 2, showProviderIcon: false, showProviderName: false,
            showRingValues: false, showWindowLabels: false, showRingTrack: false})) node.patch(key, value);
          return true;
        }
        for (const child of node.children || []) if (walk(child)) return true;
        return false;
      }
      walk(drawer);
    }
    function settings() { if (!drawer.opened) drawer.open(); drawer.openSettings(); }
    function focusRow() {
      function walk(node) {
        if ("gauges" in node) { node.forceActiveFocus(); return true; }
        for (const child of node.children || []) if (walk(child)) return true;
        return false;
      }
      walk(card);
    }
    function list() { drawer.openProvider(null); if (!drawer.opened) drawer.open(); }
    function remove() { usage.entries = usage.entries.filter(entry => entry.id !== drawer.currentSelection.id); }
    function empty(failed: bool) { usage.entries = []; usage.failed = failed; usage.loaded = !failed; }
    function stale() { usage.entries = root.reference.map(entry => Object.assign({}, entry, {stale: true})); }
    function reset() { usage.entries = root.reference; usage.loaded = true; usage.failed = false; drawer.closeAll(); }
    function error() { usage.entries = [Object.assign({}, root.reference[0], {stale: true}),
      {id: "cursor", provider: "cursor", rows: [], error: {message: "Sign in again"}},
      {id: "openrouter", provider: "openrouter", rows: [], creditsRemaining: 12.5}]; }
    function overflow() { usage.entries = root.reference.concat([root.provider("grok", 60, 32), root.provider("cursor", 75, 90)]); }
    function theme(name: string) { Pond.Theme.name = name; }
    function collapse(value: real) { card.collapseProgress = value; card.width = Pond.Theme.lerp(156, 48, Pond.Theme.collapseWidth(value)); }
  }
  FloatingWindow {
    implicitWidth: 1010
    implicitHeight: 680
    color: "#8ba3a6"
    title: "CodexBar Pond review"
    Row {
      x: 28; y: 24; spacing: 24
      Column {
        spacing: 12
        Text { text: "Reference width"; color: "white"; font.family: Pond.Theme.fontFamily; font.pixelSize: 12 }
        Codexbar.SidebarCard { width: 196; state: usage }
      }
      Column {
        spacing: 12
        Text { text: "Pond sidebar"; color: "white"; font.family: Pond.Theme.fontFamily; font.pixelSize: 12 }
        Codexbar.SidebarCard {
          id: card; width: 156; state: usage
          onTileClicked: entry => { drawer.openProvider(entry); if (!drawer.opened) drawer.open(); }
        }
        Codexbar.SidebarCard { width: 156; state: usage; expandedView: false }
      }
      Column {
        spacing: 12
        Text { text: "Rail"; color: "white"; font.family: Pond.Theme.fontFamily; font.pixelSize: 12 }
        Codexbar.SidebarCard { id: rail; width: 48; state: usage; collapseProgress: 1 }
      }
    }
    Codexbar.UsagePanel { id: drawer; x: 650; y: 26; state: usage; Component.onCompleted: Qt.callLater(open) }
  }
}
