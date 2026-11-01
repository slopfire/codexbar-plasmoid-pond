pragma ComponentBehavior: Bound

import QtQuick
import "CodexBarModel.mjs" as Model
import ".." as Shell

Shell.Card {
  id: root

  required property var state
  property real collapseProgress: 0
  property bool panelOpen: false
  property bool expandedView: true
  property int cardBars: Math.max(1, Math.min(6, Number(state.settings?.cardBars) || 2))
  property int expandedRows: 3
  signal tileClicked(var entry)
  signal foldToggled

  readonly property real widthProgress: Shell.Theme.collapseWidth(collapseProgress)
  readonly property real heightProgress: Shell.Theme.collapseHeight(collapseProgress)
  readonly property bool compact: collapseProgress >= 0.56
  readonly property bool loaded: state.loaded && (state.entries || []).length > 0
  readonly property var theme: ({
    ink: String(Shell.Theme.sidebarV3Foreground),
    yellow: "#EBE075",
    red: "#FA9CA7",
    track: Shell.Theme.daylight ? Qt.rgba(1, 1, 1, 0.16) : Shell.Theme.sidebarV3Control
  })
  readonly property string statusText: state.running ? "Refreshing"
      : state.failed || (state.entries || []).some(entry => entry.stale) ? "Stale"
      : Model.ageText(state.generatedAt, state.nowMs) === "now" ? "Updated now"
      : state.generatedAt ? Model.ageText(state.generatedAt, state.nowMs) + " ago" : "Usage left"
  readonly property real expandedHeight: loaded
      ? 8 + (expandedView ? rowList.implicitHeight : gallery.expandedHeight) + 26 : 76
  readonly property real compactHeight: loaded ? gallery.compactHeight : 48

  height: Shell.Theme.lerp(expandedHeight, compactHeight, heightProgress)
  implicitHeight: height
  radius: Shell.Theme.sidebarCardRadius
  classicColor: panelOpen ? Shell.Theme.mediaHoverBackground : Shell.Theme.sidebarV3Background
  animateClassicColor: true
  clip: true
  onYChanged: blurRegion.changed()
  onHeightChanged: blurRegion.changed()

  Behavior on height {
    enabled: root.collapseProgress === 0 || root.collapseProgress === 1
    Shell.Motion { duration: 200 }
  }

  ExpandedView {
    id: rowList
    visible: root.loaded && root.expandedView && !root.compact
    x: 8
    y: 8
    width: Math.max(0, root.width - 16)
    state: root.state
    theme: root.theme
    bars: root.cardBars
    maxRows: root.expandedRows
    onRowClicked: entry => root.tileClicked(entry)
  }

  Gallery {
    id: gallery
    visible: root.loaded && (root.compact || !root.expandedView)
    y: root.compact ? 0 : 8
    width: root.width
    state: root.state
    collapseProgress: root.collapseProgress
    theme: root.theme
    bars: root.cardBars
    maxTiles: 4
    onTileClicked: entry => root.tileClicked(entry)
  }

  Item {
    visible: root.loaded && !root.compact
    x: 12
    y: root.expandedHeight - 26
    width: Math.max(0, root.width - 24)
    height: 22
    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(0, parent.width - 22)
      text: root.statusText
      textFormat: Text.PlainText
      color: root.state.failed ? root.theme.red : root.theme.ink
      opacity: root.state.failed ? 0.9 : 0.5
      font.family: Shell.Theme.fontFamily
      font.pixelSize: 9
      elide: Text.ElideRight
    }
    Shell.IconButton {
      anchors.right: parent.right
      width: 22
      height: 22
      iconWidth: 10
      iconHeight: 10
      iconSource: Qt.resolvedUrl(root.expandedView ? "assets/chevron-up.svg" : "assets/chevron-down.svg")
      restingOpacity: 0.5
      accessibleName: root.expandedView ? "Show compact usage" : "Show provider rows"
      onClicked: root.foldToggled()
    }
  }

  FocusScope {
    anchors.fill: parent
    visible: !root.loaded
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: root.state.failed ? "Usage unavailable. Open CodexBar to retry" : "Open CodexBar"
    Accessible.onPressAction: root.tileClicked(null)
    Keys.onReturnPressed: root.tileClicked(null)
    Keys.onSpacePressed: root.tileClicked(null)
    ProviderIcon {
      provider: "codex"
      size: 20
      x: root.compact ? (parent.width - width) / 2 : 12
      anchors.verticalCenter: parent.verticalCenter
      markOpacity: 0.55
    }
    Text {
      visible: !root.compact
      x: 40
      width: Math.max(0, parent.width - x - 8)
      anchors.verticalCenter: parent.verticalCenter
      text: root.state.running ? "Reading usage" : root.state.failed ? "Usage unavailable" : "Open CodexBar"
      color: root.theme.ink
      opacity: 0.65
      font.family: Shell.Theme.fontFamily
      font.pixelSize: 11
      wrapMode: Text.Wrap
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.tileClicked(null) }
  }
}
