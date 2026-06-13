import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Modules.Notification
import qs.Modules.Panels.Settings
import qs.Services.Compositor
import qs.Services.Media
import qs.Services.UI
import qs.Widgets

// Bar Component
Item {
  id: root

  // This property will be set by MainScreen
  property ShellScreen screen: null

  // Bar shadow state (from Settings.data.bar)
  property bool barShadowEnabled: Settings.data.bar.shadowEnabled ?? false
  property color barShadowColor: Settings.data.bar.shadowColor ?? "#441e1e"
  property real barShadowSoftness: Settings.data.bar.shadowSoftness ?? 6
  property real barShadowSpread: Settings.data.bar.shadowSpread ?? 0
  property int barShadowOffsetX: Settings.data.bar.shadowOffsetX ?? 0
  property int barShadowOffsetY: Settings.data.bar.shadowOffsetY ?? 4

  // Filter widgets to only include those that exist in the registry
  // This prevents errors when plugins are missing or widgets are being cleaned up
  function filterValidWidgets(widgets: list<var>): list<var> {
    if (!widgets)
      return [];
    return widgets.filter(function (w) {
      return w && w.id && BarWidgetRegistry.hasWidget(w.id);
    });
  }

  // Hot corner: trigger click on first widget in a section
  function triggerFirstWidgetInSection(sectionName: string) {
    var widgets = BarService.getWidgetsBySection(sectionName, screen?.name);
    for (var i = 0; i < widgets.length; i++) {
      var widget = widgets[i];
      if (widget && widget.visible && widget.widgetId !== "Spacer") {
        if (typeof widget.clicked === "function") {
          widget.clicked();
        }
        return;
      }
    }
  }

  // Hot corner: trigger click on last widget in a section
  function triggerLastWidgetInSection(sectionName: string) {
    var widgets = BarService.getWidgetsBySection(sectionName, screen?.name);
    for (var i = widgets.length - 1; i >= 0; i--) {
      var widget = widgets[i];
      if (widget && widget.visible && widget.widgetId !== "Spacer") {
        if (typeof widget.clicked === "function") {
          widget.clicked();
        }
        return;
      }
    }
  }

  // Expose bar region for click-through mask
  readonly property var barRegion: barContentLoader.item?.children[0] || null

  // Expose the actual bar Item for unified background system
  readonly property var barItem: barRegion

  // Bar positioning properties (per-screen)
  readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
  readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"
  readonly property bool barFloating: Settings.data.bar.barType === "floating"

  // Bar density (per-screen)
  readonly property string barDensity: Settings.getBarDensityForScreen(screen?.name)

  // Bar sizing based on per-screen density
  readonly property real barHeight: Style.getBarHeightForDensity(barDensity, barIsVertical)
  readonly property real capsuleHeight: Settings.data.bar.capsuleFillBar ? barHeight : Style.getCapsuleHeightForDensity(barDensity, barHeight)
  readonly property real barFontSize: Style.getBarFontSizeForDensity(barHeight, capsuleHeight, barIsVertical)

  // Bar widgets (per-screen) - initial configuration
  // Note: Updates are handled via Connections to BarService.widgetsRevisionChanged
  readonly property var barWidgets: Settings.getBarWidgetsForScreen(screen?.name)

  // Stable ListModels for each section - prevents Repeater recreation on settings changes
  property ListModel leftWidgetsModel: ListModel {}
  property ListModel centerWidgetsModel: ListModel {}
  property ListModel rightWidgetsModel: ListModel {}

  // Guard: set when Bar is destroyed; prevents Qt.callLater callbacks from running
  // during/after teardown (avoids SIGSEGV in QV4::Object::insertMember when rapid
  // workspace switch causes load/unload overlap with async widget incubation)
  property bool _destroyed: false
  Component.onDestruction: root._destroyed = true

  // Grouped models for capsule support (horizontal bars only)
  property var leftGroupedModel: []
  property var centerGroupedModel: []
  property var rightGroupedModel: []

  // Display models: when collapse is active, the target section concatenates
  // all three grouped models (preserving each group's original color and structure).
  readonly property var leftDisplayModel:   Settings.data.bar.capsuleCollapseTarget === "left"   ? leftGroupedModel.concat(centerGroupedModel, rightGroupedModel)   : (Settings.data.bar.capsuleCollapseTarget === "none" ? leftGroupedModel   : [])
  readonly property var centerDisplayModel: Settings.data.bar.capsuleCollapseTarget === "center" ? leftGroupedModel.concat(centerGroupedModel, rightGroupedModel) : (Settings.data.bar.capsuleCollapseTarget === "none" ? centerGroupedModel : [])
  readonly property var rightDisplayModel:  Settings.data.bar.capsuleCollapseTarget === "right"  ? leftGroupedModel.concat(centerGroupedModel, rightGroupedModel)  : (Settings.data.bar.capsuleCollapseTarget === "none" ? rightGroupedModel  : [])

  // Intra-section spacing (rows of widgets inside a section)
  readonly property real _sectionSpacing: Settings.data.bar.capsuleGroupSpacing

  function buildGroupedModel(listModel, section) {
    var Lkey = Settings.data.bar.capsuleLeftColorKey;
    var Lop  = Settings.data.bar.capsuleLeftOpacity;
    var Ckey = Settings.data.bar.capsuleCenterColorKey;
    var Cop  = Settings.data.bar.capsuleCenterOpacity;
    var Rkey = Settings.data.bar.capsuleRightColorKey;
    var Rop  = Settings.data.bar.capsuleRightOpacity;

    function colorFor(id) {
      var _lw = Settings.data.bar.widgets.left   || [];
      for (var i = 0; i < _lw.length; i++) { if (_lw[i] && _lw[i].id === id) return { key: Lkey, op: Lop }; }
      var _cw = Settings.data.bar.widgets.center || [];
      for (var j = 0; j < _cw.length; j++) { if (_cw[j] && _cw[j].id === id) return { key: Ckey, op: Cop }; }
      var _rw = Settings.data.bar.widgets.right  || [];
      for (var k = 0; k < _rw.length; k++) { if (_rw[k] && _rw[k].id === id) return { key: Rkey, op: Rop }; }
      if (section === "left")   return { key: Lkey, op: Lop };
      if (section === "center") return { key: Ckey, op: Cop };
      return                            { key: Rkey, op: Rop };
    }

    if (!Settings.data.bar.capsuleGroupEnabled) {
      var out = [];
      for (var n = 0; n < listModel.count; n++) {
        var idN = listModel.get(n).id;
        var cN = colorFor(idN);
        out.push({ ids: [idN], startIndex: n, capsule: false, colorKey: cN.key, opacity: cN.op });
      }
      return out;
    }

    var capsuleSet = new Set(Settings.data.bar.capsuleGroupWidgets || []);
    var individualColors = (Settings.data.bar["capsuleIndividualColors" + section.charAt(0).toUpperCase() + section.slice(1)] === true);
    var groups = [];
    var tempGroup = [];
    for (var i = 0; i < listModel.count; i++) {
      var id = listModel.get(i).id;
      var c = colorFor(id);
      if (capsuleSet.has(id)) {
        tempGroup.push(id);
      } else {
        if (tempGroup.length > 0) {
          var groupStart = i - tempGroup.length;
          if (individualColors) {
            // Each widget in the group gets its own capsule with its own color
            for (var g = 0; g < tempGroup.length; g++) {
              var gid = tempGroup[g];
              var gc = colorFor(gid);
              groups.push({ ids: [gid], startIndex: groupStart + g, capsule: true, colorKey: gc.key, opacity: gc.op });
            }
          } else {
            // Original behavior: one capsule for the whole group, using the first widget's color
            var firstId = tempGroup[0];
            var fc = colorFor(firstId);
            groups.push({ ids: tempGroup.slice(), startIndex: groupStart, capsule: true, colorKey: fc.key, opacity: fc.op });
          }
          tempGroup = [];
        }
        groups.push({ ids: [id], startIndex: i, capsule: false, colorKey: c.key, opacity: c.op });
      }
    }
    if (tempGroup.length > 0) {
      var groupStart2 = listModel.count - tempGroup.length;
      if (individualColors) {
        for (var g2 = 0; g2 < tempGroup.length; g2++) {
          var gid2 = tempGroup[g2];
          var gc2 = colorFor(gid2);
          groups.push({ ids: [gid2], startIndex: groupStart2 + g2, capsule: true, colorKey: gc2.key, opacity: gc2.op });
        }
      } else {
        var fc2 = colorFor(tempGroup[0]);
        groups.push({ ids: tempGroup, startIndex: groupStart2, capsule: true, colorKey: fc2.key, opacity: fc2.op });
      }
    }
    return groups;
  }

  function rebuildGroupedModels() {
    leftGroupedModel   = root.buildGroupedModel(root.leftWidgetsModel,   "left");
    centerGroupedModel = root.buildGroupedModel(root.centerWidgetsModel, "center");
    rightGroupedModel  = root.buildGroupedModel(root.rightWidgetsModel,  "right");
  }

  // Sync a ListModel with widget data, preserving delegates when only settings change
  function syncWidgetModel(model, newWidgets) {
    var validWidgets = filterValidWidgets(newWidgets);

    // Build list of current IDs in model
    var currentIds = [];
    for (var i = 0; i < model.count; i++) {
      currentIds.push(model.get(i).id);
    }

    // Build list of new IDs
    var newIds = validWidgets.map(w => w.id);

    // Check if structure changed (different IDs or order)
    var structureChanged = currentIds.length !== newIds.length;
    if (!structureChanged) {
      for (var i = 0; i < currentIds.length; i++) {
        if (currentIds[i] !== newIds[i]) {
          structureChanged = true;
          break;
        }
      }
    }

    Logger.d("Bar", "syncWidgetModel:", currentIds.join("|"), "→", newIds.join("|"), "changed:", structureChanged);

    if (structureChanged) {
      // Rebuild model - IDs changed
      model.clear();
      for (var i = 0; i < validWidgets.length; i++) {
        model.append(validWidgets[i]);
      }
    }
    // If structure didn't change, delegates are preserved and will read fresh settings
  }

  // Sync models when widget revision changes
  // Note: We use Connections instead of onBarWidgetsChanged because getBarWidgetsForScreen
  // returns the same object reference (Settings.data.bar.widgets) even when content changes,
  // so QML won't detect the change via property binding.
  Connections {
    target: BarService
    function onWidgetsRevisionChanged() {
      Logger.d("Bar", "onWidgetsRevisionChanged, revision:", BarService.widgetsRevision, "screen:", root.screen?.name);
      Qt.callLater(root._syncFromRevision);
    }
  }

  Connections {
    target: Settings.data.bar
    function onCapsuleGroupWidgetsChanged() {
      root.rebuildGroupedModels();
    }
    function onCapsuleGroupEnabledChanged() {
      root.rebuildGroupedModels();
    }
    function onCapsuleCollapseTargetChanged() {
      Logger.i("Bar", "capsuleCollapseTarget →", Settings.data.bar.capsuleCollapseTarget);
      Qt.callLater(root.rebuildGroupedModels);
    }
    function onCapsuleLeftColorKeyChanged()   { root.rebuildGroupedModels(); }
    function onCapsuleCenterColorKeyChanged() { root.rebuildGroupedModels(); }
    function onCapsuleRightColorKeyChanged()  { root.rebuildGroupedModels(); }
    function onCapsuleLeftOpacityChanged()    { root.rebuildGroupedModels(); }
    function onCapsuleCenterOpacityChanged()  { root.rebuildGroupedModels(); }
    function onCapsuleRightOpacityChanged()   { root.rebuildGroupedModels(); }
  }

  function _syncFromRevision() {
    if (root._destroyed)
      return;
    var widgets = Settings.getBarWidgetsForScreen(screen?.name);
    if (widgets) {
      syncWidgetModel(leftWidgetsModel, widgets.left);
      syncWidgetModel(centerWidgetsModel, widgets.center);
      syncWidgetModel(rightWidgetsModel, widgets.right);
      root.rebuildGroupedModels();
    }
  }

  // Initialize models — deferred to next event-loop tick via Qt.callLater to avoid
  // re-entrant incubation: Component.onCompleted fires during QQmlObjectCreator::finalize,
  // and ListModel.append synchronously creates Repeater delegates whose own finalization
  // can corrupt the V4 heap (SIGSEGV in QV4::Object::insertMember).
  Component.onCompleted: {
    Logger.d("Bar", "Bar Component.onCompleted for screen:", screen?.name);
    Qt.callLater(root._initModels);
  }

  function _initModels() {
    if (root._destroyed)
      return;
    var widgets = Settings.getBarWidgetsForScreen(screen?.name);
    if (widgets) {
      syncWidgetModel(leftWidgetsModel, widgets.left);
      syncWidgetModel(centerWidgetsModel, widgets.center);
      syncWidgetModel(rightWidgetsModel, widgets.right);
      root.rebuildGroupedModels();
    }
  }

  // Fill the parent (the Loader)
  anchors.fill: parent

  // Register bar when screen becomes available
  onScreenChanged: {
    if (screen && screen.name) {
      Logger.d("Bar", "Bar screen set to:", screen.name);
      Logger.d("Bar", "  Position:", barPosition, "Floating:", barFloating);
      BarService.registerBar(screen.name);
    }
  }

  // Wait for screen to be set before loading bar content
  Loader {
    id: barContentLoader
    anchors.fill: parent
    active: {
      if (root.screen === null || root.screen === undefined) {
        return false;
      }

      var monitors = Settings.data.bar.monitors || [];
      var result = monitors.length === 0 || monitors.includes(root.screen.name);
      return result;
    }

    sourceComponent: Item {
      anchors.fill: parent

      // Bar shadow (synced with niri shadow)
      RectangularShadow {
        id: barShadow
        anchors.fill: bar
        offset.x: root.barShadowOffsetX
        offset.y: root.barShadowOffsetY
        radius: Settings.data.bar.frameRadius || 12
        blur: root.barShadowSoftness
        spread: root.barShadowSpread
        color: root.barShadowColor
        visible: root.barShadowEnabled
      }

      // Bar container - Content
      Item {
        id: bar

        // Wheel scroll handling (empty bar area)
        property int barWheelAccumulatedDelta: 0
        property bool barWheelCooldown: false
        readonly property string barWheelAction: {
          return Settings.data.bar.mouseWheelAction || "none";
        }
        readonly property string barRightClickAction: Settings.data.bar.rightClickAction || "controlCenter"

        // Position and size the bar content based on orientation
        x: (root.barPosition === "right") ? (parent.width - root.barHeight) : 0
        y: (root.barPosition === "bottom") ? (parent.height - root.barHeight) : 0
        width: root.barIsVertical ? root.barHeight : parent.width
        height: root.barIsVertical ? parent.height : root.barHeight

        // Corner states for new unified background system
        // State -1: No radius (flat/square corner)
        // State 0: Normal (inner curve)
        // State 1: Horizontal inversion (outer curve on X-axis)
        // State 2: Vertical inversion (outer curve on Y-axis)
        readonly property int topLeftCornerState: {
          // Floating bar: always simple rounded corners
          if (barFloating)
            return 0;
          // Top bar: top corners against screen edge = no radius
          if (barPosition === "top")
            return -1;
          // Left bar: top-left against screen edge = no radius
          if (barPosition === "left")
            return -1;
          // Bottom/Right bar with outerCorners: inverted corner
          if (Settings.data.bar.outerCorners && (barPosition === "bottom" || barPosition === "right")) {
            return barIsVertical ? 1 : 2; // horizontal invert for vertical bars, vertical invert for horizontal
          }
          // No outerCorners = square
          return -1;
        }

        readonly property int topRightCornerState: {
          // Floating bar: always simple rounded corners
          if (barFloating)
            return 0;
          // Top bar: top corners against screen edge = no radius
          if (barPosition === "top")
            return -1;
          // Right bar: top-right against screen edge = no radius
          if (barPosition === "right")
            return -1;
          // Bottom/Left bar with outerCorners: inverted corner
          if (Settings.data.bar.outerCorners && (barPosition === "bottom" || barPosition === "left")) {
            return barIsVertical ? 1 : 2;
          }
          // No outerCorners = square
          return -1;
        }

        readonly property int bottomLeftCornerState: {
          // Floating bar: always simple rounded corners
          if (barFloating)
            return 0;
          // Bottom bar: bottom corners against screen edge = no radius
          if (barPosition === "bottom")
            return -1;
          // Left bar: bottom-left against screen edge = no radius
          if (barPosition === "left")
            return -1;
          // Top/Right bar with outerCorners: inverted corner
          if (Settings.data.bar.outerCorners && (barPosition === "top" || barPosition === "right")) {
            return barIsVertical ? 1 : 2;
          }
          // No outerCorners = square
          return -1;
        }

        readonly property int bottomRightCornerState: {
          // Floating bar: always simple rounded corners
          if (barFloating)
            return 0;
          // Bottom bar: bottom corners against screen edge = no radius
          if (barPosition === "bottom")
            return -1;
          // Right bar: bottom-right against screen edge = no radius
          if (barPosition === "right")
            return -1;
          // Top/Left bar with outerCorners: inverted corner
          if (Settings.data.bar.outerCorners && (barPosition === "top" || barPosition === "left")) {
            return barIsVertical ? 1 : 2;
          }
          // No outerCorners = square
          return -1;
        }

        function isPointOverWidget(xPos, yPos) {
          var widgets = BarService.getAllWidgetInstances(null, screen.name);
          for (var i = 0; i < widgets.length; i++) {
            var widget = widgets[i];
            if (!widget || !widget.visible || widget.widgetId === "Spacer") {
              continue;
            }
            var localPos = mapToItem(widget, xPos, yPos);

            if (root.barIsVertical) {
              if (localPos.y >= -Style.marginS && localPos.y <= widget.height + Style.marginS) {
                return true;
              }
            } else {
              if (localPos.x >= -Style.marginS && localPos.x <= widget.width + Style.marginS) {
                return true;
              }
            }
          }
          return false;
        }

        function switchWorkspaceByOffset(offset) {
          if (!root.screen || CompositorService.workspaces.count === 0)
            return;

          var screenName = root.screen.name.toLowerCase();
          var candidates = [];
          for (var i = 0; i < CompositorService.workspaces.count; i++) {
            var ws = CompositorService.workspaces.get(i);
            var matchesScreen = CompositorService.globalWorkspaces || (ws.output && ws.output.toLowerCase() === screenName);
            if (matchesScreen)
              candidates.push(ws);
          }

          if (candidates.length <= 1)
            return;

          var current = -1;
          for (var j = 0; j < candidates.length; j++) {
            if (candidates[j].isFocused) {
              current = j;
              break;
            }
          }
          if (current < 0)
            current = 0;

          var next = current + offset;
          if (Settings.data.bar.mouseWheelWrap) {
            next = next % candidates.length;
            if (next < 0)
              next = candidates.length - 1;
          } else {
            if (next < 0 || next >= candidates.length)
              return;
          }

          if (next === current)
            return;
          CompositorService.switchToWorkspace(candidates[next]);
        }

        function handleEmptyBarClick(action, followMouse, command, mouse) {
          if (action === "none")
            return;
          if (action === "controlCenter") {
            var controlCenterPanel = PanelService.getPanel("controlCenterPanel", screen);
            controlCenterPanel?.toggle(null, followMouse ? mapToItem(null, mouse.x, mouse.y) : "ControlCenter");
            mouse.accepted = true;
          } else if (action === "settings") {
            var settingsPanel = PanelService.getPanel("settingsPanel", screen);
            settingsPanel?.toggle(null, followMouse ? mapToItem(null, mouse.x, mouse.y) : null);
            mouse.accepted = true;
          } else if (action === "launcherPanel") {
            var launcherPanel = PanelService.getPanel("launcherPanel", screen);
            launcherPanel?.toggle(null, followMouse ? mapToItem(null, mouse.x, mouse.y) : null);
            mouse.accepted = true;
          } else if (action === "command") {
            runCustomCommand(command);
            mouse.accepted = true;
          }
        }

        function runCustomCommand(command) {
          if (!command || command.trim() === "")
            return;

          const processString = "import QtQuick; import Quickshell.Io; Process { command: [\"sh\", \"-lc\", \"\"] }";

          try {
            const processObj = Qt.createQmlObject(processString, root, "BarCommandProcess_" + Date.now());
            processObj.command = ["sh", "-lc", command];

            processObj.exited.connect(function (exitCode) {
              if (exitCode !== 0) {
                ToastService.showError(I18n.tr("toast.custom-command-failed.title"), I18n.tr("toast.custom-command-failed.description", {
                                                                                                command: command,
                                                                                                code: exitCode
                                                                                              }));
              }
              processObj.destroy();
            });

            processObj.running = true;
          } catch (e) {
            Logger.e("Bar", "Failed to start custom command:", e);
            ToastService.showError(I18n.tr("toast.custom-command-failed.title"), I18n.tr("toast.custom-command-failed.description", {
                                                                                            command: command,
                                                                                            code: "start_error"
                                                                                          }));
          }
        }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.RightButton | Qt.MiddleButton
          // Keep enabled even when actions are "none" so we still swallow right/middle on
          // empty bar gaps. Otherwise Qt Quick's context-menu path can crash on Wayland
          // (QQuickDeliveryAgentPrivate::contextMenuTargets / mapToScene).
          enabled: true
          hoverEnabled: false
          preventStealing: true
          onClicked: mouse => {
                       if (mouse.button === Qt.RightButton) {
                         if (bar.isPointOverWidget(mouse.x, mouse.y))
                         return;
                         bar.handleEmptyBarClick(bar.barRightClickAction, Settings.data.bar.rightClickFollowMouse, Settings.data.bar.rightClickCommand, mouse);
                         mouse.accepted = true;
                         return;
                       }
                       if (mouse.button === Qt.MiddleButton) {
                         if (bar.isPointOverWidget(mouse.x, mouse.y))
                         return;
                         bar.handleEmptyBarClick(Settings.data.bar.middleClickAction || "none", Settings.data.bar.middleClickFollowMouse, Settings.data.bar.middleClickCommand, mouse);
                         mouse.accepted = true;
                         return;
                       }
                     }
        }

        // Debounce timer for wheel interactions
        Timer {
          id: barWheelDebounce
          interval: 150
          repeat: false
          onTriggered: {
            bar.barWheelCooldown = false;
            bar.barWheelAccumulatedDelta = 0;
          }
        }

        // Scroll on empty bar area action
        WheelHandler {
          id: barWheelHandler
          target: bar
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          enabled: bar.barWheelAction !== "none"

          onWheel: function (event) {
            if (bar.isPointOverWidget(event.x, event.y))
              return;

            var dy = event.angleDelta.y;
            var dx = event.angleDelta.x;
            var useDy = Math.abs(dy) >= Math.abs(dx);
            var delta = useDy ? dy : dx;
            var step = 120;

            if (bar.barWheelAction === "volume") {
              if (Settings.data.bar.reverseScroll)
                delta *= -1;

              bar.barWheelAccumulatedDelta += delta;
              if (bar.barWheelAccumulatedDelta >= step) {
                AudioService.increaseVolume();
                bar.barWheelAccumulatedDelta = 0;
                event.accepted = true;
              } else if (bar.barWheelAccumulatedDelta <= -step) {
                AudioService.decreaseVolume();
                bar.barWheelAccumulatedDelta = 0;
                event.accepted = true;
              }
              return;
            }

            if (bar.barWheelCooldown)
              return;

            bar.barWheelAccumulatedDelta += delta;
            if (Math.abs(bar.barWheelAccumulatedDelta) >= step) {
              var direction = bar.barWheelAccumulatedDelta > 0 ? -1 : 1;
              if (Settings.data.bar.reverseScroll)
                direction *= -1;
              if (bar.barWheelAction === "workspace") {
                bar.switchWorkspaceByOffset(direction);
              } else if (bar.barWheelAction === "content") {
                CompositorService.scrollWorkspaceContent(direction);
              }
              bar.barWheelCooldown = true;
              barWheelDebounce.restart();
              bar.barWheelAccumulatedDelta = 0;
              event.accepted = true;
            }
          }
        }

        Loader {
          anchors.fill: parent
          sourceComponent: root.barIsVertical ? verticalBarComponent : horizontalBarComponent
        }
      }
    }
  }

  // For vertical bars
  Component {
    id: verticalBarComponent
    Item {
      anchors.fill: parent
      clip: true

      // Top edge hot corner - triggers first widget in left (top) section
      MouseArea {
        width: parent.width
        height: Style.marginS
        x: 0
        y: 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function (mouse) {
          if (mouse.button !== Qt.LeftButton) {
            mouse.accepted = true;
            return;
          }
          root.triggerFirstWidgetInSection("left");
        }
      }

      // Bottom edge hot corner - triggers last widget in right (bottom) section
      MouseArea {
        width: parent.width
        height: Style.marginS
        x: 0
        anchors.bottom: parent.bottom
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function (mouse) {
          if (mouse.button !== Qt.LeftButton) {
            mouse.accepted = true;
            return;
          }
          root.triggerLastWidgetInSection("right");
        }
      }

      // Calculate margin to center widgets vertically within the bar height
      readonly property real verticalBarMargin: Math.round((root.barHeight - root.capsuleHeight) / 2)

      // Top section (left widgets) - uses grouped model for capsule colors
      ColumnLayout {
        x: Style.pixelAlignCenter(parent.width, width)
        anchors.top: parent.top
        anchors.topMargin: verticalBarMargin + (Settings.data.bar.capsuleFillBar ? 0 : Settings.data.bar.contentPadding)
        spacing: root._sectionSpacing

        Repeater {
          model: root.leftDisplayModel

          delegate: CapsuleGroup {
            required property var modelData

            widgetIds: modelData.ids
            widgetScreen: root.screen
            sectionName: "left"
            sectionWidgetsCount: root.leftWidgetsModel.count
            startIndex: modelData.startIndex
            capsuleEnabled: modelData.capsule
            capsuleColorKey: modelData.colorKey || "none"
            capsuleOpacity: modelData.opacity !== undefined ? modelData.opacity : 0.3
            vertical: true
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }

      // Center section (center widgets) - uses grouped model for capsule colors
      ColumnLayout {
        x: Style.pixelAlignCenter(parent.width, width)
        anchors.verticalCenter: parent.verticalCenter
        spacing: root._sectionSpacing

        Repeater {
          model: root.centerDisplayModel

          delegate: CapsuleGroup {
            required property var modelData

            widgetIds: modelData.ids
            widgetScreen: root.screen
            sectionName: "center"
            sectionWidgetsCount: root.centerWidgetsModel.count
            startIndex: modelData.startIndex
            capsuleEnabled: modelData.capsule
            capsuleColorKey: modelData.colorKey || "none"
            capsuleOpacity: modelData.opacity !== undefined ? modelData.opacity : 0.3
            vertical: true
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }

      // Bottom section (right widgets) - uses grouped model for capsule colors
      ColumnLayout {
        x: Style.pixelAlignCenter(parent.width, width)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: verticalBarMargin + (Settings.data.bar.capsuleFillBar ? 0 : Settings.data.bar.contentPadding)
        spacing: root._sectionSpacing

        Repeater {
          model: root.rightDisplayModel

          delegate: CapsuleGroup {
            required property var modelData

            widgetIds: modelData.ids
            widgetScreen: root.screen
            sectionName: "right"
            sectionWidgetsCount: root.rightWidgetsModel.count
            startIndex: modelData.startIndex
            capsuleEnabled: modelData.capsule
            capsuleColorKey: modelData.colorKey || "none"
            capsuleOpacity: modelData.opacity !== undefined ? modelData.opacity : 0.3
            vertical: true
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }
    }
  }

  // For horizontal bars
  Component {
    id: horizontalBarComponent
    Item {
      anchors.fill: parent
      clip: true

      // Left edge hot corner - triggers first widget in left section
      MouseArea {
        width: Style.marginS
        height: parent.height
        x: 0
        y: 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function (mouse) {
          if (mouse.button !== Qt.LeftButton) {
            mouse.accepted = true;
            return;
          }
          root.triggerFirstWidgetInSection("left");
        }
      }

      // Right edge hot corner - triggers last widget in right section
      MouseArea {
        width: Style.marginS
        height: parent.height
        anchors.right: parent.right
        y: 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function (mouse) {
          if (mouse.button !== Qt.LeftButton) {
            mouse.accepted = true;
            return;
          }
          root.triggerLastWidgetInSection("right");
        }
      }

      // Calculate margin to center widgets horizontally within the bar height
      readonly property real horizontalBarMargin: Math.round((root.barHeight - root.capsuleHeight) / 2)

      // Left Section
      RowLayout {
        id: leftSection
        objectName: "leftSection"
        anchors.left: parent.left
        anchors.leftMargin: horizontalBarMargin + (Settings.data.bar.capsuleFillBar ? 0 : Settings.data.bar.contentPadding)
        y: Style.pixelAlignCenter(parent.height, height)
        spacing: root._sectionSpacing

        Repeater {
          model: root.leftDisplayModel

          delegate: CapsuleGroup {
            required property var modelData

            widgetIds: modelData.ids
            widgetScreen: root.screen
            sectionName: "left"
            sectionWidgetsCount: root.leftWidgetsModel.count
            startIndex: modelData.startIndex
            capsuleEnabled: modelData.capsule
            capsuleColorKey: modelData.colorKey || "none"
            capsuleOpacity: modelData.opacity !== undefined ? modelData.opacity : 0.3
            Layout.alignment: Qt.AlignVCenter
          }
        }
      }

      // Center Section
      RowLayout {
        id: centerSection
        objectName: "centerSection"
        anchors.horizontalCenter: parent.horizontalCenter
        y: Style.pixelAlignCenter(parent.height, height)
        spacing: root._sectionSpacing

        Repeater {
          model: root.centerDisplayModel

          delegate: CapsuleGroup {
            required property var modelData

            widgetIds: modelData.ids
            widgetScreen: root.screen
            sectionName: "center"
            sectionWidgetsCount: root.centerWidgetsModel.count
            startIndex: modelData.startIndex
            capsuleEnabled: modelData.capsule
            capsuleColorKey: modelData.colorKey || "none"
            capsuleOpacity: modelData.opacity !== undefined ? modelData.opacity : 0.3
            Layout.alignment: Qt.AlignVCenter
          }
        }
      }

      // Right Section
      RowLayout {
        id: rightSection
        objectName: "rightSection"
        anchors.right: parent.right
        anchors.rightMargin: horizontalBarMargin + (Settings.data.bar.capsuleFillBar ? 0 : Settings.data.bar.contentPadding)
        y: Style.pixelAlignCenter(parent.height, height)
        spacing: root._sectionSpacing

        Repeater {
          model: root.rightDisplayModel

          delegate: CapsuleGroup {
            required property var modelData

            widgetIds: modelData.ids
            widgetScreen: root.screen
            sectionName: "right"
            sectionWidgetsCount: root.rightWidgetsModel.count
            startIndex: modelData.startIndex
            capsuleEnabled: modelData.capsule
            capsuleColorKey: modelData.colorKey || "none"
            capsuleOpacity: modelData.opacity !== undefined ? modelData.opacity : 0.3
            Layout.alignment: Qt.AlignVCenter
          }
        }
      }
    }
  }
}
