pragma ComponentBehavior: Bound
import QtQuick
import ".." as Shell
import "CodexBarModel.mjs" as Model
import "RingLayout.mjs" as RingLayout

Item {
  id: root
  required property var entry
  required property var rings
  required property var theme
  required property real nowMs
  property var settings: ({})
  property bool showIcon: settings.showProviderIcon !== false
  property bool showValue: !showIcon && settings.showRingValues !== false
  readonly property var geometry: RingLayout.nestedRings(rings.length, Math.min(width, height),
    settings.ringWidth || 2, settings.ringGap === undefined ? 1 : settings.ringGap,
    settings.nestedRingWidth || "equal", showIcon ? 16 : showValue ? 14 : 2)
  readonly property string markerStyle: settings.paceIndicatorStyle || "position"
  objectName: "ringStack"

  Repeater {
    model: root.geometry
    delegate: Ring {
      required property var modelData
      required property int index
      readonly property var gauge: root.rings[index] || ({value: 0, row: null})
      anchors.centerIn: parent
      width: modelData.size
      height: width
      stroke: modelData.stroke
      markerExtent: 0
      value: gauge.value
      color: Model.sidebarRingColor(root.entry, gauge.row, root.theme, root.settings)
      trackColor: root.settings.showRingTrack === false ? "transparent" : root.theme.track
      timeLeft: Model.windowLeft(gauge.row, root.nowMs)
      markerStyle: root.markerStyle
      tickColor: Model.paceMarkerColor(gauge.row, root.entry, markerStyle, root.theme, root.nowMs, root.settings)
    }
  }
  ProviderIcon {
    objectName: "sidebarProviderIcon"
    anchors.centerIn: parent
    visible: root.showIcon
    provider: root.entry ? root.entry.provider : ""
    size: 14
    color: Model.isErrorOnly(root.entry) ? root.theme.red : root.theme.ink
  }
  Text {
    objectName: "ringValue"
    anchors.centerIn: parent
    visible: root.showValue
    text: root.rings.length ? (root.rings[0].kind === "window"
      ? String(Math.round(root.rings[0].value)) : root.rings[0].text) : ""
    color: root.theme.ink
    font.family: Shell.Theme.fontFamily
    font.pixelSize: 9
  }
}
