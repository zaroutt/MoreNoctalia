import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

NIconButton {
  id: root

  property var pluginApi: null

  property var _syncData: ({})
  property bool _sync: _syncData.syncWidgetColors ?? false
  property string _syncIconKey: _syncData.syncedIconColor ?? "none"
  property color _syncIconColor: _sync && _syncIconKey !== "none" ? Color.resolveColorKey(_syncIconKey) : "transparent"
  property color _syncHoverColor: _sync && _syncData.syncedHoverColor !== "none" ? Color.resolveColorKey(_syncData.syncedHoverColor) : "transparent"

  FileView {
    id: syncColorsView
    path: Quickshell.env("HOME") + "/.config/noctalia/sync-colors.json"
    printErrors: false
    onLoaded: {
      try {
        root._syncData = JSON.parse(text())
      } catch(e) {
        root._syncData = {}
      }
    }
    onLoadFailed: {
      root._syncData = {}
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: true
    onTriggered: syncColorsView.reload()
  }

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string iconColorKey: cfg.iconColor ?? defaults.iconColor ?? "none"

  readonly property color iconColor: Color.resolveColorKey(iconColorKey)  

  icon: "adjustments-horizontal"
  tooltipText: pluginApi?.tr("widget.tooltip")
  tooltipDirection: BarService.getTooltipDirection(screen?.name)
  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  customRadius: Style.radiusL
  colorBg: Style.capsuleColor
  colorFg: root._syncIconColor.a > 0 ? root._syncIconColor : (root._sync ? Color.mOnSurface : iconColor)
  colorBgHover: root._syncHoverColor.a > 0 ? root._syncHoverColor : Style.capsuleColor
  colorFgHover: root._syncIconColor.a > 0 ? root._syncIconColor : Color.mOnHover

  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  onClicked: {
    if (pluginApi) {
      pluginApi.openPanel(root.screen, this);
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("menu.settings"),
        "action": "settings",
        "icon": "settings"
      }
    ]

    onTriggered: function(action) {
      contextMenu.close();
      PanelService.closeContextMenu(screen);
      if (action === "settings") {
        BarService.openPluginSettings(root.screen, pluginApi.manifest);
      }
    }
  }

  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen);
  }
}
