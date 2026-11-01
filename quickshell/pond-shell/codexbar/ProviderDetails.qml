pragma ComponentBehavior: Bound
import QtQuick
import "CodexBarModel.mjs" as Model
import ".." as Shell

Column {
  id: root
  required property var pageState
  required property var entry
  property bool interactive: true
  property bool headingVisible: true
  readonly property var usageRows: Model.rowsOf(entry)
  readonly property var spend: Model.spendOf(entry)
  readonly property var history: Model.historyBars(entry)
  readonly property var resets: Model.resetCreditsOf(entry)
  readonly property var credits: Model.creditsOf(entry)
  readonly property string status: Model.stateText(entry)
  readonly property bool failed: Model.isErrorOnly(entry)
  readonly property string note: entry?.usageUnavailable ? "Usage limits are unavailable. Spend is local."
      : entry?.stale ? "Showing the last reading. CodexBar will retry."
      : spend?.provenance === "listPriceEstimate" ? "Spend is a list-price estimate, not a bill." : ""
  spacing: 16

  Column {
    width: root.width
    spacing: 5
    visible: !!root.entry
    Row {
      visible: root.headingVisible
      spacing: 8
      ProviderIcon { provider: root.entry?.provider || ""; size: 20; anchors.verticalCenter: parent.verticalCenter }
      Text {
        width: root.width - 28
        text: Model.providerName(root.entry?.provider)
        textFormat: Text.PlainText
        color: "white"; font.family: Shell.Theme.fontFamily; font.pixelSize: 17; font.weight: Font.DemiBold
        elide: Text.ElideRight
      }
    }
    Text {
      width: root.width
      text: [root.entry?.plan, root.entry?.account].filter(Boolean).join(" · ")
      visible: text !== ""
      textFormat: Text.PlainText
      color: "white"; opacity: 0.5
      font.family: Shell.Theme.fontFamily; font.pixelSize: 11
      wrapMode: Text.WrapAnywhere
    }
    Text {
      width: root.width
      text: root.status + (root.entry?.source ? (root.status ? " · " : "") + root.entry.source : "")
      visible: text !== ""
      textFormat: Text.PlainText
      color: root.failed ? "#FA9CA7" : "white"; opacity: 0.65
      font.family: Shell.Theme.fontFamily; font.pixelSize: 10
    }
  }

  Text {
    objectName: "providerError"
    width: root.width
    visible: root.failed
    text: root.entry ? Model.errorText(root.entry, 400) : ""
    textFormat: Text.PlainText
    color: "#FA9CA7"; wrapMode: Text.Wrap
    font.family: Shell.Theme.fontFamily; font.pixelSize: 12
  }

  Column {
    objectName: "usageWindows"
    width: root.width
    spacing: 14
    visible: root.usageRows.length > 0
    Repeater {
      model: root.usageRows
      delegate: Bar {
        required property var modelData
        objectName: "usageWindow"
        width: root.width
        wide: true
        row: modelData
        nowMs: root.pageState.nowMs
      }
    }
  }

  Bar {
    width: root.width
    visible: root.entry?.codeReviewRemainingPercent !== null
        && root.entry?.codeReviewRemainingPercent !== undefined
    row: ({title: "Code review", percentLeft: root.entry?.codeReviewRemainingPercent || 0})
  }

  Text {
    width: root.width
    visible: !!root.resets
    text: root.resets ? root.resets.availableCount + " limit resets available" : ""
    color: "white"; opacity: 0.7
    font.family: Shell.Theme.fontFamily; font.pixelSize: 12
    wrapMode: Text.Wrap
  }

  Text {
    width: root.width
    visible: root.credits !== null
    text: root.credits !== null ? Model.compactNumber(root.credits) + " credits remaining" : ""
    color: "white"; font.family: Shell.Theme.fontFamily; font.pixelSize: 16
  }

  Column {
    objectName: "spendSection"
    width: root.width
    spacing: 8
    visible: !!root.spend
    Text { text: "Spend"; color: "white"; opacity: 0.5; font.family: Shell.Theme.fontFamily; font.pixelSize: 11 }
    Row {
      spacing: 8
      Repeater {
        model: [
          { label: root.spend?.sessionLabel || "Today", value: root.spend?.sessionCostUSD,
            tokens: root.spend?.sessionTokens },
          { label: root.spend?.last30DaysLabel || "30 days", value: root.spend?.last30DaysCostUSD,
            tokens: root.spend?.last30DaysTokens }
        ]
        delegate: Rectangle {
          id: metric
          required property var modelData
          width: (root.width - 8) / 2
          height: numbers.implicitHeight + 20
          radius: 10
          color: Shell.PanelStyle.hover
          Column {
            id: numbers
            x: 12; y: 10; width: parent.width - 24; spacing: 4
            Text { text: metric.modelData.label; color: "white"; opacity: 0.5; font.family: Shell.Theme.fontFamily; font.pixelSize: 10 }
            Text {
              text: metric.modelData.value !== null && metric.modelData.value !== undefined ? Model.money(metric.modelData.value) : "-"
              color: "white"; font.family: Shell.Theme.plexFontFamily; font.pixelSize: 16
            }
            Text {
              visible: metric.modelData.tokens !== null && metric.modelData.tokens !== undefined
              text: Model.compactNumber(metric.modelData.tokens) + " tokens"
              color: "white"; opacity: 0.5; font.family: Shell.Theme.fontFamily; font.pixelSize: 10
            }
          }
        }
      }
    }
  }

  Column {
    objectName: "historySection"
    width: root.width
    spacing: 8
    visible: root.history.length > 0 && root.pageState.settings?.history !== false
    Text { text: "Daily spend"; color: "white"; opacity: 0.5; font.family: Shell.Theme.fontFamily; font.pixelSize: 11 }
    Item {
      width: root.width; height: 38
      Repeater {
        model: root.history
        delegate: Rectangle {
          required property real modelData
          required property int index
          x: index * root.width / root.history.length
          y: 38 - height
          width: Math.max(1, root.width / root.history.length - 2)
          height: Math.max(2, 38 * modelData)
          radius: 2
          color: modelData > 0 ? Shell.PanelStyle.accent : Shell.PanelStyle.pressed
        }
      }
    }
  }

  Text {
    objectName: "providerNote"
    width: root.width
    visible: root.note !== ""
    text: root.note; textFormat: Text.PlainText
    wrapMode: Text.Wrap
    color: "white"; opacity: 0.55
    font.family: Shell.Theme.fontFamily; font.pixelSize: 11
  }

  ActionButton {
    visible: !!root.entry && Model.providerSite(root.entry) !== ""
    width: root.width
    text: "Open usage page"
    interactive: root.interactive
    onClicked: root.pageState.openSite(Model.providerSite(root.entry))
  }
}
