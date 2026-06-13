import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI
import qs.Services.Theming
Item {
    id: root
    property var pluginApi: null
    readonly property var  geometryPlaceholder:  panelContainer
    readonly property bool allowAttach:          true
    property real contentPreferredWidth:         360 * Style.uiScaleRatio
    property real contentPreferredHeight:        mainCol.implicitHeight + Style.marginM * 2
    anchors.fill: parent
    property bool squareCorners: false
    property bool noiseEnabled: false
    property bool focusRingEnabled: false
    property bool focusRingGradient: true
    property int focusRingWidth: 3

    function refreshFocusRingState() {
        if (_niriBusy) return
        _niriBusy = true
        niriProc.exec({ command: ["python3", _scriptsDir + "niri-toggle.py", "get-focus-ring-gradient"] })
    }

    function saveSyncColors() {
        var path = Quickshell.env("HOME") + "/.config/noctalia/sync-colors.json"
        var sc = root.syncWidgetColors ? "True" : "False"
        var cc = root.syncedCountColor
        var ic = root.syncedIconColor
        var hc = root.syncedHoverColor
        Quickshell.execDetached(["python3", "-c",
            "import json,sys; json.dump({'syncWidgetColors':" + sc + ",'syncedCountColor':'" + cc + "','syncedIconColor':'" + ic + "','syncedHoverColor':'" + hc + "'}, open(sys.argv[1],'w'))",
            path
        ])
    }

    property bool filledBackground: Settings.data.ui.filledBackground ?? true
    property bool noColorsMode: pluginApi?.pluginSettings?.noColorsMode ?? false

    property int kittyGlassMode: 0          // 0=glass(0.0), 1=semi(0.5), 2=solid(1.0)
    property bool niriBlurGlobalEnabled: false
    property bool niriBlurWindowEnabled: false
    property bool _niriBusy: false
    // Safety timeout: reset _niriBusy if stuck
    Timer {
        id: niriBusyTimeout
        interval: 5000
        repeat: false
        onTriggered: {
            if (root._niriBusy) {
                root._niriBusy = false
                Logger.w("QuickConfig", "niriBusy timeout - reset")
            }
        }
    }
    property int  tabIndex: 0
    property var  snapshotList: []
    property var  schemeList: []
    property bool useWallpaper: false
    property string currentSchemeLabel: "Wallpaper"
    property bool zenCustomBg: pluginApi?.pluginSettings?.zenCustomBackground ?? false
    property bool syncWidgetColors: false
    property string syncedCountColor: "none"
    property string syncedIconColor: "none"
    property string syncedHoverColor: "none"
    property bool _skipSnapshotWallpaper: false
    property bool _skipSnapshotColors: false

    FileView {
        id: _syncLoader
        path: Quickshell.env("HOME") + "/.config/noctalia/sync-colors.json"
        printErrors: false
        onLoaded: {
            try {
                var d = JSON.parse(text())
                root.syncWidgetColors = d.syncWidgetColors ?? false
                root.syncedCountColor = d.syncedCountColor ?? "none"
                root.syncedIconColor = d.syncedIconColor ?? "none"
                root.syncedHoverColor = d.syncedHoverColor ?? "none"
            } catch(e) {}
        }
        onLoadFailed: {
            root.saveSyncColors()
        }
    }

    readonly property color _bgSurfaceVariant: root.filledBackground ? Color.smartAlpha(Color.mSurfaceVariant) : "transparent"
    readonly property color _bgSurface: root.filledBackground ? Color.smartAlpha(Color.mSurface) : "transparent"
    readonly property string _scriptsDir: Qt.resolvedUrl("scripts/").toString().replace("file://", "")

    // ── Processes ──────────────────────────────────────────────────────────────
    Process {
        id: niriProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function(exitCode, exitStatus) {
            root._niriBusy = false
            if (exitCode !== 0) {
                Logger.w("QuickConfig", "niri-toggle failed: " + stderr.text)
            } else {
                var text = stdout.text.trim()
                if (text === "on" || text === "off") {
                    root.focusRingGradient = (text === "on")
                    if (!root._niriBusy && !niriProc.running) {
                        root._niriBusy = true
                        niriProc.exec({ command: ["python3", _scriptsDir + "niri-toggle.py", "get-focus-ring-width"] })
                    }
                } else if (/^\d+$/.test(text)) {
                    var w = parseInt(text)
                    if (w > 0 && w <= 10) root.focusRingWidth = w
                } else if (text !== "") {
                    root.applyNiriShadowState(text)
                }
            }
        }
    }
    Process {
        id: snapshotProc
        command: []
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        property string _action: ""
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0 && stdout.text !== "") {
                try {
                    var parsed = JSON.parse(stdout.text)
                    if (_action === "save") {
                        snapRefreshTimer.start()
                    } else if (Array.isArray(parsed)) {
                        root.snapshotList = parsed
                    }
                } catch(e) {
                    Logger.w("QuickConfig", "snapshotProc parse error: " + e)
                }
            } else if (exitCode !== 0) {
                Logger.w("QuickConfig", "snapshotProc exitCode=" + exitCode + " stderr=" + stderr.text)
            }
        }
    }

    Process {
        id: snapDeleteProc
        command: []
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function(exitCode, exitStatus) {
            Logger.i("QuickConfig", "snapDeleteProc exited code=" + exitCode + " stdout=[" + stdout.text + "] stderr=[" + stderr.text + "]")
            if (exitCode === 0) {
                snapRefreshTimer.start()
            } else {
                Logger.w("QuickConfig", "snapshot delete failed: " + stderr.text)
            }
        }
    }
    Process {
        id: snapLoadProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                root.readAndApplyNiriShadow()
            }
        }
    }

    Timer {
        id: snapRefreshTimer
        interval: 50; repeat: false
        onTriggered: root.refreshSnapshots()
    }

    Timer {
        id: schemeRefreshTimer
        interval: 50; repeat: false
        onTriggered: root.refreshSchemeInfo()
    }

    Timer {
        id: niriColorSyncTimer
        interval: 200; repeat: false
        onTriggered: niriProc.exec({ command: ["python3", _scriptsDir + "niri-toggle.py", "sync-focus-ring-color"] })
    }

    Process {
        id: deferredProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0)
                Logger.w("QuickConfig", "deferred toggle failed: " + stderr.text)
        }
    }

    Process {
        id: schemeProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        property string _action: ""
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0 && stdout.text !== "") {
                try {
                    var parsed = JSON.parse(stdout.text)
                    if (parsed.schemes) {
                        root.schemeList = parsed.schemes
                        root.useWallpaper = parsed.useWallpaper
                        root.currentSchemeLabel = parsed.useWallpaper ? "Wallpaper" : (parsed.currentScheme || "Wallpaper")
                    } else if (parsed.applied || parsed.deleted || parsed.renamed) {
                        schemeRefreshTimer.start()
                    } else if (parsed.error) {
                        Logger.w("QuickConfig", "scheme error: " + parsed.error)
                    }
                } catch(e) {
                    Logger.w("QuickConfig", "schemeProc parse error: " + e)
                }
            } else if (exitCode !== 0) {
                Logger.w("QuickConfig", "schemeProc exitCode=" + exitCode + " stderr=" + stderr.text)
            }
        }
    }

    Process {
        id: zenProc
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                Logger.i("QuickConfig", "zen-bg applied")
            } else {
                Logger.w("QuickConfig", "zen-bg failed code=" + exitCode + ": " + (stderr.text || "unknown"))
            }
        }
    }

    // ── Trace: confirm which QML functions actually fire ─────────────────────
    Process {
        id: traceProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    // ── Quickshell reload ─────────────────────────────────────────────────────
    Process {
        id: qsReloadProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }


    function reloadQuickshell() {
        // Write trigger file — BarWidget (persistent in bar) watches this and executes reload
        var writeProc = Qt.createQmlObject(
            'import QtQuick; import Quickshell.Io; Process {}',
            root
        );
        writeProc.exec({
            command: ["/bin/sh", "-c", "echo 1 > /tmp/do-quickshell-reload"]
        });
    }

    // ── Snapshot functions ─────────────────────────────────────────────────────
    Component.onCompleted: { refreshSnapshots(); refreshSchemeInfo(); refreshFocusRingState() }

    function refreshSnapshots() {
        Logger.i("QuickConfig", "refreshSnapshots() called")
        if (snapshotProc.running) snapshotProc.terminate()
        snapshotProc._action = "list"
        snapshotProc.command = ["python3", _scriptsDir + "snapshot.py", "list"]
        snapshotProc.running = true
    }

    function saveSnapshot() {
        Logger.i("QuickConfig", "saveSnapshot() called")
        var state = {
            barOutline:              Settings.data.bar.showBarOutline,
            barOutlineWidth:         Settings.data.bar.barOutlineWidth,
            barBlur:                 Settings.data.bar.barBlurEnabled,
            useSeparateOpacity:      Settings.data.bar.useSeparateOpacity,
            backgroundOpacity:       Settings.data.bar.backgroundOpacity,
            enableBlurBehind:        Settings.data.general.enableBlurBehind,
            translucentWidgets:      Settings.data.ui.translucentWidgets,
            panelBackgroundOpacity:  Settings.data.ui.panelBackgroundOpacity,
            panelOutlineEnabled:     Settings.data.ui["panelOutlineEnabled"] ?? false,
            panelOutlineWidth:       Settings.data.ui["panelOutlineWidth"] ?? 2,
            widgetOutline:           Settings.data.bar.showOutline,
            showCapsule:             Settings.data.bar.showCapsule,
            capsuleOpacity:          Settings.data.bar.capsuleOpacity,
            radiusRatio:             Settings.data.general.radiusRatio,
            iRadiusRatio:            Settings.data.general.iRadiusRatio,
            squareCorners:           squareCorners,
            noiseEnabled:            noiseEnabled,
            focusRingEnabled:        focusRingEnabled,
            focusRingGradient:       focusRingGradient,
            focusRingWidth:          focusRingWidth,
            shadowEnabled:           shadowEnabled,
            kittyGlassMode:          kittyGlassMode,
            niriBlurGlobal:          niriBlurGlobalEnabled,
            niriBlurWindow:          niriBlurWindowEnabled,
            hoverRevealOpacity:      Settings.data.bar.hoverRevealOpacity ?? 1.0,
            generationMethod:        Settings.data.colorSchemes.generationMethod,
            predefinedScheme:        Settings.data.colorSchemes.predefinedScheme,
            useWallpaperColors:      Settings.data.colorSchemes.useWallpaperColors,
            darkMode:                Settings.data.colorSchemes.darkMode,
            paletteColors:           pluginApi?.pluginSettings?.paletteColors ?? [],
            colorHistory:            pluginApi?.pluginSettings?.colorHistory  ?? [],
            wallpaperFavorites:      Settings.data.wallpaper.favorites,
            barType:                 Settings.data.bar.barType ?? "simple",
            panelsAttachedToBar:     Settings.data.ui.panelsAttachedToBar,
            settingsPanelMode:       Settings.data.ui.settingsPanelMode ?? "attached",
            zenCustomBg:             zenCustomBg,
            filledBackground:        Settings.data.ui.filledBackground ?? true,
            position:                Settings.data.bar.position ?? "top",
            capsuleOutlineWidth:     Settings.data.bar.capsuleOutlineWidth ?? 0,
            capsuleGroupEnabled:     Settings.data.bar.capsuleGroupEnabled ?? false,
            capsuleCollapseTarget:   Settings.data.bar.capsuleCollapseTarget ?? "none",
            capsuleFillBar:          Settings.data.bar.capsuleFillBar ?? false,
            capsuleInnerPadding:     Settings.data.bar.capsuleInnerPadding ?? 0,
            capsuleGroupSpacing:     Settings.data.bar.capsuleGroupSpacing ?? 6,
            capsuleLeftOpacity:      Settings.data.bar.capsuleLeftOpacity ?? 1.0,
            capsuleCenterOpacity:    Settings.data.bar.capsuleCenterOpacity ?? 1.0,
            capsuleRightOpacity:     Settings.data.bar.capsuleRightOpacity ?? 1.0,
            capsuleLeftColorKey:     Settings.data.bar.capsuleLeftColorKey ?? "",
            capsuleCenterColorKey:   Settings.data.bar.capsuleCenterColorKey ?? "",
            capsuleRightColorKey:    Settings.data.bar.capsuleRightColorKey ?? "",
            capsuleIndividualColorsLeft:   Settings.data.bar.capsuleIndividualColorsLeft ?? false,
            capsuleIndividualColorsCenter: Settings.data.bar.capsuleIndividualColorsCenter ?? false,
            capsuleIndividualColorsRight:  Settings.data.bar.capsuleIndividualColorsRight ?? false,
            capsuleTranslucent:      Settings.data.bar.capsuleTranslucent ?? false,
            boxBorderEnabled:        Settings.data.ui.boxBorderEnabled ?? false,
            syncWidgetColors:        syncWidgetColors,
            syncedCountColor:        syncedCountColor,
            syncedIconColor:         syncedIconColor,
            syncedHoverColor:        syncedHoverColor
        }
        if (snapshotProc.running) snapshotProc.terminate()
        snapshotProc._action = "save"
        snapshotProc.command = ["python3", _scriptsDir + "snapshot.py", "save", JSON.stringify(state)]
        snapshotProc.running = true
    }

    function loadSnapshot(index) {
        Logger.i("QuickConfig", "loadSnapshot(" + index + ") called, list.length=" + snapshotList.length)
        if (index < 0 || index >= snapshotList.length) return
        var s = snapshotList[index]
        var ws = s.widgetState || {}
        if (ws.barOutline !== undefined)     Settings.data.bar.showBarOutline        = ws.barOutline
        if (ws.barOutlineWidth !== undefined) Settings.data.bar.barOutlineWidth       = ws.barOutlineWidth
        if (ws.barBlur !== undefined)        Settings.data.bar.barBlurEnabled        = ws.barBlur
        if (ws.useSeparateOpacity !== undefined) Settings.data.bar.useSeparateOpacity = ws.useSeparateOpacity
        if (ws.backgroundOpacity !== undefined)  Settings.data.bar.backgroundOpacity  = ws.backgroundOpacity
        if (ws.enableBlurBehind !== undefined)   Settings.data.general.enableBlurBehind = ws.enableBlurBehind
        if (ws.translucentWidgets !== undefined) Settings.data.ui.translucentWidgets = ws.translucentWidgets
        if (ws.panelBackgroundOpacity !== undefined) Settings.data.ui.panelBackgroundOpacity = ws.panelBackgroundOpacity
        if (ws.panelOutlineEnabled !== undefined) Settings.data.ui["panelOutlineEnabled"] = ws.panelOutlineEnabled
        if (ws.panelOutlineWidth !== undefined) Settings.data.ui["panelOutlineWidth"] = ws.panelOutlineWidth
        if (ws.widgetOutline !== undefined) Settings.data.bar.showOutline = ws.widgetOutline
        if (ws.showCapsule !== undefined) Settings.data.bar.showCapsule = ws.showCapsule
        if (ws.capsuleOpacity !== undefined) Settings.data.bar.capsuleOpacity = ws.capsuleOpacity
        if (ws.radiusRatio !== undefined)     Settings.data.general.radiusRatio       = ws.radiusRatio
        if (ws.iRadiusRatio !== undefined)    Settings.data.general.iRadiusRatio      = ws.iRadiusRatio
        if (ws.radiusRatio !== undefined || ws.iRadiusRatio !== undefined) syncCornerRadius()
        if (ws.squareCorners !== undefined)   squareCorners = ws.squareCorners
        if (ws.noiseEnabled !== undefined)    noiseEnabled = ws.noiseEnabled
        if (ws.focusRingEnabled !== undefined) focusRingEnabled = ws.focusRingEnabled
        if (ws.focusRingGradient !== undefined) focusRingGradient = ws.focusRingGradient
        if (ws.focusRingWidth !== undefined) focusRingWidth = ws.focusRingWidth
        if (ws.shadowEnabled !== undefined) shadowEnabled = ws.shadowEnabled
        if (ws.kittyGlassMode !== undefined)  kittyGlassMode = ws.kittyGlassMode
        niriBlurGlobalEnabled = ws.niriBlurGlobal !== undefined ? ws.niriBlurGlobal : false
        niriBlurWindowEnabled = ws.niriBlurWindow !== undefined ? ws.niriBlurWindow : false
        if (ws.hoverRevealOpacity !== undefined) Settings.data.bar.hoverRevealOpacity = ws.hoverRevealOpacity
        var niriSnapshotKitty = null
        if (s.kittyOpacity !== undefined && s.kittyOpacity <= 1.0) {
            kittyGlassMode = s.kittyOpacity <= 0.0 ? 0 : (s.kittyOpacity <= 0.25 ? 1 : 2)
            niriSnapshotKitty = String(s.kittyOpacity)
        } else if (ws.kittyGlassMode !== undefined) {
            niriSnapshotKitty = ws.kittyGlassMode === 0 ? "0.0" : (ws.kittyGlassMode === 1 ? "0.5" : "1.0")
        }
        // ⚠️ NÃO REMOVER ESTE BLOCO — o parser QML do Quickshell gera bytecode
        // corrompido se ele for removido, causando toggles fantasmas de blur.
        // Blur/kitty são aplicados atomicamente por snapshot.py _do_load.
        if (niriSnapshotKitty !== null || ws.niriBlurGlobal !== undefined || ws.niriBlurWindow !== undefined) {
            var blurG = (ws.niriBlurGlobal !== undefined ? ws.niriBlurGlobal : false) ? "on" : "off"
            var blurW = (ws.niriBlurWindow !== undefined ? ws.niriBlurWindow : false) ? "on" : "off"
            if (niriSnapshotKitty === null) { niriSnapshotKitty = kittyGlassMode === 0 ? "0.0" : (kittyGlassMode === 1 ? "0.5" : "1.0") }
            // Blur/kitty applied atomically by snapshot.py _do_load
        }
        if (!root._skipSnapshotColors) {
            if (ws.generationMethod !== undefined)   Settings.data.colorSchemes.generationMethod   = ws.generationMethod
            if (ws.predefinedScheme !== undefined)   Settings.data.colorSchemes.predefinedScheme   = ws.predefinedScheme
            if (ws.useWallpaperColors !== undefined) Settings.data.colorSchemes.useWallpaperColors = ws.useWallpaperColors
            if (ws.darkMode !== undefined)           Settings.data.colorSchemes.darkMode           = ws.darkMode
            if (ws.paletteColors !== undefined) { pluginApi.pluginSettings.paletteColors = ws.paletteColors }
            if (ws.colorHistory !== undefined)  { pluginApi.pluginSettings.colorHistory  = ws.colorHistory }
        }
if (ws.zenCustomBg !== undefined) {
            var needsTrigger = ws.zenCustomBg !== zenCustomBg
            pluginApi.pluginSettings.zenCustomBackground = ws.zenCustomBg
            if (needsTrigger) {
                if (zenProc.running) zenProc.terminate()
                zenProc.exec({ command: ["/usr/bin/python3", _scriptsDir + "cycle-scheme.py", "zen-bg", ws.zenCustomBg ? "true" : "false"] })
            }
        }
        if (ws.wallpaperFavorites !== undefined) { Settings.data.wallpaper.favorites = ws.wallpaperFavorites }
        if (ws.barType !== undefined)            Settings.data.bar.barType            = ws.barType
        if (ws.panelsAttachedToBar !== undefined) Settings.data.ui.panelsAttachedToBar = ws.panelsAttachedToBar
        if (ws.settingsPanelMode !== undefined)   Settings.data.ui.settingsPanelMode   = ws.settingsPanelMode
        if (ws.filledBackground !== undefined)    Settings.data.ui.filledBackground    = ws.filledBackground
        if (ws.position !== undefined)            Settings.data.bar.position           = ws.position
        if (ws.capsuleOutlineWidth !== undefined) Settings.data.bar.capsuleOutlineWidth = ws.capsuleOutlineWidth
        if (ws.capsuleGroupEnabled !== undefined) Settings.data.bar.capsuleGroupEnabled = ws.capsuleGroupEnabled
        if (ws.capsuleCollapseTarget !== undefined) Settings.data.bar.capsuleCollapseTarget = ws.capsuleCollapseTarget
        if (ws.capsuleFillBar !== undefined)      Settings.data.bar.capsuleFillBar     = ws.capsuleFillBar
        if (ws.capsuleInnerPadding !== undefined) Settings.data.bar.capsuleInnerPadding = ws.capsuleInnerPadding
        if (ws.capsuleGroupSpacing !== undefined) Settings.data.bar.capsuleGroupSpacing = ws.capsuleGroupSpacing
        if (ws.capsuleLeftOpacity !== undefined)  Settings.data.bar.capsuleLeftOpacity = ws.capsuleLeftOpacity
        if (ws.capsuleCenterOpacity !== undefined) Settings.data.bar.capsuleCenterOpacity = ws.capsuleCenterOpacity
        if (ws.capsuleRightOpacity !== undefined) Settings.data.bar.capsuleRightOpacity = ws.capsuleRightOpacity
        if (ws.capsuleLeftColorKey !== undefined) Settings.data.bar.capsuleLeftColorKey = ws.capsuleLeftColorKey
        if (ws.capsuleCenterColorKey !== undefined) Settings.data.bar.capsuleCenterColorKey = ws.capsuleCenterColorKey
        if (ws.capsuleRightColorKey !== undefined) Settings.data.bar.capsuleRightColorKey = ws.capsuleRightColorKey
        if (ws.capsuleIndividualColorsLeft !== undefined) Settings.data.bar.capsuleIndividualColorsLeft = ws.capsuleIndividualColorsLeft
        if (ws.capsuleIndividualColorsCenter !== undefined) Settings.data.bar.capsuleIndividualColorsCenter = ws.capsuleIndividualColorsCenter
        if (ws.capsuleIndividualColorsRight !== undefined) Settings.data.bar.capsuleIndividualColorsRight = ws.capsuleIndividualColorsRight
        if (ws.capsuleTranslucent !== undefined)  Settings.data.bar.capsuleTranslucent = ws.capsuleTranslucent
        if (ws.boxBorderEnabled !== undefined)    Settings.data.ui.boxBorderEnabled   = ws.boxBorderEnabled
        if (ws.syncWidgetColors !== undefined) syncWidgetColors = ws.syncWidgetColors
        if (ws.syncedCountColor !== undefined) syncedCountColor = ws.syncedCountColor
        if (ws.syncedIconColor !== undefined) syncedIconColor = ws.syncedIconColor
        if (ws.syncedHoverColor !== undefined) syncedHoverColor = ws.syncedHoverColor
        saveSyncColors()
        Settings.saveImmediate()
        if (pluginApi) pluginApi.saveSettings()

        // Reload color scheme to apply wallpaper colors or predefined scheme
        if (ws.useWallpaperColors !== undefined || ws.predefinedScheme !== undefined) {
            if (Settings.data.colorSchemes.useWallpaperColors) {
                ColorSchemeService.applyScheme("")
            } else {
                ColorSchemeService.applyScheme(Settings.data.colorSchemes.predefinedScheme)
            }
        }
        snapLoadProc.exec({ command: ["python3", _scriptsDir + "snapshot.py", "load", String(index)] })
        if (!root._skipSnapshotWallpaper && s.wallpaper && s.wallpaper !== "")
            WallpaperService.changeWallpaper(s.wallpaper, undefined)
    }

    function deleteSnapshot(index) {
        Logger.i("QuickConfig", "deleteSnapshot(" + index + ") called")
        if (snapDeleteProc.running) snapDeleteProc.terminate()
        snapDeleteProc.command = ["python3", _scriptsDir + "snapshot.py", "delete", String(index)]
        snapDeleteProc.running = true
    }

    function renameSnapshot(index, newName) {
        Logger.i("QuickConfig", "renameSnapshot(" + index + ", " + newName + ") called")
        if (snapshotProc.running) snapshotProc.terminate()
        snapshotProc._action = "rename"
        snapshotProc.command = ["python3", _scriptsDir + "snapshot.py", "rename", String(index), newName]
        snapshotProc.running = true
    }

    function applyNiriShadowState(jsonText) {
        try {
            var p = JSON.parse(jsonText)
            if (p.on === undefined) return
            if (p.on !== undefined)      Settings.data.bar.shadowEnabled  = p.on
            if (p.color)                 Settings.data.bar.shadowColor    = p.color
            if (p.softness !== undefined) Settings.data.bar.shadowSoftness = p.softness
            if (p.spread !== undefined)  Settings.data.bar.shadowSpread   = p.spread
            if (p.offsetX !== undefined) Settings.data.bar.shadowOffsetX  = p.offsetX
            if (p.offsetY !== undefined) Settings.data.bar.shadowOffsetY  = p.offsetY
            Settings.saveImmediate()
        } catch(e) {}
    }

    function readAndApplyNiriShadow() {
        var xhr = new XMLHttpRequest()
        xhr.open('GET', 'file:///tmp/niri-shadow.json')
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 0) {
                root.applyNiriShadowState(xhr.responseText)
            }
        }
        xhr.send()
    }

    // ── Noctalia simple toggles ────────────────────────────────────────────────
    function toggleBarOutline() {
        if (!Settings.data.bar.showBarOutline) {
            Settings.data.bar.showBarOutline = true
            Settings.data.bar.barOutlineWidth = 1
        } else if (Settings.data.bar.barOutlineWidth < 5) {
            Settings.data.bar.barOutlineWidth++
        } else {
            Settings.data.bar.showBarOutline = false
        }
        Settings.saveImmediate()
    }

    function toggleBarBlur() {
        Settings.data.bar.barBlurEnabled = !Settings.data.bar.barBlurEnabled
        Settings.saveImmediate()
    }

    function toggleBarOpacity() {
        if (Settings.data.bar.useSeparateOpacity) {
            Settings.data.bar.useSeparateOpacity = false
            Settings.data.bar.backgroundOpacity = 0.93
        } else {
            Settings.data.bar.useSeparateOpacity = true
            Settings.data.bar.backgroundOpacity = 0
        }
        Settings.saveImmediate()
    }

    function toggleNoctaliaOpacity() {
        var opacity = Settings.data.ui.panelBackgroundOpacity ?? 1.0
        if (opacity >= 0.9) {
            // Opaco → Meio-termo
            Settings.data.general.enableBlurBehind = true
            Settings.data.ui.translucentWidgets    = true
            Settings.data.ui.panelBackgroundOpacity = 0.5
        } else if (opacity >= 0.3) {
            // Meio-termo → Transparente
            Settings.data.general.enableBlurBehind = true
            Settings.data.ui.translucentWidgets    = true
            Settings.data.ui.panelBackgroundOpacity = 0.0
        } else {
            // Transparente → Opaco
            Settings.data.general.enableBlurBehind = false
            Settings.data.ui.translucentWidgets    = false
            Settings.data.ui.panelBackgroundOpacity = 1.0
        }
        Settings.saveImmediate()
    }


    // ── Niri toggles ───────────────────────────────────────────────────────────
    function toggleSquareCorners() {
        if (_niriBusy) return
        if (squareCorners) {
            Settings.data.general.radiusRatio  = 0.8
            Settings.data.general.iRadiusRatio = 0.8
            _niriBusy = true
            niriProc.exec({ command: ["python3", _scriptsDir + "niri-toggle.py", "round"] })
            squareCorners = false
        } else {
            Settings.data.general.radiusRatio  = 0
            Settings.data.general.iRadiusRatio = 0
            _niriBusy = true
            niriProc.exec({ command: ["python3", _scriptsDir + "niri-toggle.py", "square"] })
            squareCorners = true
        }
    }

    function toggleFocusRing() {
        if (_niriBusy) return
        _niriBusy = true
        focusRingEnabled = !focusRingEnabled
        niriProc.exec({ command: ["python3", _scriptsDir + "niri-toggle.py", "focus-ring"] })
    }

    function toggleFocusRingGradient() {
        if (_niriBusy) return
        _niriBusy = true
        focusRingGradient = !focusRingGradient
        niriProc.exec({ command: ["python3", _scriptsDir + "niri-toggle.py", "focus-ring-gradient", focusRingGradient ? "on" : "off"] })
    }

    function toggleFocusRingWidth() {
        if (_niriBusy) return
        _niriBusy = true
        var widths = [1, 2, 3, 4, 5]
        var idx = widths.indexOf(focusRingWidth)
        var next = (idx + 1) % widths.length
        focusRingWidth = widths[next]
        niriProc.exec({ command: ["python3", _scriptsDir + "niri-toggle.py", "focus-ring-width", String(focusRingWidth)] })
    }

    function toggleNoiseSat() {
        if (_niriBusy) return
        _niriBusy = true
        noiseEnabled = !noiseEnabled
        niriProc.exec({ command: ["python3", _scriptsDir + "niri-toggle.py", "noise-toggle"] })
    }

    function toggleKittyGlass() {
        kittyGlassMode = (kittyGlassMode + 1) % 3
        var opacity = kittyGlassMode === 0 ? "0.0" : (kittyGlassMode === 1 ? "0.5" : "1.0")
        niriProc.exec({ command: ["python3", _scriptsDir + "niri-toggle.py", "glass-set", opacity] })
    }

    function syncCornerRadius() {
        var rr = Settings.data.general.radiusRatio
        deferredProc.exec({ command: ["python3", _scriptsDir + "niri-toggle.py", "corner-sync", String(rr)] })
    }

    function toggleHoverReveal() {
        var current = Settings.data.bar.hoverRevealOpacity ?? 1.0
        Settings.data.bar.hoverRevealOpacity = (current < 1.0) ? 1.0 : 0.0
        Settings.saveImmediate()
    }

    function toggleBarType() {
        var types = ["simple", "floating", "framed"]
        var current = Settings.data.bar.barType || "simple"
        var idx = types.indexOf(current)
        Settings.data.bar.barType = types[(idx + 1) % types.length]
        Settings.saveImmediate()
    }

    function toggleBarPosition() {
        var positions = ["top", "bottom", "left", "right"]
        var current = Settings.data.bar.position || "top"
        var idx = positions.indexOf(current)
        Settings.data.bar.position = positions[(idx + 1) % positions.length]
        Settings.saveImmediate()
    }

    function cycleWidgetSpacing() {
        var current = Settings.data.bar.capsuleInnerPadding ?? 0
        var next
        if (current >= 8) next = 0
        else next = current + 2
        Settings.data.bar.capsuleInnerPadding = next
        Settings.saveImmediate()
    }

    function cycleCapsuleGroupSpacing() {
        var steps = [2, 4, 6, 8, 10, 12]
        var current = Settings.data.bar.capsuleGroupSpacing ?? 6
        var idx = steps.indexOf(current)
        Settings.data.bar.capsuleGroupSpacing = steps[(idx + 1) % steps.length]
        Settings.saveImmediate()
    }

    function cycleCapsuleInnerPadding() {
        var steps = [0, 2, 4, 6, 8]
        var current = Settings.data.bar.capsuleInnerPadding ?? 0
        var idx = steps.indexOf(current)
        Settings.data.bar.capsuleInnerPadding = steps[(idx + 1) % steps.length]
        Settings.saveImmediate()
    }

    function toggleCapsuleFillBar() {
        Settings.data.bar.capsuleFillBar = !Settings.data.bar.capsuleFillBar
        Settings.saveImmediate()
    }

    function toggleCapsuleCollapse() {
        var order = ["none", "left", "center", "right"]
        var current = Settings.data.bar.capsuleCollapseTarget || "none"
        var idx = order.indexOf(current)
        Settings.data.bar.capsuleCollapseTarget = order[(idx + 1) % order.length]
        Settings.saveImmediate()
    }


    function toggleNoColorsMode() {
        noColorsMode = !noColorsMode
        if (pluginApi && pluginApi.pluginSettings) {
            pluginApi.pluginSettings.noColorsMode = noColorsMode
        }
        if (noColorsMode) {
            Settings.data.wallpaper.enabled = false
            Settings.data.colorSchemes.useWallpaperColors = false
            Settings.data.colorSchemes.predefinedScheme = "Noctalia (default)"
        } else {
            Settings.data.wallpaper.enabled = true
            Settings.data.colorSchemes.useWallpaperColors = true
        }
        Settings.saveImmediate()
    }

    function toggleSettingsPanelMode() {
        var modes = ["attached", "centered", "window"]
        var current = Settings.data.ui.settingsPanelMode || "attached"
        var idx = modes.indexOf(current)
        Settings.data.ui.settingsPanelMode = modes[(idx + 1) % modes.length]
        Settings.saveImmediate()
    }

    property bool shadowEnabled: true

    function toggleNiriShadow() {
        if (_niriBusy) return
        _niriBusy = true
        niriProc.exec({ command: ["python3", _scriptsDir + "niri-toggle.py", "shadow-toggle"] })
    }

    function syncShadowColor() {
        if (_niriBusy) return
        _niriBusy = true
        niriProc.exec({ command: ["python3", _scriptsDir + "niri-toggle.py", "shadow-sync"] })
    }

    function toggleNiriBlurGlobal() {
        traceProc.exec({command: ["touch", "/tmp/qml-trace-blur-global"]})
        if (_niriBusy) return
        niriBlurGlobalEnabled = !niriBlurGlobalEnabled
        _niriBusy = true
        niriProc.exec({ command: ["python3", _scriptsDir + "niri-toggle.py", "blur-global-toggle"] })
    }

    function toggleNiriBlurPerWindow() {
        traceProc.exec({command: ["touch", "/tmp/qml-trace-blur-window"]})
        if (_niriBusy) return
        niriBlurWindowEnabled = !niriBlurWindowEnabled
        _niriBusy = true
        niriProc.exec({ command: ["python3", _scriptsDir + "niri-toggle.py", "blur-window-toggle"] })
    }

    function toggleCapsuleGroup() {
        Settings.data.bar.capsuleGroupEnabled = !Settings.data.bar.capsuleGroupEnabled
        Settings.saveImmediate()
    }

    function toggleContainerOutline() {
        var w = Settings.data.bar.capsuleOutlineWidth ?? 0
        if (w <= 0) w = 1
        else if (w < 2) w = 2
        else if (w < 3) w = 3
        else w = 0
        Settings.data.bar.capsuleOutlineWidth = w
        Settings.saveImmediate()
    }

    function toggleContentOutline() {
        Settings.data.ui.boxBorderEnabled = !Settings.data.ui.boxBorderEnabled
        Settings.saveImmediate()
    }

    function cycleCapsuleOpacity(section) {
        var key
        if (section === "left")      key = "capsuleLeftOpacity"
        else if (section === "center") key = "capsuleCenterOpacity"
        else if (section === "right")  key = "capsuleRightOpacity"
        else return

        var current = Settings.data.bar[key] ?? 0.3
        var next
        if (current <= 0.01)      next = 0.5
        else if (current < 0.75)  next = 1.0
        else                      next = 0.0

        Settings.data.bar[key] = next
        Settings.saveImmediate()
    }

    function fmtCapsuleOpacity(section) {
        var key
        if (section === "left")      key = "capsuleLeftOpacity"
        else if (section === "center") key = "capsuleCenterOpacity"
        else if (section === "right")  key = "capsuleRightOpacity"
        else return "—"
        var v = Settings.data.bar[key] ?? 0.3
        if (v <= 0.01) return "0%"
        if (v >= 0.99) return "100%"
        return Math.round(v * 100) + "%"
    }

    function refreshSchemeInfo() {
        schemeProc.exec({ command: ["python3", _scriptsDir + "cycle-scheme.py", "list-full", Quickshell.shellDir + "/Assets/ColorScheme"] })
    }

    function applyScheme(name) {
        Settings.data.colorSchemes.useWallpaperColors = false
        Settings.data.colorSchemes.predefinedScheme = name
        ColorSchemeService.applyScheme(name)
        // Delay niri focus ring color sync to ensure colors.json is written
        niriColorSyncTimer.start()
        schemeRefreshTimer.start()
    }

    function applyWallpaperColors() {
        traceProc.exec({command: ["touch", "/tmp/qml-trace-wallpaper"]})
        schemeProc._action = "wallpaper"
        schemeProc.exec({ command: ["python3", _scriptsDir + "cycle-scheme.py", "wallpaper"] })
    }

    function deleteScheme(name) {
        schemeProc._action = "delete"
        schemeProc.exec({ command: ["python3", _scriptsDir + "cycle-scheme.py", "delete", name] })
    }

    function renameScheme(oldName, newName) {
        Logger.i("QuickConfig", "renameScheme(" + oldName + ", " + newName + ") called")
        schemeProc._action = "rename"
        schemeProc.exec({ command: ["python3", _scriptsDir + "cycle-scheme.py", "rename", oldName, newName] })
    }

    function applyZenCustomBg(enabled) {
        Logger.i("QuickConfig", "applyZenCustomBg(" + enabled + ") called")
        if (zenProc.running) {
            Logger.i("QuickConfig", "zen-bg already running, terminating previous")
            zenProc.terminate()
        }
        pluginApi.pluginSettings.zenCustomBackground = enabled
        pluginApi.saveSettings()
        zenProc.exec({ command: ["/usr/bin/python3", _scriptsDir + "cycle-scheme.py", "zen-bg", enabled ? "true" : "false"] })
    }

    function relativeTime(isoString) {
        if (!isoString) return ""
        var now = new Date()
        var then = new Date(isoString)
        var diff = Math.floor((now - then) / 1000)
        if (diff < 60) return "just now"
        if (diff < 3600) return Math.floor(diff / 60) + "m ago"
        if (diff < 86400) return Math.floor(diff / 3600) + "h ago"
        if (diff < 2592000) return Math.floor(diff / 86400) + "d ago"
        return then.toLocaleDateString()
    }

    // ── UI ─────────────────────────────────────────────────────────────────────
    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"
        Column {
            id: mainCol
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: Style.marginM
            spacing: Style.marginS
            Item {
                width: parent.width; height: Style.fontSizeL * 1.6
                NIcon { icon: "crosshair"; color: Color.mPrimary; anchors.verticalCenter: parent.verticalCenter; x: 0 }
                NText { text: pluginApi?.tr("panel.title"); pointSize: Style.fontSizeL; font.weight: Font.Bold; color: Color.mOnSurface; anchors.verticalCenter: parent.verticalCenter; x: Style.fontSizeL * 1.2 }
                NButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitHeight: Style.fontSizeL * 1.4
                    implicitWidth: implicitHeight
                    buttonRadius: Style.radiusM
                    backgroundColor: qsReloadProc.running ? Color.mPrimary : Color.mSurfaceVariant
                    textColor: qsReloadProc.running ? Color.mOnPrimary : Color.mOnSurface
                    icon: "refresh"
                    iconSize: Style.fontSizeS
                    onClicked: root.reloadQuickshell()
                }
            }

            // Tab bar
            NTabBar {
                width: parent.width
                spacing: Style.marginS
                distributeEvenly: true
                onCurrentIndexChanged: root.tabIndex = currentIndex
                NTabButton {
                    icon: "adjustments-horizontal"
                    text: "Controls"
                    tabIndex: 0
                    checked: root.tabIndex === 0
                    pointSize: Style.fontSizeXXS
                }
                NTabButton {
                    icon: "camera"
                    text: "Snaps"
                    tabIndex: 1
                    checked: root.tabIndex === 1
                    pointSize: Style.fontSizeXXS
                }
                NTabButton {
                    icon: "palette"
                    text: "Colors"
                    tabIndex: 2
                    checked: root.tabIndex === 2
                    pointSize: Style.fontSizeXXS
                }
                NTabButton {
                    icon: "stars"
                    text: "Themes"
                    tabIndex: 3
                    checked: root.tabIndex === 3
                    pointSize: Style.fontSizeXXS
                }
                NTabButton {
                    icon: "info-circle"
                    text: "Notes"
                    tabIndex: 4
                    checked: root.tabIndex === 4
                    pointSize: Style.fontSizeXXS
                }
            }

            // Controls tab
            Rectangle {
                visible: root.tabIndex === 0
                width: parent.width; height: root.tabIndex === 0 ? controlsCol.implicitHeight + Style.marginM : 0
                color: "transparent"
                Column {
                    id: controlsCol
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    spacing: Style.marginS

                    // ── Card 1: Niri ──
                    Rectangle {
                        width: parent.width
                        height: compCol.implicitHeight + Style.marginS * 2
                        color: root._bgSurfaceVariant; radius: Style.radiusL
                        Column {
                            id: compCol
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Style.marginS }
                            spacing: Style.marginS
                            readonly property int btnSize: Math.floor(((width - Style.marginS * 4) / 5) * 0.88)

                            NText { text: "Niri"; pointSize: Style.fontSizeXXS; color: Color.mOnSurfaceVariant; font.weight: Font.Bold }
                            Row {
                                spacing: Style.marginS
                                anchors.horizontalCenter: parent.horizontalCenter
                                Repeater {
                                    model: 5
                                    delegate: ToolBtn {
                                        readonly property var labels: ["Blur Global", "Blur Window", "Square Corners", "Focus Ring", "Niri Shadow"]
                                        readonly property int myIdx: index
                                        num: index + 1
                                        tooltip: myIdx === 0
                                            ? "Blur Global: " + (root.niriBlurGlobalEnabled ? "On" : "Off")
                                            : myIdx === 1
                                                ? "Blur Window: " + (root.niriBlurWindowEnabled ? "On" : "Off")
                                                : myIdx === 2
                                                    ? "Square Corners: " + (root.squareCorners ? "On" : "Off")
                                                    : myIdx === 3
                                                        ? "Focus Ring: " + (root.focusRingEnabled ? "On" : "Off")
                                                        : labels[index]
                                        width: compCol.btnSize; height: compCol.btnSize
                                        interactive: true
                                        onTriggered: {
                                            if (myIdx === 0) root.toggleNiriBlurGlobal()
                                            else if (myIdx === 1) root.toggleNiriBlurPerWindow()
                                            else if (myIdx === 2) root.toggleSquareCorners()
                                            else if (myIdx === 3) root.toggleFocusRing()
                                            else if (myIdx === 4) root.toggleNiriShadow()
                                        }
                                    }
                                }
                            }
                            Row {
                                spacing: Style.marginS
                                anchors.horizontalCenter: parent.horizontalCenter
                                Repeater {
                                    model: 5
                                    delegate: ToolBtn {
                                        readonly property var labels: ["Sync Radius", "Sync Shadow", "Rainbow Ring", "Ring Width", "Noise & Sat"]
                                        readonly property int myIdx: index
                                        num: index + 6
                                        tooltip: myIdx === 2
                                            ? (root.focusRingGradient ? "Rainbow: On" : "Rainbow: Off")
                                            : myIdx === 3
                                                ? "Width: " + root.focusRingWidth + "px"
                                                : myIdx === 4
                                                    ? "Noise & Sat: " + (root.noiseEnabled ? "On" : "Off")
                                                    : labels[index]
                                        width: compCol.btnSize; height: compCol.btnSize
                                        interactive: true
                                        onTriggered: {
                                            if (myIdx === 0) root.syncCornerRadius()
                                            else if (myIdx === 1) root.syncShadowColor()
                                            else if (myIdx === 2) root.toggleFocusRingGradient()
                                            else if (myIdx === 3) root.toggleFocusRingWidth()
                                            else if (myIdx === 4) root.toggleNoiseSat()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Card 2: Noctalia ──
                    Rectangle {
                        width: parent.width
                        height: noctCol.implicitHeight + Style.marginS * 2
                        color: root._bgSurfaceVariant; radius: Style.radiusL
                        Column {
                            id: noctCol
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Style.marginS }
                            spacing: Style.marginS
                            readonly property int btnSize: Math.floor(((width - Style.marginS * 4) / 5) * 0.88)

                            NText { text: "Noctalia"; pointSize: Style.fontSizeXXS; color: Color.mOnSurfaceVariant; font.weight: Font.Bold }
                            Row {
                                spacing: Style.marginS
                                anchors.horizontalCenter: parent.horizontalCenter
                                Repeater {
                                    model: 4
                                    delegate: ToolBtn {
                                        readonly property var labels: ["Widgets", "Filled BG", "Noctalia Opacity", "Kitty Glass"]
                                        readonly property int myIdx: index
                                        num: index + 11
                                        tooltip: myIdx === 0
                                            ? "translucentWidgets: " + (Settings.data.ui.translucentWidgets ? "On" : "Off")
                                            : myIdx === 1
                                                ? "Cards: " + (root.filledBackground ? "On" : "Off")
                                                : myIdx === 2
                                                    ? "Noctalia Opacity: " + (Settings.data.general.enableBlurBehind ? "On" : "Off")
                                                    : myIdx === 3
                                                        ? "Kitty: " + (root.kittyGlassMode === 0 ? "Glass" : root.kittyGlassMode === 1 ? "Semi" : "Solid")
                                                        : ""

                                        width: noctCol.btnSize; height: noctCol.btnSize
                                        interactive: true
                                        onTriggered: {
                                            if (myIdx === 0) {
                                                Settings.data.ui.translucentWidgets = !Settings.data.ui.translucentWidgets
                                                Settings.saveImmediate()
                                            } else if (myIdx === 1) {
                                                Settings.data.ui.filledBackground = !(Settings.data.ui.filledBackground ?? true)
                                                Settings.saveImmediate()
                                            } else if (myIdx === 2) {
                                                root.toggleNoctaliaOpacity()
                                            } else if (myIdx === 3) {
                                                root.toggleKittyGlass()
                                            }
                                        }
                                    }
                                }
                            }
                            Row {
                                spacing: Style.marginS
                                anchors.horizontalCenter: parent.horizontalCenter
                                Repeater {
                                    model: 4
                                    delegate: ToolBtn {
                                        readonly property var labels: ["Snap Panels", "Settings Mode", "Panel Outline", "No Colors"]
                                        readonly property int myIdx: index
                                        num: index + 15
                                        tooltip: myIdx === 0
                                            ? "Snap: " + (Settings.data.ui.panelsAttachedToBar ? "On" : "Off")
                                            : myIdx === 1
                                                ? "Mode: " + (Settings.data.ui.settingsPanelMode || "attached")
                                                : myIdx === 2
                                                    ? "Outline: " + (Settings.data.ui["panelOutlineEnabled"] ? Settings.data.ui["panelOutlineWidth"] + "px" : "Off")
                                                    : myIdx === 3
                                                        ? "No Colors: " + (root.noColorsMode ? "On" : "Off")
                                                        : ""
                                        width: noctCol.btnSize; height: noctCol.btnSize
                                        interactive: true
                                        onTriggered: {
                                            if (myIdx === 0) {
                                                Settings.data.ui.panelsAttachedToBar = !Settings.data.ui.panelsAttachedToBar
                                                Settings.saveImmediate()
                                            } else if (myIdx === 1) {
                                                root.toggleSettingsPanelMode()
                                            } else if (myIdx === 2) {
                                                if (!Settings.data.ui["panelOutlineEnabled"]) {
                                                    Settings.data.ui["panelOutlineEnabled"] = true
                                                    Settings.data.ui["panelOutlineWidth"] = 2
                                                } else if (Settings.data.ui["panelOutlineWidth"] < 3) {
                                                    Settings.data.ui["panelOutlineWidth"]++
                                                } else {
                                                    Settings.data.ui["panelOutlineEnabled"] = false
                                                    Settings.data.ui["panelOutlineWidth"] = 0
                                                }
                                            } else if (myIdx === 3) {
                                                root.toggleNoColorsMode()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Card 3: Bar ──
                    Rectangle {
                        width: parent.width
                        height: barCol.implicitHeight + Style.marginS * 2
                        color: root._bgSurfaceVariant; radius: Style.radiusL
                        Column {
                            id: barCol
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Style.marginS }
                            spacing: Style.marginS
                            readonly property int btnSize: Math.floor(((width - Style.marginS * 4) / 6) * 0.88)

                            NText { text: "Bar"; pointSize: Style.fontSizeXXS; color: Color.mOnSurfaceVariant; font.weight: Font.Bold }
                            Row {
                                spacing: Style.marginS
                                anchors.horizontalCenter: parent.horizontalCenter
                                Repeater {
                                    model: 7
                                    delegate: ToolBtn {
                                        readonly property var labels: ["Bar Blur", "Bar Opacity", "Hover Reveal", "Bar Outline", "Bar Type", "Position", "Link Dark/Light"]
                                        readonly property int myIdx: index
                                        num: index + 18
                                        tooltip: myIdx === 0
                                            ? "Bar Blur: " + (Settings.data.bar.barBlurEnabled ? "On" : "Off")
                                            : myIdx === 1
                                                ? "Bar Opacity: " + (Settings.data.bar.useSeparateOpacity ? "Transparent" : "Opaque")
                                                : myIdx === 2
                                                    ? "Hover Reveal: " + ((Settings.data.bar.hoverRevealOpacity ?? 1.0) > 0 ? "On" : "Off")
                                                    : myIdx === 3
                                                        ? (Settings.data.bar.showBarOutline ? "Outline: " + Settings.data.bar.barOutlineWidth + "px" : "Outline: Off")
                                                        : myIdx === 4
                                                            ? "Type: " + (Settings.data.bar.barType || "simple")
                                                            : myIdx === 5
                                                        ? "Position: " + (Settings.data.bar.position || "top")
                                                        : "Link D/L: " + (Settings.data.wallpaper.linkLightAndDarkWallpapers ? "On" : "Off")
                                        width: barCol.btnSize; height: barCol.btnSize
                                        interactive: true
                                        onTriggered: {
                                            if (myIdx === 0) root.toggleBarBlur()
                                            else if (myIdx === 1) root.toggleBarOpacity()
                                            else if (myIdx === 2) root.toggleHoverReveal()
                                            else if (myIdx === 3) root.toggleBarOutline()
                                            else if (myIdx === 4) root.toggleBarType()
                                            else if (myIdx === 5) root.toggleBarPosition()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Card 4: Widgets & Capsules (General) ──
                    Rectangle {
                        width: parent.width
                        height: widgetCol.implicitHeight + Style.marginS * 2
                        color: root._bgSurfaceVariant; radius: Style.radiusL
                        Column {
                            id: widgetCol
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Style.marginS }
                            spacing: Style.marginS
                            readonly property int btnSize: Math.floor(((width - Style.marginS * 4) / 5) * 0.88)

                            NText { text: "Widgets & Capsules (General)"; pointSize: Style.fontSizeXXS; color: Color.mOnSurfaceVariant; font.weight: Font.Bold }
                            Row {
                                spacing: Style.marginS
                                anchors.horizontalCenter: parent.horizontalCenter
                                Repeater {
                                    model: 5
                                    delegate: ToolBtn {
                                        readonly property var labels: ["Widget Outline", "Capsule Outline", "Group", "Collapse", "Fill"]
                                        readonly property int myIdx: index
                                        num: index + 24
                                        tooltip: myIdx === 0
                                            ? "Widget Outline: " + (Settings.data.bar.showOutline ? "On" : "Off")
                                            : myIdx === 1
                                                ? "Capsule: " + ((Settings.data.bar.capsuleOutlineWidth ?? 0) > 0 ? Settings.data.bar.capsuleOutlineWidth + "px" : "Off")
                                                : myIdx === 2
                                                    ? "Capsule: " + (Settings.data.bar.capsuleGroupEnabled ? "On" : "Off")
                                                    : myIdx === 3
                                                        ? "Collapse: " + ({
                                                            "none":   "Off",
                                                            "left":   "Left",
                                                            "center": "Center",
                                                            "right":  "Right"
                                                          }[Settings.data.bar.capsuleCollapseTarget || "none"])
                                                        : "Fill: " + (Settings.data.bar.capsuleFillBar ? "On" : "Off")
                                        width: widgetCol.btnSize; height: widgetCol.btnSize
                                        interactive: true
                                        onTriggered: {
                                            if (myIdx === 0) {
                                                var newVal = !Settings.data.bar.showOutline
                                                Settings.data.bar.showOutline = newVal
                                                Settings.saveImmediate()
                                            } else if (myIdx === 1) {
                                                root.toggleContainerOutline()
                                            } else if (myIdx === 2) {
                                                root.toggleCapsuleGroup()
                                            } else if (myIdx === 3) {
                                                root.toggleCapsuleCollapse()
                                            } else if (myIdx === 4) {
                                                root.toggleCapsuleFillBar()
                                            }
                                        }
                                    }
                                }
                            }
                            Row {
                                spacing: Style.marginS
                                anchors.horizontalCenter: parent.horizontalCenter
                                Repeater {
                                    model: 3
                                    delegate: ToolBtn {
                                        readonly property var labels: ["Widget Spacing", "Content Outline", "Capsule Translucent"]
                                        readonly property int myIdx: index
                                        num: index + 29
                                        tooltip: myIdx === 0
                                            ? "Groups: " + (Settings.data.bar.capsuleGroupSpacing ?? 6) + "px / Inner: " + (Settings.data.bar.capsuleInnerPadding ?? 0) + "px"
                                            : myIdx === 1
                                                ? "Container Outline: " + (Settings.data.ui.boxBorderEnabled ? "On" : "Off")
                                                : "Capsule Translucent: " + (Settings.data.bar.capsuleTranslucent ? "On" : "Off")
                                        width: widgetCol.btnSize; height: widgetCol.btnSize
                                        interactive: true
                                        onTriggered: {
                                            if (myIdx === 0) {
                                                root.cycleWidgetSpacing()
                                            } else if (myIdx === 1) {
                                                root.toggleContentOutline()
                                            } else if (myIdx === 2) {
                                                Settings.data.bar.capsuleTranslucent = !Settings.data.bar.capsuleTranslucent
                                                Settings.saveImmediate()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Card 5: Section Capsules ──
                    Rectangle {
                        width: parent.width
                        height: sectionCol.implicitHeight + Style.marginS * 2
                        color: root._bgSurfaceVariant; radius: Style.radiusL
                        Column {
                            id: sectionCol
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Style.marginS }
                            spacing: Style.marginS
                            readonly property int btnSize: Math.floor(((width - Style.marginS * 4) / 5) * 0.88)

                            NText { text: "Section Capsules"; pointSize: Style.fontSizeXXS; color: Color.mOnSurfaceVariant; font.weight: Font.Bold }
                            Row {
                                spacing: Style.marginS
                                anchors.horizontalCenter: parent.horizontalCenter
                                Repeater {
                                    model: 5
                                    delegate: ToolBtn {
                                        readonly property var labels: ["Opacity L", "Opacity C", "Opacity R", "Group Spacing", "Inner Spacing"]
                                        readonly property int myIdx: index
                                        num: index + 32
                                        tooltip: myIdx === 0
                                            ? "Left Capsule Opacity: " + root.fmtCapsuleOpacity("left")
                                            : myIdx === 1
                                                ? "Center Capsule Opacity: " + root.fmtCapsuleOpacity("center")
                                                : myIdx === 2
                                                    ? "Right Capsule Opacity: " + root.fmtCapsuleOpacity("right")
                                                    : myIdx === 3
                                                        ? "Group Spacing: " + (Settings.data.bar.capsuleGroupSpacing ?? 6) + "px"
                                                        : "Inner Padding: " + (Settings.data.bar.capsuleInnerPadding ?? 0) + "px"
                                        width: sectionCol.btnSize; height: sectionCol.btnSize
                                        interactive: true
                                        onTriggered: {
                                            if (myIdx === 0) root.cycleCapsuleOpacity("left")
                                            else if (myIdx === 1) root.cycleCapsuleOpacity("center")
                                            else if (myIdx === 2) root.cycleCapsuleOpacity("right")
                                            else if (myIdx === 3) root.cycleCapsuleGroupSpacing()
                                            else if (myIdx === 4) root.cycleCapsuleInnerPadding()
                                        }
                                    }
                                }
                            }
                        }
                    }


                }
            }

            // Snapshots tab
            Rectangle {
                visible: root.tabIndex === 1
                width: parent.width; height: root.tabIndex === 1 ? snapsCol.implicitHeight + Style.marginM * 2 + 32 : 0
                color: "transparent"
                Rectangle {
                    anchors.fill: parent
                    color: root._bgSurfaceVariant; radius: Style.radiusL
                    Column {
                        id: snapsCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.marginM }
                        spacing: Style.marginS

                        Rectangle {
                            width: snapsCol.width; height: 38; radius: Style.radiusM
                            color: root._bgSurface
                            border.color: Color.mPrimary; border.width: Style.borderM
                            MouseArea {
                                id: saveArea; anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.saveSnapshot()
                            }
                            Row {
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Style.marginS }
                                spacing: Style.marginS
                                NIcon { icon: "camera"; color: Color.mPrimary; anchors.verticalCenter: parent.verticalCenter }
                                NText {
                                    text: "Save Current State"; pointSize: Style.fontSizeXS; font.weight: Font.Bold
                                    color: Color.mOnSurface; anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 36; elide: Text.ElideRight
                                }
                            }
                        }

                        NToggle {
                            width: snapsCol.width
                            label: "Skip Wallpaper"
                            checked: root._skipSnapshotWallpaper
                            onToggled: root._skipSnapshotWallpaper = checked
                        }
                        NToggle {
                            width: snapsCol.width
                            label: "Skip Colors"
                            checked: root._skipSnapshotColors
                            onToggled: root._skipSnapshotColors = checked
                        }

                        Flow {
                            width: snapsCol.width; spacing: Style.marginS
                            Repeater {
                                model: root.snapshotList
                                delegate: Rectangle {
                                    id: snapCard
                                    required property var modelData
                                    required property int index
                                    property bool renaming: false
                                    width: (snapsCol.width - Style.marginS) / 2; height: 46; radius: Style.radiusM
                                    color: snapCardMouse.containsMouse ? root._bgSurfaceVariant : root._bgSurface
                                    border.color: snapCard.renaming ? Color.mPrimary : (snapCardMouse.containsMouse ? Color.mPrimary : Color.mOutline)
                                    border.width: snapCard.renaming ? Style.borderM : Style.borderS
                                    Behavior on color { ColorAnimation { duration: Style.animationFast } }
                                    Behavior on border.color { ColorAnimation { duration: Style.animationFast } }
                                    MouseArea {
                                        id: snapCardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: snapCard.renaming ? Qt.IBeamCursor : Qt.PointingHandCursor
                                        onClicked: {
                                            if (snapCard.renaming) return
                                            root.loadSnapshot(snapCard.index)
                                        }
                                    }
                                    Column {
                                        anchors { left: parent.left; right: parent.right; leftMargin: Style.marginS; rightMargin: 52; verticalCenter: parent.verticalCenter }
                                        spacing: Style.marginXXS
                                        NText {
                                            visible: !snapCard.renaming
                                            text: modelData.name || ""; color: Color.mOnSurface
                                            pointSize: Style.fontSizeXXS; font.weight: Font.Bold
                                            width: parent.width; elide: Text.ElideRight
                                        }
                                        TextField {
                                            id: snapRenameField
                                            visible: snapCard.renaming
                                            text: modelData.name || ""
                                            color: Color.mOnSurface
                                            font.pointSize: Style.fontSizeXXS * 0.85
                                            font.weight: Font.Bold
                                            selectByMouse: true
                                            padding: 2
                                            background: Rectangle {
                                                color: Color.mSurface
                                                border.color: Color.mPrimary
                                                border.width: 1
                                                radius: 2
                                            }
                                            onVisibleChanged: {
                                                if (visible) {
                                                    text = modelData.name || ""
                                                    forceActiveFocus()
                                                    selectAll()
                                                }
                                            }
                                            onAccepted: {
                                                snapCard.renaming = false
                                                var t = text.trim()
                                                if (t !== "" && t !== modelData.name) {
                                                    root.renameSnapshot(snapCard.index, t)
                                                }
                                            }
                                            onActiveFocusChanged: {
                                                if (visible && !activeFocus) {
                                                    snapCard.renaming = false
                                                }
                                            }
                                        }
                                        NText {
                                            text: root.relativeTime(modelData.timestamp)
                                            pointSize: Style.fontSizeXXS; color: Color.mOnSurfaceVariant
                                        }
                                    }
                                    Row {
                                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 4 }
                                        spacing: 2
                                        Rectangle {
                                            id: snapRenameIcon
                                            width: 20; height: 20; radius: 4
                                            color: snapRenameHover.containsMouse ? Color.mPrimary : "transparent"
                                            Behavior on color { ColorAnimation { duration: Style.animationFast } }
                                            NText {
                                                anchors.centerIn: parent
                                                text: "\u270E"
                                                pointSize: Style.fontSizeXS
                                                color: snapRenameHover.containsMouse ? Color.mOnPrimary : Color.mOnSurfaceVariant
                                                font.weight: Font.Bold
                                            }
                                            MouseArea {
                                                id: snapRenameHover; anchors.fill: parent
                                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    snapCard.renaming = true
                                                    snapRenameField.forceActiveFocus()
                                                    snapRenameField.selectAll()
                                                }
                                            }
                                        }
                                        Rectangle {
                                            id: snapDelIcon
                                            width: 20; height: 20; radius: 4
                                            color: snapDelHover.containsMouse ? Color.mError : "transparent"
                                            Behavior on color { ColorAnimation { duration: Style.animationFast } }
                                            NText {
                                                anchors.centerIn: parent
                                                text: "X"
                                                pointSize: Style.fontSizeXS
                                                color: snapDelHover.containsMouse ? Color.mOnError : Color.mOnSurfaceVariant
                                                opacity: snapDelHover.containsMouse ? 1.0 : 0.5
                                                font.weight: Font.Bold
                                            }
                                            MouseArea {
                                                id: snapDelHover; anchors.fill: parent
                                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.deleteSnapshot(snapCard.index)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Colors tab
            Rectangle {
                visible: root.tabIndex === 2
                width: parent.width; height: root.tabIndex === 2 ? colorsCol.implicitHeight + Style.marginM * 2 + 32 : 0
                color: "transparent"
                Rectangle {
                    anchors.fill: parent
                    color: root._bgSurfaceVariant; radius: Style.radiusL
                    Column {
                        id: colorsCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.marginM }
                        spacing: Style.marginS
                        NToggle {
                            width: colorsCol.width
                            label: "Wallpaper Colors"
                            checked: root.useWallpaper
                            onToggled: {
                                root.useWallpaper = true
                                root.applyWallpaperColors()
                            }
                        }
                        NToggle {
                            width: colorsCol.width
                            label: "Zen Custom Background"
                            checked: root.zenCustomBg
                            onToggled: checked => root.applyZenCustomBg(checked)
                        }
                        NToggle {
                            width: colorsCol.width
                            label: "Sync Widget Colors"
                            description: "Sync count color across all widgets"
                            checked: root.syncWidgetColors
                            onToggled: function(v) {
                                root.syncWidgetColors = v
                                root.saveSyncColors()
                            }
                        }
                        NColorChoice {
                            width: colorsCol.width
                            visible: root.syncWidgetColors
                            label: "Count Color"
                            description: "Synced count color for all widgets"
                            currentKey: root.syncedCountColor
                            onSelected: function(key) {
                                root.syncedCountColor = key
                                root.saveSyncColors()
                            }
                        }
                        NColorChoice {
                            width: colorsCol.width
                            visible: root.syncWidgetColors
                            label: "Icon Color"
                            description: "Synced icon color for all widgets"
                            currentKey: root.syncedIconColor
                            onSelected: function(key) {
                                root.syncedIconColor = key
                                root.saveSyncColors()
                            }
                        }
                        NColorChoice {
                            width: colorsCol.width
                            visible: root.syncWidgetColors
                            label: "Hover Color"
                            description: "Synced color that appears on hover"
                            currentKey: root.syncedHoverColor
                            onSelected: function(key) {
                                root.syncedHoverColor = key
                                root.saveSyncColors()
                            }
                        }

                        // ── Capsule Colors per Section ──
                        NDivider { width: colorsCol.width }
                        NText { text: "Capsule Colors"; pointSize: Style.fontSizeXXS; color: Color.mOnSurfaceVariant; font.weight: Font.Bold }

                        // Left section
                        NColorChoice {
                            width: colorsCol.width
                            label: "Left Capsule"
                            description: "Capsule color for left section widgets"
                            currentKey: Settings.data.bar.capsuleLeftColorKey
                            onSelected: function(key) {
                                Settings.data.bar.capsuleLeftColorKey = key
                                Settings.saveImmediate()
                            }
                        }
                        Row {
                            spacing: Style.marginM
                            anchors.horizontalCenter: parent.horizontalCenter
                            NToggle {
                                label: "Individual"
                                description: "Each widget keeps its own color"
                                checked: Settings.data.bar.capsuleIndividualColorsLeft
                                onToggled: function(v) {
                                    Settings.data.bar.capsuleIndividualColorsLeft = v
                                    Settings.saveImmediate()
                                }
                            }
                            ToolBtn {
                                num: 1
                                interactive: true
                                tooltip: "Opacity: " + root.fmtCapsuleOpacity("left")
                                width: 40; height: 40
                                onTriggered: root.cycleCapsuleOpacity("left")
                            }
                        }

                        // Center section
                        NColorChoice {
                            width: colorsCol.width
                            label: "Center Capsule"
                            description: "Capsule color for center section widgets"
                            currentKey: Settings.data.bar.capsuleCenterColorKey
                            onSelected: function(key) {
                                Settings.data.bar.capsuleCenterColorKey = key
                                Settings.saveImmediate()
                            }
                        }
                        Row {
                            spacing: Style.marginM
                            anchors.horizontalCenter: parent.horizontalCenter
                            NToggle {
                                label: "Individual"
                                description: "Each widget keeps its own color"
                                checked: Settings.data.bar.capsuleIndividualColorsCenter
                                onToggled: function(v) {
                                    Settings.data.bar.capsuleIndividualColorsCenter = v
                                    Settings.saveImmediate()
                                }
                            }
                            ToolBtn {
                                num: 2
                                interactive: true
                                tooltip: "Opacity: " + root.fmtCapsuleOpacity("center")
                                width: 40; height: 40
                                onTriggered: root.cycleCapsuleOpacity("center")
                            }
                        }

                        // Right section
                        NColorChoice {
                            width: colorsCol.width
                            label: "Right Capsule"
                            description: "Capsule color for right section widgets"
                            currentKey: Settings.data.bar.capsuleRightColorKey
                            onSelected: function(key) {
                                Settings.data.bar.capsuleRightColorKey = key
                                Settings.saveImmediate()
                            }
                        }
                        Row {
                            spacing: Style.marginM
                            anchors.horizontalCenter: parent.horizontalCenter
                            NToggle {
                                label: "Individual"
                                description: "Each widget keeps its own color"
                                checked: Settings.data.bar.capsuleIndividualColorsRight
                                onToggled: function(v) {
                                    Settings.data.bar.capsuleIndividualColorsRight = v
                                    Settings.saveImmediate()
                                }
                            }
                            ToolBtn {
                                num: 3
                                interactive: true
                                tooltip: "Opacity: " + root.fmtCapsuleOpacity("right")
                                width: 40; height: 40
                                onTriggered: root.cycleCapsuleOpacity("right")
                            }
                        }
                    }
                }
            }

            // Schemes tab
            Rectangle {
                visible: root.tabIndex === 3
                width: parent.width; height: root.tabIndex === 3 ? schemesCol.implicitHeight + Style.marginM * 2 + 32 : 0
                color: "transparent"
                Rectangle {
                    anchors.fill: parent
                    color: root._bgSurfaceVariant; radius: Style.radiusL
                    Column {
                        id: schemesCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.marginM }
                        spacing: Style.marginS
                        Flow {
                            width: schemesCol.width; spacing: Style.marginS
                            Repeater {
                                model: root.schemeList
                                delegate: Rectangle {
                                    id: schemeCard
                                    required property var modelData
                                    required property int index
                                    property bool renaming: false
                                    readonly property bool isActive: !root.useWallpaper && root.currentSchemeLabel === modelData.name
                                    width: (schemesCol.width - Style.marginS) / 2; height: 38; radius: Style.radiusM
                                    color: root._bgSurface
                                    border.color: schemeCard.renaming ? Color.mPrimary : (isActive ? Color.mPrimary : Color.mOutline)
                                    border.width: schemeCard.renaming ? Style.borderM : (isActive ? Style.borderM : Style.borderS)
                                    MouseArea {
                                        id: cardClick
                                        anchors.fill: parent
                                        cursorShape: schemeCard.renaming ? Qt.IBeamCursor : Qt.PointingHandCursor
                                        onClicked: {
                                            if (schemeCard.renaming) return
                                            root.applyScheme(modelData.name)
                                        }
                                    }
                                    Row {
                                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Style.marginS }
                                        spacing: Style.marginS
                                        Rectangle {
                                            width: 26; height: 26; radius: 6
                                            color: modelData.primary || "#000000"
                                            border.color: Color.mOutline; border.width: Style.borderS
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Item {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 100
                                            height: 24
                                            NText {
                                                visible: !schemeCard.renaming
                                                text: modelData.name; color: Color.mOnSurface
                                                pointSize: Style.fontSizeXS; font.weight: Font.Bold
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width; elide: Text.ElideRight
                                            }
                                            TextField {
                                                id: schemeRenameField
                                                visible: schemeCard.renaming
                                                text: modelData.name
                                                color: Color.mOnSurface
                                                font.pointSize: Style.fontSizeXS * 0.85
                                                font.weight: Font.Bold
                                                selectByMouse: true
                                                padding: 2
                                                background: Rectangle {
                                                    color: Color.mSurface
                                                    border.color: Color.mPrimary
                                                    border.width: 1
                                                    radius: 2
                                                }
                                                onVisibleChanged: {
                                                    if (visible) {
                                                        text = modelData.name
                                                        forceActiveFocus()
                                                        selectAll()
                                                    }
                                                }
                                                onAccepted: {
                                                    schemeCard.renaming = false
                                                    var t = text.trim()
                                                    if (t !== "" && t !== modelData.name) {
                                                        root.renameScheme(modelData.name, t)
                                                    }
                                                }
                                                onActiveFocusChanged: {
                                                    if (visible && !activeFocus) {
                                                        schemeCard.renaming = false
                                                    }
                                                }
                                            }
                                        }
                                        Rectangle {
                                            width: 20; height: 20; radius: 4
                                            color: schemeRenameHover.containsMouse ? Color.mPrimary : "transparent"
                                            Behavior on color { ColorAnimation { duration: Style.animationFast } }
                                            anchors.verticalCenter: parent.verticalCenter
                                            NText {
                                                anchors.centerIn: parent
                                                text: "\u270E"
                                                pointSize: Style.fontSizeXS
                                                color: schemeRenameHover.containsMouse ? Color.mOnPrimary : Color.mOnSurfaceVariant
                                                font.weight: Font.Bold
                                            }
                                            MouseArea {
                                                id: schemeRenameHover; anchors.fill: parent
                                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    schemeCard.renaming = true
                                                    schemeRenameField.forceActiveFocus()
                                                    schemeRenameField.selectAll()
                                                }
                                            }
                                        }
                                        Rectangle {
                                            width: 20; height: 20; radius: 4
                                            color: delHover.containsMouse ? Color.mError : "transparent"
                                            Behavior on color { ColorAnimation { duration: Style.animationFast } }
                                            NText {
                                                anchors.centerIn: parent
                                                text: isActive ? "\u2713" : "X"
                                                pointSize: Style.fontSizeXS
                                                color: isActive ? Color.mPrimary : (delHover.containsMouse ? Color.mOnError : Color.mOnSurfaceVariant)
                                                opacity: isActive ? 1.0 : (delHover.containsMouse ? 1.0 : 0.5)
                                                font.weight: Font.Bold
                                            }
                                            MouseArea {
                                                id: delHover; anchors.fill: parent
                                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: root.deleteScheme(modelData.name)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Notes tab - read-only information
            Rectangle {
                visible: root.tabIndex === 4
                width: parent.width; height: root.tabIndex === 4 ? notesCol.implicitHeight + Style.marginM * 2 : 0
                color: "transparent"
                Rectangle {
                    anchors.fill: parent
                    color: root._bgSurfaceVariant; radius: Style.radiusL
                    Column {
                        id: notesCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.marginM }
                        spacing: Style.marginM

                        NText {
                            text: "Notes & Tips"
                            pointSize: Style.fontSizeL
                            font.weight: Font.Bold
                            color: Color.mPrimary
                        }

                        // Note 1: Capsule Translucent
                        Rectangle {
                            width: notesCol.width
                            height: note1Col.implicitHeight + Style.marginM * 2
                            radius: Style.radiusM
                            color: root._bgSurface
                            border.color: Color.mOutline
                            border.width: Style.borderS
                            Column {
                                id: note1Col
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.marginM }
                                spacing: Style.marginXS

                                NText {
                                    text: "Capsule Translucent"
                                    pointSize: Style.fontSizeM
                                    font.weight: Font.Bold
                                    color: Color.mOnSurface
                                }
                                NText {
                                    text: "For capsule transparent to work, cards need to be enabled (Filled BG toggle in Controls tab)."
                                    pointSize: Style.fontSizeS
                                    color: Color.mOnSurfaceVariant
                                    wrapMode: Text.WordWrap
                                    width: notesCol.width - Style.marginM * 2
                                }
                            }
                        }

                        // Note 2: Panel Opacity
                        Rectangle {
                            width: notesCol.width
                            height: note2Col.implicitHeight + Style.marginM * 2
                            radius: Style.radiusM
                            color: root._bgSurface
                            border.color: Color.mOutline
                            border.width: Style.borderS
                            Column {
                                id: note2Col
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.marginM }
                                spacing: Style.marginXS

                                NText {
                                    text: "Panel Opacity"
                                    pointSize: Style.fontSizeM
                                    font.weight: Font.Bold
                                    color: Color.mOnSurface
                                }
                                NText {
                                    text: "Use Noctalia Opacity toggle (button 13) to cycle between 100%, 50%, and 0% opacity. Widgets toggle (button 11) must be ON for transparency to work."
                                    pointSize: Style.fontSizeS
                                    color: Color.mOnSurfaceVariant
                                    wrapMode: Text.WordWrap
                                    width: notesCol.width - Style.marginM * 2
                                }
                            }
                        }

                        // Note 3: Wallpaper Links
                        Rectangle {
                            width: notesCol.width
                            height: note3Col.implicitHeight + Style.marginM * 2
                            radius: Style.radiusM
                            color: root._bgSurface
                            border.color: Color.mOutline
                            border.width: Style.borderS
                            Column {
                                id: note3Col
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.marginM }
                                spacing: Style.marginXS

                                NText {
                                    text: "Dark/Light Wallpaper"
                                    pointSize: Style.fontSizeM
                                    font.weight: Font.Bold
                                    color: Color.mOnSurface
                                }
                                NText {
                                    text: "Use 'Link Dark/Light' toggle in Bar section to control whether wallpaper changes when switching dark/light mode."
                                    pointSize: Style.fontSizeS
                                    color: Color.mOnSurfaceVariant
                                    wrapMode: Text.WordWrap
                                    width: notesCol.width - Style.marginM * 2
                                }
                            }
                        }
                    }
                }
            }

        }
    }

    component ToolBtn: Item {
        id: btn
        property int    num:         0
        property bool   interactive: false
        property string tooltip:     ""
        signal triggered()
        Rectangle {
            anchors.centerIn: parent
            width:  Math.min(btn.width - 8, 42)
            height: Math.min(btn.height - 4, 42)
            radius: Style.radiusM
            color: btn.interactive ? (btnArea.containsMouse ? Color.mHover : root._bgSurface) : root._bgSurface
            border.color: btn.interactive ? (btnArea.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant) : "transparent"
            border.width: btn.interactive ? 1 : 0
            clip: true
            scale: (btn.interactive && btnArea.containsMouse) ? 1.08 : 1.0
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
            Behavior on border.color { ColorAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic } }
            NText {
                anchors.centerIn: parent; text: btn.num.toString()
                pointSize: Style.fontSizeXXS; font.weight: Font.Bold; color: btnArea.containsMouse ? Color.mOnHover : Color.mOnSurface
                Behavior on color { ColorAnimation { duration: Style.animationFast } }
            }
            MouseArea {
                id: btnArea; anchors.fill: parent; visible: btn.interactive
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.triggered()
            }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom; anchors.topMargin: 2
            width: tipText.implicitWidth + 10; height: tipText.implicitHeight + 4
            radius: 4; color: root._bgSurfaceVariant
            border.color: Color.mOutline; border.width: Style.borderS
            visible: btn.interactive && btnArea.containsMouse && btn.tooltip !== ""
            NText {
                id: tipText; anchors.centerIn: parent
                text: btn.tooltip; pointSize: Style.fontSizeXS; color: Color.mOnSurface
            }
        }
    }
}
