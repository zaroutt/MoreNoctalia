import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Theming
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null

  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 320 * Style.uiScaleRatio
  property real contentPreferredHeight: editorLayout.implicitHeight + Style.marginL
  readonly property bool allowAttach: true

  // ── State ────────────────────────────────────────────────────
  property var editingScheme: null
  property string editingVariant: "dark"
  property string pickerTargetKey: ""
  property bool previewActive: false
  property var originalColors: null
  property string pendingSchemeName: ""
  property string generatePrimaryColor: "#7aa2f7"

  // Restore colors when panel is destroyed (closes) while preview is active
  Component.onDestruction: {
    root.stopPreview();
  }


  readonly property var colorRoles: [
    {
      key: "mPrimary",
      label: "Primary"
    },
    {
      key: "mOnPrimary",
      label: "On Primary"
    },
    {
      key: "mSecondary",
      label: "Secondary"
    },
    {
      key: "mOnSecondary",
      label: "On Secondary"
    },
    {
      key: "mTertiary",
      label: "Tertiary"
    },
    {
      key: "mOnTertiary",
      label: "On Tertiary"
    },
    {
      key: "mError",
      label: "Error"
    },
    {
      key: "mOnError",
      label: "On Error"
    },
    {
      key: "mSurface",
      label: "Surface"
    },
    {
      key: "mOnSurface",
      label: "On Surface"
    },
    {
      key: "mSurfaceVariant",
      label: "Surface Variant"
    },
    {
      key: "mOnSurfaceVariant",
      label: "On Surface Variant"
    },
    {
      key: "mOutline",
      label: "Outline"
    },
    {
      key: "mShadow",
      label: "Shadow"
    },
    {
      key: "mHover",
      label: "Hover"
    },
    {
      key: "mOnHover",
      label: "On Hover"
    }
  ]

  readonly property var terminalColorRoles: [
    // Normal 8
    { path: ["normal","black"], label: "Black" },
    { path: ["normal","red"], label: "Red" },
    { path: ["normal","green"], label: "Green" },
    { path: ["normal","yellow"], label: "Yellow" },
    { path: ["normal","blue"], label: "Blue" },
    { path: ["normal","magenta"], label: "Magenta" },
    { path: ["normal","cyan"], label: "Cyan" },
    { path: ["normal","white"], label: "White" },
    // Bright 8
    { path: ["bright","black"], label: "Bright Black" },
    { path: ["bright","red"], label: "Bright Red" },
    { path: ["bright","green"], label: "Bright Green" },
    { path: ["bright","yellow"], label: "Bright Yellow" },
    { path: ["bright","blue"], label: "Bright Blue" },
    { path: ["bright","magenta"], label: "Bright Magenta" },
    { path: ["bright","cyan"], label: "Bright Cyan" },
    { path: ["bright","white"], label: "Bright White" },
    // Special
    { path: ["foreground"], label: "Foreground" },
    { path: ["background"], label: "Background" },
    { path: ["selectionFg"], label: "Selection Fg" },
    { path: ["selectionBg"], label: "Selection Bg" },
    { path: ["cursor"], label: "Cursor" },
    { path: ["cursorText"], label: "Cursor Text" }
  ]

  anchors.fill: parent

  // pluginApi is set AFTER Component.onCompleted fires, so we initialize here
  onPluginApiChanged: {
    if (!pluginApi)
      return;
    seedEditor();
  }

  function getTerminalAt(variant, path) {
    var obj = variant.terminal;
    if (!obj) return "#000000";
    for (var i = 0; i < path.length; i++) {
      if (!obj) return "#000000";
      obj = obj[path[i]];
    }
    return obj || "#000000";
  }

  function setTerminalAt(variant, path, color) {
    var obj = variant;
    if (!obj.terminal) obj.terminal = {};
    obj = obj.terminal;
    for (var i = 0; i < path.length - 1; i++) {
      if (!obj[path[i]]) obj[path[i]] = {};
      obj = obj[path[i]];
    }
    obj[path[path.length - 1]] = color;
  }

  onEditingSchemeChanged: {
    saveWip();
    if (root.editingScheme) {
      if (!root.editingScheme.dark.terminal)
        root.editingScheme.dark.terminal = generateTerminalColors(root.editingScheme.dark);
      if (!root.editingScheme.light.terminal)
        root.editingScheme.light.terminal = generateTerminalColors(root.editingScheme.light);
    }
  }

  function saveWip() {
    if (!pluginApi || !root.editingScheme)
      return;
    pluginApi.pluginSettings.wip = {
      name: nameInput.text,
      dark: root.editingScheme.dark,
      light: root.editingScheme.light
    };
    pluginApi.saveSettings();
  }

  function clearWip() {
    if (!pluginApi)
      return;
    pluginApi.pluginSettings.wip = null;
    pluginApi.saveSettings();
  }

  // ── Scheme File Reader ────────────────────────────────────────
  FileView {
    id: schemeFileReader
    onLoaded: {
      try {
        var data = JSON.parse(text());
        if (data && data.dark && data.light) {
          root.editingScheme = {
            dark: data.dark,
            light: data.light
          };
        } else {
          root.editingScheme = root.fallbackScheme();
        }
      } catch (e) {
        root.editingScheme = root.fallbackScheme();
      }
      clearWip();
    }
  }

  // ── Processes ─────────────────────────────────────────────────
  Process {
    id: writeProcess
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      if (code === 0) {
        var name = root.pendingSchemeName;
        var filePath = Settings.configDir + "colorschemes/" + name + "/" + name + ".json";
        Settings.data.colorSchemes.useWallpaperColors = false;
        Settings.data.colorSchemes.predefinedScheme = name;
        ColorSchemeService.applyScheme(filePath);
        ColorSchemeService.loadColorSchemes();
        ToastService.showNotice(pluginApi?.tr("panel.title"), pluginApi?.tr("notifications.saved"));
      } else {
        ToastService.showError(pluginApi?.tr("panel.title"), pluginApi?.tr("notifications.save-error"));
      }
      root.pendingSchemeName = "";
    }
  }

  Process {
    id: paletteProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: {
      if (exitCode === 0 && stdout.text !== "") {
        try {
          var colors = JSON.parse(stdout.text)
          var scheme = { dark: {}, light: {} }
          for (var k in colors) {
            if (k === "terminal") continue
            scheme.dark[k] = colors[k]
            scheme.light[k] = colors[k]
          }
          root.editingScheme = scheme
          clearWip()
        } catch(e) {}
      }
    }
  }

  // ── Color Picker Dialog ───────────────────────────────────────
  NColorPickerDialog {
    id: colorPicker
    screen: pluginApi?.panelOpenScreen
    liveMode: root.previewActive
    onColorSelected: function(color) {
      if (!root.editingScheme || !root.pickerTargetKey)
        return;
      var updated = JSON.parse(JSON.stringify(root.editingScheme));
      var target = updated[root.editingVariant];
      if (root.pickerTargetKey.startsWith("terminal:")) {
        var path = root.pickerTargetKey.substring(9).split(".");
        setTerminalAt(target, path, color.toString());
      } else {
        target[root.pickerTargetKey] = color.toString();
      }
      root.editingScheme = updated;
      if (root.previewActive)
        root.applyPreview();
    }
  }

  // ── Logic ─────────────────────────────────────────────────────
  function seedColors() {
    var md3 = {
      mPrimary: Color.mPrimary.toString(),
      mOnPrimary: Color.mOnPrimary.toString(),
      mSecondary: Color.mSecondary.toString(),
      mOnSecondary: Color.mOnSecondary.toString(),
      mTertiary: Color.mTertiary.toString(),
      mOnTertiary: Color.mOnTertiary.toString(),
      mError: Color.mError.toString(),
      mOnError: Color.mOnError.toString(),
      mSurface: Color.mSurface.toString(),
      mOnSurface: Color.mOnSurface.toString(),
      mSurfaceVariant: Color.mSurfaceVariant.toString(),
      mOnSurfaceVariant: Color.mOnSurfaceVariant.toString(),
      mOutline: Color.mOutline.toString(),
      mShadow: Color.mShadow.toString(),
      mHover: Color.mHover.toString(),
      mOnHover: Color.mOnHover.toString()
    };
    md3.terminal = generateTerminalColors(md3);
    return md3;
  }

  function fallbackScheme() {
    // Used only when no predefined scheme is available (e.g. wallpaper colors).
    // Both variants start from the active Color.m* — user will need to adjust the other manually.
    var seed = seedColors();
    return {
      dark: seed,
      light: JSON.parse(JSON.stringify(seed))
    };
  }

  function startPreview() {
    if (root.previewActive)
      return;
    root.originalColors = seedColors();
    root.previewActive = true;
    applyPreview();
  }

  function stopPreview() {
    if (!root.previewActive)
      return;
    root.previewActive = false;
    if (root.originalColors) {
      ColorSchemeService.writeColorsToDisk(root.originalColors);
      root.originalColors = null;
    }
  }

  function applyPreview() {
    if (!root.previewActive || !root.editingScheme)
      return;
    var variant = Settings.data.colorSchemes.darkMode ? root.editingScheme.dark : root.editingScheme.light;
    ColorSchemeService.writeColorsToDisk(variant);
  }

  function seedEditor() {
    root.stopPreview();
    nameInput.text = "";
    root.editingVariant = "dark";
    var useWallpaper = Settings.data.colorSchemes.useWallpaperColors;
    var predefined = Settings.data.colorSchemes.predefinedScheme;
    if (!useWallpaper && predefined) {
      // Load from scheme file (has both dark + light variants)
      var path = ColorSchemeService.resolveSchemePath(predefined);
      schemeFileReader.path = "";
      schemeFileReader.path = path;
    } else {
      // Wallpaper mode — load current colors.json (single set)
      paletteProc.exec({ command: ["python3", "-c", "import sys,json; print(json.dumps(json.load(open(sys.argv[1]))))", Settings.configDir + "colors.json"] })
    }
  }

  // ── Generate full scheme from primary color ────────────────────
  function hueShift(h, degrees) {
    return ((h * 360 + degrees + 360) % 360) / 360;
  }

  function hslStr(h, s, l) {
    return Qt.hsla(h, s, l, 1).toString();
  }

  function deriveVariantFromPrimary(primaryHex, isDark) {
    var p = Qt.color(primaryHex);
    var h = p.hslHue / 360;
    var sat = p.hslSaturation;
    var ds = sat > 0.3 ? sat : (isDark ? 0.7 : 0.65);

    if (isDark) {
      var darkV = {
        mPrimary: primaryHex,
        mOnPrimary: hslStr(h, Math.min(1, ds * 0.2), 0.92),
        mSecondary: hslStr(hueShift(h, 40), Math.max(0.3, ds * 0.55), 0.72),
        mOnSecondary: hslStr(hueShift(h, 40), 0.1, 0.92),
        mTertiary: hslStr(hueShift(h, -50), Math.max(0.2, ds * 0.35), 0.62),
        mOnTertiary: hslStr(hueShift(h, -50), 0.05, 0.92),
        mError: "#FD4663",
        mOnError: "#FFFFFF",
        mSurface: hslStr(h, Math.min(1, ds * 0.4), 0.08),
        mOnSurface: hslStr(h, Math.min(1, ds * 0.15), 0.88),
        mSurfaceVariant: hslStr(h, Math.min(1, ds * 0.35), 0.12),
        mOnSurfaceVariant: hslStr(h, Math.min(1, ds * 0.2), 0.55),
        mOutline: hslStr(h, Math.min(1, ds * 0.25), 0.22),
        mShadow: hslStr(h, Math.min(1, ds * 0.35), 0.05),
        mHover: hslStr(hueShift(h, -50), Math.max(0.2, ds * 0.35), 0.62),
        mOnHover: hslStr(hueShift(h, -50), 0.05, 0.92)
      };
      darkV.terminal = generateTerminalColors(darkV);
      return darkV;
    } else {
      var lightV = {
        mPrimary: hslStr(h, Math.min(1, ds * 0.85), 0.45),
        mOnPrimary: hslStr(h, 0.1, 0.08),
        mSecondary: hslStr(hueShift(h, 40), Math.max(0.25, ds * 0.45), 0.50),
        mOnSecondary: hslStr(hueShift(h, 40), 0.05, 0.08),
        mTertiary: hslStr(hueShift(h, -50), Math.max(0.15, ds * 0.25), 0.42),
        mOnTertiary: hslStr(hueShift(h, -50), 0.02, 0.08),
        mError: "#FD4663",
        mOnError: "#FFFFFF",
        mSurface: hslStr(h, Math.min(1, ds * 0.1), 0.93),
        mOnSurface: hslStr(h, Math.min(1, ds * 0.45), 0.12),
        mSurfaceVariant: hslStr(h, Math.min(1, ds * 0.15), 0.85),
        mOnSurfaceVariant: hslStr(h, Math.min(1, ds * 0.25), 0.40),
        mOutline: hslStr(h, Math.min(1, ds * 0.15), 0.72),
        mShadow: hslStr(h, Math.min(1, ds * 0.1), 0.88),
        mHover: hslStr(hueShift(h, -50), Math.max(0.15, ds * 0.25), 0.42),
        mOnHover: hslStr(hueShift(h, -50), 0.02, 0.08)
      };
      lightV.terminal = generateTerminalColors(lightV);
      return lightV;
    }
  }

  function deriveSchemeFromPrimary(primaryHex) {
    return {
      dark: deriveVariantFromPrimary(primaryHex, true),
      light: deriveVariantFromPrimary(primaryHex, false)
    };
  }

  // Derive terminal ANSI colors from MD3 color roles so terminal themes generate correctly.
  // green and yellow have no MD3 equivalents so we synthesize them from the primary's
  // saturation/value at standard ANSI hues (135° green, 55° yellow).
  function generateTerminalColors(variant) {
    var surface = Qt.color(variant.mSurface);
    var isDark = (surface.r + surface.g + surface.b) / 3 < 0.5;

    var primary = Qt.color(variant.mPrimary);
    var sat = primary.hsvSaturation > 0.3 ? primary.hsvSaturation : (isDark ? 0.70 : 0.65);
    var val = isDark ? 0.80 : 0.55;

    function colorAt(hueDeg) {
      return Qt.hsva(hueDeg / 360, sat, val, 1).toString().toUpperCase();
    }

    function brighten(hexColor) {
      var c = Qt.color(hexColor);
      var h = c.hsvHue < 0 ? 0 : c.hsvHue;
      return Qt.hsva(h, Math.max(0, c.hsvSaturation - 0.1), Math.min(1.0, c.hsvValue + (isDark ? 0.15 : 0.20)), 1).toString().toUpperCase();
    }

    var normGreen = colorAt(135);
    var normYellow = colorAt(55);

    return {
      normal: {
        black: surface.toString().toUpperCase(),
        red: Qt.color(variant.mError).toString().toUpperCase(),
        green: normGreen,
        yellow: normYellow,
        blue: Qt.color(variant.mPrimary).toString().toUpperCase(),
        magenta: Qt.color(variant.mSecondary).toString().toUpperCase(),
        cyan: Qt.color(variant.mTertiary).toString().toUpperCase(),
        white: Qt.color(variant.mOnSurface).toString().toUpperCase()
      },
      bright: {
        black: Qt.color(variant.mSurfaceVariant).toString().toUpperCase(),
        red: brighten(variant.mError),
        green: brighten(normGreen),
        yellow: brighten(normYellow),
        blue: brighten(variant.mPrimary),
        magenta: brighten(variant.mSecondary),
        cyan: brighten(variant.mTertiary),
        white: isDark ? "#FFFFFF" : brighten(variant.mOnSurface)
      },
      foreground: Qt.color(variant.mOnSurface).toString().toUpperCase(),
      background: surface.toString().toUpperCase(),
      selectionFg: Qt.color(variant.mOnPrimary).toString().toUpperCase(),
      selectionBg: Qt.color(variant.mPrimary).toString().toUpperCase(),
      cursor: Qt.color(variant.mPrimary).toString().toUpperCase(),
      cursorText: Qt.color(variant.mOnPrimary).toString().toUpperCase()
    };
  }

  function saveScheme() {
    var name = nameInput.text.trim();
    if (!name)
      return;
    var dir = Settings.configDir + "colorschemes/" + name;
    var filePath = dir + "/" + name + ".json";
    var darkVariant = JSON.parse(JSON.stringify(root.editingScheme.dark));
    var lightVariant = JSON.parse(JSON.stringify(root.editingScheme.light));
    var payload = {
      dark: darkVariant,
      light: lightVariant
    };
    var json = JSON.stringify(payload, null, 2);
    root.pendingSchemeName = name;
    writeProcess.command = ["python3", "-c", "import sys, os, json; d=json.loads(sys.argv[1]); os.makedirs(sys.argv[2], exist_ok=True); open(sys.argv[3],'w').write(json.dumps(d, indent=2))", json, dir, filePath];
    writeProcess.running = true;
    // Clear preview state without restoring — saved colors are already applied
    root.previewActive = false;
    root.originalColors = null;
    clearWip();
    seedEditor();
  }

  // ── Panel Container ───────────────────────────────────────────
  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      id: editorLayout
      anchors.fill: parent
      anchors.margins: Style.marginXS
      spacing: Style.marginXXS

      // Header
      NBox {
        Layout.fillWidth: true
        implicitHeight: headerContent.implicitHeight + Style.marginM

        RowLayout {
          id: headerContent
          anchors {
            fill: parent
            margins: Style.marginXS
          }

          NIcon {
            icon: "palette"
            pointSize: Style.fontSizeS
            color: Color.mPrimary
          }

          NText {
            text: pluginApi?.tr("panel.title")
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.fillWidth: true
          }

          NIconButton {
            icon: "close"
            tooltipText: I18n.tr("common.close")
            baseSize: Style.baseWidgetSize * 0.5
            onClicked: pluginApi.closePanel(pluginApi.panelOpenScreen)
          }
        }
      }

      // Generate from Primary
      NBox {
        Layout.fillWidth: true
        implicitHeight: generateRow.implicitHeight + Style.marginM

        RowLayout {
          id: generateRow
          anchors {
            fill: parent
            margins: Style.marginXS
          }
          spacing: Style.marginXXS

          NText {
            text: "Primary:"
            color: Color.mOnSurface
            pointSize: Style.fontSizeXXS
            Layout.alignment: Qt.AlignVCenter
          }

          NColorPicker {
            selectedColor: root.generatePrimaryColor
            screen: pluginApi?.panelOpenScreen
            onColorSelected: color => root.generatePrimaryColor = color
          }

          NButton {
            text: "Derive"
            implicitHeight: 22
            onClicked: {
              root.editingScheme = root.deriveSchemeFromPrimary(root.generatePrimaryColor);
            }
          }
        }
      }

      // Color roles — two columns: Dark | Light
      NBox {
        Layout.fillWidth: true
        implicitHeight: colorList.implicitHeight + Style.marginM

        ColumnLayout {
          id: colorList
          anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Style.marginXS
          }
          spacing: 2

          // Column headers
          RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 2

            Item {
              Layout.preferredWidth: 100 * Style.uiScaleRatio
            }

            NText {
              text: pluginApi?.tr("panel.dark")
              color: Color.mOnSurfaceVariant
              pointSize: 8
              font.weight: Font.Medium
              horizontalAlignment: Text.AlignHCenter
              Layout.fillWidth: true
            }

            NText {
              text: pluginApi?.tr("panel.light")
              color: Color.mOnSurfaceVariant
              pointSize: 8
              font.weight: Font.Medium
              horizontalAlignment: Text.AlignHCenter
              Layout.fillWidth: true
            }
          }

          Repeater {
            model: root.colorRoles

            RowLayout {
              required property var modelData
              Layout.fillWidth: true
              spacing: Style.marginXXS

              NText {
                text: modelData.label
                color: Color.mOnSurface
                pointSize: 8
                Layout.preferredWidth: 100 * Style.uiScaleRatio
                elide: Text.ElideRight
              }

              // Dark swatch
              Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 16

                Rectangle {
                  anchors.centerIn: parent
                  width: 16; height: 16
                  radius: 3
                  color: root.editingScheme?.dark?.[modelData.key] ?? "#000000"
                  border.color: Color.mOutline
                  border.width: 1

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.editingVariant = "dark";
                      root.pickerTargetKey = modelData.key;
                      colorPicker.selectedColor = root.editingScheme?.dark?.[modelData.key] ?? "#000000";
                      colorPicker.open();
                    }
                  }
                }
              }

              // Light swatch
              Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 16

                Rectangle {
                  anchors.centerIn: parent
                  width: 16; height: 16
                  radius: 3
                  color: root.editingScheme?.light?.[modelData.key] ?? "#000000"
                  border.color: Color.mOutline
                  border.width: 1

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.editingVariant = "light";
                      root.pickerTargetKey = modelData.key;
                      colorPicker.selectedColor = root.editingScheme?.light?.[modelData.key] ?? "#000000";
                      colorPicker.open();
                    }
                  }
                }
              }
            }
          }
        }
      }

      // ── Terminal Colors ──
      NBox {
        Layout.fillWidth: true
        implicitHeight: terminalList.implicitHeight + Style.marginM

        ColumnLayout {
          id: terminalList
          anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Style.marginXS
          }
          spacing: 2

          NText {
            text: "Terminal Colors"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeXXS
            font.weight: Font.Bold
          }

          // Column headers
          RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 2

            Item {
              Layout.preferredWidth: 100 * Style.uiScaleRatio
            }

            NText {
              text: pluginApi?.tr("panel.dark")
              color: Color.mOnSurfaceVariant
              pointSize: 8
              font.weight: Font.Medium
              horizontalAlignment: Text.AlignHCenter
              Layout.fillWidth: true
            }

            NText {
              text: pluginApi?.tr("panel.light")
              color: Color.mOnSurfaceVariant
              pointSize: 8
              font.weight: Font.Medium
              horizontalAlignment: Text.AlignHCenter
              Layout.fillWidth: true
            }
          }

          Repeater {
            model: root.terminalColorRoles

            RowLayout {
              required property var modelData
              Layout.fillWidth: true
              spacing: Style.marginXXS

              NText {
                text: modelData.label
                color: Color.mOnSurface
                pointSize: 7
                Layout.preferredWidth: 100 * Style.uiScaleRatio
                elide: Text.ElideRight
              }

              // Dark swatch
              Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 16

                Rectangle {
                  anchors.centerIn: parent
                  width: 16; height: 16
                  radius: 3
                  color: root.getTerminalAt(root.editingScheme?.dark ?? {}, modelData.path)
                  border.color: Color.mOutline
                  border.width: 1

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.editingVariant = "dark";
                      root.pickerTargetKey = "terminal:" + modelData.path.join(".");
                      colorPicker.selectedColor = root.getTerminalAt(root.editingScheme?.dark ?? {}, modelData.path);
                      colorPicker.open();
                    }
                  }
                }
              }

              // Light swatch
              Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 16

                Rectangle {
                  anchors.centerIn: parent
                  width: 16; height: 16
                  radius: 3
                  color: root.getTerminalAt(root.editingScheme?.light ?? {}, modelData.path)
                  border.color: Color.mOutline
                  border.width: 1

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.editingVariant = "light";
                      root.pickerTargetKey = "terminal:" + modelData.path.join(".");
                      colorPicker.selectedColor = root.getTerminalAt(root.editingScheme?.light ?? {}, modelData.path);
                      colorPicker.open();
                    }
                  }
                }
              }
            }
          }
        }
      }

      // Footer
      NBox {
        Layout.fillWidth: true
        implicitHeight: footerRow.implicitHeight + Style.marginM

        RowLayout {
          id: footerRow
          anchors {
            fill: parent
            margins: Style.marginXS
          }
          spacing: Style.marginXXS

          NTextInput {
            id: nameInput
            Layout.fillWidth: true
            placeholderText: pluginApi?.tr("panel.scheme-name-placeholder")
            implicitHeight: 22
            onTextChanged: root.saveWip()
          }

          NButton {
            text: pluginApi?.tr("panel.preview")
            icon: root.previewActive ? "eye-off" : "eye"
            outlined: !root.previewActive
            implicitHeight: 22
            onClicked: root.previewActive ? root.stopPreview() : root.startPreview()
          }

          NButton {
            text: pluginApi?.tr("panel.reset")
            outlined: true
            implicitHeight: 22
            onClicked: root.seedEditor()
          }

          NButton {
            text: pluginApi?.tr("panel.save")
            icon: "device-floppy"
            enabled: nameInput.text.trim().length > 0
            implicitHeight: 22
            onClicked: root.saveScheme()
          }
        }
      }
    }
  }
}
