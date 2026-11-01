pragma ComponentBehavior: Bound

import QtQuick
import "../" as Pond

// CodexBar usage drawer.
//
// `state` is required: the sidebar owns the only instance and passes it down.
//
// Same card stack as the Wi-Fi panel: 316 px pages, a 20 px close-button
// gutter, push and pop transitions. The first page lists every provider, worst
// first. Picking a row pushes the provider page. Opening the panel also puts
// the CLI to work: the helpers only run while a panel asks for a refresh.
//
// The root is the shell's CardStack, taken from the shell directory itself:
// a bare or path import of the file is not a type in this Quickshell build.
Pond.CardStack {
  id: root

  required property var state

  pageComponents: ({drawer: listComponent, provider: providerComponent, settings: settingsComponent})
  property var pendingEntry: null
  property bool selectionPending: false
  property bool settingsPending: false

  function openSettings() {
    pendingEntry = null;
    selectionPending = false;
    settingsPending = true;
    syncSelection();
  }

  // Apply queued clicks after Pond finishes its page transition.
  function openProvider(entry) {
    pendingEntry = entry || null;
    selectionPending = true;
    if (opened && !transitionRunning)
      applyPending();
  }

  function applyPending() {
    if (!opened || transitionRunning || !selectionPending)
      return;
    const entry = pendingEntry;
    if (!entry) {
      if (currentPage !== "drawer") {
        pop(false);
        return;
      }
    } else {
      // Return to the list before selecting another provider.
      if (currentPage !== "drawer") {
        pop(false);
        return;
      }
      if (root.state.entries.some(candidate => candidate.id === entry.id))
        push("provider", { id: entry.id, provider: entry.provider });
    }
    pendingEntry = null;
    selectionPending = false;
  }

  function syncSelection() {
    if (!opened || transitionRunning)
      return;
    if (settingsPending) {
      if (currentPage === "settings") { settingsPending = false; return; }
      if (currentPage !== "drawer") { pop(false); return; }
      settingsPending = false;
      push("settings", {});
      return;
    }
    if (selectionPending) {
      applyPending();
      return;
    }
    if (currentPage === "provider"
        && !root.state.entries.some(entry => entry.id === currentSelection.id))
      pop(false);
  }

  onTransitionRunningChanged: if (!transitionRunning) Qt.callLater(root.syncSelection)
  onOpenedChanged: {
    if (opened) {
      root.state.noteDemand();
      Qt.callLater(root.syncSelection);
    } else {
      selectionPending = false;
      settingsPending = false;
      pendingEntry = null;
    }
  }
  Connections {
    target: root.state
    function onEntriesChanged() { Qt.callLater(root.syncSelection); }
  }

  Component {
    id: listComponent
    List {
      pageState: root.state
    }
  }

  Component {
    id: settingsComponent
    SettingsPage { pageState: root.state }
  }

  Component {
    id: providerComponent
    ProviderPage {
      pageState: root.state
    }
  }
}
