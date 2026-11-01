pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import ".." as Shell

Item {
  id: root
  property string text: ""
  property int value: 0
  property int minimum: 0
  property int maximum: 100
  property int step: 1
  signal changed(int value)
  implicitHeight: 44
  Text {
    width: parent.width - 116; anchors.verticalCenter: parent.verticalCenter
    text: root.text; color: "white"; wrapMode: Text.Wrap
    font.family: Shell.Theme.fontFamily; font.pixelSize: 12
  }
  Controls.SpinBox {
    id: spin
    anchors.right: parent.right; width: 108; height: 40
    from: root.minimum; to: root.maximum; stepSize: root.step
    value: root.value; editable: true
    font.family: Shell.Theme.fontFamily; font.pixelSize: 12
    palette.text: "white"; palette.buttonText: "white"; palette.base: Shell.PanelStyle.hover
    palette.button: Shell.PanelStyle.pressed
    background: Rectangle { color: Shell.PanelStyle.hover; radius: 10 }
    contentItem: TextInput {
      text: spin.textFromValue(spin.value, spin.locale)
      font: spin.font; color: "white"
      horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
      readOnly: !spin.editable; validator: spin.validator
      inputMethodHints: Qt.ImhDigitsOnly
      selectByMouse: true
    }
    up.indicator: Rectangle {
      x: spin.width - width; width: 24; height: spin.height / 2
      color: spin.up.pressed ? Shell.PanelStyle.border : "transparent"
      Text { anchors.centerIn: parent; text: "+"; color: "white"; opacity: 0.6; font.pixelSize: 13 }
    }
    down.indicator: Rectangle {
      x: spin.width - width; y: spin.height / 2; width: 24; height: spin.height / 2
      color: spin.down.pressed ? Shell.PanelStyle.border : "transparent"
      Text { anchors.centerIn: parent; text: "-"; color: "white"; opacity: 0.6; font.pixelSize: 13 }
    }
    Accessible.name: root.text
    onValueModified: root.changed(value)
  }
}
