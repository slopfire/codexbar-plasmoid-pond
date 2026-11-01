pragma ComponentBehavior: Bound
import QtQuick
import "CodexBarModel.mjs" as Model
import ".." as Shell

Item {
  id: root
  required property var pageState
  property var stackController
  property bool interactive: true
  enabled: interactive
  property var selection: ({})
  property string selectedId: ""
  readonly property var entries: pageState.ordered || []
  readonly property var entry: entries.find(item => item.id === selectedId) || entries[0] || null
  readonly property string message: pageState.failed ? "Refresh failed. Showing the last reading."
      : pageState.running ? "Refreshing usage" : pageState.costNote ? "Spend history is unavailable" : ""
  readonly property int bodyTop: entries.length > 1 ? 120 : 76
  implicitWidth: Shell.PanelStyle.width
  implicitHeight: Math.min(580, bodyTop + (entry ? details.implicitHeight : 100) + (message ? 36 : 16))

  Shell.PanelBackground { anchors.fill: parent }
  Text {
    x: 20; y: 20; width: 190
    text: "CodexBar"
    color: "white"; font.family: Shell.Theme.titleFontFamily; font.pixelSize: 20
  }
  Shell.IconButton {
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Accessible.onPressAction: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    x: 226; y: 18; width: 32; height: 32
    iconSource: Qt.resolvedUrl("assets/refresh.svg")
    iconWidth: 16; iconHeight: 16
    accessibleName: "Refresh usage"
    restingOpacity: root.pageState.running ? 0.3 : 0.65
    onClicked: if (root.interactive) root.pageState.refreshSoon(true)
  }
  Shell.IconButton {
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Accessible.onPressAction: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    objectName: "openSettings"
    x: 264; y: 18; width: 32; height: 32
    iconSource: Qt.resolvedUrl("../assets/settings.svg")
    iconWidth: 18; iconHeight: 18
    accessibleName: "CodexBar settings"
    onClicked: if (root.interactive) root.stackController.push("settings", {})
  }

  Flickable {
    x: 12; y: 72; width: parent.width - 24; height: 34
    visible: root.entries.length > 1
    contentWidth: tabs.width
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    Row {
      id: tabs
      spacing: 6
      Repeater {
        model: root.entries
        delegate: Rectangle {
          id: tab
          required property var modelData
          required property int index
          readonly property bool selected: root.entry?.id === modelData.id
          width: Math.min(200, label.implicitWidth + 24); height: 32; radius: 10
          color: selected ? Shell.PanelStyle.pressed : hover.hovered ? Shell.PanelStyle.hover : "transparent"
          border.width: selected ? 1 : 0
          border.color: Shell.PanelStyle.border
          activeFocusOnTab: true
          Accessible.role: Accessible.Button
          Accessible.name: Model.providerName(modelData.provider) + (modelData.account ? ", " + modelData.account : "")
          Accessible.onPressAction: root.selectedId = tab.modelData.id
          Keys.onReturnPressed: root.selectedId = tab.modelData.id
          Keys.onSpacePressed: root.selectedId = tab.modelData.id
          Text {
            id: label; anchors.centerIn: parent; width: parent.width - 24
            text: Model.providerName(tab.modelData.provider)
                + (root.entries.filter(item => item.provider === tab.modelData.provider).length > 1
                  ? " · " + (tab.modelData.account || String(tab.index + 1)) : "")
            textFormat: Text.PlainText
            color: "white"; opacity: tab.selected ? 1 : 0.6
            font.family: Shell.Theme.fontFamily; font.pixelSize: 11
            elide: Text.ElideRight
          }
          HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
          TapHandler { enabled: root.interactive; onTapped: root.selectedId = tab.modelData.id }
        }
      }
    }
  }

  Flickable {
    id: viewport
    x: 20; y: root.bodyTop; width: parent.width - 40
    height: parent.height - y - (root.message ? 36 : 16)
    contentHeight: details.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: root.interactive && contentHeight > height
    ProviderDetails { id: details; width: viewport.width; pageState: root.pageState; entry: root.entry; interactive: root.interactive }
    Text {
      width: parent.width
      visible: !root.entry
      text: root.pageState.running ? "Reading usage..." : "No providers enabled. Open Settings to add a provider."
      textFormat: Text.PlainText
      wrapMode: Text.Wrap
      color: "white"; opacity: 0.6
      font.family: Shell.Theme.fontFamily; font.pixelSize: 12
    }
  }
  Text {
    x: 20; y: parent.height - 26; width: parent.width - 40
    visible: root.message !== ""
    text: root.message
    textFormat: Text.PlainText
    color: root.pageState.failed ? "#FA9CA7" : "white"; opacity: 0.6
    font.family: Shell.Theme.fontFamily; font.pixelSize: 10
    elide: Text.ElideRight
  }
}
