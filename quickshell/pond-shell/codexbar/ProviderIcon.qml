pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "CodexBarModel.mjs" as Model
import ".." as Shell

Item {
  id: root

  required property string provider
  property color color: Shell.Theme.sidebarV3Foreground
  property real size: 16
  property real markOpacity: 1
  property color fill: "transparent"
  readonly property string iconPath: Model.providerIcon(provider)
  readonly property bool hasIcon: iconPath !== "" && mark.status !== Image.Error

  implicitWidth: size
  implicitHeight: size
  opacity: markOpacity

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: root.fill
  }

  Image {
    id: mark
    anchors.fill: parent
    source: root.iconPath === "" ? "" : Qt.resolvedUrl(root.iconPath)
    sourceSize: Qt.size(Math.ceil(root.size * 2), Math.ceil(root.size * 2))
    fillMode: Image.PreserveAspectFit
    visible: root.hasIcon
    layer.enabled: true
    layer.effect: MultiEffect {
      colorization: 1
      colorizationColor: root.color
    }
  }

  Text {
    anchors.centerIn: parent
    visible: !root.hasIcon
    text: Model.tag(root.provider)
    color: root.color
    font.pixelSize: Math.max(7, Math.round(root.size * 0.48))
    font.weight: Font.DemiBold
    font.family: Shell.Theme.fontFamily
  }
}
