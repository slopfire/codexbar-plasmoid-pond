"""Add CodexBar hooks to Pond without replacing unrelated shell code."""
import re


class IntegrationError(ValueError):
    pass


def closing(text, start):
    pairs = {"(": ")", "[": "]", "{": "}"}
    stack = [pairs[text[start]]]
    quote = None
    position = start + 1
    while position < len(text):
        char = text[position]
        if quote:
            if char == "\\":
                position += 2
                continue
            if char == quote:
                quote = None
        elif char in "\"'`":
            quote = char
        elif text.startswith("//", position):
            position = text.find("\n", position)
            if position < 0:
                break
            continue
        elif text.startswith("/*", position):
            position = text.find("*/", position + 2)
            if position < 0:
                break
            position += 2
            continue
        elif char in pairs:
            stack.append(pairs[char])
        elif char in ")]}" and char == stack[-1]:
            stack.pop()
            if not stack:
                return position
        position += 1
    raise IntegrationError("Pond contains an unclosed QML expression")


def replace_once(text, pattern, replacement, label):
    result, count = re.subn(pattern, lambda match: replacement(match), text, count=1, flags=re.M)
    if count != 1:
        raise IntegrationError("Cannot locate Pond's " + label + ". No files were changed.")
    return result


def expression(text, name, update):
    match = re.search(r"^  readonly property (?:bool|var) " + re.escape(name) + r": ([^\n]*(?:\n      [^\n]*)*)", text, re.M)
    if not match:
        raise IntegrationError("Cannot locate Pond's " + name + " property")
    value = update(match.group(1))
    return text[:match.start(1)] + value + text[match.end(1):]


def add_call_argument(text, prefix, token, argument):
    start = text.find(prefix)
    if start < 0:
        raise IntegrationError("Cannot locate Pond expression " + prefix)
    opening = text.index("(", start)
    end = closing(text, opening)
    if token not in text[opening:end]:
        text = text[:end] + ",\n      " + argument + text[end:]
    return text


STATE = '''  // CodexBar integration. The module is maintained by codexbar-pond.
  property bool codexbarExpandedView: codexbarState.expandedCard
  Codexbar.State {
    id: codexbarState
    wanted: true
  }
  readonly property bool codexbarCommandOutput: root.screen.name === (NiriMsg.focusedOutputName
      || Quickshell.screens[0]?.name || "")
  Connections {
    target: Codexbar.Commands
    function onToggleRequested() {
      if (root.codexbarCommandOutput) root.togglePanel("codexbar");
    }
    function onRefreshRequested() {
      if (root.codexbarCommandOutput) codexbarState.refreshSoon(true);
    }
    function onSettingsRequested() {
      if (!root.codexbarCommandOutput) return;
      if (!codexbarPanel.opened) root.togglePanel("codexbar");
      codexbarPanel.openSettings();
    }
  }

'''

CARD = '''    Codexbar.SidebarCard {
      id: codexbarCard
      state: codexbarState
      width: root.cardWidth
      collapseProgress: root.collapseProgress
      panelOpen: codexbarPanel.opened
      expandedView: root.codexbarExpandedView
      cardBars: codexbarState.cardBars
      expandedRows: codexbarState.expandedRows
      onFoldToggled: root.codexbarExpandedView = !root.codexbarExpandedView
      onTileClicked: entry => {
        codexbarPanel.openProvider(entry);
        if (!codexbarPanel.opened) root.togglePanel("codexbar");
      }
    }

'''

PANEL = '''  Codexbar.UsagePanel {
    id: codexbarPanel
    state: codexbarState
    x: root.panelX
    z: 80
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Theme.sidebarOuterMargin
  }

'''


def integrate_sidebar(text):
    if 'import "codexbar" as Codexbar' not in text:
        text = replace_once(text, r'^import Quickshell\s*$', lambda m: m[0] + '\nimport "codexbar" as Codexbar', "Quickshell import")
    text = expression(text, "panelOpen", lambda value: value if "codexbarPanel.opened" in value else value + " || codexbarPanel.opened")
    def active(value):
        if "codexbarPanel.opened" in value:
            return value
        if not value.rstrip().endswith(": null"):
            raise IntegrationError("Pond's activePanel expression has changed")
        return value.rstrip()[:-6] + ": codexbarPanel.opened ? codexbarPanel : null"
    text = expression(text, "activePanel", active)
    def panels(value):
        if "codexbar:" in value:
            return value
        if not value.rstrip().endswith("})"):
            raise IntegrationError("Pond's panel map has changed")
        return value.rstrip()[:-2] + ", codexbar: codexbarPanel})"
    text = expression(text, "panels", panels)
    if "id: codexbarState" not in text:
        text = replace_once(text, r'^  function togglePopup\(', lambda m: STATE + m[0], "popup function")
    else:
        # Adopt the existing CodexBar integration without replacing its other hooks.
        connection = re.search(r'Connections\s*\{\s*target:\s*Codexbar.Commands', text)
        if not connection:
            raise IntegrationError("Existing CodexBar state has no command connection")
        opening = text.index("{", connection.start())
        end = closing(text, opening)
        if "onSettingsRequested" not in text[opening:end]:
            if not re.search(r'property bool codexbarCommandOutput:', text):
                predicate = ('  readonly property bool codexbarCommandOutput: root.screen.name === (NiriMsg.focusedOutputName\n'
                             '      || Quickshell.screens[0]?.name || "")\n')
                line = text.rfind("\n", 0, connection.start()) + 1
                text = text[:line] + predicate + text[line:]
                end += len(predicate)
            handler = '''    function onSettingsRequested() {
      if (!root.codexbarCommandOutput) return;
      if (!codexbarPanel.opened) root.togglePanel("codexbar");
      codexbarPanel.openSettings();
    }
  '''
            text = text[:end] + handler + text[end:]
    regions = re.search(r"regions:\s*\[", text)
    if not regions:
        raise IntegrationError("Cannot locate Pond's card blur regions")
    end = closing(text, text.index("[", regions.start()))
    if "codexbarCard.blurRegion" not in text[regions.start():end]:
        text = text[:end] + ", codexbarCard.blurRegion" + text[end:]
    text = add_call_argument(text, "Math.max(Theme.sidebarOuterMargin", "codexbarPanel.visible", "codexbarPanel.visible ? panelX + codexbarPanel.width + 67 : 0")
    text = add_call_argument(text, "Math.max(root.cardWidth", "codexbarCard.width", "codexbarCard.width")
    minimap = text.find("id: workspacesCard")
    maximum = text.find("maximumHeight:", minimap)
    if minimap < 0 or maximum < 0:
        raise IntegrationError("Cannot locate Pond's workspace height calculation")
    opening = text.index("(", maximum)
    end = closing(text, opening)
    value = text[opening:end]
    if "codexbarCard.height" not in value:
        value = replace_once(value, r'- notificationCard\.height', lambda m: m[0] + " - codexbarCard.height - Theme.sidebarCardGap", "notification height")
    elif not re.search(r'codexbarCard\.height\s*-\s*Theme.sidebarCardGap', value):
        value = value.replace("- codexbarCard.height", "- codexbarCard.height - Theme.sidebarCardGap", 1)
    text = text[:opening] + value + text[end:]
    if "id: codexbarCard" not in text:
        text = replace_once(text, r'^    Installs.SidebarCard\s*\{', lambda m: CARD + m[0], "Installs card")
    if "id: codexbarPanel" not in text:
        text = replace_once(text, r'^  Column\s*\{\n    id: bottomStack', lambda m: PANEL + m[0], "bottom stack")
    for token in ["id: codexbarState", "id: codexbarCard", "id: codexbarPanel", "onSettingsRequested"]:
        if text.count(token) != 1:
            raise IntegrationError("Expected exactly one " + token)
    return text


def integrate_shell(text):
    text = text.replace('import "codexbar/State.qml" as CodexbarState', 'import "codexbar" as Codexbar')
    if 'import "codexbar" as Codexbar' not in text:
        text = replace_once(text, r'^import Quickshell.Io\s*$', lambda m: m[0] + '\nimport "codexbar" as Codexbar', "IPC import")
    target = re.search(r'IpcHandler\s*\{\s*(?:id:\s*\w+\s*)?target:\s*"codexbar"', text)
    if target:
        opening = text.index("{", target.start())
        end = closing(text, opening)
        block = text[opening:end]
        block = block.replace("CodexbarState.State.refreshRequested()", "Codexbar.Commands.refreshRequested()")
        for action, signal in [("toggle", "toggleRequested"), ("refresh", "refreshRequested"), ("settings", "settingsRequested")]:
            if not re.search(r'function\s+' + action + r'\s*\(', block):
                block += '\n    function ' + action + '() { Codexbar.Commands.' + signal + '(); }\n  '
        text = text[:opening] + block + text[end:]
    else:
        block = '''  IpcHandler {
    target: "codexbar"
    function toggle() { Codexbar.Commands.toggleRequested(); }
    function refresh() { Codexbar.Commands.refreshRequested(); }
    function settings() { Codexbar.Commands.settingsRequested(); }
  }

'''
        text = replace_once(text, r'^  Variants\s*\{', lambda m: block + m[0], "screen variants")
    return text
