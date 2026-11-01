pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import ".." as Shell

Controls.ComboBox {
  id: root
  property var options: []
  property string value: ""
  signal picked(string value)
  model: options
  textRole: "label"
  valueRole: "value"
  currentIndex: Math.max(0, options.findIndex(option => option.value === value))
  implicitHeight: 40
  leftPadding: 12
  rightPadding: 26
  font.family: Shell.Theme.fontFamily
  font.pixelSize: 12
  palette.text: "white"
  palette.buttonText: "white"
  palette.highlight: Shell.PanelStyle.accent
  background: Rectangle { radius: 10; color: root.hovered || root.activeFocus ? Shell.PanelStyle.pressed : Shell.PanelStyle.hover }
  contentItem: Text {
    text: root.displayText; textFormat: Text.PlainText
    font: root.font; color: "white"; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
  }
  delegate: Controls.ItemDelegate {
    id: option
    required property var modelData
    width: root.width
    text: modelData.label
    font: root.font
    contentItem: Text { text: option.text; font: root.font; color: "white"; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
    background: Rectangle { color: option.highlighted || option.hovered ? Shell.PanelStyle.pressed : Shell.PanelStyle.hover }
  }
  popup: Controls.Popup {
    y: root.height + 4; width: Math.max(root.width, 180)
    height: Math.min(contentItem.implicitHeight + 8, 240)
    padding: 4
    background: Rectangle { color: Shell.PanelStyle.hover; radius: 10; border.width: 1; border.color: Shell.PanelStyle.border }
    contentItem: ListView {
      clip: true
      implicitHeight: contentHeight
      model: root.popup.visible ? root.delegateModel : null
      currentIndex: root.highlightedIndex
      Controls.ScrollIndicator.vertical: Controls.ScrollIndicator {}
    }
  }
  onActivated: root.picked(String(currentValue))
}
