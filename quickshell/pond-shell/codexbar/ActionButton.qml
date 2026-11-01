import QtQuick
import ".." as Shell

Shell.ActionButton {
  id: root
  activeFocusOnTab: interactive
  Accessible.role: Accessible.Button
  Accessible.name: text
  Accessible.onPressAction: if (root.interactive) root.clicked()
  Keys.onReturnPressed: if (root.interactive) root.clicked()
  Keys.onSpacePressed: if (root.interactive) root.clicked()
  border.width: activeFocus ? 1 : 0
  border.color: Shell.PanelStyle.accent
}
