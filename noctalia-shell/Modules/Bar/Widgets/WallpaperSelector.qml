import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets
import Quickshell.Io
import Quickshell.Io
import Quickshell.Io

NIconButton {
  id: root

  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  readonly property string screenName: screen ? screen.name : ""
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0 && screenName) {
      var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
      if (widgets && sectionWidgetIndex < widgets.length) {
        return widgets[sectionWidgetIndex];
      }
    }
    return {};
  }

  readonly property string iconColorKey: widgetSettings.iconColor !== undefined ? widgetSettings.iconColor : widgetMetadata.iconColor

  // ── Sync Widget Colors ──
  property var _syncData: ({})
  property bool _sync: _syncData.syncWidgetColors ?? false
  property string _syncIconKey: _syncData.syncedIconColor ?? "none"
  property color _syncIconColor: _sync && _syncIconKey !== "none" ? Color.resolveColorKey(_syncIconKey) : "transparent"
  property color _syncHoverColor: _sync && _syncData.syncedHoverColor !== "none" ? Color.resolveColorKey(_syncData.syncedHoverColor) : "transparent"

  FileView {
    id: _syncColorsView
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
    id: _syncColorsTimer
    interval: 2000
    repeat: true
    running: true
    onTriggered: _syncColorsView.reload()
  }

  enabled: Settings.data.wallpaper.enabled
  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  customRadius: Style.radiusL
  icon: "wallpaper-selector"
  tooltipText: {
    if (PanelService.getPanel("wallpaperPanel", screen)?.isPanelOpen) {
      return "";
    } else {
      return I18n.tr("tooltips.wallpaper-selector");
    }
  }
  tooltipDirection: BarService.getTooltipDirection(screen?.name)
  colorBg: Style.capsuleColor
  colorFg: root._syncIconColor.a > 0 ? root._syncIconColor : Color.resolveColorKey(iconColorKey)
  colorFgHover: root._syncIconColor.a > 0 ? root._syncIconColor : Color.mOnHover
  colorBgHover: root._syncHoverColor.a > 0 ? root._syncHoverColor : Style.capsuleColor
  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": I18n.tr("actions.random-wallpaper"),
        "action": "random-wallpaper",
        "icon": "dice"
      },
      {
        "label": I18n.tr("actions.widget-settings"),
        "action": "widget-settings",
        "icon": "settings"
      },
    ]

    onTriggered: action => {
                   contextMenu.close();
                   PanelService.closeContextMenu(screen);

                   if (action === "random-wallpaper") {
                     WallpaperService.setRandomWallpaper();
                   } else if (action === "widget-settings") {
                     BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
                   }
                 }
  }

  onClicked: {
    var wallpaperPanel = PanelService.getPanel("wallpaperPanel", screen);
    if (Settings.data.wallpaper.panelPosition === "follow_bar") {
      wallpaperPanel?.toggle(this);
    } else {
      wallpaperPanel?.toggle();
    }
  }
  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen);
  }
}
