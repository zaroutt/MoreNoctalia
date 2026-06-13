import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Modules.MainScreen.Backgrounds

/**
* PanelBackground - Dynamic ShapePath for rendering panel backgrounds
*
* Dynamically switches between panels based on which panel is currently
* assigned by PanelService. Only 2 instances are needed: one for the
* currently open panel and one for a closing panel during transitions.
*
* Uses 4-state per-corner system for flexible corner rendering:
* - State -1: No radius (flat/square corner)
* - State 0: Normal (inner curve)
* - State 1: Horizontal inversion (outer curve on X-axis)
* - State 2: Vertical inversion (outer curve on Y-axis)
*/
ShapePath {
  id: root

  property var assignedPanel: null

  required property var shapeContainer

  property color defaultBackgroundColor: Color.mSurface

  property bool strokeOnly: false

  readonly property real radius: Style.radiusL

  readonly property var panelRegion: assignedPanel?.panelRegion ?? null

  readonly property var panelBg: (panelRegion && panelRegion.visible) ? panelRegion.panelItem : null

  readonly property color effectiveBackgroundColor: {
    if (!assignedPanel)
      return "transparent";
    if (assignedPanel.panelBackgroundColor !== undefined) {
      return assignedPanel.panelBackgroundColor;
    }
    return defaultBackgroundColor;
  }

  readonly property real panelX: panelBg ? panelBg.x : 0
  readonly property real panelY: panelBg ? panelBg.y : 0
  readonly property real panelWidth: panelBg ? panelBg.width : 0
  readonly property real panelHeight: panelBg ? panelBg.height : 0
  readonly property bool isRenderable: assignedPanel && panelBg && panelWidth > 0 && panelHeight > 0

  readonly property bool shouldFlatten: panelBg ? ShapeCornerHelper.shouldFlatten(panelWidth, panelHeight, radius) : false
  readonly property real effectiveRadius: shouldFlatten ? ShapeCornerHelper.getFlattenedRadius(Math.min(panelWidth, panelHeight), radius) : radius

  readonly property real _minR: 0.01

  function getCornerRadius(cornerState) {
    if (cornerState === -1)
      return _minR;
    return Math.max(_minR, effectiveRadius);
  }

  readonly property real tlMultX: panelBg ? ShapeCornerHelper.getMultX(panelBg.topLeftCornerState) : 1
  readonly property real tlMultY: panelBg ? ShapeCornerHelper.getMultY(panelBg.topLeftCornerState) : 1
  readonly property real tlRadius: panelBg ? getCornerRadius(panelBg.topLeftCornerState) : 0

  readonly property real trMultX: panelBg ? ShapeCornerHelper.getMultX(panelBg.topRightCornerState) : 1
  readonly property real trMultY: panelBg ? ShapeCornerHelper.getMultY(panelBg.topRightCornerState) : 1
  readonly property real trRadius: panelBg ? getCornerRadius(panelBg.topRightCornerState) : 0

  readonly property real brMultX: panelBg ? ShapeCornerHelper.getMultX(panelBg.bottomRightCornerState) : 1
  readonly property real brMultY: panelBg ? ShapeCornerHelper.getMultY(panelBg.bottomRightCornerState) : 1
  readonly property real brRadius: panelBg ? getCornerRadius(panelBg.bottomRightCornerState) : 0

  readonly property real blMultX: panelBg ? ShapeCornerHelper.getMultX(panelBg.bottomLeftCornerState) : 1
  readonly property real blMultY: panelBg ? ShapeCornerHelper.getMultY(panelBg.bottomLeftCornerState) : 1
  readonly property real blRadius: panelBg ? getCornerRadius(panelBg.bottomLeftCornerState) : 0

  strokeWidth: {
    if (!root.strokeOnly) return -1;
    if (!Settings.data.ui.panelOutlineEnabled) return 0;
    if (root.assignedPanel && root.assignedPanel.showPanelOutline === false) return 0;
    return Settings.data.ui.panelOutlineWidth;
  }

  startX: isRenderable ? (panelX + tlRadius * tlMultX) : -0.75
  startY: isRenderable ? panelY : -1

  fillColor: isRenderable ? effectiveBackgroundColor : "transparent"
  strokeColor: {
    if (!root.strokeOnly) return "transparent";
    if (!Settings.data.ui.panelOutlineEnabled) return "transparent";
    if (root.assignedPanel && root.assignedPanel.showPanelOutline === false) return "transparent";
    return Color.mPrimary;
  }

  PathLine {
    relativeX: root.isRenderable ? (root.panelWidth - root.tlRadius * root.tlMultX - root.trRadius * root.trMultX) : 0.75
    relativeY: 0
  }

  PathArc {
    relativeX: root.isRenderable ? (root.trRadius * root.trMultX) : 0
    relativeY: root.isRenderable ? (root.trRadius * root.trMultY) : 0.25
    radiusX: root.isRenderable ? root.trRadius : 0
    radiusY: root.isRenderable ? root.trRadius : 0
    direction: ShapeCornerHelper.getArcDirection(root.trMultX, root.trMultY)
  }

  PathLine {
    relativeX: 0
    relativeY: root.isRenderable ? (root.panelHeight - root.trRadius * root.trMultY - root.brRadius * root.brMultY) : 0.75
  }

  PathArc {
    relativeX: root.isRenderable ? (-root.brRadius * root.brMultX) : -0.25
    relativeY: root.isRenderable ? (root.brRadius * root.brMultY) : 0
    radiusX: root.isRenderable ? root.brRadius : 0
    radiusY: root.isRenderable ? root.brRadius : 0
    direction: ShapeCornerHelper.getArcDirection(root.brMultX, root.brMultY)
  }

  PathLine {
    relativeX: root.isRenderable ? (-(root.panelWidth - root.brRadius * root.brMultX - root.blRadius * root.blMultX)) : -0.75
    relativeY: 0
  }

  PathArc {
    relativeX: root.isRenderable ? (-root.blRadius * root.blMultX) : 0
    relativeY: root.isRenderable ? (-root.blRadius * root.blMultY) : -0.25
    radiusX: root.isRenderable ? root.blRadius : 0
    radiusY: root.isRenderable ? root.blRadius : 0
    direction: ShapeCornerHelper.getArcDirection(root.blMultX, root.blMultY)
  }

  PathLine {
    relativeX: 0
    relativeY: root.isRenderable ? (-(root.panelHeight - root.blRadius * root.blMultY - root.tlRadius * root.tlMultY)) : -0.75
  }

  PathArc {
    relativeX: root.isRenderable ? (root.tlRadius * root.tlMultX) : 0.25
    relativeY: root.isRenderable ? (-root.tlRadius * root.tlMultY) : 0
    radiusX: root.isRenderable ? root.tlRadius : 0
    radiusY: root.isRenderable ? root.tlRadius : 0
    direction: ShapeCornerHelper.getArcDirection(root.tlMultX, root.tlMultY)
  }
}
