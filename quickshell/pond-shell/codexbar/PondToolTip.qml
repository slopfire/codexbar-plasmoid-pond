pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import ".." as Shell

Controls.ToolTip {
  id: root
  property string heading: ""

  objectName: "pondToolTip"
  popupType: Controls.Popup.Window
  width: 292
  padding: 12
  margins: 8
  delay: 500
  font.family: Shell.Theme.fontFamily
  font.pixelSize: 11
  leftInset: 0
  rightInset: 0
  topInset: 0
  bottomInset: 0

  background: Rectangle {
    radius: Shell.PanelStyle.rowRadius
    color: Shell.PanelStyle.surface
    border.width: 1
    border.color: Shell.PanelStyle.border
  }

  contentItem: Column {
    spacing: 7
    Text {
      width: parent.width
      visible: root.heading !== ""
      text: root.heading
      textFormat: Text.PlainText
      font.family: root.font.family
      font.pixelSize: root.font.pixelSize
      font.weight: Font.DemiBold
      color: Shell.Theme.sidebarV3Foreground
      wrapMode: Text.Wrap
    }
    Text {
      width: parent.width
      text: root.text
      textFormat: Text.PlainText
      font: root.font
      color: Shell.Theme.sidebarV3Foreground
      opacity: 0.75
      lineHeight: 1.25
      wrapMode: Text.Wrap
    }
  }
}
