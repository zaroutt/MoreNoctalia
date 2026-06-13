import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  // Bar positioning properties
  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real barHeight: Style.getBarHeightForScreen(screenName)
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  readonly property real contentWidth: root.isVertical ? root.capsuleHeight : horizontalRow.implicitWidth + Style.marginM * 2
  readonly property real contentHeight: root.isVertical ? root.capsuleHeight : root.capsuleHeight

  readonly property int todoCount: getIntValue(pluginApi?.pluginSettings?.count, getIntValue(pluginApi?.manifest?.metadata?.defaultSettings?.count, 0))
  readonly property int completedCount: getIntValue(pluginApi?.pluginSettings?.completedCount, getIntValue(pluginApi?.manifest?.metadata?.defaultSettings?.completedCount, 0))
  readonly property int activeCount: todoCount - completedCount
  property var _syncData: ({})
  property bool globalSyncEnabled: _syncData.syncWidgetColors ?? false
  property string globalCountColorKey: _syncData.syncedCountColor ?? "none"
  property string globalIconColorKey: _syncData.syncedIconColor ?? "none"
  property color _syncHoverColor: globalSyncEnabled && _syncData.syncedHoverColor !== "none" ? Color.resolveColorKey(_syncData.syncedHoverColor) : "transparent"
  readonly property string countColorKey: pluginApi?.pluginSettings?.countColor ?? pluginApi?.manifest?.metadata?.defaultSettings?.countColor ?? "none"
  readonly property color countColor: globalSyncEnabled && globalCountColorKey !== "none" ? Color.resolveColorKey(globalCountColorKey) : globalSyncEnabled ? Color.mOnSurface : (countColorKey !== "none" ? Color.resolveColorKey(countColorKey) : Color.mOnSurface)
  readonly property color contentColor: mouseArea.containsMouse ? (globalSyncEnabled && globalCountColorKey !== "none" ? Color.resolveColorKey(globalCountColorKey) : Color.mOnHover) : root.countColor

  // Tooltip text for vertical mode
  readonly property string tooltipText: {
    var count = root.activeCount;
    var key = count === 1 ? "bar_widget.todo_count_singular" : "bar_widget.todo_count_plural";
    return pluginApi?.tr(key).replace("{count}", count);
  }

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  function getIntValue(value, defaultValue) {
    return (typeof value === 'number') ? Math.floor(value) : defaultValue;
  }

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

  // Visual capsule - pixel-perfect centered
  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    radius: Style.radiusL
    color: mouseArea.containsMouse ? (root._syncHoverColor.a > 0 ? root._syncHoverColor : Style.capsuleColor) : Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    Row {
      id: horizontalRow
      anchors.centerIn: parent
      spacing: Style.marginS
      visible: !root.isVertical

      NText {
        anchors.verticalCenter: parent.verticalCenter
        text: root.activeCount.toString()
        color: root.contentColor
        pointSize: root.barFontSize
        applyUiScale: false
      }
    }

    Column {
      id: verticalColumn
      anchors.centerIn: parent
      spacing: Style.marginS
      visible: root.isVertical

      NText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.activeCount.toString()
        color: root.contentColor
        pointSize: root.barFontSize
        applyUiScale: false
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: function (mouse) {
      if (mouse.button === Qt.LeftButton) {
        if (pluginApi) {
          Logger.i("Todo", "Opening Todo panel");
          pluginApi.openPanel(root.screen, this);
        }
      } else if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, screen);
      }
    }
    onEntered: {
      if (root.isVertical) {
        TooltipService.show(root, tooltipText, BarService.getTooltipDirection(root.screen?.name));
      }
    }
    onExited: {
      TooltipService.hide();
    }
  }

  // Right-click context menu
  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("actions.widget_settings") || "Settings",
        "action": "widget-settings",
        "icon": "settings"
      },
    ]

    onTriggered: action => {
                   contextMenu.close();
                   PanelService.closeContextMenu(screen);

                   if (action === "widget-settings") {
                     BarService.openPluginSettings(screen, pluginApi.manifest);
                   }
                 }
  }
}
