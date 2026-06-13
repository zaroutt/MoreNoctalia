import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Services.UI
import qs.Widgets
import Quickshell.Io
import Quickshell

/**
* AllBackgrounds - Unified Shape container for all bar and panel backgrounds
*
* Unified shadow system. This component contains a single Shape
* with multiple ShapePath children (one for bar, one for each panel type).
*
* Benefits:
* - Single GPU-accelerated rendering pass for all backgrounds
* - Unified shadow system (one MultiEffect for everything)
*/
Item {
  id: root

  // Reference Bar
  required property var bar

  // Reference to MainScreen (for panel access)
  required property var windowRoot

  readonly property color panelBackgroundColor: Color.mSurface

  anchors.fill: parent

  // Bar outline layer — rendered OUTSIDE opacity containers at full opacity
  // so the outline color matches widget outlines exactly
  Shape {
    id: barOutlineShape
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    asynchronous: true
    enabled: false
    visible: Settings.data.bar.showBarOutline

    BarBackground {
      bar: root.bar
      shapeContainer: barOutlineShape
      windowRoot: root.windowRoot
      backgroundColor: "transparent"
      strokeOnly: true
      outlineHoleOnly: root.bar.type === "framed"
    }
  }

  // Unified background container
  Item {
    anchors.fill: parent

    // When not using separate bar opacity, use unified approach (original behavior)
    Item {
      anchors.fill: parent
      visible: !Settings.data.bar.useSeparateOpacity

      // Enable layer caching to prevent continuous re-rendering
      layer.enabled: true
      opacity: Style.effectivePanelOpacity * Style.panelFadeProgress

      Shape {
        id: unifiedBackgroundsShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: true
        enabled: false

        Component.onCompleted: {
          Logger.d("AllBackgrounds", "AllBackgrounds initialized");
        }

        /**
        *  Bar
        */
        BarBackground {
          bar: root.bar
          shapeContainer: unifiedBackgroundsShape
          windowRoot: root.windowRoot
          backgroundColor: Settings.data.bar.backgroundOpacity > 0 ? panelBackgroundColor : "transparent"
        }

        /**
        *  Panel Background Slots
        *  Only 2 slots needed: one for currently open/opening panel, one for closing panel
        */

        // Slot 0: Currently open/opening panel
        PanelBackground {
          assignedPanel: {
            var p = PanelService.backgroundSlotAssignments[0];
            // Only render if this panel belongs to this screen
            return (p && p.screen === root.windowRoot.screen) ? p : null;
          }
          shapeContainer: unifiedBackgroundsShape
          defaultBackgroundColor: panelBackgroundColor
        }

        // Slot 1: Closing panel (during transitions)
        PanelBackground {
          assignedPanel: {
            var p = PanelService.backgroundSlotAssignments[1];
            // Only render if this panel belongs to this screen
            return (p && p.screen === root.windowRoot.screen) ? p : null;
          }
          shapeContainer: unifiedBackgroundsShape
          defaultBackgroundColor: panelBackgroundColor
        }
      }

      // Apply shadow to the unified backgrounds
      NDropShadow {
        anchors.fill: parent
        source: unifiedBackgroundsShape
      }
    }

    // When using separate bar opacity, separate the rendering
    Item {
      anchors.fill: parent
      visible: Settings.data.bar.useSeparateOpacity

      // Panel backgrounds
      Item {
        anchors.fill: parent

        layer.enabled: true
        opacity: Style.effectivePanelOpacity
        visible: true

        Shape {
          id: panelBackgroundsShape
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          asynchronous: true
          enabled: false

          /**
          *  Panel Background Slots
          *  Only 2 slots needed: one for currently open/opening panel, one for closing panel
          */

          // Slot 0: Currently open/opening panel
          PanelBackground {
            assignedPanel: {
              var p = PanelService.backgroundSlotAssignments[0];
              // Only render if this panel belongs to this screen
              return (p && p.screen === root.windowRoot.screen) ? p : null;
            }
            shapeContainer: panelBackgroundsShape
            defaultBackgroundColor: panelBackgroundColor
          }

          // Slot 1: Closing panel (during transitions)
          PanelBackground {
            assignedPanel: {
              var p = PanelService.backgroundSlotAssignments[1];
              // Only render if this panel belongs to this screen
              return (p && p.screen === root.windowRoot.screen) ? p : null;
            }
            shapeContainer: panelBackgroundsShape
            defaultBackgroundColor: panelBackgroundColor
          }
        }

        // Apply shadow to the panel backgrounds
        NDropShadow {
          anchors.fill: parent
          source: panelBackgroundsShape
        }
      }

      // Bar background with separate opacity
      Item {
        anchors.fill: parent

        layer.enabled: true
        opacity: Style.effectiveBarOpacity

        Shape {
          id: barBackgroundShape
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          asynchronous: true
          enabled: false

          BarBackground {
            bar: root.bar
            shapeContainer: barBackgroundShape
            windowRoot: root.windowRoot
            backgroundColor: panelBackgroundColor
          }
        }

        NDropShadow {
          anchors.fill: parent
          source: barBackgroundShape
        }
      }
    }
  }
  // Panel outline layer — rendered OUTSIDE opacity containers at full opacity
  // so panel outline renders ON TOP of background fills
  Shape {
    id: panelOutlineShape
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    asynchronous: true
    enabled: true

    // Slot 0
    PanelBackground {
      assignedPanel: {
        var p = PanelService.backgroundSlotAssignments[0];
        return (p && p.screen === root.windowRoot.screen) ? p : null;
      }
      shapeContainer: panelOutlineShape
      defaultBackgroundColor: "transparent"
      strokeOnly: true
    }

    // Slot 1
    PanelBackground {
      assignedPanel: {
        var p = PanelService.backgroundSlotAssignments[1];
        return (p && p.screen === root.windowRoot.screen) ? p : null;
      }
      shapeContainer: panelOutlineShape
      defaultBackgroundColor: "transparent"
      strokeOnly: true
    }
  }

  // Watch settings.json for external opacity changes (e.g. button 13)
  FileView {
    id: opacityFileWatcher
    path: StandardPath.home + "/.config/quickshell/noctalia-shell/settings.json"
    printErrors: false
    watchChanges: true

    onFileChanged: { if (path) reload() }
    onPathChanged: { if (path) reload() }

    onLoaded: {
      try {
        var json = JSON.parse(text())
        if (json && json.ui && typeof json.ui.panelBackgroundOpacity === "number") {
          Style.panelOpacityOverride = json.ui.panelBackgroundOpacity
        }
      } catch (_) {}
    }
  }

  // When slider changes Settings, reset override so slider takes precedence
  Connections {
    target: Settings.data.ui
    function onPanelBackgroundOpacityChanged() {
      Style.panelOpacityOverride = -1
    }
  }
}
