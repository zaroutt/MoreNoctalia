import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    property var pluginApi: null
    spacing: Style.marginL

    property string screenshotPath:         ""
    property string videoPath:              ""
    property string filenameFormat:         ""
    property string x02ApiKey:             ""
    property string x02Expiry:             "7d"
    property bool   shareSkipPopover:      false
    property bool   recordSkipConfirmation: false
    property bool   recordCopyToClipboard:  false
    property int    gifMaxSeconds:          30
    property string searchEngineUrl:        ""

    function buildPreview(fmt) {
        var now = new Date()
        if (!fmt || fmt.trim() === "")
            return Qt.formatDateTime(now, "yyyy-MM-dd_HH-mm-ss")
        return fmt
            .replace(/%Y/g, Qt.formatDateTime(now, "yyyy"))
            .replace(/%m/g, Qt.formatDateTime(now, "MM"))
            .replace(/%d/g, Qt.formatDateTime(now, "dd"))
            .replace(/%H/g, Qt.formatDateTime(now, "HH"))
            .replace(/%M/g, Qt.formatDateTime(now, "mm"))
            .replace(/%S/g, Qt.formatDateTime(now, "ss"))
    }

    // ── Screenshot & Recording ────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        RowLayout {
            spacing: Style.marginS
            NIcon  { icon: "camera"; color: Color.mPrimary }
            NLabel { label: pluginApi?.tr("settings.screenshotSection") }
        }

        NTextInput {
            Layout.fillWidth: true
            label:           pluginApi?.tr("settings.screenshotPath")
            description:     pluginApi?.tr("settings.screenshotPathDesc")
            placeholderText: "~/Pictures/Screenshots"
        }

        NTextInput {
            Layout.fillWidth: true
            label:           pluginApi?.tr("settings.videoPath")
            description:     pluginApi?.tr("settings.videoPathDesc")
            placeholderText: "~/Videos"
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            ColumnLayout {
                spacing: Style.marginXS
                NLabel { label: pluginApi?.tr("settings.filenameFormat") }
                NText {
                    text:      pluginApi?.tr("settings.filenameFormatDesc")
                    pointSize: Style.fontSizeXS
                    color:     Color.mOnSurfaceVariant
                    wrapMode:  Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: Style.marginS
                readonly property var tokens: [
                    { label: pluginApi?.tr("settings.filenameTokens.year"),   value: "%Y" },
                    { label: pluginApi?.tr("settings.filenameTokens.month"),  value: "%m" },
                    { label: pluginApi?.tr("settings.filenameTokens.day"),    value: "%d" },
                    { label: pluginApi?.tr("settings.filenameTokens.hour"),   value: "%H" },
                    { label: pluginApi?.tr("settings.filenameTokens.minute"), value: "%M" },
                    { label: pluginApi?.tr("settings.filenameTokens.second"), value: "%S" },
                ]
                Repeater {
                    model: parent.tokens
                    delegate: Rectangle {
                        height: 28
                        width:  tokenRow.implicitWidth + Style.marginM * 2
                        radius: Style.radiusM
                        color:  Color.mSurfaceVariant
                        Row {
                            id: tokenRow
                            anchors.centerIn: parent
                            spacing: Style.marginXS
                            NText {
                                text:        modelData.label
                                pointSize:   Style.fontSizeXS
                                font.weight: Font.Medium
                                color:       Color.mOnSurface
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            NText {
                                text:      modelData.value
                                pointSize: Style.fontSizeXS
                                color:     Color.mOnSurfaceVariant
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }

            NTextInput {
                id: filenameInput
                Layout.fillWidth: true
                placeholderText: "%Y-%m-%dT%H-%M-%S"
            }

            Rectangle {
                Layout.fillWidth: true
                height:  previewRow.implicitHeight + Style.marginM * 2
                radius:  Style.radiusM
                color:   Color.mSurfaceVariant
                opacity: 0.7
                Row {
                    id: previewRow
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: Style.marginM; rightMargin: Style.marginM
                    }
                    spacing: Style.marginS
                    NIcon {
                        icon:  "file"; color: Color.mOnSurfaceVariant; scale: 0.85
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    NText {
                        text:        root.buildPreview(root.filenameFormat) + ".ext"
                        pointSize:   Style.fontSizeXS
                        color:       Color.mOnSurface
                        font.family: "monospace"
                        elide:       Text.ElideRight
                        width:       parent.width - Style.marginM * 2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }

    NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

    // ── Share ─────────────────────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        RowLayout {
            spacing: Style.marginS
            NIcon  { icon: "share"; color: Color.mPrimary }
            NLabel { label: pluginApi?.tr("settings.shareSection") }
        }

        NTextInput {
            Layout.fillWidth: true
            label:           pluginApi?.tr("settings.x02ApiKey")
            description:     pluginApi?.tr("settings.x02ApiKeyDesc")
            placeholderText: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing:  Style.marginXS

            NLabel { label: pluginApi?.tr("settings.x02Expiry") }

            NText {
                text:      pluginApi?.tr("settings.x02ExpiryDesc")
                pointSize: Style.fontSizeXS
                color:     Color.mOnSurfaceVariant
                wrapMode:  Text.WordWrap
                Layout.fillWidth: true
            }

            Flow {
                Layout.fillWidth: true
                spacing: Style.marginS

                readonly property var expiryDefs: [
                    { id: "1h",        label: pluginApi?.tr("settings.expiry1h")        },
                    { id: "1d",        label: pluginApi?.tr("settings.expiry1d")        },
                    { id: "7d",        label: pluginApi?.tr("settings.expiry7d")        },
                    { id: "30d",       label: pluginApi?.tr("settings.expiry30d")       },
                    { id: "permanent", label: pluginApi?.tr("settings.expiryPermanent") },
                ]

                Repeater {
                    model: parent.expiryDefs
                    delegate: Rectangle {
                        height:  28
                        width:   _expLabel.implicitWidth + Style.marginM * 2
                        radius:  Style.radiusM
                        color:   Color.mSurfaceVariant
                        NText {
                            id: _expLabel
                            anchors.centerIn: parent
                            text:        modelData.label
                            pointSize:   Style.fontSizeXS
                            font.weight: Font.Normal
                            color:       Color.mOnSurface
                        }
                    }
                }
            }
        }

        NToggle {
            Layout.fillWidth: true
            label:       pluginApi?.tr("settings.shareSkipPopover")
            description: pluginApi?.tr("settings.shareSkipPopoverDesc")
        }
    }

    NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

    // ── Recording ─────────────────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        RowLayout {
            spacing: Style.marginS
            NIcon  { icon: "video"; color: Color.mPrimary }
            NLabel { label: pluginApi?.tr("settings.recordingSection") }
        }

        NToggle {
            Layout.fillWidth: true
            label:       pluginApi?.tr("settings.recordSkipConfirmation")
            description: pluginApi?.tr("settings.recordSkipConfirmationDesc")
        }

        NToggle {
            Layout.fillWidth: true
            label:       pluginApi?.tr("settings.recordCopyToClipboard")
            description: pluginApi?.tr("settings.recordCopyToClipboardDesc")
        }

        NTextInput {
            Layout.fillWidth: true
            label:           pluginApi?.tr("settings.gifMaxSeconds")
            description:     pluginApi?.tr("settings.gifMaxSecondsDesc")
            placeholderText: "30"
        }
    }

    NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

    // ── OCR ───────────────────────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        RowLayout {
            spacing: Style.marginS
            NIcon  { icon: "scan"; color: Color.mPrimary }
            NLabel { label: pluginApi?.tr("settings.ocrSection") }
        }

        NTextInput {
            Layout.fillWidth: true
            label:           pluginApi?.tr("settings.searchEngineUrl")
            description:     pluginApi?.tr("settings.searchEngineUrlDesc")
            placeholderText: "https://www.google.com/search?q="
        }
    }

    NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

    // ── Bar Controls ──────────────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        RowLayout {
            spacing: Style.marginS
            NIcon  { icon: "layout-board"; color: Color.mPrimary }
            NLabel { label: "Bar Controls" }
        }

        NToggle {
            Layout.fillWidth: true
            label: "Hover Reveal"
            description: "Widgets stay transparent until the mouse hovers nearby"
            checked: Settings.data.bar.hoverRevealOpacity !== undefined && Settings.data.bar.hoverRevealOpacity < 1.0
            onToggled: function(v) {
                Settings.data.bar.hoverRevealOpacity = v ? 0.0 : 1.0
                Settings.saveImmediate()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Style.marginL
            spacing: Style.marginS
            visible: Settings.data.bar.hoverRevealOpacity !== undefined && Settings.data.bar.hoverRevealOpacity < 1.0

            NLabel { label: "Widgets with Hover Reveal" }

            Repeater {
                model: {
                    var widgets = [];
                    var barWidgets = Settings.data.bar.widgets;
                    if (barWidgets) {
                        if (barWidgets.left) {
                            for (var i = 0; i < barWidgets.left.length; i++) {
                                widgets.push(barWidgets.left[i]);
                            }
                        }
                        if (barWidgets.center) {
                            for (var i = 0; i < barWidgets.center.length; i++) {
                                widgets.push(barWidgets.center[i]);
                            }
                        }
                        if (barWidgets.right) {
                            for (var i = 0; i < barWidgets.right.length; i++) {
                                widgets.push(barWidgets.right[i]);
                            }
                        }
                    }
                    return widgets;
                }
                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    NText {
                        text: modelData.id || ""
                        Layout.fillWidth: true
                    }

                    NToggle {
                        checked: modelData.hoverReveal !== false
                        onToggled: function(v) {
                            var barWidgets = Settings.data.bar.widgets;
                            var sections = ["left", "center", "right"];
                            for (var s = 0; s < sections.length; s++) {
                                var section = barWidgets[sections[s]];
                                if (section) {
                                    for (var i = 0; i < section.length; i++) {
                                        if (section[i].id === modelData.id) {
                                            var newSectionArray = section.slice();
                                            var old = section[i];
                                            var newWidget = {};
                                            var keys = Object.keys(old);
                                            for (var k = 0; k < keys.length; k++) {
                                                newWidget[keys[k]] = old[keys[k]];
                                            }
                                            newWidget.hoverReveal = v;
                                            newSectionArray[i] = newWidget;
                                            barWidgets[sections[s]] = newSectionArray;
                                            Settings.saveImmediate();
                                            return;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        NToggle {
            Layout.fillWidth: true
            label: "Bar Outline"
            description: "Show a colored outline around the bar"
            checked: Settings.data.bar.showBarOutline
            onToggled: function(v) { Settings.data.bar.showBarOutline = v; Settings.saveImmediate() }
        }

        NToggle {
            Layout.fillWidth: true
            label: "Bar Blur"
            description: "Blur the area behind the bar"
            checked: Settings.data.bar.barBlurEnabled
            onToggled: function(v) { Settings.data.bar.barBlurEnabled = v; Settings.saveImmediate() }
        }

        NToggle {
            Layout.fillWidth: true
            label: "Separate Opacity"
            description: "Use independent bar opacity (0 = transparent bar)"
            checked: Settings.data.bar.useSeparateOpacity
            onToggled: function(v) {
                Settings.data.bar.useSeparateOpacity = v
                if (!v) Settings.data.bar.backgroundOpacity = 0.93
                Settings.saveImmediate()
            }
        }

        NToggle {
            Layout.fillWidth: true
            label: "Group Widgets in Capsule"
            description: "Selected widgets get a capsule background. Consecutive selected widgets share one capsule."
            checked: Settings.data.bar.capsuleGroupEnabled
            onToggled: function(v) { Settings.data.bar.capsuleGroupEnabled = v; Settings.saveImmediate() }
        }

        NToggle {
            Layout.fillWidth: true
            label: "Individual Colors - Left"
            description: "Each widget in a capsule keeps its own color instead of sharing the first widget's color."
            checked: Settings.data.bar.capsuleIndividualColorsLeft
            visible: Settings.data.bar.capsuleGroupEnabled
            enabled: Settings.data.bar.capsuleGroupEnabled
            onToggled: function(v) { Settings.data.bar.capsuleIndividualColorsLeft = v; Settings.saveImmediate() }
        }

        NToggle {
            Layout.fillWidth: true
            label: "Individual Colors - Center"
            description: "Each widget in a capsule keeps its own color instead of sharing the first widget's color."
            checked: Settings.data.bar.capsuleIndividualColorsCenter
            visible: Settings.data.bar.capsuleGroupEnabled
            enabled: Settings.data.bar.capsuleGroupEnabled
            onToggled: function(v) { Settings.data.bar.capsuleIndividualColorsCenter = v; Settings.saveImmediate() }
        }

        NToggle {
            Layout.fillWidth: true
            label: "Individual Colors - Right"
            description: "Each widget in a capsule keeps its own color instead of sharing the first widget's color."
            checked: Settings.data.bar.capsuleIndividualColorsRight
            visible: Settings.data.bar.capsuleGroupEnabled
            enabled: Settings.data.bar.capsuleGroupEnabled
            onToggled: function(v) { Settings.data.bar.capsuleIndividualColorsRight = v; Settings.saveImmediate() }
        }
    }
}
