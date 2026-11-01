import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import "CodexBarModel.mjs" as Model
import "CodexBarSettings.mjs" as Preferences

// CodexBar usage state for the Pond sidebar.
//
// The vendored helper (codexbar-helper.mjs) does the fetching, caching, retries,
// and cost scanning. This component only runs it, keeps the last good snapshot,
// and shows how old that snapshot is. A failed run keeps the last reading.
//
// Settings live in ~/.config/codexbar-plasmoid/config.json:
//   { "cliPath": "...", "autoUpdateCli": false, "provider": "all",
//     "refreshIntervalSeconds": 150, "cost": true, "credits": true,
//     "anonymizeEmail": true }
// Missing keys use the defaults below, which match the KDE plasmoid.
//
// This is a plain component, not a singleton: a singleton declared inside a
// plain directory is opaque to QML property and signal access in this
// Quickshell build, so only its own methods would work. The Sidebar creates
// the one instance and passes it to the card and the panel.
Item {
  id: root

  // Until the first run finishes, the widget shows its skeleton.
  property bool loaded: false
  property bool running: false
  property bool failed: false
  property string lastError: ""
  // Top-level cost scan complaint. Cost is optional, so this is a note only.
  property string costNote: ""
  property string generatedAt: ""
  // Entries from the last successful run, unranked. Read through ordered.
  property var entries: []
  property real nowMs: Date.now()

  // The owner requests periodic updates while the widget is in use.
  property bool wanted: false

  // The module-imported singleton (shell.qml, Sidebar.qml) only exposes this
  // instance's methods in this build, so the sidebar and shell talk to it
  // through signals, which cross that boundary.
  //   refreshRequested - re-run the CLI now (an IPC or keybind action).
  //   (wanted, set by the panel's open state, is a plain property and also
  //    reads correctly from the sidebar.)
  signal refreshRequested

  // Last thing the IPC path needs to do to the state. The shell reaches the
  // sidebar's own instance through this reference, because a second import of
  // the file in shell.qml would create a different, empty object.
  property var settings: ({})
  readonly property var cliPath: String(settings.cliPath || "")
  readonly property bool autoUpdate: settings.autoUpdateCli === true
  readonly property string provider: String(settings.provider || "all")
  readonly property int refreshSeconds: Math.max(60, Math.min(86400, Number(settings.refreshIntervalSeconds) || 150))
  readonly property int pollSeconds: Math.max(60, Math.min(86400, Preferences.refreshInterval(settings, detectedProviders())))
  readonly property bool includeCost: settings.cost !== false
  readonly property bool includeStatus: settings.includeStatus !== false
  readonly property bool shareProviderFetches: settings.shareProviderFetches !== false
  readonly property int costRefreshIntervalSeconds: Math.max(300, Math.min(604800, Number(settings.costRefreshIntervalSeconds) || 3600))
  readonly property int providerRetryAttempts: Math.max(1, Math.min(4, Number(settings.providerRetryAttempts) || 2))
  readonly property int failureCooldownSeconds: Math.max(30, Math.min(3600, Number(settings.failureCooldownSeconds) || 180))
  readonly property int costScanTimeoutSeconds: Math.max(60, Math.min(1800, Number(settings.costScanTimeoutSeconds) || 300))
  readonly property bool includeCredits: settings.credits !== false
  readonly property bool anonymizeEmail: settings.anonymizeEmail !== false
  readonly property int timeoutSeconds: Math.max(5, Math.min(300, Number(settings.timeoutSeconds) || 60))
  // Maximum rings per provider. The card also limits them to its width.
  readonly property int cardBars: Math.max(1, Math.min(6, Number(settings.cardBars) || 2))
  // Provider rows in the card. An explicit 0 shows all providers.
  readonly property int expandedRows: settings.expandedRows === undefined ? 3
      : Math.max(0, Math.min(8, Number(settings.expandedRows) || 0))
  readonly property bool expandedCard: settings.expanded !== false

  // The path may hold "~" or "$HOME"; the helper spawns binaries itself, so a
  // relative name would resolve against the shell process directory.
  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string resolvedCliPath: resolveCliPath(cliPath)

  readonly property string helperPath: localPath(Qt.resolvedUrl("codexbar-helper.mjs"))
  readonly property string settingsPath: localPath(StandardPaths.writableLocation(StandardPaths.ConfigLocation))
      + "/codexbar-plasmoid/config.json"
  // Synthetic snapshots for previews and tests.
  readonly property bool demoMode: Quickshell.env("CODEXBAR_POND_DEMO") === "1"
      || Quickshell.env("CODEXBAR_POND_GALLERY") === "1"
  readonly property url fixturePath: Quickshell.env("CODEXBAR_POND_GALLERY") === "1"
      ? Qt.resolvedUrl("demo/gallery.json") : Qt.resolvedUrl("demo/snapshot.json")
  property bool initialized: false

  // Ranked worst first. Kept as one value so Repeaters see one change per run.
  readonly property var ordered: {
    const ranked = Model.rank(entries);
    if (!Array.isArray(settings.providerConfigs)) return ranked;
    const configured = settings.providerConfigs.filter(row => row.enabled !== false);
    const ids = configured.map(row => Model.normalizeId(row.provider));
    return ranked.filter(entry => ids.includes(Model.normalizeId(entry.provider)))
      .sort((a, b) => ids.indexOf(Model.normalizeId(a.provider)) - ids.indexOf(Model.normalizeId(b.provider)));
  }
  readonly property var leadEntry: Model.lead(entries)
  readonly property string leadLabel: Model.compactLabel(leadEntry)
  readonly property string ageLabel: generatedAt === "" ? "" : Model.ageText(generatedAt, nowMs)
  readonly property real totalSpend: Model.totalSpend(entries)

  // A forced refresh bypasses the usage cache.
  function options(force) {
    return {
      force: force === true,
      cost: includeCost,
      credits: includeCredits,
      status: includeStatus,
      anonymize: anonymizeEmail,
      autoUpdate,
      provider: "all",
      providers: root.providerConfigs(),
    };
  }

  function command(options) {
    const args = [
      "node", helperPath,
      "--provider", options.provider,
      "--timeout", String(root.timeoutSeconds),
      "--cost", options.cost ? "true" : "false",
      "--credits", options.credits ? "true" : "false",
      "--status", options.status ? "true" : "false",
      "--anonymize-emails", options.anonymize ? "true" : "false",
      "--auto-update", options.autoUpdate ? "true" : "false",
      "--cache-seconds", String(root.shareProviderFetches ? root.refreshSeconds : 0),
      "--refresh-interval-seconds", String(root.refreshSeconds),
      "--cost-cache-seconds", String(root.costRefreshIntervalSeconds),
      "--retry-attempts", String(root.providerRetryAttempts),
      "--cooldown-cap-seconds", String(root.failureCooldownSeconds),
      "--cost-timeout", String(root.costScanTimeoutSeconds),
      "--force", options.force ? "true" : "false",
    ];
    if (root.resolvedCliPath !== "") {
      args.push("--cli", root.resolvedCliPath);
    }
    args.push("--providers-stdin", "true");
    return args;
  }

  // Providers to ask for. CodexBar's own auto-discovery guesses a dozen agents
  // from bare home directories (Augment, Factory, Kiro and others appear from
  // half-hidden caches and only ever fail), so the list is explicit:
  //  - `settings.providers` names them, when set;
  //  - otherwise Codex always, plus the agents this shell can see signed in.
  // A provider that fails anyway stays in the drawer (its error is real, for
  // example an expired cursor session), but it never reaches the grid.
  function providerConfigs() {
    return Preferences.providerRows(settings, detectedProviders());
  }

  // Agents and the profile directories that mean "signed in here". Every path
  // is checked, so a provider is detected by any of its plausible spots.
  readonly property var agentProfiles: {
    const home = root.home;
    const config = Quickshell.env("XDG_CONFIG_HOME") || home + "/.config";
    return [
      { id: "codex", paths: [home + "/.codex"] },
      { id: "claude", paths: [home + "/.claude"] },
      { id: "antigravity", paths: [home + "/.antigravity"] },
      { id: "grok", paths: [home + "/.grok"] },
      { id: "cursor", paths: [config + "/Cursor", home + "/.cursor"] },
      // opencode and opencodego share one profile; asking both doubles the
      // fetch for the same console session.
      { id: "opencode", paths: [config + "/opencode", home + "/.local/share/opencode"] },
      { id: "commandcode", paths: [home + "/.commandcode"] },
      { id: "codebuddy", paths: [home + "/.codebuddy", home + "/.local/share/CodeBuddyExtension"] },
    ];
  }

  readonly property var profilePaths: {
    const list = [];
    for (const agent of agentProfiles)
      for (const path of agent.paths)
        if (list.indexOf(path) < 0) list.push(path);
    return list;
  }

  // Agents with a signed-in profile here, in a stable order. Codex is always
  // asked: it is the account the widget exists for. The first run may start
  // before the probes finish, which only means fewer agents that once.
  function detectedProviders() {
    const found = agentProfiles
        .filter(agent => agent.paths.some(path => root.pathExists(path)))
        .map(agent => agent.id);
    return found.indexOf("codex") >= 0 ? found : ["codex"].concat(found);
  }

  // Which agents have a profile here. A probe FileView per path, built once
  // and destroyed after it reports; a directory opens with an empty read,
  // which FileView.loads reports as a failure.
  property var probeResults: ({})
  property var probeQueue: []
  property bool probing: false

  function pathExists(path) {
    return probeResults[path] === true;
  }

  function probePaths(paths) {
    const pending = [];
    for (const path of paths) {
      if (!(path in probeResults))
        pending.push(path);
    }
    if (pending.length === 0)
      return;
    for (const path of pending) {
      probeResults[path] = false;
      probeQueue.push(path);
    }
    probeResults = Object.assign({}, probeResults);
    if (!probing) {
      probing = true;
      Qt.callLater(root.runProbe);
    }
  }

  function runProbe() {
    if (probeQueue.length === 0) {
      probing = false;
      if (root.initialized && root.wanted) root.noteDemand();
      return;
    }
    const path = probeQueue.shift();
    const view = pathProbe.createObject(root, { path: path });
    view.probed.connect(ok => {
      probeResults[path] = ok;
      probeResults = Object.assign({}, probeResults);
      view.destroy();
      Qt.callLater(root.runProbe);
    });
    view.running = true;
  }

  // Check existence without reading account files or opening directories.
  readonly property Component pathProbe: Component {
    Process {
      required property string path
      signal probed(bool ok)
      command: ["test", "-e", path]
      onExited: exitCode => probed(exitCode === 0)
    }
  }

  function resolveCliPath(path) {
    const value = String(path || "").trim();
    if (value === "") {
      return "";
    }
    if (value === "~" || value.startsWith("~/")) {
      return root.home + value.slice(1);
    }
    return value;
  }

  function localPath(url) {
    return decodeURIComponent(String(url).replace(/^file:\/\//, ""));
  }

  onRefreshRequested: root.refreshSoon(true)

  // Called every time the panel opens. The first open starts a refresh; a
  // later open picks up whatever the background schedule has chosen.
  function noteDemand() {
    if (failures >= 3) {
      failures = 0;
    }
    if (!running && !restartDelay.running) {
      refresh(false);
    }
  }

  // A manual refresh always goes to the CLI and restarts the failure backoff.
  function refresh(force) {
    failures = 0;
    restartDelay.stop();
    start(options(force === true));
  }

  // A manual refresh during a run asks for one more run afterwards.
  function refreshSoon(force) {
    refresh(force === true);
  }

  function start(runOptions) {
    if (demoMode) return;
    if (proc.running) {
      pending = options(runOptions.force || pending?.force === true);
      return;
    }
    restartDelay.stop();
    request = runOptions;
    proc.stdinEnabled = true;
    proc.command = command(runOptions);
    running = true;
    proc.running = true;
  }

  function accept(text) {
    const trimmed = String(text || "").trim();
    if (trimmed === "") {
      return "CodexBar returned no data";
    }
    let parsed;
    try {
      parsed = JSON.parse(trimmed);
    } catch (error) {
      return "CodexBar sent unreadable data: " + trimmed.slice(0, 120);
    }
    if (!parsed || typeof parsed !== "object") {
      return "CodexBar sent unreadable data";
    }
    if (parsed.ok === false) {
      return String(parsed.error || "CodexBar could not run");
    }
    if (!Array.isArray(parsed.entries)) {
      return "CodexBar sent no provider list";
    }
    entries = parsed.entries.filter(entry => entry && typeof entry === "object" && entry.provider);
    nowMs = Date.now();
    generatedAt = String(parsed.generatedAt || "");
    costNote = String(parsed.costError || "");
    loaded = true;
    return "";
  }

  function finish(errorText) {
    running = false;
    failed = errorText !== "";
    lastError = errorText;
    if (errorText === "") {
      failures = 0;
    } else {
      failures += 1;
    }
    // Keep the last good snapshot on screen; only the footer reports failure.
    scheduleRefresh();
    if (pending !== null) {
      const next = pending;
      pending = null;
      start(next);
    }
  }

  function scheduleRefresh() {
    // Stopped processes still schedule; work runs only with panel demand.
    if (!wanted || demoMode) {
      return;
    }
    restartDelay.stop();
    if (failures > 0) {
      const wait = Math.min(1800, 60 * Math.pow(2, failures - 1));
      restartDelay.interval = wait * 1000;
    } else {
      restartDelay.interval = pollSeconds * 1000;
    }
    restartDelay.restart();
  }

  // Provider pages open in the user's browser: CodexBar has no in-app view.
  function openSite(url) {
    if (!/^https?:\/\//.test(String(url || ""))) {
      return;
    }
    Quickshell.execDetached(["xdg-open", url]);
  }

  property bool savingSettings: false
  property string settingsSaveError: ""
  property var settingsRequest: ({})
  signal settingsSaved

  function saveSettings(patch, base) {
    if (savingSettings) return;
    settingsSaveError = "";
    try { Preferences.validate(patch); }
    catch (error) { settingsSaveError = error.message; return; }
    settingsRequest = {patch: patch, base: base};
    savingSettings = true;
    settingsWriter.stdinEnabled = true;
    settingsWriter.running = true;
  }

  Process {
    id: settingsWriter
    command: ["node", root.localPath(Qt.resolvedUrl("settings-store.mjs")), root.settingsPath]
    onStarted: {
      write(JSON.stringify(root.settingsRequest));
      stdinEnabled = false;
    }
    stdout: StdioCollector { id: settingsOutput }
    onExited: exitCode => {
      root.savingSettings = false;
      let result = {};
      try { result = JSON.parse(settingsOutput.text); } catch (error) {}
      if (exitCode !== 0 || !result.ok) {
        root.settingsSaveError = String(result.error || "Could not save settings");
        return;
      }
      root.settings = Object.assign({}, root.settings, root.settingsRequest.patch);
      settingsFile.reload();
      root.settingsSaved();
      root.refreshSoon(true);
    }
  }

  property bool authenticating: false
  property string authMessage: ""

  function authenticate(action) {
    if (authenticating || !["login", "logout"].includes(action)) return;
    authMessage = "";
    authProcess.command = ["node", helperPath, "--provider", "antigravity", "--auth-action", action,
      "--nativeCli", Quickshell.env("CODEXBAR_NATIVE_CLI") || localPath(Qt.resolvedUrl("codexbar-plasmoid"))];
    authenticating = true;
    authProcess.running = true;
  }
  Process {
    id: authProcess
    stdout: StdioCollector { id: authOutput }
    onExited: exitCode => {
      root.authenticating = false;
      let result = {};
      try { result = JSON.parse(authOutput.text); } catch (error) {}
      root.authMessage = String(result.message || "Could not run the sign-in action");
      if (result.ok) root.refreshSoon(true);
    }
  }

  property bool discoveringAccounts: false
  property var accountEntries: []
  property string accountError: ""
  property var accountRequest: ({})
  property bool accountTimedOut: false

  function discoverAccounts(config) {
    if (discoveringAccounts || !config) return;
    accountError = "";
    accountEntries = [];
    accountTimedOut = false;
    accountRequest = Object.assign({}, config, {enabled: true, allAccounts: true, account: "", accountIndex: 0, includeCost: false});
    const options = root.options(false);
    options.providers = [accountRequest];
    options.status = false;
    const args = command(options);
    args.push("--cost", "false", "--auto-update", "false", "--anonymize-emails", "false");
    accountProcess.command = args;
    accountProcess.stdinEnabled = true;
    discoveringAccounts = true;
    accountProcess.running = true;
  }

  Timer {
    interval: (root.timeoutSeconds + 15) * 1000
    running: root.discoveringAccounts
    onTriggered: {
      root.accountTimedOut = true;
      accountProcess.running = false;
    }
  }
  Process {
    id: accountProcess
    onStarted: { write(JSON.stringify([root.accountRequest])); stdinEnabled = false; }
    stdout: StdioCollector { id: accountOutput }
    onExited: exitCode => {
      root.discoveringAccounts = false;
      if (root.accountTimedOut) { root.accountError = "Account detection timed out"; return; }
      let snapshot = {};
      try { snapshot = JSON.parse(accountOutput.text); } catch (error) {}
      root.accountEntries = (snapshot.entries || []).filter(entry => !entry.error && entry.account);
      const failure = snapshot.error || (snapshot.entries || []).find(entry => entry.error)?.error;
      let message = failure ? String(failure.message || failure) : exitCode !== 0 ? "Account detection stopped with exit code " + exitCode : "";
      const key = String(root.accountRequest.apiKey || "");
      if (key) message = message.split(key).join("[hidden]");
      root.accountError = message.slice(0, 240) || (root.accountEntries.length > 0 ? "" : "No named accounts found. Use Active account or sign in with the provider CLI.");
    }
  }

  // Failed refreshes retry with a delay, including when cached data is present.
  property int failures: 0
  // Options of the last run; a failed forced run retries on the backoff.
  property var request: ({})
  property string stdoutBuffer: ""
  property bool killed: false
  property var pending: null

  onWantedChanged: {
    if (!wanted) restartDelay.stop();
    else if (initialized && !probing) noteDemand();
  }

  Component.onCompleted: {
    initialized = true;
    if (!demoMode) {
      root.probePaths(root.profilePaths);
      if (!probing && wanted) noteDemand();
    }
  }

  Timer {
    interval: 30000
    repeat: true
    running: root.loaded
    onTriggered: root.nowMs = Date.now()
  }

  Timer {
    id: restartDelay
    repeat: false
    onTriggered: {
      if (root.failures > 0 && root.request.force)
        root.start(root.options(true));
      else if (root.wanted)
        root.start(root.options(false));
    }
  }

  // A run that outlives its own timeout is stuck; kill it and report.
  Timer {
    id: watchdog
    interval: (root.timeoutSeconds + 90) * 1000
    running: root.running
    onTriggered: {
      if (!root.running) {
        return;
      }
      root.killed = true;
      proc.running = false;
    }
  }

  // A missing or broken settings file keeps the defaults; the widget reacts by
  // reloading settings when the file is edited.
  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        const parsed = JSON.parse(text());
        root.settings = parsed && typeof parsed === "object" ? parsed : ({});
      } catch (error) {
        root.settings = ({});
      }
    }
    onFileChanged: reload()
  }

  // Sample snapshot for CODEXBAR_POND_DEMO=1.
  FileView {
    id: fixtureRead
    path: root.demoMode ? root.fixturePath : ""
    printErrors: false
    onLoaded: {
      const error = root.accept(text());
      root.nowMs = Date.now();
      root.generatedAt = new Date(root.nowMs).toISOString();
      root.loaded = true;
      if (error !== "") {
        root.failures = 1;
      }
      root.failed = error !== "";
      root.lastError = error;
    }
  }

  Process {
    id: proc
    environment: ({ "LC_ALL": "C" })
    onStarted: {
      root.killed = false;
      proc.write(JSON.stringify(root.request.providers));
      proc.stdinEnabled = false;
    }
    onExited: exitCode => {
      watchdog.stop();
      if (root.killed) {
        root.killed = false;
        root.stdoutBuffer = "";
        root.finish("CodexBar did not answer in time");
        return;
      }
      let errorText = root.accept(root.stdoutBuffer);
      root.stdoutBuffer = "";
      if (errorText === "" && exitCode !== 0) {
        errorText = "CodexBar stopped with exit code " + exitCode;
      }
      root.finish(errorText);
    }
    stdout: StdioCollector {
      onStreamFinished: root.stdoutBuffer = text
    }
  }
}
