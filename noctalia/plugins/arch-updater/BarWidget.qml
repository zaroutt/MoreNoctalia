import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Commons
import qs.Widgets
import qs.Services.UI
import qs.Services.System
import qs.Modules.Bar.Extras

Item {
    id: root

    // Plugin API (injected by PluginService)
    property var pluginApi: null

    // Required properties for bar widgets
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    // Per-screen bar properties (for multi-monitor and vertical bar support)
    readonly property string screenName: screen.name ?? ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

    // Customizable appearance
    readonly property bool boldText: pluginApi?.pluginSettings?.boldText ?? pluginApi?.manifest?.metadata?.defaultSettings?.boldText ?? true

    // Customizable icon
    readonly property string iconName: pluginApi?.pluginSettings?.iconName || pluginApi?.manifest?.metadata?.defaultSettings?.iconName
    readonly property bool useDistroLogo: pluginApi?.pluginSettings?.useDistroLogo ?? pluginApi?.manifest?.metadata?.defaultSettings?.useDistroLogo ?? false
    readonly property string customIconPath: pluginApi?.pluginSettings?.customIconPath ?? pluginApi?.manifest?.metadata?.defaultSettings?.customIconPath ?? ""
    readonly property bool enableColorization: pluginApi?.pluginSettings?.enableColorization ?? pluginApi?.manifest?.metadata?.defaultSettings?.enableColorization ?? false
    readonly property string iconColorKey: pluginApi?.pluginSettings?.iconColor ?? pluginApi?.manifest?.metadata?.defaultSettings?.iconColor ?? "none"
    readonly property color iconColor: enableColorization ? Color.resolveColorKey(iconColorKey) : Color.mPrimary

    property var _syncData: ({})
    property bool globalSyncEnabled: _syncData.syncWidgetColors ?? false
    property string globalCountColorKey: _syncData.syncedCountColor ?? "none"
    property color _syncHoverColor: globalSyncEnabled && _syncData.syncedHoverColor !== "none" ? Color.resolveColorKey(_syncData.syncedHoverColor) : "transparent"
    readonly property string countColorKey: pluginApi?.pluginSettings?.countColor ?? pluginApi?.manifest?.metadata?.defaultSettings?.countColor ?? "none"
    readonly property color countColor: globalSyncEnabled && globalCountColorKey !== "none"
        ? Color.resolveColorKey(globalCountColorKey)
        : globalSyncEnabled ? Color.mOnSurface
        : (enableColorization && countColorKey !== "none" ? Color.resolveColorKey(countColorKey) : Color.mOnSurface)

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

    // Content dimensions (visual capsule size)
    readonly property real contentWidth: isBarVertical ? capsuleHeight : layout.implicitWidth + Style.marginM * 2
    readonly property real contentHeight: isBarVertical ? layout.implicitHeight + Style.marginM * 2 : capsuleHeight

    // Widget dimensions (extends to full bar height for better click area)
    implicitWidth: contentWidth
    implicitHeight: contentHeight

    // Hide on empty
    visible: root.pluginApi.mainInstance.updates.length | !(pluginApi.pluginSettings.hideOnEmpty ?? pluginApi.manifest.metadata.defaultSettings.hideOnEmpty)

    // Tooltip Text
    property string tooltipText: root.pluginApi.mainInstance.systemStr + (root.pluginApi.mainInstance.aurStr ? "\n" + root.pluginApi.mainInstance.aurStr : "") + (root.pluginApi.mainInstance.flatpakStr ? "\n" + root.pluginApi.mainInstance.flatpakStr : "")
    property string tooltipTextTrimmed: root.tooltipText.split("\n").slice(0, 30).join("\n")

    // Visual capsule - centered within the full click area
    Rectangle {
        id: visualCapsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: root.contentWidth
        height: root.contentHeight
        color: mouseArea.containsMouse ? (root._syncHoverColor.a > 0 ? root._syncHoverColor : Style.capsuleColor) : (root.pluginApi.mainInstance.noctaliaUpdate ? "#40" + Color.mTertiary.toString().slice(1) : Style.capsuleColor)
        radius: Style.radiusL
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth
        Item {
            id: layout
            anchors.centerIn: parent
            implicitWidth: contentHorizontal.visible ? contentHorizontal.implicitWidth : contentVertical.implicitWidth
            implicitHeight: contentHorizontal.visible ? contentHorizontal.implicitHeight : contentVertical.implicitHeight

            RowLayout { // Horizontal Widget
                id: contentHorizontal
                visible: !root.isBarVertical
                anchors.centerIn: parent
                spacing: Style.marginS
                NText { // Count
                    visible: !root.pluginApi.mainInstance.refreshing
                    text: (root.pluginApi.mainInstance.updates.length).toString()
                    color: mouseArea.containsMouse ? (root.globalSyncEnabled && root.globalCountColorKey !== "none" ? Color.resolveColorKey(root.globalCountColorKey) : Color.mOnHover) : (root.pluginApi.mainInstance.noctaliaUpdate ? Color.mSecondary : root.countColor)
                    pointSize: root.barFontSize
                    applyUiScale: false
                    font.weight: root.boldText ? Font.Bold : Font.Normal
                }
            }


            ColumnLayout { // Vertical Widget
                id: contentVertical
                visible: root.isBarVertical
                anchors.centerIn: parent
                spacing: Style.marginS
                NText { // Count
                    visible: !root.pluginApi.mainInstance.refreshing
                    text: root.pluginApi.mainInstance.updates.length.toString()
                    color: mouseArea.containsMouse ? (root.globalSyncEnabled && root.globalCountColorKey !== "none" ? Color.resolveColorKey(root.globalCountColorKey) : Color.mOnHover) : (root.pluginApi.mainInstance.noctaliaUpdate ? Color.mSecondary : root.countColor)
                    pointSize: root.barFontSize
                    applyUiScale: false
                    font.weight: root.boldText ? Font.Bold : Font.Normal
                }
            }
        }
    }

    NPopupContextMenu { // Context menu
        id: contextMenu
        model: [
            {
                "label": pluginApi.tr("context.refresh"),
                "action": "refresh",
                "icon": "refresh"
            },
            {
                "label": pluginApi.tr("context.update"),
                "action": "update",
                "icon": "arrow-big-down-lines"
            },
            {
                "label": pluginApi.tr("context.settings"),
                "action": "settings",
                "icon": "settings"
            }
        ]

        onTriggered: action => {
            // Always close the menu first
            contextMenu.close();
            PanelService.closeContextMenu(screen);

            // Handle actions
            if (action === "refresh") {
                Logger.d("Arch Updater", "Refreshing from context menu...")
                root.pluginApi.mainInstance.refresh() // Refresh available updates
            }
            else if (action === "update") {
                Logger.d("Arch Updater", "Updating from context menu...")
                root.pluginApi.mainInstance.update() // Update
            }
            else if (action === "settings") {
                Logger.d("Arch Updater", "Opening settings from context menu...")
                BarService.openPluginSettings(screen, pluginApi.manifest) // Open plugin settings
            }
        }
    }

    MouseArea { // MouseArea at root level for extended click area
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                Logger.d("Arch Updater", "Opening panel from bar...")
                pluginApi.openPanel(root.screen, root) // Open panel
            }
            else if (mouse.button === Qt.RightButton) {
                Logger.d("Arch Updater", "Opening context menu from bar...")
                PanelService.showContextMenu(contextMenu, root, screen) // Open context menu
            }
            else if (mouse.button === Qt.MiddleButton) {
                Logger.d("Arch Updater", "Refreshing from bar...")
                root.pluginApi.mainInstance.refresh() // Refresh available updates
            }
        }
        onEntered: {
            // Tooltip shows available updates for both system and flatpak
            if (pluginApi.pluginSettings.tooltip ?? pluginApi.manifest.metadata.defaultSettings.tooltip) {
                TooltipService.show(root, (root.pluginApi.mainInstance.noctaliaUpdate ? pluginApi.tr("tooltip.noctaliaUpdates") : pluginApi.tr("tooltip.availableUpdates")) + "\n---------------\n" + (root.tooltipTextTrimmed !== root.tooltipText ? root.tooltipTextTrimmed + "\n..." : root.tooltipTextTrimmed), BarService.getTooltipDirection(root.screen?.name))
            }
        }

        onExited: {
            TooltipService.hide()
        }
    }
}