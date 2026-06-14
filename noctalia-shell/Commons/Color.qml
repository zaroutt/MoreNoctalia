pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Power

/*
Noctalia is not strictly a Material Design project, it supports both some predefined
color schemes and dynamic color generation from the wallpaper.

We ultimately decided to use a restricted set of colors that follows the
Material Design 3 naming convention.

NOTE: All color names are prefixed with 'm' (e.g., mPrimary) to prevent QML from
misinterpreting them as signals (e.g., the 'onPrimary' property name).
*/
Singleton {
  id: root

  property bool reloadColors: false

  // Debounce external reload requests (file watcher + directory watcher)
  // so atomic replacements only trigger one reload.
  Timer {
    id: externalColorReloadTimer
    running: false
    interval: 200
    onTriggered: {
      if (customColorsFile.path !== undefined) {
        Logger.d("Color", "Reloading colors from disk");
        reloadColors = true;
        customColorsFile.reload();
      }
    }
  }

  function scheduleExternalColorReload() {
    if (!Settings.directoriesCreated || customColorsFile.path === undefined) {
      return;
    }
    externalColorReloadTimer.restart();
  }

  // Suppress transition animations until the first colors.json load completes
  property bool skipTransition: true

  // Flag indicating theme colors are currently transitioning (for widgets to disable their own animations)
  property bool isTransitioning: false

  // Timer to reset isTransitioning after animation completes
  Timer {
    id: transitionTimer
    interval: Style.animationSlowest + 50 // Small buffer after animation
    onTriggered: root.isTransitioning = false
  }

  // --- Key Colors: These are the main accent colors that define your app's style
  property color mPrimary: defaultColors.mPrimary
  property color mOnPrimary: defaultColors.mOnPrimary
  property color mSecondary: defaultColors.mSecondary
  property color mOnSecondary: defaultColors.mOnSecondary
  property color mTertiary: defaultColors.mTertiary
  property color mOnTertiary: defaultColors.mOnTertiary

  // --- Utility Colors: These colors serve specific, universal purposes like indicating errors
  property color mError: defaultColors.mError
  property color mOnError: defaultColors.mOnError

  // --- Surface and Variant Colors: These provide additional options for surfaces and their contents, creating visual hierarchy
  property color mSurface: defaultColors.mSurface
  property color mOnSurface: defaultColors.mOnSurface

  property color mSurfaceVariant: defaultColors.mSurfaceVariant
  property color mOnSurfaceVariant: defaultColors.mOnSurfaceVariant

  property color mOutline: defaultColors.mOutline
  property color mShadow: defaultColors.mShadow

  property color mHover: defaultColors.mHover
  property color mOnHover: defaultColors.mOnHover

  // --- Terminal Colors: ANSI palette for terminal emulators
  property color mTermBlack:        defaultColors.mTermBlack
  property color mTermRed:          defaultColors.mTermRed
  property color mTermGreen:        defaultColors.mTermGreen
  property color mTermYellow:       defaultColors.mTermYellow
  property color mTermBlue:         defaultColors.mTermBlue
  property color mTermMagenta:      defaultColors.mTermMagenta
  property color mTermCyan:         defaultColors.mTermCyan
  property color mTermWhite:        defaultColors.mTermWhite
  property color mTermBrightBlack:  defaultColors.mTermBrightBlack
  property color mTermBrightRed:    defaultColors.mTermBrightRed
  property color mTermBrightGreen:  defaultColors.mTermBrightGreen
  property color mTermBrightYellow: defaultColors.mTermBrightYellow
  property color mTermBrightBlue:   defaultColors.mTermBrightBlue
  property color mTermBrightMagenta:defaultColors.mTermBrightMagenta
  property color mTermBrightCyan:   defaultColors.mTermBrightCyan
  property color mTermBrightWhite:  defaultColors.mTermBrightWhite
  property color mTermForeground:   defaultColors.mTermForeground
  property color mTermBackground:   defaultColors.mTermBackground
  property color mTermCursor:       defaultColors.mTermCursor

  // --- Color transition animations ---
  Behavior on mPrimary {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnPrimary {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mSecondary {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnSecondary {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mTertiary {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnTertiary {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mError {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnError {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mSurface {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnSurface {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mSurfaceVariant {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnSurfaceVariant {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOutline {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mShadow {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mHover {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnHover {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }

  // Helper to start transition and update a color
  function startTransition() {
    root.isTransitioning = true;
    transitionTimer.restart();
  }

  // Update colors when customColorsData changes (imperative assignment enables Behavior animations)
  Connections {
    target: customColorsData
    function onMPrimaryChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mPrimary = customColorsData.mPrimary;
    }
    function onMOnPrimaryChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mOnPrimary = customColorsData.mOnPrimary;
    }
    function onMSecondaryChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mSecondary = customColorsData.mSecondary;
    }
    function onMOnSecondaryChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mOnSecondary = customColorsData.mOnSecondary;
    }
    function onMTertiaryChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mTertiary = customColorsData.mTertiary;
    }
    function onMOnTertiaryChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mOnTertiary = customColorsData.mOnTertiary;
    }
    function onMErrorChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mError = customColorsData.mError;
    }
    function onMOnErrorChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mOnError = customColorsData.mOnError;
    }
    function onMSurfaceChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mSurface = customColorsData.mSurface;
    }
    function onMOnSurfaceChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mOnSurface = customColorsData.mOnSurface;
    }
    function onMSurfaceVariantChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mSurfaceVariant = customColorsData.mSurfaceVariant;
    }
    function onMOnSurfaceVariantChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mOnSurfaceVariant = customColorsData.mOnSurfaceVariant;
    }
    function onMOutlineChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mOutline = customColorsData.mOutline;
    }
    function onMShadowChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mShadow = customColorsData.mShadow;
    }
    function onMHoverChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mHover = customColorsData.mHover;
    }
    function onMOnHoverChanged() {
      if (!root.skipTransition) {
        startTransition();
      }
      root.mOnHover = customColorsData.mOnHover;
    }
    function onMTermBlackChanged() { root.mTermBlack = customColorsData.mTermBlack; }
    function onMTermRedChanged() { root.mTermRed = customColorsData.mTermRed; }
    function onMTermGreenChanged() { root.mTermGreen = customColorsData.mTermGreen; }
    function onMTermYellowChanged() { root.mTermYellow = customColorsData.mTermYellow; }
    function onMTermBlueChanged() { root.mTermBlue = customColorsData.mTermBlue; }
    function onMTermMagentaChanged() { root.mTermMagenta = customColorsData.mTermMagenta; }
    function onMTermCyanChanged() { root.mTermCyan = customColorsData.mTermCyan; }
    function onMTermWhiteChanged() { root.mTermWhite = customColorsData.mTermWhite; }
    function onMTermBrightBlackChanged() { root.mTermBrightBlack = customColorsData.mTermBrightBlack; }
    function onMTermBrightRedChanged() { root.mTermBrightRed = customColorsData.mTermBrightRed; }
    function onMTermBrightGreenChanged() { root.mTermBrightGreen = customColorsData.mTermBrightGreen; }
    function onMTermBrightYellowChanged() { root.mTermBrightYellow = customColorsData.mTermBrightYellow; }
    function onMTermBrightBlueChanged() { root.mTermBrightBlue = customColorsData.mTermBrightBlue; }
    function onMTermBrightMagentaChanged() { root.mTermBrightMagenta = customColorsData.mTermBrightMagenta; }
    function onMTermBrightCyanChanged() { root.mTermBrightCyan = customColorsData.mTermBrightCyan; }
    function onMTermBrightWhiteChanged() { root.mTermBrightWhite = customColorsData.mTermBrightWhite; }
    function onMTermForegroundChanged() { root.mTermForeground = customColorsData.mTermForeground; }
    function onMTermBackgroundChanged() { root.mTermBackground = customColorsData.mTermBackground; }
    function onMTermCursorChanged() { root.mTermCursor = customColorsData.mTermCursor; }
  }

  function resolveColorKey(key) {
    switch (key) {
    case "primary":
      return root.mPrimary;
    case "secondary":
      return root.mSecondary;
    case "tertiary":
      return root.mTertiary;
    case "error":
      return root.mError;
    default:
      if (key && key.charAt(0) === '#')
        return key;
      return root.mOnSurface;
    }
  }

  function resolveOnColorKey(key) {
    switch (key) {
    case "primary":
      return root.mOnPrimary;
    case "secondary":
      return root.mOnSecondary;
    case "tertiary":
      return root.mOnTertiary;
    case "error":
      return root.mOnError;
    default:
      if (key && key.charAt(0) === '#')
        return "#ffffff";
      return root.mSurface;
    }
  }

  function resolveColorKeyOptional(key) {
    switch (key) {
    case "primary":
      return root.mPrimary;
    case "secondary":
      return root.mSecondary;
    case "tertiary":
      return root.mTertiary;
    case "error":
      return root.mError;
    default:
      return "transparent";
    }
  }

  // Adaptive opacity calculation: automatically makes light mode more transparent
  function adaptiveOpacity(baseOpacity) {
    if (PowerProfileService.noctaliaPerformanceMode)
      return 1.0;
    return Settings.data.colorSchemes.darkMode ? baseOpacity : Math.pow(baseOpacity, 1.5);
  }

  function smartAlpha(baseColor, minAlpha = 0.4) {
    if (!(Settings.data.ui.filledBackground ?? true))
      return "transparent";
    if (PowerProfileService.noctaliaPerformanceMode)
      return baseColor;

    if (!Settings.data.ui.translucentWidgets)
      return baseColor;

    let alpha = Math.max(adaptiveOpacity(Settings.data.ui.panelBackgroundOpacity), minAlpha);

    // Combine with the base color's existing alpha
    let resultAlpha = Math.max(0, baseColor.a - (1.0 - alpha));
    return Qt.alpha(baseColor, resultAlpha);
  }

  // ── Synced Widget Colors (from sync-colors.json, resolved via FileView) ──
  // Widgets reference these directly — no per-widget FileView needed.
  property bool syncWidgetColors: false
  property string _syncIconKey: "none"
  property string _syncCountKey: "none"
  property string _syncHoverKey: "none"

  readonly property color syncedIconColor: root.syncWidgetColors && root._syncIconKey !== "none" ? root.resolveColorKey(root._syncIconKey) : "transparent"
  readonly property color syncedCountColor: root.syncWidgetColors && root._syncCountKey !== "none" ? root.resolveColorKey(root._syncCountKey) : "transparent"
  readonly property color syncedHoverColor: root.syncWidgetColors && root._syncHoverKey !== "none" ? root.resolveColorKey(root._syncHoverKey) : "transparent"

  FileView {
    id: syncColorsFile
    path: Settings.directoriesCreated ? (Quickshell.env("HOME") + "/.config/noctalia/sync-colors.json") : undefined
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try {
        var d = JSON.parse(text())
        root.syncWidgetColors = d.syncWidgetColors ?? false
        root._syncIconKey = d.syncedIconColor ?? "none"
        root._syncCountKey = d.syncedCountColor ?? "none"
        root._syncHoverKey = d.syncedHoverColor ?? "none"
      } catch(e) {}
    }
    onLoadFailed: {
      root.syncWidgetColors = false
      root._syncIconKey = "none"
      root._syncCountKey = "none"
      root._syncHoverKey = "none"
    }
  }

  readonly property var colorKeyModel: [
    {
      "key": "none",
      "name": I18n.tr("common.none")
    },
    {
      "key": "primary",
      "name": I18n.tr("common.primary")
    },
    {
      "key": "secondary",
      "name": I18n.tr("common.secondary")
    },
    {
      "key": "tertiary",
      "name": I18n.tr("common.tertiary")
    },
    {
      "key": "error",
      "name": I18n.tr("common.error")
    }
  ]

  // --------------------------------
  // Default colors: Noctalia (default) dark — must match Assets/ColorScheme/Noctalia-default
  QtObject {
    id: defaultColors

    readonly property color mPrimary: "#fff59b"
    readonly property color mOnPrimary: "#0e0e43"

    readonly property color mSecondary: "#a9aefe"
    readonly property color mOnSecondary: "#0e0e43"

    readonly property color mTertiary: "#9BFECE"
    readonly property color mOnTertiary: "#0e0e43"

    readonly property color mError: "#FD4663"
    readonly property color mOnError: "#0e0e43"

    readonly property color mSurface: "#070722"
    readonly property color mOnSurface: "#f3edf7"

    readonly property color mSurfaceVariant: "#11112d"
    readonly property color mOnSurfaceVariant: "#7c80b4"

    readonly property color mOutline: "#21215F"
    readonly property color mShadow: "#070722"

    readonly property color mHover: "#9BFECE"
    readonly property color mOnHover: "#0e0e43"

    // Terminal ANSI color palette — 16 standard colors + foreground/background/cursor
    readonly property color mTermBlack:        "#000000"
    readonly property color mTermRed:          "#FD4663"
    readonly property color mTermGreen:        "#3DCC61"
    readonly property color mTermYellow:       "#CCC03D"
    readonly property color mTermBlue:         "#fff59b"
    readonly property color mTermMagenta:      "#a9aefe"
    readonly property color mTermCyan:         "#9BFECE"
    readonly property color mTermWhite:        "#f3edf7"
    readonly property color mTermBrightBlack:  "#7c80b4"
    readonly property color mTermBrightRed:    "#FFB4AB"
    readonly property color mTermBrightGreen:  "#61F285"
    readonly property color mTermBrightYellow: "#F2E661"
    readonly property color mTermBrightBlue:   "#FFFFFF"
    readonly property color mTermBrightMagenta:"#ECECEC"
    readonly property color mTermBrightCyan:   "#FFFFFF"
    readonly property color mTermBrightWhite:  "#FFFFFF"
    readonly property color mTermForeground:   "#f3edf7"
    readonly property color mTermBackground:   "#070722"
    readonly property color mTermCursor:       "#fff59b"
  }

  // ----------------------------------------------------------------
  // FileView to load custom colors data from colors.json
  FileView {
    id: customColorsFile
    path: Settings.directoriesCreated ? (Settings.configDir + "colors.json") : undefined
    printErrors: false
    watchChanges: true
    onFileChanged: scheduleExternalColorReload()
    onAdapterUpdated: {
      Logger.d("Color", "Writing colors to disk");
      writeAdapter();
    }

    onLoaded: {
      if (root.skipTransition) {
        Qt.callLater(function () {
          root.skipTransition = false;
        });
      }
    }

    // Trigger initial load when path changes from empty to actual path
    onPathChanged: {
      if (path !== undefined) {
        reload();
      }
    }
    onLoadFailed: function (error) {
      if (reloadColors) {
        reloadColors = false;
        return;
      }

      if (root.skipTransition) {
        Qt.callLater(function () {
          root.skipTransition = false;
        });
      }

      // Error code 2 = ENOENT (No such file or directory)
      if (error === 2 || error.toString().includes("No such file")) {
        // File doesn't exist, create it with default values
        writeAdapter();
      }
    }
    JsonAdapter {
      id: customColorsData

      property color mPrimary: defaultColors.mPrimary
      property color mOnPrimary: defaultColors.mOnPrimary

      property color mSecondary: defaultColors.mSecondary
      property color mOnSecondary: defaultColors.mOnSecondary

      property color mTertiary: defaultColors.mTertiary
      property color mOnTertiary: defaultColors.mOnTertiary

      property color mError: defaultColors.mError
      property color mOnError: defaultColors.mOnError

      property color mSurface: defaultColors.mSurface
      property color mOnSurface: defaultColors.mOnSurface

      property color mSurfaceVariant: defaultColors.mSurfaceVariant
      property color mOnSurfaceVariant: defaultColors.mOnSurfaceVariant

      property color mOutline: defaultColors.mOutline
      property color mShadow: defaultColors.mShadow

      property color mHover: defaultColors.mHover
      property color mOnHover: defaultColors.mOnHover

      property color mTermBlack:        defaultColors.mTermBlack
      property color mTermRed:          defaultColors.mTermRed
      property color mTermGreen:        defaultColors.mTermGreen
      property color mTermYellow:       defaultColors.mTermYellow
      property color mTermBlue:         defaultColors.mTermBlue
      property color mTermMagenta:      defaultColors.mTermMagenta
      property color mTermCyan:         defaultColors.mTermCyan
      property color mTermWhite:        defaultColors.mTermWhite
      property color mTermBrightBlack:  defaultColors.mTermBrightBlack
      property color mTermBrightRed:    defaultColors.mTermBrightRed
      property color mTermBrightGreen:  defaultColors.mTermBrightGreen
      property color mTermBrightYellow: defaultColors.mTermBrightYellow
      property color mTermBrightBlue:   defaultColors.mTermBrightBlue
      property color mTermBrightMagenta:defaultColors.mTermBrightMagenta
      property color mTermBrightCyan:   defaultColors.mTermBrightCyan
      property color mTermBrightWhite:  defaultColors.mTermBrightWhite
      property color mTermForeground:   defaultColors.mTermForeground
      property color mTermBackground:   defaultColors.mTermBackground
      property color mTermCursor:       defaultColors.mTermCursor
    }
  }

  // Watch parent config directory as a fallback for declarative setups where
  // colors.json may be replaced atomically (e.g., symlink/store-path swap).
  FileView {
    id: colorsDirWatcher
    path: Settings.directoriesCreated ? Settings.configDir : undefined
    printErrors: false
    watchChanges: true
    onFileChanged: scheduleExternalColorReload()
  }
}
