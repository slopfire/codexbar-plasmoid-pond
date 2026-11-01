pragma ComponentBehavior: Bound
import QtQuick
import ".." as Shell
import "CodexBarModel.mjs" as Model
import "CodexBarSettings.mjs" as Settings
import "codexbar-accounts.mjs" as Accounts

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
  readonly property string accountMode: Accounts.mode(config)
  property string pendingLogout: ""
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
    if (editing < 0 || !providers[editing]) return;
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
    return [{value: "active", label: "Follow active account"}, {value: "all", label: "All accounts"},
      {value: "selected", label: "Selected accounts"}, {value: "index", label: "Account index (advanced)"}];
  }
  function selectAccount(value, accounts) {
    if (editing < 0) return;
    const rows = Settings.clone(providers);
    rows[editing] = Accounts.selection(config, value, accounts);
    patch("providerConfigs", rows);
  }
  function accountCandidates() {
    const detected = pageState.accountRequest?.provider === config?.provider
      && pageState.accountRequest?.source === config?.source ? pageState.accountEntries || [] : [];
    return Accounts.candidates(config, detected);
  }
  function toggleAccount(name, checked) {
    const list = Accounts.selected(config);
    selectAccount("selected", checked ? list.concat([name])
      : list.filter(value => value.toLowerCase() !== name.toLowerCase()));
  }
  function addAccountProfile() {
    const rows = Settings.clone(providers);
    const next = Accounts.selection(config, "active", []);
    next.profileName = "New account";
    next.apiKey = "";
    rows.splice(editing + 1, 0, next);
    patch("providerConfigs", rows);
    editing += 1;
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
  onEditingChanged: { pendingLogout = ""; accountName.text = ""; }
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
              Text { width: parent.width; text: providerRow.modelData.profileName || Model.providerName(providerRow.modelData.provider); textFormat: Text.PlainText; elide: Text.ElideRight; color: "white"; font.family: Shell.Theme.fontFamily; font.pixelSize: 12 }
              Text { width: parent.width; text: (providerRow.modelData.source || "auto") + " · " + (Accounts.mode(providerRow.modelData) === "selected" ? Accounts.selected(providerRow.modelData).join(", ") || "Select accounts" : providerRow.modelData.allAccounts ? "All accounts" : providerRow.modelData.accountIndex ? "Account " + providerRow.modelData.accountIndex : "Active account"); textFormat: Text.PlainText; elide: Text.ElideRight; color: "white"; opacity: 0.5; font.family: Shell.Theme.fontFamily; font.pixelSize: 10 }
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
        Shell.Field {
          visible: root.config?.source === "api" || !!root.config?.profileName
          width: parent.width; text: root.config?.profileName || ""; placeholderText: "Account label, for example Work"
          onTextChanged: if (root.config && root.config.profileName !== text) root.updateProvider("profileName", text)
          Accessible.name: "Account label"
        }
        Text {
          visible: root.config?.provider === "devin"
          text: "Organization ID"; color: "white"; opacity: 0.6
          font.family: Shell.Theme.fontFamily; font.pixelSize: 11
        }
        Shell.Field {
          visible: root.config?.provider === "devin"
          width: parent.width; text: root.config?.account || ""; placeholderText: "Organization ID (optional)"
          onTextChanged: if (root.config && root.config.account !== text) root.updateProvider("account", text)
          Accessible.name: "Organization ID"
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
        Column {
          width: parent.width; spacing: 8
          visible: !["devin", "bedrock", "demo"].includes(root.config?.provider)
          Text { text: "Accounts"; color: "white"; opacity: 0.6; font.family: Shell.Theme.fontFamily; font.pixelSize: 11 }
          SettingChoice {
            objectName: "accountMode"
            width: parent.width; options: root.accountOptions()
            value: root.accountMode
            Accessible.name: "Accounts to show"
            onPicked: value => root.selectAccount(value)
          }
          Text {
            width: parent.width
            text: root.config?.source === "api" ? "Use a saved account name, or add another account profile for a separate API key. Add account names by hand for this source."
              : root.accountMode === "active" ? "Follows the account signed in to the provider. This does not switch the provider's login."
              : root.accountMode === "all" ? "Shows every account the source can read. Some sources only return the active account."
              : "Select the accounts to show. Add a name if detection does not find it."
            wrapMode: Text.Wrap; color: "white"; opacity: 0.5; font.family: Shell.Theme.fontFamily; font.pixelSize: 10
          }
          Repeater {
            model: root.accountMode === "selected" ? root.accountCandidates() : []
            delegate: SettingToggle {
              required property string modelData
              width: parent.width; text: modelData
              checked: Accounts.selected(root.config).some(name => name.toLowerCase() === modelData.toLowerCase())
              onToggled: value => root.toggleAccount(modelData, value)
            }
          }
          Shell.Field {
            id: accountName
            visible: root.accountMode === "selected"
            width: parent.width; placeholderText: "Account name or email"
            Accessible.name: "Account name or email"
          }
          ActionButton {
            visible: root.accountMode === "selected"
            width: parent.width; text: "Add account name"
            interactive: accountName.text.trim().length > 0
            onClicked: { root.toggleAccount(accountName.text, true); accountName.text = ""; }
          }
          Text {
            width: parent.width
            visible: root.accountMode === "selected" && Accounts.selected(root.config).length === 0
            text: "Select at least one account before you apply."
            wrapMode: Text.Wrap; color: "#FA9CA7"; font.family: Shell.Theme.fontFamily; font.pixelSize: 11
          }
          SettingNumber {
            visible: root.accountMode === "index"
            width: parent.width; text: "Account index"; minimum: 1; maximum: 1000
            value: root.config?.accountIndex || 1
            onChanged: value => root.updateProvider("accountIndex", value)
          }
          ActionButton {
            width: parent.width; text: root.pageState.discoveringAccounts ? "Detecting accounts..." : "Detect accounts"
            interactive: !root.pageState.discoveringAccounts && root.config?.source !== "api"
            onClicked: root.pageState.discoverAccounts(Settings.clone(root.config))
          }
          Text {
            width: parent.width
            visible: root.pageState.accountRequest?.provider === root.config?.provider && root.pageState.accountError !== ""
            text: root.pageState.accountError || ""; textFormat: Text.PlainText
            color: "#FA9CA7"; wrapMode: Text.Wrap
            font.family: Shell.Theme.fontFamily; font.pixelSize: 11
          }
        }
        ActionButton { width: parent.width; text: "Add another account profile"; onClicked: root.addAccountProfile() }
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
            ActionButton { width: (fields.width - 8) / 2; text: "Sign out selected"; interactive: !root.pageState.authenticating && root.accountMode === "selected" && Accounts.selected(root.config).length === 1
              onClicked: root.pendingLogout = Accounts.selected(root.config)[0] }
          }
          Column {
            width: parent.width; spacing: 8
            visible: root.pendingLogout !== ""
            Text { width: parent.width; text: "Sign out " + root.pendingLogout + "? This removes its saved login on this device."; textFormat: Text.PlainText; wrapMode: Text.Wrap; color: "white"; font.family: Shell.Theme.fontFamily; font.pixelSize: 11 }
            ActionButton { width: parent.width; text: "Confirm sign out"; onClicked: { root.pageState.authenticate("logout", root.pendingLogout); root.pendingLogout = ""; } }
            ActionButton { width: parent.width; text: "Keep account"; onClicked: root.pendingLogout = "" }
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
