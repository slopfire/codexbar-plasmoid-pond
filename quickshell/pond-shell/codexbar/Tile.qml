pragma ComponentBehavior: Bound

import QtQuick
import "CodexBarModel.mjs" as Model
import ".." as Shell

FocusScope {
  id: root
  required property var tile
  required property bool compact
  required property var theme
  required property real nowMs
  property string markerStyle: "position"
  signal clicked

  readonly property var entry: tile ? tile.entry : null
  readonly property var row: Model.tightestRow(entry)
  readonly property bool failed: Model.isErrorOnly(entry)
  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: Model.accessibleLabel(tile, nowMs)
  PondToolTip {
    visible: pointer.hovered || root.activeFocus
    heading: Model.providerName(root.entry?.provider)
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
    anchors.horizontalCenter: parent.horizontalCenter
    y: root.compact ? (root.height - height) / 2 : 2
    width: 28
    height: 28
    stroke: 2
    value: root.tile?.rings?.[0]?.value || 0
    color: Model.sidebarRingColor(root.entry, root.row, root.theme)
    trackColor: root.theme.track
    timeLeft: Model.windowLeft(root.row, root.nowMs)
    markerStyle: root.markerStyle
    tickColor: Model.paceMarkerColor(root.row, root.entry, markerStyle, root.theme, root.nowMs)
    ProviderIcon {
      anchors.centerIn: parent
      provider: root.entry ? String(root.entry.provider) : ""
      size: 15
      color: root.failed ? root.theme.red : root.theme.ink
      markOpacity: root.failed ? 0.6 : 0.9
    }
  }
  Text {
    visible: !root.compact
    y: 34
    width: parent.width
    text: root.entry ? Model.shortName(root.entry.provider) : ""
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
