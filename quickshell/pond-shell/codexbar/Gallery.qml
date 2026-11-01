pragma ComponentBehavior: Bound

import QtQuick
import "CodexBarModel.mjs" as Model
import "RingLayout.mjs" as RingLayout
import "CodexBarSettings.mjs" as Settings
import ".." as Shell

Item {
  id: root
  required property var state
  required property real collapseProgress
  required property var theme
  property int bars: 2
  property int maxTiles: 4
  signal tileClicked(var entry)

  readonly property var settings: state.settings || ({})
  readonly property bool compact: collapseProgress >= 0.56
  readonly property var tiles: (state.ordered || []).map(entry => {
    const appearance = Settings.appearance(settings, entry.provider);
    return {entry, settings: appearance, rings: appearance.ringLayout === "nested"
      ? Model.sidebarRings(entry, appearance.cardBars || root.bars) : Model.rings(entry, 1), error: Model.isErrorOnly(entry)};
  })
  readonly property int expandedCapacity: Math.max(1, maxTiles)
  readonly property int compactCapacity: 3
  readonly property int capacity: compact ? compactCapacity : expandedCapacity
  readonly property int shownCount: Math.min(tiles.length, tiles.length > capacity ? capacity - 1 : capacity)
  readonly property int hiddenCount: tiles.length - shownCount
  readonly property int cellCount: shownCount + (hiddenCount > 0 ? 1 : 0)
  readonly property int columns: compact ? 1 : 2
  readonly property real cellWidth: Math.max(0, (width - 12) / columns)
  readonly property int tileHeight: Math.max(36, ...tiles.map(tile => RingLayout.diameter(tile.settings) + 8))
  readonly property int namedHeight: tileHeight + (tiles.some(tile => tile.settings.showProviderName !== false) ? 18 : 0)
  readonly property int cellHeight: compact ? tileHeight : namedHeight
  readonly property int expandedHeight: Math.ceil(Math.min(tiles.length, expandedCapacity) / 2) * namedHeight + 8
  readonly property int compactHeight: Math.min(tiles.length, compactCapacity) * tileHeight + 12
  implicitHeight: compact ? compactHeight : expandedHeight

  Repeater {
    model: root.cellCount
    delegate: Item {
      id: cell
      required property int index
      readonly property bool more: index >= root.shownCount
      x: 6 + (index % root.columns) * root.cellWidth
      y: 6 + Math.floor(index / root.columns) * root.cellHeight
      width: root.cellWidth
      height: root.cellHeight
      Tile {
        anchors.fill: parent
        visible: !cell.more
        tile: !cell.more ? root.tiles[cell.index] : null
        compact: root.compact
        theme: root.theme
        nowMs: root.state.nowMs
        settings: tile?.settings || ({})
        markerStyle: settings.paceIndicatorStyle || "position"
        onClicked: root.tileClicked(root.tiles[cell.index].entry)
      }
      FocusScope {
        anchors.fill: parent
        visible: cell.more
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: "Show " + root.hiddenCount + " more providers"
        Accessible.onPressAction: root.tileClicked(null)
        Keys.onReturnPressed: root.tileClicked(null)
        Keys.onSpacePressed: root.tileClicked(null)
        Text {
          anchors.centerIn: parent
          text: "+" + root.hiddenCount
          color: root.theme.ink
          opacity: pointer.hovered || parent.activeFocus ? 1 : 0.65
          font.family: Shell.Theme.fontFamily
          font.pixelSize: 11
        }
        HoverHandler { id: pointer; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.tileClicked(null) }
      }
    }
  }
}
