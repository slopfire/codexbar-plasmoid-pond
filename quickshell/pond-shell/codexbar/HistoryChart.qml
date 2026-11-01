pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import "CodexBarModel.mjs" as Model
import ".." as Shell

Column {
  id: root
  property var points: []
  property var bars: []
  property bool interactive: true
  property int selectedIndex: -1
  readonly property bool costSeries: points.some(point => Number(point?.costUSD) > 0)
  readonly property int detailIndex: hoveredIndex >= 0 ? hoveredIndex : selectedIndex
  property int hoveredIndex: -1
  spacing: 8
  onPointsChanged: { selectedIndex = -1; hoveredIndex = -1; }

  Text {
    text: root.costSeries ? "Daily spend" : "Daily tokens"
    color: "white"; opacity: 0.5
    font.family: Shell.Theme.fontFamily; font.pixelSize: 11
  }

  Item {
    id: plot
    width: root.width; height: 68
    Repeater {
      id: days
      model: root.points
      delegate: Item {
        id: cell
        required property var modelData
        required property int index
        readonly property bool selected: root.detailIndex === index
        readonly property real value: Math.max(0, Math.min(1, Number(root.bars[index]) || 0))
        readonly property bool hasReset: (modelData?.limitResets?.length || 0) > 0
        x: index * plot.width / Math.max(1, root.points.length)
        width: plot.width / Math.max(1, root.points.length)
        height: plot.height
        activeFocusOnTab: root.interactive
        Accessible.role: Accessible.Button
        Accessible.name: Model.historyTooltip(modelData)
        Accessible.onPressAction: if (root.interactive) root.selectedIndex = index
        onActiveFocusChanged: if (activeFocus) root.selectedIndex = index
        Keys.onLeftPressed: event => {
          if (root.interactive && index > 0) days.itemAt(index - 1).forceActiveFocus();
          event.accepted = true;
        }
        Keys.onRightPressed: event => {
          if (root.interactive && index + 1 < days.count) days.itemAt(index + 1).forceActiveFocus();
          event.accepted = true;
        }
        Keys.onPressed: event => {
          if (!root.interactive || !days.count) return;
          if (event.key === Qt.Key_Home) {
            days.itemAt(0).forceActiveFocus();
            event.accepted = true;
          } else if (event.key === Qt.Key_End) {
            days.itemAt(days.count - 1).forceActiveFocus();
            event.accepted = true;
          }
        }
        Keys.onReturnPressed: if (root.interactive) root.selectedIndex = index
        Keys.onSpacePressed: if (root.interactive) root.selectedIndex = index
        Keys.onEscapePressed: root.selectedIndex = -1
        Controls.ToolTip {
          id: dayTip
          text: Model.historyTooltip(cell.modelData)
          visible: root.interactive && hover.hovered
          delay: 250
          contentItem: Text { text: dayTip.text; font: dayTip.font; color: dayTip.palette.toolTipText; textFormat: Text.PlainText; wrapMode: Text.Wrap }
        }

        Rectangle {
          anchors.fill: parent
          anchors.margins: 1
          radius: 3
          color: cell.selected ? Shell.PanelStyle.hover : "transparent"
          border.width: cell.activeFocus ? 1 : 0
          border.color: Shell.PanelStyle.accent
        }
        Rectangle {
          anchors.bottom: parent.bottom
          anchors.horizontalCenter: parent.horizontalCenter
          width: Math.max(1, parent.width - 3)
          height: Math.max(2, (parent.height - 10) * cell.value)
          radius: 2
          color: cell.value > 0 ? Shell.PanelStyle.accent : Shell.PanelStyle.pressed
          opacity: cell.selected ? 1 : 0.7
        }
        Rectangle {
          anchors.top: parent.top
          anchors.topMargin: 2
          anchors.horizontalCenter: parent.horizontalCenter
          visible: cell.hasReset
          width: Math.min(5, cell.width); height: width; radius: width / 2
          color: "white"; opacity: 0.75
        }
        HoverHandler {
          id: hover
          enabled: root.interactive
          onHoveredChanged: {
            if (hovered) root.hoveredIndex = cell.index;
            else if (root.hoveredIndex === cell.index) root.hoveredIndex = -1;
          }
        }
        TapHandler {
          enabled: root.interactive
          onTapped: { root.selectedIndex = cell.index; cell.forceActiveFocus(); }
        }
      }
    }
  }

  Row {
    width: root.width
    Text {
      width: root.width / 2
      text: String(root.points[0]?.dayKey || "")
      color: "white"; opacity: 0.4
      font.family: Shell.Theme.fontFamily; font.pixelSize: 9
    }
    Text {
      width: root.width / 2
      text: String(root.points[root.points.length - 1]?.dayKey || "")
      horizontalAlignment: Text.AlignRight
      color: "white"; opacity: 0.4
      font.family: Shell.Theme.fontFamily; font.pixelSize: 9
    }
  }

  Text {
    objectName: "historyDayDetails"
    width: root.width
    visible: root.detailIndex >= 0 && root.detailIndex < root.points.length
    text: visible ? Model.historyTooltip(root.points[root.detailIndex]) : ""
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    color: "white"; opacity: 0.7
    font.family: Shell.Theme.fontFamily; font.pixelSize: 11
  }
}
