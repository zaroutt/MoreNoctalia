import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property var availableWidgets
  property var addWidgetToSection
  property var removeWidgetFromSection
  property var reorderWidgetInSection
  property var updateWidgetSettingsInSection
  property var moveWidgetBetweenSections

  signal openPluginSettings(var manifest)

  // This sub-tab edits the global default widget configuration (Settings.data.bar.widgets).
  // Per-screen widget overrides are edited in MonitorWidgetsConfig.qml (Monitors sub-tab).

  // determine bar orientation
  readonly property string barPosition: Settings.data.bar.position
  readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"

  function getSectionIcons() {
    return {
      "left": "arrow-bar-to-up",
      "center": "layout-distribute-horizontal",
      "right": "arrow-bar-to-down"
    };
  }

  NText {
    text: I18n.tr("panels.bar.widgets-desc")
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }

  // Left Section
  NSectionEditor {
    sectionName: root.barIsVertical ? I18n.tr("positions.top") : I18n.tr("positions.left")
    sectionId: "left"
    barIsVertical: root.barIsVertical
    settingsDialogComponent: Qt.resolvedUrl(Quickshell.shellDir + "/Modules/Panels/Settings/Bar/BarWidgetSettingsDialog.qml")
    widgetRegistry: BarWidgetRegistry
    widgetModel: Settings.data.bar.widgets.left
    sectionIcons: root.getSectionIcons()
    availableWidgets: root.availableWidgets
    onAddWidget: (widgetId, section) => root.addWidgetToSection(widgetId, section)
    onRemoveWidget: (section, index) => root.removeWidgetFromSection(section, index)
    onReorderWidget: (section, fromIndex, toIndex) => root.reorderWidgetInSection(section, fromIndex, toIndex)
    onUpdateWidgetSettings: (section, index, settings) => root.updateWidgetSettingsInSection(section, index, settings)
    onMoveWidget: (fromSection, index, toSection) => root.moveWidgetBetweenSections(fromSection, index, toSection)
    onOpenPluginSettingsRequested: manifest => root.openPluginSettings(manifest)
  }

  // Center Section
  NSectionEditor {
    sectionName: I18n.tr("positions.center")
    sectionId: "center"
    barIsVertical: root.barIsVertical
    settingsDialogComponent: Qt.resolvedUrl(Quickshell.shellDir + "/Modules/Panels/Settings/Bar/BarWidgetSettingsDialog.qml")
    widgetRegistry: BarWidgetRegistry
    widgetModel: Settings.data.bar.widgets.center
    sectionIcons: root.getSectionIcons()
    availableWidgets: root.availableWidgets
    onAddWidget: (widgetId, section) => root.addWidgetToSection(widgetId, section)
    onRemoveWidget: (section, index) => root.removeWidgetFromSection(section, index)
    onReorderWidget: (section, fromIndex, toIndex) => root.reorderWidgetInSection(section, fromIndex, toIndex)
    onUpdateWidgetSettings: (section, index, settings) => root.updateWidgetSettingsInSection(section, index, settings)
    onMoveWidget: (fromSection, index, toSection) => root.moveWidgetBetweenSections(fromSection, index, toSection)
    onOpenPluginSettingsRequested: manifest => root.openPluginSettings(manifest)
  }

  // Right Section
  NSectionEditor {
    sectionName: root.barIsVertical ? I18n.tr("positions.bottom") : I18n.tr("positions.right")
    sectionId: "right"
    barIsVertical: root.barIsVertical
    settingsDialogComponent: Qt.resolvedUrl(Quickshell.shellDir + "/Modules/Panels/Settings/Bar/BarWidgetSettingsDialog.qml")
    widgetRegistry: BarWidgetRegistry
    widgetModel: Settings.data.bar.widgets.right
    sectionIcons: root.getSectionIcons()
    availableWidgets: root.availableWidgets
    onAddWidget: (widgetId, section) => root.addWidgetToSection(widgetId, section)
    onRemoveWidget: (section, index) => root.removeWidgetFromSection(section, index)
    onReorderWidget: (section, fromIndex, toIndex) => root.reorderWidgetInSection(section, fromIndex, toIndex)
    onUpdateWidgetSettings: (section, index, settings) => root.updateWidgetSettingsInSection(section, index, settings)
    onMoveWidget: (fromSection, index, toSection) => root.moveWidgetBetweenSections(fromSection, index, toSection)
    onOpenPluginSettingsRequested: manifest => root.openPluginSettings(manifest)
  }

  // ── Capsule grouping section ──
  NDivider {
    Layout.fillWidth: true
  }

  NText {
    text: "Capsules"
    pointSize: Style.fontSizeL
    font.weight: Style.fontWeightBold
    color: Color.mPrimary
  }

  NToggle {
    label: "Group widgets in capsule"
    description: "When enabled, each selected widget gets an individual background. Consecutive selected widgets share the same background (single capsule)."
    checked: Settings.data.bar.capsuleGroupEnabled
    onToggled: checked => Settings.data.bar.capsuleGroupEnabled = checked
  }

  NText {
    text: "Marque os widgets que devem ter fundo de cápsula. Mesmo sozinhos, eles ganham o fundo. Se houver 2+ consecutivos na mesma seção, eles se fundem em uma única cápsula."
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
    visible: Settings.data.bar.capsuleGroupEnabled
  }

  NToggle {
    label: "Individual Colors - Left"
    description: "Each widget in a capsule keeps its own color instead of sharing the first widget's color."
    checked: Settings.data.bar.capsuleIndividualColorsLeft
    visible: Settings.data.bar.capsuleGroupEnabled
    enabled: Settings.data.bar.capsuleGroupEnabled
    onToggled: checked => Settings.data.bar.capsuleIndividualColorsLeft = checked
}

        NToggle {
    label: "Individual Colors - Center"
    description: "Each widget in a capsule keeps its own color instead of sharing the first widget's color."
    checked: Settings.data.bar.capsuleIndividualColorsCenter
    visible: Settings.data.bar.capsuleGroupEnabled
    enabled: Settings.data.bar.capsuleGroupEnabled
    onToggled: checked => Settings.data.bar.capsuleIndividualColorsCenter = checked
}

        NToggle {
    label: "Individual Colors - Right"
    description: "Each widget in a capsule keeps its own color instead of sharing the first widget's color."
    checked: Settings.data.bar.capsuleIndividualColorsRight
    visible: Settings.data.bar.capsuleGroupEnabled
    enabled: Settings.data.bar.capsuleGroupEnabled
    onToggled: checked => Settings.data.bar.capsuleIndividualColorsRight = checked
}

  Repeater {
    model: BarWidgetRegistry.getAvailableWidgets()
    delegate: NToggle {
      label: modelData
      checked: Settings.data.bar.capsuleGroupWidgets.indexOf(modelData) >= 0
      visible: Settings.data.bar.capsuleGroupEnabled
      enabled: Settings.data.bar.capsuleGroupEnabled
      onToggled: checked => {
        var arr = Settings.data.bar.capsuleGroupWidgets.slice();
        var idx = arr.indexOf(modelData);
        if (checked && idx < 0)
          arr.push(modelData);
        else if (!checked && idx >= 0)
          arr.splice(idx, 1);
        Settings.data.bar.capsuleGroupWidgets = arr;
      }
    }
  }

  function _sectionHasCapsule(sectionName) {
    if (!Settings.data.bar.capsuleGroupEnabled) return false;
    var sectionWidgets = Settings.data.bar.widgets ? (Settings.data.bar.widgets[sectionName] || []) : [];
    var capsuleSet = new Set(Settings.data.bar.capsuleGroupWidgets || []);
    for (var i = 0; i < sectionWidgets.length; i++) {
      if (capsuleSet.has(sectionWidgets[i].id)) return true;
    }
    return false;
  }

  NText {
    text: "Capsule color per section"
    pointSize: Style.fontSizeS
    font.weight: Style.fontWeightBold
    color: Color.mSecondary
    visible: Settings.data.bar.capsuleGroupEnabled && (_sectionHasCapsule("left") || _sectionHasCapsule("center") || _sectionHasCapsule("right"))
  }

  NText {
    text: "Choose the capsule background color and opacity for each bar section."
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
    visible: Settings.data.bar.capsuleGroupEnabled && (_sectionHasCapsule("left") || _sectionHasCapsule("center") || _sectionHasCapsule("right"))
  }

  NColorChoice {
    Layout.fillWidth: true
    visible: Settings.data.bar.capsuleGroupEnabled && _sectionHasCapsule("left")
    label: "Left"
    description: "Capsule color for left section widgets"
    noneColor: Color.mSurfaceVariant
    noneOnColor: Color.mOnSurfaceVariant
    currentKey: Settings.data.bar.capsuleLeftColorKey
    onSelected: key => Settings.data.bar.capsuleLeftColorKey = key
  }
  NValueSlider {
    Layout.fillWidth: true
    visible: Settings.data.bar.capsuleGroupEnabled && _sectionHasCapsule("left")
    label: "Opacity (left)"
    from: 0
    to: 1
    stepSize: 0.01
    value: Settings.data.bar.capsuleLeftOpacity
    onMoved: v => Settings.data.bar.capsuleLeftOpacity = v
    text: Math.floor(Settings.data.bar.capsuleLeftOpacity * 100) + "%"
  }

  NColorChoice {
    Layout.fillWidth: true
    visible: Settings.data.bar.capsuleGroupEnabled && _sectionHasCapsule("center")
    label: "Center"
    description: "Capsule color for center section widgets"
    noneColor: Color.mSurfaceVariant
    noneOnColor: Color.mOnSurfaceVariant
    currentKey: Settings.data.bar.capsuleCenterColorKey
    onSelected: key => Settings.data.bar.capsuleCenterColorKey = key
  }
  NValueSlider {
    Layout.fillWidth: true
    visible: Settings.data.bar.capsuleGroupEnabled && _sectionHasCapsule("center")
    label: "Opacity (center)"
    from: 0
    to: 1
    stepSize: 0.01
    value: Settings.data.bar.capsuleCenterOpacity
    onMoved: v => Settings.data.bar.capsuleCenterOpacity = v
    text: Math.floor(Settings.data.bar.capsuleCenterOpacity * 100) + "%"
  }

  NColorChoice {
    Layout.fillWidth: true
    visible: Settings.data.bar.capsuleGroupEnabled && _sectionHasCapsule("right")
    label: "Right"
    description: "Capsule color for right section widgets"
    noneColor: Color.mSurfaceVariant
    noneOnColor: Color.mOnSurfaceVariant
    currentKey: Settings.data.bar.capsuleRightColorKey
    onSelected: key => Settings.data.bar.capsuleRightColorKey = key
  }
  NValueSlider {
    Layout.fillWidth: true
    visible: Settings.data.bar.capsuleGroupEnabled && _sectionHasCapsule("right")
    label: "Opacity (right)"
    from: 0
    to: 1
    stepSize: 0.01
    value: Settings.data.bar.capsuleRightOpacity
    onMoved: v => Settings.data.bar.capsuleRightOpacity = v
    text: Math.floor(Settings.data.bar.capsuleRightOpacity * 100) + "%"
  }
  NDivider {
    Layout.fillWidth: true
    visible: Settings.data.bar.capsuleGroupEnabled && (_sectionHasCapsule("left") || _sectionHasCapsule("center") || _sectionHasCapsule("right"))
  }

  NText {
    text: "Capsule outline"
    pointSize: Style.fontSizeS
    font.weight: Style.fontWeightBold
    color: Color.mSecondary
    visible: Settings.data.bar.capsuleGroupEnabled && (_sectionHasCapsule("left") || _sectionHasCapsule("center") || _sectionHasCapsule("right"))
  }

  NToggle {
    Layout.fillWidth: true
    visible: Settings.data.bar.capsuleGroupEnabled && (_sectionHasCapsule("left") || _sectionHasCapsule("center") || _sectionHasCapsule("right"))
    label: "Show outline"
    description: "Adds a visible border around the capsules"
    checked: (Settings.data.bar.capsuleOutlineWidth ?? 0) > 0
    onToggled: checked => {
      if (checked) {
        Settings.data.bar.capsuleOutlineWidth = 1
      } else {
        Settings.data.bar.capsuleOutlineWidth = 0
      }
    }
  }

  NValueSlider {
    Layout.fillWidth: true
    visible: Settings.data.bar.capsuleGroupEnabled && (Settings.data.bar.capsuleOutlineWidth ?? 0) > 0
    label: "Outline thickness"
    from: 0
    to: 5
    stepSize: 1
    value: Settings.data.bar.capsuleOutlineWidth ?? 0
    onMoved: v => Settings.data.bar.capsuleOutlineWidth = v
    text: Settings.data.bar.capsuleOutlineWidth > 0 ? Settings.data.bar.capsuleOutlineWidth + "px" : "Off"
  }

}
