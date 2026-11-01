pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "CodexBarModel.mjs" as Model

Item {
  id: root

  required property real value
  property color color: "white"
  property color trackColor: Qt.rgba(1, 1, 1, 0.16)
  property color tickColor: "white"
  property real timeLeft: -1
  property string markerStyle: "position"
  property real stroke: 2.5
  property real markerExtent: 3
  readonly property real percent: Math.max(0, Math.min(100, Number(value) || 0))
  readonly property real size: Math.min(width, height)
  // Leave room for the tick inside the item, including at 12 o'clock.
  readonly property real radius: Math.max(0, (size - stroke - markerExtent) / 2)
  // Allow for round caps, the 1.5 px tick, and 0.5 px clearance on each side.
  readonly property real markerHalfGap: Math.asin(Math.min(1, (stroke / 2 + 1.25) / Math.max(1, radius))) * 180 / Math.PI
  readonly property bool hasMarker: markerStyle !== "off" && Number.isFinite(timeLeft) && timeLeft >= 0 && timeLeft <= 1
  readonly property real markerFraction: hasMarker ? timeLeft : -1

  implicitWidth: 30
  implicitHeight: 30

  Repeater {
    model: [{value: 100, color: root.trackColor}, {value: root.percent, color: root.color}]
    delegate: Item {
      id: arc
      required property var modelData
      anchors.fill: parent
      Repeater {
        model: Model.ringArcs(arc.modelData.value, root.markerFraction, root.markerHalfGap)
        delegate: Shape {
          id: segment
          required property var modelData
          anchors.centerIn: parent
          width: root.size
          height: root.size
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            fillColor: "transparent"
            strokeColor: arc.modelData.color
            strokeWidth: root.stroke
            capStyle: ShapePath.RoundCap
            PathAngleArc {
              centerX: root.size / 2
              centerY: root.size / 2
              radiusX: root.radius
              radiusY: root.radius
              startAngle: -90 + segment.modelData.start
              sweepAngle: segment.modelData.sweep
            }
          }
        }
      }
    }
  }

  Item {
    objectName: "paceMarker"
    anchors.centerIn: parent
    width: root.size
    height: root.size
    visible: root.hasMarker && root.markerStyle !== "gaps"
    rotation: 360 * root.timeLeft
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      y: (root.size / 2) - root.radius - height / 2
      width: 1.5
      height: root.stroke + root.markerExtent
      radius: width / 2
      color: root.tickColor
      antialiasing: true
    }
  }
}
