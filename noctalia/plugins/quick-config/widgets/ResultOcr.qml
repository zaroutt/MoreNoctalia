import QtQuick
import qs.Commons
import qs.Widgets
Item {
    id: root
    property var    pluginApi:    null
    property var    mainInstance: null
    implicitWidth:  parent?.width ?? 0
    implicitHeight: contentCol.implicitHeight
    Column {
        id: contentCol
        width: parent.width
        spacing: Style.marginS
        Rectangle {
            width: parent.width; height: 160 * Style.uiScaleRatio
            radius: Style.radiusM; color: Color.mSurfaceVariant; clip: true
        }
        Rectangle {
            width: parent.width; height: 220 * Style.uiScaleRatio
            radius: Style.radiusM; color: Color.mSurface; clip: true
            border.color: Style.capsuleBorderColor
            border.width: Style.capsuleBorderWidth
            Flickable {
                id: ocrFlick; anchors.fill: parent; anchors.margins: Style.marginS
                contentHeight: ocrText.implicitHeight; clip: true
                interactive: ocrText.implicitHeight > ocrFlick.height
                TextEdit {
                    id: ocrText; width: ocrFlick.width; text: ""
                    wrapMode: TextEdit.WordWrap; color: Color.mOnSurface
                    font.pointSize: Style.fontSizeS
                    selectByMouse: true; selectionColor: Color.mPrimary
                    selectedTextColor: Color.mOnPrimary
                    WheelHandler {
                        onWheel: event => { ocrFlick.flick(0, event.angleDelta.y * 5); event.accepted = false }
                    }
                }
            }
        }
        Row {
            width: parent.width; spacing: Style.marginXS
            Flow {
                width: parent.width - _ocrClearBtn.width - Style.marginS
                spacing: Style.marginXS
                Rectangle {
                    height: 26; width: _ocrSearchRow.implicitWidth + Style.marginS * 2; radius: Style.radiusS
                    color: Color.mSurfaceVariant
                    Row {
                        id: _ocrSearchRow; anchors.centerIn: parent; spacing: Style.marginXS
                        NIcon { icon: "search"; color: Color.mOnSurface; scale: 0.8 }
                        NText { text: pluginApi?.tr("panel.searchText"); color: Color.mOnSurface; pointSize: Style.fontSizeXS }
                    }
                }
                Rectangle {
                    height: 26; width: _ocrCopyRow.implicitWidth + Style.marginS * 2; radius: Style.radiusS
                    color: Color.mSurfaceVariant
                    Row {
                        id: _ocrCopyRow; anchors.centerIn: parent; spacing: Style.marginXS
                        NIcon { icon: "copy"; color: Color.mOnSurface; scale: 0.8 }
                        NText { text: pluginApi?.tr("panel.copy"); color: Color.mOnSurface; pointSize: Style.fontSizeXS }
                    }
                }
            }
            Rectangle {
                id: _ocrClearBtn; height: 26; width: _ocrClearRow.implicitWidth + Style.marginM * 2; radius: Style.radiusS
                color: Color.mSurfaceVariant
                border.color: Color.mError; border.width: Style.capsuleBorderWidth
                Row {
                    id: _ocrClearRow; anchors.centerIn: parent; spacing: Style.marginXS
                    NIcon { icon: "trash"; color: Color.mOnSurfaceVariant; scale: 0.8 }
                    NText { text: pluginApi?.tr("panel.clearResult"); color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeXS }
                }
            }
        }
        Row {
            width: parent.width; spacing: Style.marginS
            Rectangle { width: 32; height: 1; color: Color.mOnSurfaceVariant; opacity: 0.25; anchors.verticalCenter: parent.verticalCenter }
            NIcon { icon: "world"; color: Color.mOnSurfaceVariant; scale: 0.75 }
            NText { text: pluginApi?.tr("ocr.translateSection"); color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeXS }
            Rectangle {
                height: 1; color: Color.mOnSurfaceVariant; opacity: 0.25
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 32 - Style.marginS * 3 - 16 - _transLabel.implicitWidth
            }
            NText { id: _transLabel; visible: false; text: pluginApi?.tr("ocr.translateSection") }
        }
        NText {
            width: parent.width
            text: pluginApi?.tr("ocr.noTranslateTool")
            color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeXS; wrapMode: Text.WordWrap
        }
        Column {
            width: parent.width; spacing: Style.marginS
            visible: false
            Row {
                width: parent.width; spacing: Style.marginS
                NComboBox {
                    width: parent.width - translateBtn.width - Style.marginS
                    label: pluginApi?.tr("panel.translateTo")
                    minimumWidth: 100; popupHeight: 220
                }
                Rectangle {
                    id: translateBtn; height: 34; width: 34; radius: Style.radiusM
                    color: Color.mSurfaceVariant
                    NIcon { anchors.centerIn: parent; icon: "world"; color: Color.mOnSurface }
                }
            }
            Rectangle {
                width: parent.width; height: 140 * Style.uiScaleRatio
                radius: Style.radiusM; color: Color.mSurface; clip: true
                border.color: Style.capsuleBorderColor
                border.width: Style.capsuleBorderWidth
                visible: false
                Flickable {
                    id: trFlick; anchors.fill: parent; anchors.margins: Style.marginS
                    contentHeight: trText.implicitHeight; clip: true
                    interactive: trText.implicitHeight > trFlick.height
                    TextEdit {
                        id: trText; width: trFlick.width; text: ""
                        color: Color.mOnSurface; font.pointSize: Style.fontSizeS
                        wrapMode: TextEdit.WordWrap
                        selectByMouse: true; selectionColor: Color.mPrimary
                        selectedTextColor: Color.mOnPrimary
                        WheelHandler {
                            onWheel: event => { trFlick.flick(0, event.angleDelta.y * 5); event.accepted = false }
                        }
                    }
                }
                NIcon {
                    icon: "copy"; color: Color.mOnSurfaceVariant
                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Style.marginS
                }
            }
        }
    }
}
