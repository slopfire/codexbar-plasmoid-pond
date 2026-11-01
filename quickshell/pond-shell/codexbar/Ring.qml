pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

Item {
  id: root

  required property real value
  property color color: "white"
  property color trackColor: Qt.rgba(1, 1, 1, 0.16)
  property color tickColor: "white"
  property real timeLeft: -1
  property real stroke: 2.5
  readonly property real percent: Math.max(0, Math.min(100, Number(value) || 0))
  readonly property real size: Math.min(width, height)
  readonly property real radius: Math.max(0, (size - stroke) / 2)

  implicitWidth: 30
  implicitHeight: 30

  Rectangle {
    anchors.centerIn: parent
    width: root.size
    height: root.size
    radius: width / 2
    color: "transparent"
    border.width: root.stroke
    border.color: root.trackColor
    antialiasing: true
  }

  Shape {
    anchors.centerIn: parent
    width: root.size
    height: root.size
    visible: root.percent > 0
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.color
      strokeWidth: root.stroke
      capStyle: ShapePath.RoundCap
      PathAngleArc {
        centerX: root.size / 2
        centerY: root.size / 2
        radiusX: root.radius
        radiusY: root.radius
        startAngle: -90
        sweepAngle: 360 * root.percent / 100
      }
    }
  }

  Item {
    anchors.centerIn: parent
    width: root.size
    height: root.size
    visible: root.timeLeft >= 0 && root.timeLeft <= 1
    rotation: 360 * Math.max(0, Math.min(1, root.timeLeft))
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      y: -1
      width: 1
      height: root.stroke + 2
      radius: 0.5
      color: root.tickColor
      opacity: 0.65
      antialiasing: true
    }
  }
}
