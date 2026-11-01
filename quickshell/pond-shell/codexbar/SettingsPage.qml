pragma ComponentBehavior: Bound
import QtQuick
import ".." as Shell
import "CodexBarModel.mjs" as Model
import "CodexBarSettings.mjs" as Settings

Item {
  id: root
  required property var pageState
  property var stackController
  property bool interactive: true
  enabled: interactive
  property var selection: ({})
  Component.onCompleted: {
    pageState.settingsSaveError = "";
    pageState.accountError = "";
  }
  property int tab: 0
  property int editing: -1
  property string accountMode: "active"
  onEditingChanged: {
    accountMode = config?.allAccounts ? "all" : config?.account ? "named" : config?.accountIndex > 0 ? "index" : "active";
  }
  property var base: Settings.clone(pageState.settings || {})
  property var draft: Object.assign({}, base, {provider: "all",
    providerConfigs: Settings.providerRows(base, pageState.detectedProviders())})
  property string validationError: ""
  readonly property var providers: draft.providerConfigs
  readonly property var config: editing >= 0 ? providers[editing] : null
  readonly property string error: validationError || pageState.settingsSaveError || ""
  implicitWidth: Shell.PanelStyle.width
  implicitHeight: 580

  function patch(key, value) { const next = Object.assign({}, draft); next[key] = value; draft = next; }
  function updateProvider(key, value) {
    const rows = Settings.clone(providers);
    rows[editing][key] = value;
    patch("providerConfigs", rows);
  }
  function addProvider(id) {
    const rows = Settings.clone(providers);
    rows.push(Settings.newProvider(id));
    patch("providerConfigs", rows);
    editing = rows.length - 1;
  }
  function removeProvider() {
    const rows = Settings.clone(providers); rows.splice(editing, 1);
    patch("providerConfigs", rows); editing = -1;
  }
  function moveProvider(delta) {
    const index = editing + delta;
    if (index < 0 || index >= providers.length) return;
    const rows = Settings.clone(providers);
    const row = rows.splice(editing, 1)[0]; rows.splice(index, 0, row);
    patch("providerConfigs", rows); editing = index;
  }
  function accountOptions() {
    const rows = [{value: "active", label: "Active account"}, {value: "all", label: "All accounts"},
      {value: "named", label: "Named account"}, {value: "index", label: "Account index"}];
    const seen = [];
    for (const entry of (pageState.accountEntries || []).concat(pageState.entries || [])) {
      if (entry.provider !== config?.provider || !entry.account || seen.includes(entry.account)) continue;
      seen.push(entry.account); rows.push({value: "saved:" + entry.account, label: entry.account});
    }
    return rows;
  }
  function selectAccount(value) {
    accountMode = value.startsWith("saved:") ? "named" : value;
    const rows = Settings.clone(providers); const item = rows[editing];
    item.allAccounts = value === "all";
    if (value.startsWith("saved:")) { item.account = value.slice(6); item.accountIndex = 0; }
    else if (value === "active" || value === "all") { item.account = ""; item.accountIndex = 0; }
    else if (value === "index") { item.account = ""; item.accountIndex = Math.max(1, Number(item.accountIndex) || 1); }
    else { item.account = item.account || ""; item.accountIndex = 0; }
    patch("providerConfigs", rows);
  }
  function apply() {
    validationError = "";
    const update = {};
    for (const key of ["provider", "providerConfigs", "cliPath", "refreshIntervalSeconds", "timeoutSeconds",
      "autoUpdateCli", "cost", "credits", "anonymizeEmail", "cardBars", "expandedRows", "expanded", "history", "includeStatus",
      "costRefreshIntervalSeconds", "shareProviderFetches", "providerRetryAttempts", "failureCooldownSeconds",
      "costScanTimeoutSeconds", "paceIndicatorStyle", "ringLayout", "nestedRingWidth", "ringSize", "ringWidth", "ringGap",
      "showProviderIcon", "showProviderName", "showRingValues", "showWindowLabels", "showRingTrack"])
      if (draft[key] !== undefined) update[key] = draft[key];
    try { Settings.validate(update); }
    catch (error) { validationError = error.message; return; }
    pageState.saveSettings(update, base);
  }
  Connections {
    target: root.pageState
    function onSettingsSaved() { root.stackController.pop(false); }
  }
  Keys.onEscapePressed: { if (editing >= 0) editing = -1; else root.stackController.pop(); }

  Shell.PanelBackground { anchors.fill: parent }
  Text {
    x: 20; y: 20; width: 236
    text: root.editing >= 0 ? Model.providerName(root.config?.provider) : "Settings"
    textFormat: Text.PlainText
    color: "white"; elide: Text.ElideRight
    font.family: Shell.Theme.titleFontFamily; font.pixelSize: 20
  }
  Shell.IconButton {
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Accessible.onPressAction: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    x: 262; y: 18; width: 32; height: 32
    iconSource: Qt.resolvedUrl("assets/back.svg")
    accessibleName: root.editing >= 0 ? "Back to providers" : "Back to usage"
    onClicked: { if (root.editing >= 0) root.editing = -1; else root.stackController.pop(); }
  }
  Row {
    x: 12; y: 72; spacing: 4
    visible: root.editing < 0
    Repeater {
      model: ["General", "Providers", "Appearance"]
      delegate: Rectangle {
        id: section
        required property string modelData
        required property int index
        width: 94; height: 32; radius: 10
        color: root.tab === index ? Shell.PanelStyle.pressed : hover.hovered ? Shell.PanelStyle.hover : "transparent"
        Text { anchors.centerIn: parent; text: section.modelData; color: "white"; opacity: root.tab === section.index ? 1 : 0.6; font.family: Shell.Theme.fontFamily; font.pixelSize: 11 }
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: { root.tab = section.index; viewport.contentY = 0; } }
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: modelData
        Accessible.onPressAction: root.tab = index
        Keys.onReturnPressed: root.tab = index
        Keys.onSpacePressed: root.tab = index
      }
    }
  }

  Flickable {
    id: viewport
    x: 20; y: root.editing >= 0 ? 76 : 120
    width: parent.width - 40
    height: parent.height - y - (root.error ? 104 : 72)
    contentHeight: fields.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    Column {
      id: fields
      width: viewport.width
      spacing: 12
      Column {
        width: parent.width; spacing: 12
        visible: root.tab === 0 && root.editing < 0
        Text { text: "CodexBar CLI"; color: "white"; opacity: 0.6; font.family: Shell.Theme.fontFamily; font.pixelSize: 11 }
        Shell.Field {
          width: parent.width
          text: root.draft.cliPath || ""
          placeholderText: "Automatic CLI path"
          onTextChanged: root.patch("cliPath", text)
          Accessible.name: "CodexBar CLI path"
        }
        SettingNumber { width: parent.width; text: "Refresh interval, seconds"; minimum: 60; maximum: 86400; step: 30; value: root.draft.refreshIntervalSeconds || 150; onChanged: value => root.patch("refreshIntervalSeconds", value) }
        SettingNumber { width: parent.width; text: "CLI timeout, seconds"; minimum: 5; maximum: 300; step: 5; value: root.draft.timeoutSeconds || 60; onChanged: value => root.patch("timeoutSeconds", value) }
        SettingToggle { width: parent.width; text: "Fetch provider status"; checked: root.draft.includeStatus !== false; onToggled: value => root.patch("includeStatus", value) }
        SettingToggle { width: parent.width; text: "Share matching usage fetches"; checked: root.draft.shareProviderFetches !== false; onToggled: value => root.patch("shareProviderFetches", value) }
        SettingNumber { width: parent.width; text: "Cost refresh, seconds"; minimum: 300; maximum: 604800; step: 300; value: root.draft.costRefreshIntervalSeconds || 3600; onChanged: value => root.patch("costRefreshIntervalSeconds", value) }
        SettingNumber { width: parent.width; text: "Provider attempts"; minimum: 1; maximum: 4; value: root.draft.providerRetryAttempts || 2; onChanged: value => root.patch("providerRetryAttempts", value) }
        SettingNumber { width: parent.width; text: "Failure cooldown, seconds"; minimum: 30; maximum: 3600; step: 30; value: root.draft.failureCooldownSeconds || 180; onChanged: value => root.patch("failureCooldownSeconds", value) }
        SettingNumber { width: parent.width; text: "Cost scan timeout, seconds"; minimum: 60; maximum: 1800; step: 60; value: root.draft.costScanTimeoutSeconds || 300; onChanged: value => root.patch("costScanTimeoutSeconds", value) }
        SettingToggle { width: parent.width; text: "Show spend history"; checked: root.draft.cost !== false; onToggled: value => root.patch("cost", value) }
        SettingToggle { width: parent.width; text: "Show credits"; checked: root.draft.credits !== false; onToggled: value => root.patch("credits", value) }
        SettingToggle { width: parent.width; text: "Mask account email"; checked: root.draft.anonymizeEmail !== false; onToggled: value => root.patch("anonymizeEmail", value) }
        SettingToggle { width: parent.width; text: "Update managed CLI"; checked: root.draft.autoUpdateCli === true; onToggled: value => root.patch("autoUpdateCli", value) }
      }
      Column {
        width: parent.width; spacing: 12
        visible: root.tab === 2 && root.editing < 0
        SettingNumber { width: parent.width; text: "Sidebar provider rows"; minimum: 0; maximum: 8; value: root.draft.expandedRows === undefined ? 3 : root.draft.expandedRows; onChanged: value => root.patch("expandedRows", value) }
        Text { width: parent.width; text: "0 shows all providers. Extra providers appear as a count."; color: "white"; opacity: 0.5; wrapMode: Text.Wrap; font.family: Shell.Theme.fontFamily; font.pixelSize: 11 }
        Text { text: "Ring layout"; color: "white"; opacity: 0.6; font.family: Shell.Theme.fontFamily; font.pixelSize: 11 }
        SettingChoice {
          width: parent.width
          value: root.draft.ringLayout || "separate"
          options: [{value: "separate", label: "Separate rings"}, {value: "nested", label: "Nested rings"}]
          Accessible.name: "Ring layout"
          onPicked: value => root.patch("ringLayout", value)
        }
        SettingChoice {
          width: parent.width
          visible: root.draft.ringLayout === "nested"
          value: root.draft.nestedRingWidth || "equal"
          options: [{value: "equal", label: "Equal ring widths"}, {value: "decreasing", label: "Thinner inner rings"}]
          Accessible.name: "Nested ring width"
          onPicked: value => root.patch("nestedRingWidth", value)
        }
        SettingNumber { width: parent.width; text: "Ring size, pixels"; minimum: 24; maximum: 44; step: 2; value: root.draft.ringSize || (root.draft.ringLayout === "nested" ? 40 : 28); onChanged: value => root.patch("ringSize", value) }
        SettingNumber { width: parent.width; text: "Ring width, pixels"; minimum: 1; maximum: 5; value: root.draft.ringWidth || 2; onChanged: value => root.patch("ringWidth", value) }
        SettingNumber { width: parent.width; visible: root.draft.ringLayout === "nested"; text: "Ring gap, pixels"; minimum: 0; maximum: 4; value: root.draft.ringGap === undefined ? 1 : root.draft.ringGap; onChanged: value => root.patch("ringGap", value) }
        Text { width: parent.width; visible: root.draft.ringLayout === "nested"; text: "The shortest window is the outer ring. Widths and gaps scale down when needed to fit all rings."; color: "white"; opacity: 0.5; wrapMode: Text.Wrap; font.family: Shell.Theme.fontFamily; font.pixelSize: 11 }
        SettingToggle { width: parent.width; text: "Show provider icons"; checked: root.draft.showProviderIcon !== false; onToggled: value => root.patch("showProviderIcon", value) }
        SettingToggle { width: parent.width; text: "Show provider names"; checked: root.draft.showProviderName !== false; onToggled: value => root.patch("showProviderName", value) }
        SettingToggle { width: parent.width; text: "Show ring values"; checked: root.draft.showRingValues !== false; onToggled: value => root.patch("showRingValues", value) }
        SettingToggle { width: parent.width; text: "Show window labels"; checked: root.draft.showWindowLabels !== false; onToggled: value => root.patch("showWindowLabels", value) }
        SettingToggle { width: parent.width; text: "Show ring tracks"; checked: root.draft.showRingTrack !== false; onToggled: value => root.patch("showRingTrack", value) }
        SettingNumber { width: parent.width; text: "Rings per provider"; minimum: 1; maximum: 6; value: root.draft.cardBars || 2; onChanged: value => root.patch("cardBars", value) }
        SettingToggle { width: parent.width; text: "Start with provider rows"; checked: root.draft.expanded !== false; onToggled: value => root.patch("expanded", value) }
        SettingToggle { width: parent.width; text: "Show daily spend chart"; checked: root.draft.history !== false; onToggled: value => root.patch("history", value) }
        Text { text: "Circular pace marker"; color: "white"; opacity: 0.6; font.family: Shell.Theme.fontFamily; font.pixelSize: 11 }
        SettingChoice {
          width: parent.width
          value: root.draft.paceIndicatorStyle || "position"
          options: [{value: "position", label: "Time remaining color"}, {value: "bar", label: "Usage color"},
            {value: "provider", label: "Provider color"}, {value: "theme", label: "Theme text color"},
            {value: "gaps", label: "Gap only"}, {value: "off", label: "Hidden"}]
          Accessible.name: "Pace marker style"
          onPicked: value => root.patch("paceIndicatorStyle", value)
        }
        Text { width: parent.width; text: "The arc shows budget left. The tick shows time left. An arc past the tick has reserve."; color: "white"; opacity: 0.5; wrapMode: Text.Wrap; font.family: Shell.Theme.fontFamily; font.pixelSize: 11 }
        Text { width: parent.width; text: "Colors and fonts follow the Pond theme."; color: "white"; opacity: 0.5; wrapMode: Text.Wrap; font.family: Shell.Theme.fontFamily; font.pixelSize: 11 }
      }
      Column {
        width: parent.width; spacing: 10
        visible: root.tab === 1 && root.editing < 0
        Text { width: parent.width; text: "Enable the providers you use. Select a row to set its source and account."; color: "white"; opacity: 0.6; wrapMode: Text.Wrap; font.family: Shell.Theme.fontFamily; font.pixelSize: 11 }
        Repeater {
          model: root.providers
          delegate: Rectangle {
            id: providerRow
            required property var modelData
            required property int index
            width: fields.width; height: 62; radius: 10
            color: rowHover.hovered ? Shell.PanelStyle.pressed : Shell.PanelStyle.hover
            ProviderIcon { x: 12; y: 22; size: 18; provider: providerRow.modelData.provider }
            Column {
              x: 40; y: 12; width: parent.width - 110; spacing: 5
              Text { width: parent.width; text: Model.providerName(providerRow.modelData.provider); textFormat: Text.PlainText; elide: Text.ElideRight; color: "white"; font.family: Shell.Theme.fontFamily; font.pixelSize: 12 }
              Text { width: parent.width; text: (providerRow.modelData.source || "auto") + " · " + (providerRow.modelData.allAccounts ? "All accounts" : providerRow.modelData.account || (providerRow.modelData.accountIndex ? "Account " + providerRow.modelData.accountIndex : "Active account")); textFormat: Text.PlainText; elide: Text.ElideRight; color: "white"; opacity: 0.5; font.family: Shell.Theme.fontFamily; font.pixelSize: 10 }
            }
            MouseArea {
              width: parent.width - 68; height: parent.height
              cursorShape: Qt.PointingHandCursor
              onClicked: { root.editing = providerRow.index; viewport.contentY = 0; }
            }
            Shell.Toggle {
              x: parent.width - 64; y: 17
              checked: providerRow.modelData.enabled !== false
              onToggled: value => {
                const rows = Settings.clone(root.providers); rows[providerRow.index].enabled = value;
                root.patch("providerConfigs", rows);
              }
              Accessible.role: Accessible.CheckBox
              Accessible.name: "Enable " + Model.providerName(providerRow.modelData.provider)
            }
            HoverHandler { id: rowHover }
          }
        }
        Text { text: "Add provider"; color: "white"; opacity: 0.6; font.family: Shell.Theme.fontFamily; font.pixelSize: 11 }
        SettingChoice {
          width: parent.width
          options: [{value: "", label: "Choose a provider..."}].concat(Settings.catalog.map(item => ({value: item.id, label: item.name})))
          onPicked: value => { if (value) { root.addProvider(value); viewport.contentY = 0; } }
        }
      }
      Column {
        width: parent.width; spacing: 10
        visible: root.editing >= 0
        SettingToggle { width: parent.width; text: "Enabled"; checked: root.config?.enabled !== false; onToggled: value => root.updateProvider("enabled", value) }
        Text { text: "Source"; color: "white"; opacity: 0.6; font.family: Shell.Theme.fontFamily; font.pixelSize: 11 }
        SettingChoice { objectName: "providerSource"; width: parent.width; options: Settings.sources(root.config?.provider); value: root.config?.source || "auto"; onPicked: value => root.updateProvider("source", value) }
        Text { visible: root.config?.provider !== "bedrock"; text: root.config?.provider === "devin" ? "Organization ID" : "Account"; color: "white"; opacity: 0.6; font.family: Shell.Theme.fontFamily; font.pixelSize: 11 }
        SettingChoice {
          visible: root.config?.provider !== "devin" && root.config?.provider !== "bedrock"
          width: parent.width; options: root.accountOptions()
          value: root.accountMode
          onPicked: value => root.selectAccount(value)
        }
        Shell.Field {
          visible: root.config?.provider !== "bedrock" && (root.accountMode === "named" || root.config?.provider === "devin")
          width: parent.width; text: root.config?.account || ""; placeholderText: root.config?.provider === "devin" ? "Organization ID (optional)" : "Account name or email"
          onTextChanged: if (root.config && root.config.account !== text) root.updateProvider("account", text)
          Accessible.name: "Account name or email"
        }
        SettingNumber {
          visible: root.accountMode === "index" && root.config?.provider !== "bedrock"
          width: parent.width; text: "Account index"; minimum: 1; maximum: 100
          value: root.config?.accountIndex || 1
          onChanged: value => root.updateProvider("accountIndex", value)
        }
        ActionButton {
          width: parent.width
          visible: root.config?.provider !== "bedrock" && root.config?.provider !== "devin"
          text: root.pageState.discoveringAccounts ? "Detecting accounts..." : "Detect accounts"
          interactive: !root.pageState.discoveringAccounts
          onClicked: root.pageState.discoverAccounts(Settings.clone(root.config))
        }
        Text {
          width: parent.width
          visible: root.pageState.accountError !== ""
          text: root.pageState.accountError || ""
          textFormat: Text.PlainText
          color: "#FA9CA7"; wrapMode: Text.Wrap
          font.family: Shell.Theme.fontFamily; font.pixelSize: 11
        }
        Column {
          width: parent.width; spacing: 8
          visible: root.config?.source === "api" && root.config?.provider !== "bedrock" || root.config?.provider === "devin"
          Text { text: root.config?.provider === "claude" ? "Admin API key" : "API key or token"; color: "white"; opacity: 0.6; font.family: Shell.Theme.fontFamily; font.pixelSize: 11 }
          Shell.Field {
            objectName: "providerKey"
          width: parent.width; password: true
            text: root.config?.apiKey || ""; placeholderText: "Use existing credentials"
            onTextChanged: if (root.config && root.config.apiKey !== text) root.updateProvider("apiKey", text)
            Accessible.name: "Provider API key or token"
          }
          Text { width: parent.width; text: "Leave empty to use the CLI configuration or environment."; wrapMode: Text.Wrap; color: "white"; opacity: 0.5; font.family: Shell.Theme.fontFamily; font.pixelSize: 10 }
        }
        Text {
          width: parent.width; visible: root.config?.provider === "bedrock"
          text: "Uses the AWS credentials and profile configured for this session."
          wrapMode: Text.Wrap; color: "white"; opacity: 0.6
          font.family: Shell.Theme.fontFamily; font.pixelSize: 11
        }
        Column {
          width: parent.width; spacing: 8
          visible: root.config?.provider === "antigravity" && ["auto", "native", "native-auth"].includes(root.config?.source)
          Text { width: parent.width; text: "Sign in opens your browser."; wrapMode: Text.Wrap; color: "white"; opacity: 0.6; font.family: Shell.Theme.fontFamily; font.pixelSize: 11 }
          Row {
            spacing: 8
            ActionButton { width: (fields.width - 8) / 2; text: root.pageState.authenticating ? "Please wait..." : "Sign in"; interactive: !root.pageState.authenticating; onClicked: root.pageState.authenticate("login") }
            ActionButton { width: (fields.width - 8) / 2; text: "Sign out"; interactive: !root.pageState.authenticating; onClicked: root.pageState.authenticate("logout") }
          }
          Text { width: parent.width; visible: !!root.pageState.authMessage; text: root.pageState.authMessage || ""; textFormat: Text.PlainText; wrapMode: Text.Wrap; color: "white"; opacity: 0.6; font.family: Shell.Theme.fontFamily; font.pixelSize: 11 }
        }
        Text {
          width: parent.width
          text: "Use global refresh and retry settings, or set values for this provider. Manual refresh updates all providers."
          wrapMode: Text.Wrap; color: "white"; opacity: 0.6
          font.family: Shell.Theme.fontFamily; font.pixelSize: 11
        }
        SettingToggle {
          objectName: "providerRefreshOverride"
          width: parent.width; text: "Separate refresh interval"
          checked: (root.config?.refreshIntervalSeconds || 0) > 0
          onToggled: value => root.updateProvider("refreshIntervalSeconds", value ? root.draft.refreshIntervalSeconds || 150 : 0)
        }
        SettingNumber {
          objectName: "providerRefreshInterval"
          visible: (root.config?.refreshIntervalSeconds || 0) > 0
          width: parent.width; text: "Refresh interval, seconds"; minimum: 60; maximum: 86400; step: 30
          value: root.config?.refreshIntervalSeconds || 150
          onChanged: value => root.updateProvider("refreshIntervalSeconds", value)
        }
        SettingToggle {
          objectName: "providerRetryOverride"
          width: parent.width; text: "Separate retry attempts"
          checked: (root.config?.providerRetryAttempts || 0) > 0
          onToggled: value => root.updateProvider("providerRetryAttempts", value ? root.draft.providerRetryAttempts || 2 : 0)
        }
        SettingNumber {
          objectName: "providerRetryAttempts"
          visible: (root.config?.providerRetryAttempts || 0) > 0
          width: parent.width; text: "Attempts, including first try"; minimum: 1; maximum: 4
          value: root.config?.providerRetryAttempts || 2
          onChanged: value => root.updateProvider("providerRetryAttempts", value)
        }
        SettingToggle {
          objectName: "providerCooldownOverride"
          width: parent.width; text: "Separate failure cooldown"
          checked: (root.config?.failureCooldownSeconds || 0) > 0
          onToggled: value => root.updateProvider("failureCooldownSeconds", value ? root.draft.failureCooldownSeconds || 180 : 0)
        }
        SettingNumber {
          objectName: "providerFailureCooldown"
          visible: (root.config?.failureCooldownSeconds || 0) > 0
          width: parent.width; text: "Maximum cooldown, seconds"; minimum: 30; maximum: 3600; step: 30
          value: root.config?.failureCooldownSeconds || 180
          onChanged: value => root.updateProvider("failureCooldownSeconds", value)
        }
        SettingToggle { width: parent.width; text: "Include spend history"; checked: root.config?.includeCost !== false; onToggled: value => root.updateProvider("includeCost", value) }
        Row {
          spacing: 8
          ActionButton { width: (fields.width - 8) / 2; text: "Move up"; interactive: root.editing > 0; onClicked: root.moveProvider(-1) }
          ActionButton { width: (fields.width - 8) / 2; text: "Move down"; interactive: root.editing < root.providers.length - 1; onClicked: root.moveProvider(1) }
        }
        ActionButton { width: parent.width; text: "Remove provider"; onClicked: root.removeProvider() }
      }
    }
  }
  Text {
    x: 20; y: parent.height - 100; width: parent.width - 40
    visible: root.error !== ""
    text: root.error; textFormat: Text.PlainText; wrapMode: Text.Wrap
    color: "#FA9CA7"; font.family: Shell.Theme.fontFamily; font.pixelSize: 10
  }
  Row {
    x: 20; y: parent.height - 56; spacing: 8
    ActionButton { width: 134; text: "Cancel"; interactive: !root.pageState.savingSettings; onClicked: root.stackController.pop() }
    ActionButton { objectName: "applySettings"; width: 134; text: root.pageState.savingSettings ? "Saving..." : "Apply"; interactive: !root.pageState.savingSettings; onClicked: root.apply() }
  }
}
