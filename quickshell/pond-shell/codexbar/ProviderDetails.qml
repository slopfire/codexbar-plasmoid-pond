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
  readonly property var history: Model.historyPoints(entry)
  readonly property var resets: Model.resetCreditsOf(entry)
  readonly property var credits: Model.creditsOf(entry)
  readonly property string status: Model.stateText(entry)
  readonly property bool failed: Model.isErrorOnly(entry)
  readonly property string note: [
    entry?.usageUnavailable ? "Usage limits are unavailable. Spend is local." : "",
    entry?.stale ? "Showing the last reading. CodexBar will retry." : "",
    spend?.provenance === "listPriceEstimate" ? "Spend is a list-price estimate, not a bill." : "",
    entry?.tokenUsage?.historyCoverageIsEstablished === false
      ? "Local history scan is incomplete. Totals may be missing usage. Refresh to continue scanning." : ""
  ].filter(Boolean).join("\n")
  readonly property string resetExpiry: {
    const value = resets?.nextExpiresAt;
    const date = value ? new Date(value) : null;
    return date && Number.isFinite(date.getTime())
      ? Qt.formatDateTime(date, Qt.DefaultLocaleLongDate) : "";
  }
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
      text: [root.entry?.plan, root.entry?.account, root.entry?.organization].filter(Boolean).join(" · ")
      visible: text !== ""
      textFormat: Text.PlainText
      color: "white"; opacity: 0.5
      font.family: Shell.Theme.fontFamily; font.pixelSize: 11
      wrapMode: Text.WrapAnywhere
    }
    Text {
      width: root.width
      text: [root.status, root.entry?.source, root.entry?.version].filter(Boolean).join(" · ")
      visible: text !== ""
      textFormat: Text.PlainText
      color: root.failed ? "#FA9CA7" : "white"; opacity: 0.65
      font.family: Shell.Theme.fontFamily; font.pixelSize: 10
    }
  }

  Text {
    objectName: "providerError"
    width: root.width
    visible: !!root.entry?.error || !!root.entry?.lastAttemptError
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
    objectName: "resetCredits"
    width: root.width
    visible: !!root.resets
    text: root.resets ? root.resets.availableCount + " limit resets available"
        + (root.resetExpiry ? "\nNext expiry: " + root.resetExpiry : "") : ""
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

  HistoryChart {
    objectName: "historySection"
    width: root.width
    visible: root.history.length > 0 && root.pageState.settings?.history !== false
    points: root.history
    bars: Model.historyBars(root.entry)
    interactive: root.interactive
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

  Text {
    objectName: "providerStatus"
    width: root.width
    visible: text !== ""
    text: root.entry?.status?.description || ({none: "Operational", minor: "Partial outage",
      major: "Major outage", critical: "Critical issue", maintenance: "Maintenance"})[root.entry?.status?.indicator] || ""
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    color: "white"; opacity: 0.65
    font.family: Shell.Theme.fontFamily; font.pixelSize: 11
  }

  ActionButton {
    visible: !!root.entry?.status?.url
    width: root.width
    text: "Open provider status"
    interactive: root.interactive
    onClicked: root.pageState.openSite(root.entry.status.url)
  }

  Text {
    width: root.width
    readonly property date updated: new Date(root.entry?.updatedAt || "")
    visible: Number.isFinite(updated.getTime())
    text: visible ? "Updated " + Qt.formatDateTime(updated, Qt.DefaultLocaleShortDate) : ""
    color: "white"; opacity: 0.45
    font.family: Shell.Theme.fontFamily; font.pixelSize: 10
    wrapMode: Text.Wrap
  }

  ActionButton {
    visible: !!root.entry && Model.providerSite(root.entry) !== ""
    width: root.width
    text: "Open usage page"
    interactive: root.interactive
    onClicked: root.pageState.openSite(Model.providerSite(root.entry))
  }
}
