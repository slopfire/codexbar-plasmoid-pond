pragma ComponentBehavior: Bound
import QtQuick
import ".." as Shell

Item {
  id: root
  property string text: ""
  property bool checked: false
  signal toggled(bool value)
  implicitHeight: 40
  Text {
    width: parent.width - 68; anchors.verticalCenter: parent.verticalCenter
    text: root.text; textFormat: Text.PlainText
    color: "white"; font.family: Shell.Theme.fontFamily; font.pixelSize: 12
    wrapMode: Text.Wrap
  }
  Shell.Toggle {
    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
    checked: root.checked
    onToggled: value => root.toggled(value)
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: root.text
    Accessible.checked: root.checked
    Accessible.onToggleAction: root.toggled(!root.checked)
    Keys.onSpacePressed: root.toggled(!root.checked)
  }
}
