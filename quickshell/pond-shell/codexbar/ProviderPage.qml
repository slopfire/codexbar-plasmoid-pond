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
  readonly property var entry: pageState.entries.find(candidate => candidate.id === selection?.id) || null
  implicitWidth: Shell.PanelStyle.width
  implicitHeight: Math.min(580, 88 + details.implicitHeight)

  Shell.PanelBackground { anchors.fill: parent }
  Text {
    x: 20; y: 20; width: 238
    text: Model.providerName(root.entry?.provider || root.selection?.provider)
    textFormat: Text.PlainText
    color: "white"; elide: Text.ElideRight
    font.family: Shell.Theme.titleFontFamily; font.pixelSize: 20
  }
  Shell.IconButton {
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Accessible.onPressAction: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    x: 262; y: 18; width: 32; height: 32
    iconSource: Qt.resolvedUrl("assets/back.svg")
    accessibleName: "Back to providers"
    onClicked: if (root.interactive) root.stackController.pop()
  }
  Flickable {
    id: viewport
    x: 20; y: 76; width: parent.width - 40; height: parent.height - y - 12
    contentHeight: details.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: root.interactive && contentHeight > height
    ProviderDetails {
      id: details
      width: viewport.width
      pageState: root.pageState
      entry: root.entry
      interactive: root.interactive
      headingVisible: false
    }
  }
}
