pragma ComponentBehavior: Bound

import QtQuick
import "CodexBarModel.mjs" as Model
import "RingLayout.mjs" as RingLayout
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
  readonly property var settings: state.settings || ({})
  readonly property bool nested: settings.ringLayout === "nested"
  readonly property bool showIcon: settings.showProviderIcon !== false
  readonly property bool showName: settings.showProviderName !== false
  readonly property bool showLabels: settings.showWindowLabels !== false
  readonly property real ringSize: RingLayout.diameter(settings)
  readonly property int identityWidth: showIcon || showName ? 44 : 0
  readonly property int nestedCount: nested ? Math.max(1, ...rows.map(entry => Model.sidebarRings(entry, bars).length)) : 1
  readonly property int accountCaptionHeight: entries.some(entry => entry.account &&
    entries.filter(item => item.provider === entry.provider).length > 1) ? 16 : 0
  readonly property int rowHeight: accountCaptionHeight + Math.max(showIcon && showName ? 56 : 36, ringSize + (showLabels ? 23 : 12),
    nested && (showLabels || settings.showRingValues !== false) ? nestedCount * 14 + 20 : 0)
  readonly property int columns: nested ? bars : Math.max(1, Math.min(bars, Math.floor((width - identityWidth) / (ringSize + 11))))
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
      PondToolTip {
        visible: pointer.hovered || line.activeFocus
        heading: [Model.providerName(line.entry.provider), line.entry.account].filter(Boolean).join(" · ")
        text: Model.providerTooltip({entry: line.entry, rings: line.gauges}, root.state.nowMs)
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

      Text {
        objectName: "sidebarAccount"
        visible: root.accountCaptionHeight > 0
        x: 4; width: parent.width - 8; height: root.accountCaptionHeight
        text: line.entry.account || Model.shortName(line.entry.provider)
        textFormat: Text.PlainText
        color: root.theme.ink; opacity: 0.7
        font.family: Shell.Theme.fontFamily; font.pixelSize: 9
        elide: Text.ElideRight
      }
      Item {
        y: root.accountCaptionHeight
        width: parent.width
        height: parent.height - root.accountCaptionHeight
        Item {
          visible: !root.nested
          width: root.identityWidth
          height: parent.height
          ProviderIcon {
            objectName: "sidebarProviderIcon"
            visible: root.showIcon
            anchors.horizontalCenter: parent.horizontalCenter
            y: 10
            size: 18
            provider: line.entry.provider
            color: root.theme.ink
            markOpacity: line.failed ? 0.45 : 0.9
          }
          Text {
            x: 0
            visible: root.showName
            y: root.showIcon ? 33 : (parent.height - height) / 2
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
        }

        Rectangle {
          x: root.nested ? stack.x + stack.width - 3 : root.identityWidth > 0 ? 32 : parent.width - 6
          y: 8
          width: 4; height: 4; radius: 2
          visible: line.status !== ""
          color: line.failed ? root.theme.red : root.theme.yellow
        }
        RingStack {
          id: stack
          visible: root.nested
          x: root.showName || root.showLabels || root.settings.showRingValues !== false ? 4 : (parent.width - width) / 2
          y: (parent.height - height) / 2
          width: root.ringSize; height: width
          entry: line.entry
          rings: line.gauges
          theme: root.theme
          nowMs: root.state.nowMs
          settings: root.settings
          showValue: false
        }
        Column {
          visible: root.nested && line.gauges.length > 0
          x: stack.x + stack.width + 8
          width: Math.max(0, parent.width - x - 4)
          anchors.verticalCenter: parent.verticalCenter
          spacing: 4
          Text {
            visible: root.showName
            width: parent.width
            text: Model.shortName(line.entry.provider)
            color: root.theme.ink
            font.family: Shell.Theme.fontFamily; font.pixelSize: 10
            elide: Text.ElideRight
          }
          Text {
            objectName: "nestedRingLabels"
            visible: root.showLabels || root.settings.showRingValues !== false
            width: parent.width
            text: line.gauges.map(gauge => [root.showLabels ? gauge.label : "", root.settings.showRingValues !== false
              ? (gauge.kind === "window" ? Math.round(gauge.value) + "%" : gauge.text) : ""].filter(Boolean).join(" ")).join(" · ")
            color: root.theme.ink; opacity: 0.6
            font.family: Shell.Theme.fontFamily; font.pixelSize: 9
            wrapMode: Text.Wrap
          }
        }
        Row {
          visible: !root.nested
          x: root.identityWidth
          y: 6
          spacing: 0
          Repeater {
            model: line.gauges
            delegate: Item {
              id: gauge
              required property var modelData
              width: (line.width - root.identityWidth) / root.columns
              height: root.rowHeight - root.accountCaptionHeight - 10
              Ring {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.ringSize
                height: width
                stroke: root.settings.ringWidth || 2
                value: gauge.modelData.value
                color: Model.sidebarRingColor(line.entry, gauge.modelData.row, root.theme)
                trackColor: root.settings.showRingTrack === false ? "transparent" : root.theme.track
                timeLeft: Model.windowLeft(gauge.modelData.row, root.state.nowMs)
                markerStyle: root.state.settings?.paceIndicatorStyle || "position"
                tickColor: Model.paceMarkerColor(gauge.modelData.row, line.entry, markerStyle, root.theme, root.state.nowMs)
                Text {
                  objectName: "ringValue"
                  visible: root.settings.showRingValues !== false
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
                visible: root.showLabels
                y: root.ringSize + 4
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
          x: root.nested ? stack.x + stack.width + 8 : root.identityWidth + 4
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
