pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import "CodexBarModel.mjs" as Model
import ".." as Shell

Item {
  id: root

  required property var state
  required property var theme
  property int bars: 2
  property int maxRows: 3
  signal rowClicked(var entry)

  readonly property var entries: state.ordered || []
  readonly property int limit: maxRows > 0 ? maxRows : entries.length
  readonly property var rows: entries.slice(0, limit)
  readonly property int hiddenCount: Math.max(0, entries.length - rows.length)
  readonly property int rowHeight: 56
  readonly property int columns: Math.max(1, Math.min(bars, Math.floor((width - 44) / 40)))
  implicitHeight: rows.length * rowHeight + (hiddenCount > 0 ? 24 : 0)

  Repeater {
    model: root.rows
    delegate: FocusScope {
      id: line
      required property var modelData
      required property int index
      readonly property var entry: modelData
      readonly property var gauges: Model.sidebarRings(entry, root.columns)
      readonly property string status: Model.stateText(entry)
      readonly property bool failed: Model.isErrorOnly(entry)
      x: 0
      y: index * root.rowHeight
      width: root.width
      height: root.rowHeight
      activeFocusOnTab: true
      Accessible.role: Accessible.Button
      Accessible.name: Model.accessibleLabel({ entry: entry, rings: gauges }, root.state.nowMs)
      Controls.ToolTip {
        id: rowTip
        visible: pointer.hovered || line.activeFocus
        delay: 500
        text: line.Accessible.name
        contentItem: Text { text: rowTip.text; font: rowTip.font; color: rowTip.palette.toolTipText; textFormat: Text.PlainText; wrapMode: Text.Wrap }
      }
      Accessible.onPressAction: root.rowClicked(line.entry)
      Keys.onReturnPressed: root.rowClicked(line.entry)
      Keys.onSpacePressed: root.rowClicked(line.entry)

      Rectangle {
        anchors.fill: parent
        radius: Shell.PanelStyle.rowRadius
        color: pointer.hovered || line.activeFocus ? Shell.Theme.sidebarHoverFill : Shell.Theme.sidebarClearFill
        border.width: line.activeFocus ? 1 : 0
        border.color: root.theme.ink
        Behavior on color { ColorAnimation { duration: Shell.Theme.sidebarHoverDuration; easing.type: Easing.OutCubic } }
      }

      Item {
        width: 44
        height: parent.height
        ProviderIcon {
          anchors.horizontalCenter: parent.horizontalCenter
          y: 10
          size: 18
          provider: line.entry.provider
          color: root.theme.ink
          markOpacity: line.failed ? 0.45 : 0.9
        }
        Text {
          x: 0
          y: 33
          width: parent.width
          text: Model.shortName(line.entry.provider)
          textFormat: Text.PlainText
          color: root.theme.ink
          opacity: 0.72
          font.family: Shell.Theme.fontFamily
          font.pixelSize: 9
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }
        Rectangle {
          x: 32
          y: 8
          width: 4
          height: 4
          radius: 2
          visible: line.status !== ""
          color: line.failed ? root.theme.red : root.theme.yellow
        }
      }

      Row {
        x: 44
        y: 6
        spacing: 0
        Repeater {
          model: line.gauges
          delegate: Item {
            id: gauge
            required property var modelData
            width: (line.width - 44) / root.columns
            height: 46
            Ring {
              anchors.horizontalCenter: parent.horizontalCenter
              width: 29
              height: 29
              value: gauge.modelData.value
              color: Model.sidebarRingColor(line.entry, gauge.modelData.row, root.theme)
              trackColor: root.theme.track
              timeLeft: Model.windowLeft(gauge.modelData.row, root.state.nowMs)
              markerStyle: root.state.settings?.paceIndicatorStyle || "position"
              tickColor: Model.paceMarkerColor(gauge.modelData.row, line.entry, markerStyle, root.theme, root.state.nowMs)
              Text {
                anchors.centerIn: parent
                text: gauge.modelData.kind === "window"
                    ? String(Math.round(gauge.modelData.value)) : gauge.modelData.text
                textFormat: Text.PlainText
                color: root.theme.ink
                font.family: Shell.Theme.fontFamily
                font.pixelSize: text.length > 3 ? 8 : 10
                font.weight: Font.Medium
              }
            }
            Text {
              y: 33
              width: parent.width
              text: gauge.modelData.label
              textFormat: Text.PlainText
              color: root.theme.ink
              opacity: 0.5
              font.family: Shell.Theme.fontFamily
              font.pixelSize: 9
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
            }
          }
        }
      }

      Text {
        visible: line.gauges.length === 0
        x: 48
        width: Math.max(0, parent.width - x - 4)
        anchors.verticalCenter: parent.verticalCenter
        text: line.failed ? "Unavailable" : Model.headline(line.entry)?.text || "No limits"
        textFormat: Text.PlainText
        color: line.failed ? root.theme.red : root.theme.ink
        opacity: 0.7
        font.family: Shell.Theme.fontFamily
        font.pixelSize: 10
        elide: Text.ElideRight
      }
      HoverHandler { id: pointer; cursorShape: Qt.PointingHandCursor }
      TapHandler { onTapped: root.rowClicked(line.entry) }
    }
  }

  FocusScope {
    y: root.rows.length * root.rowHeight
    width: root.width
    height: 24
    visible: root.hiddenCount > 0
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: "Show " + root.hiddenCount + " more providers"
    Accessible.onPressAction: root.rowClicked(null)
    Keys.onReturnPressed: root.rowClicked(null)
    Keys.onSpacePressed: root.rowClicked(null)
    Text {
      anchors.centerIn: parent
      text: "+" + root.hiddenCount + " more"
      color: root.theme.ink
      opacity: morePointer.hovered || parent.activeFocus ? 1 : 0.6
      font.family: Shell.Theme.fontFamily
      font.pixelSize: 10
    }
    HoverHandler { id: morePointer; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.rowClicked(null) }
  }
}
