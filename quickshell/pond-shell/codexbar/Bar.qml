import QtQuick
import "CodexBarModel.mjs" as Model
import ".." as Shell

// One usage window: name and number on top, a capped bar below.
//
// The fill runs left to right and the colour follows the remaining percent,
// as in the KDE plasmoid: ink while the budget is comfortable, yellow when it
// is tight, red when CodexBar projects the window runs dry before the reset.
// The thin tick shows how much of the window is left, so a fill that reaches
// past it means the budget outlasts the clock.
Item {
  id: root

  required property var row
  property real nowMs: Date.now()
  property bool wide: false
  readonly property var theme: ({
    ink: Shell.Theme.daylight ? "#FFFFFF" : Shell.Theme.sidebarV3Foreground,
    yellow: "#EBE075",
    red: "#FA6D80",
    track: Shell.Theme.daylight ? Qt.rgba(1, 1, 1, 0.14) : "#2B2B2B"
  })
  readonly property real percentLeft: Math.max(0, Math.min(100, Number(row ? row.percentLeft : 0)))
  readonly property real timeLeft: Model.windowLeft(row, nowMs)
  readonly property string reset: Model.resetText(row, nowMs, Qt.locale().name)
  readonly property string verdict: Model.paceVerdict(row)
  readonly property color fillColor: Model.barColor(row, theme)
  readonly property string verdictText: verdict === "runs dry" ? "runs dry"
      : verdict === "tight" ? "tight" : verdict === "lasts" ? "lasts" : ""

  implicitHeight: wide ? caption.y + caption.implicitHeight : bar.y + bar.height
  Accessible.role: Accessible.ProgressBar
  Accessible.name: Model.windowDescription(row, nowMs, Qt.locale().name)
  PondToolTip {
    visible: hover.hovered
    text: Model.windowTooltip(root.row, root.nowMs, Qt.locale().name)
  }
  HoverHandler { id: hover }

  Text {
    id: title
    x: 0
    y: 1
    width: Math.max(0, parent.width - number.width - 6)
    text: root.row ? String(root.row.title || Model.windowLabel(root.row)) : ""
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: root.theme.ink
    font.family: Shell.Theme.fontFamily
    font.pixelSize: 12
    font.weight: Font.Medium
  }

  Text {
    id: number
    anchors.right: parent.right
    anchors.top: parent.top
    text: Math.round(root.percentLeft) + "%"
    color: root.row && root.verdict !== "" ? root.fillColor : root.theme.ink
    font.family: Shell.Theme.plexFontFamily
    font.pixelSize: 12
    font.weight: Font.Normal
  }

  Item {
    id: bar
    x: 0
    y: title.height + 4
    width: parent.width
    height: 5

    Rectangle {
      id: track
      anchors.fill: parent
      radius: height / 2
      color: root.theme.track
    }

    Rectangle {
      id: fill
      width: bar.width * root.percentLeft / 100
      height: parent.height
      radius: height / 2
      color: root.fillColor
      Behavior on width {
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
      }
      Behavior on color {
        ColorAnimation { duration: 240; easing.type: Easing.OutCubic }
      }
    }

    Rectangle {
      id: marker
      visible: root.timeLeft >= 0
      width: 1.5
      height: parent.height + 2
      y: -1
      radius: 0.75
      x: Math.max(0, Math.min(bar.width - width, bar.width * root.timeLeft - width / 2))
      color: root.theme.ink
      opacity: 0.55
    }
  }

  // Caption row: reset time on the left, the pace verdict on the right. Only
  // the wide (expanded) layout has the room.
  Text {
    id: caption
    visible: root.wide
    x: 0
    y: bar.y + bar.height + 4
    width: Math.max(0, parent.width - verdict.width - 6)
    text: root.reset
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: root.theme.ink
    opacity: 0.45
    font.family: Shell.Theme.fontFamily
    font.pixelSize: 11
    font.weight: Font.Normal
  }

  Text {
    id: verdict
    visible: root.wide && root.verdictText !== ""
    anchors.right: parent.right
    y: caption.y
    text: root.verdictText
    color: root.fillColor
    font.family: Shell.Theme.fontFamily
    font.pixelSize: 11
    font.weight: Font.Medium
  }
}
