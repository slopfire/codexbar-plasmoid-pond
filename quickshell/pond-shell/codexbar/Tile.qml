pragma ComponentBehavior: Bound

import QtQuick
import "CodexBarModel.mjs" as Model
import "RingLayout.mjs" as RingLayout
import ".." as Shell

FocusScope {
  id: root
  required property var tile
  required property bool compact
  required property var theme
  required property real nowMs
  property string markerStyle: "position"
  property var settings: ({})
  readonly property bool nested: settings.ringLayout === "nested"
  readonly property real ringSize: RingLayout.diameter(settings)
  readonly property bool showName: settings.showProviderName !== false
  signal clicked

  readonly property var entry: tile ? tile.entry : null
  readonly property var row: Model.tightestRow(entry)
  readonly property bool failed: Model.isErrorOnly(entry)
  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: Model.accessibleLabel(tile, nowMs)
  PondToolTip {
    visible: pointer.hovered || root.activeFocus
    heading: [Model.providerName(root.entry?.provider), root.entry?.account].filter(Boolean).join(" · ")
    text: Model.providerTooltip(root.tile, root.nowMs)
  }
  Accessible.onPressAction: root.clicked()
  Keys.onReturnPressed: root.clicked()
  Keys.onSpacePressed: root.clicked()

  Rectangle {
    anchors.fill: parent
    radius: Shell.PanelStyle.rowRadius
    color: pointer.hovered || root.activeFocus ? Shell.Theme.sidebarHoverFill : Shell.Theme.sidebarClearFill
    border.width: root.activeFocus ? 1 : 0
    border.color: root.theme.ink
    Behavior on color { ColorAnimation { duration: Shell.Theme.sidebarHoverDuration; easing.type: Easing.OutCubic } }
  }
  Ring {
    visible: !root.nested
    anchors.horizontalCenter: parent.horizontalCenter
    y: root.compact ? (root.height - height) / 2 : 2
    width: root.ringSize
    height: width
    stroke: root.settings.ringWidth || 2
    value: root.tile?.rings?.[0]?.value || 0
    color: Model.sidebarRingColor(root.entry, root.row, root.theme, root.settings)
    trackColor: root.settings.showRingTrack === false ? "transparent" : root.theme.track
    timeLeft: Model.windowLeft(root.row, root.nowMs)
    markerStyle: root.markerStyle
    tickColor: Model.paceMarkerColor(root.row, root.entry, markerStyle, root.theme, root.nowMs, root.settings)
    ProviderIcon {
      objectName: "sidebarProviderIcon"
      visible: root.settings.showProviderIcon !== false
      anchors.centerIn: parent
      provider: root.entry ? String(root.entry.provider) : ""
      size: 15
      color: root.failed ? root.theme.red : root.theme.ink
      markOpacity: root.failed ? 0.6 : 0.9
    }
    Text {
      objectName: "ringValue"
      visible: root.settings.showProviderIcon === false && root.settings.showRingValues !== false
      anchors.centerIn: parent
      text: root.tile?.rings?.length ? (root.tile.rings[0].kind === "window"
        ? String(Math.round(root.tile.rings[0].value)) : root.tile.rings[0].text) : ""
      color: root.theme.ink
      font.family: Shell.Theme.fontFamily; font.pixelSize: 9
    }
  }
  RingStack {
    visible: root.nested
    anchors.horizontalCenter: parent.horizontalCenter
    y: root.compact ? (root.height - height) / 2 : 2
    width: root.ringSize; height: width
    entry: root.entry
    rings: root.tile?.rings || []
    theme: root.theme
    nowMs: root.nowMs
    settings: root.settings
  }
  Text {
    visible: !root.compact && root.showName
    y: root.ringSize + 6
    width: parent.width
    text: root.entry ? root.entry.profileName || (root.entry.accountSelection && root.entry.account) || Model.shortName(root.entry.provider) : ""
    textFormat: Text.PlainText
    color: root.theme.ink
    opacity: 0.7
    font.family: Shell.Theme.fontFamily
    font.pixelSize: 9
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
  }
  Rectangle {
    visible: root.entry && Model.stateText(root.entry) !== ""
    x: parent.width / 2 + 9
    y: root.compact ? 3 : 0
    width: 4
    height: 4
    radius: 2
    color: root.failed ? root.theme.red : root.theme.yellow
  }
  HoverHandler { id: pointer; cursorShape: Qt.PointingHandCursor }
  TapHandler { onTapped: root.clicked() }
}
