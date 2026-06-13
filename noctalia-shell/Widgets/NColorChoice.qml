import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons
import qs.Services.UI
import qs.Widgets

RowLayout {
  id: root

  property string label: I18n.tr("common.select-color")
  property string description: I18n.tr("common.select-color-description")
  property string tooltip: ""
  property string currentKey: ""
  property var defaultValue: undefined
  property var noneColor: undefined      // color declared as var so we can nullify
  property var noneOnColor: undefined    // color declared as var so we can nullify

  readonly property bool isValueChanged: (defaultValue !== undefined) && (currentKey !== defaultValue)
  readonly property string indicatorTooltip: {
    I18n.tr("panels.indicator.default-value", {
              "value": defaultValue === "" ? "(empty)" : String(defaultValue)
            });
  }

  readonly property int diameter: Style.baseWidgetSize * 0.9 * Style.uiScaleRatio

  signal selected(string key)

  NLabel {
    label: root.label
    description: root.description
    showIndicator: root.isValueChanged
    indicatorTooltip: root.indicatorTooltip
  }

  RowLayout {
    id: colourRow

    opacity: enabled ? 1.0 : 0.6
    Layout.minimumWidth: root.diameter * Color.colorKeyModel.length

    Repeater {
      model: Color.colorKeyModel

      Rectangle {
        id: colorCircle

        property bool isSelected: root.currentKey === modelData.key
        property bool isHovered: circleMouseArea.containsMouse

        Layout.alignment: Qt.AlignHCenter
        implicitWidth: root.diameter
        implicitHeight: root.diameter
        radius: root.diameter * 0.5
        color: (modelData.key === "none" && root.noneColor !== undefined) ? root.noneColor : Color.resolveColorKey(modelData.key)
        border.color: (isSelected || isHovered) ? Color.mOnSurface : Color.mOutline
        border.width: Style.borderM

        MouseArea {
          id: circleMouseArea

          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: TooltipService.show(parent, modelData.name)
          onExited: TooltipService.hide()
          onClicked: {
            root.currentKey = modelData.key;
            root.selected(modelData.key);
          }
        }

        NIcon {
          anchors.centerIn: parent
          icon: "check"
          pointSize: Math.max(Style.fontSizeXS, colorCircle.width * 0.4)
          color: (modelData.key === "none" && root.noneOnColor !== undefined) ? root.noneOnColor : Color.resolveOnColorKey(modelData.key)
          font.weight: Style.fontWeightBold
          visible: colorCircle.isSelected
        }

        Behavior on border.color {
          ColorAnimation {
            duration: Style.animationFast
          }
        }
      }
    }

    // Custom color circle
    Rectangle {
      id: customCircle

      property bool isCustomSelected: root.currentKey && root.currentKey.charAt(0) === '#'
      property bool isHovered: customCircleMouseArea.containsMouse
      property color customFillColor: isCustomSelected ? root.currentKey : Color.mSurface

      Layout.alignment: Qt.AlignHCenter
      implicitWidth: root.diameter
      implicitHeight: root.diameter
      radius: root.diameter * 0.5
      color: customFillColor
      border.color: (isCustomSelected || isHovered) ? Color.mOnSurface : Color.mOutline
      border.width: Style.borderM

      MouseArea {
        id: customCircleMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: TooltipService.show(parent, "Custom Color")
        onExited: TooltipService.hide()
        onClicked: {
          var dlg = Qt.createComponent("NColorPickerDialog.qml").createObject(customCircle, {
            "selectedColor": customCircle.isCustomSelected ? root.currentKey : "#ffffff",
            "parent": Overlay.overlay,
          });
          dlg.colorSelected.connect(function(color) {
            var hex = color.toString()
            if (hex.startsWith("#")) {
              root.currentKey = hex;
              root.selected(hex);
            }
          });
          dlg.open();
        }
      }

      // Palette icon when no custom color selected
      NIcon {
        anchors.centerIn: parent
        icon: "color-picker"
        pointSize: Math.max(Style.fontSizeXS, customCircle.width * 0.4)
        color: Color.mOutline
        font.weight: Style.fontWeightBold
        visible: !customCircle.isCustomSelected
      }

      // Checkmark when custom color is active
      NIcon {
        anchors.centerIn: parent
        icon: "check"
        pointSize: Math.max(Style.fontSizeXS, customCircle.width * 0.4)
        color: "#ffffff"
        font.weight: Style.fontWeightBold
        visible: customCircle.isCustomSelected
      }

      Behavior on border.color {
        ColorAnimation {
          duration: Style.animationFast
        }
      }
    }
  }
}
