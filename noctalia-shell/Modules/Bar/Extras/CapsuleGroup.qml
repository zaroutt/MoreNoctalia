import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Modules.Bar.Extras

// Wraps 1+ widgets in a row or column.
// If >1 widget and all consecutive in capsuleGroupWidgets, draws a single
// background (no 1px seams between adjacent items).
Item {
  id: root

  required property var widgetIds
  required property var widgetScreen
  required property string sectionName
  property int sectionWidgetsCount: 0
  property int startIndex: 0
  property bool capsuleEnabled: false
  property string capsuleColorKey: "none"
  property real capsuleOpacity: 0.3
  property bool vertical: false

  readonly property bool isCapsule: capsuleEnabled
  readonly property real capsuleHeight: Settings.data.bar.capsuleFillBar ? barHeight : Style.getCapsuleHeightForScreen(widgetScreen?.name)
  readonly property real barHeight: Style.getBarHeightForScreen(widgetScreen?.name)

  // Raw color (full alpha) resolved from key
  readonly property color _rawCapsuleColor: capsuleColorKey !== "none"
    ? Color.resolveColorKey(capsuleColorKey)
    : Qt.rgba(0, 0, 0, 1)

  // When capsuleTranslucent is enabled: use smartAlpha directly (same as widgets), replacing capsuleOpacity
  readonly property color _capsuleBgColor: Settings.data.bar.capsuleTranslucent
    ? Color.smartAlpha(_rawCapsuleColor)
    : Qt.alpha(_rawCapsuleColor, capsuleOpacity)

  readonly property real _radius: Math.min(Style.radiusL, capsuleHeight / 2)

  readonly property real _innerPad: root.isCapsule ? (Settings.data.bar.capsuleInnerPadding ?? 0) : 0

  implicitWidth: isCapsule ? (vertical ? capsuleHeight : contentLayout.implicitWidth + _innerPad * 2) : contentLayout.implicitWidth
  implicitHeight: isCapsule ? (vertical ? contentLayout.implicitHeight + _innerPad * 2 : capsuleHeight) : contentLayout.implicitHeight

  Rectangle {
    id: capsuleBg
    visible: root.isCapsule
    anchors.fill: parent
    radius: root._radius
    color: root._capsuleBgColor
    border.width: Settings.data.bar.capsuleOutlineWidth
    border.color: Color.mPrimary
  }

  Flow {
    id: contentLayout
    flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
    spacing: Settings.data.bar.widgetSpacing

    Repeater {
      model: widgetIds

      delegate: Item {
        id: wrapper
        required property string modelData
        required property int index

        clip: root.isCapsule
        width: root.vertical ? (root.isCapsule ? root.capsuleHeight : root.barHeight) : loader.implicitWidth
        height: root.vertical ? loader.implicitHeight : (root.isCapsule ? root.capsuleHeight : root.barHeight)

        BarWidgetLoader {
          id: loader
          anchors.fill: parent
          anchors.margins: 0

          widgetId: wrapper.modelData
          widgetScreen: root.widgetScreen
          widgetProps: ({
            "widgetId": wrapper.modelData,
            "section": root.sectionName,
            "sectionWidgetIndex": root.startIndex + index,
            "sectionWidgetsCount": root.sectionWidgetsCount
          })
        }
      }
    }
  }
}
