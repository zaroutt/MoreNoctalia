import QtQuick
import qs.Commons
import qs.Widgets
Item {
    id: root
    property var pluginApi: null
    property var mainInstance: null
    implicitWidth: parent?.width ?? 0
    implicitHeight: contentCol.implicitHeight
    Column {
        id: contentCol
        width: parent.width
        spacing: Style.marginM
        Row {
            width: parent.width
            spacing: Style.marginS
            NIcon {
                icon: "qrcode"
                color: Color.mPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
            NText {
                text: pluginApi?.tr("tools.qr")
                color: Color.mPrimary
                font.weight: Font.Bold
                pointSize: Style.fontSizeS
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Rectangle {
            width: parent.width
            height: 160 * Style.uiScaleRatio
            radius: Style.radiusM
            color: "transparent"
            clip: true
            border.color: Style.capsuleBorderColor
            border.width: Style.capsuleBorderWidth
            visible: false
        }
        Rectangle {
            height: 26
            width: qrBadge.implicitWidth + Style.marginM * 2
            radius: Style.radiusS
            color: Qt.alpha(Color.mPrimary, 0.15)
            NText {
                id: qrBadge
                anchors.centerIn: parent
                font.weight: Font.Bold
                pointSize: Style.fontSizeXS
                color: Color.mPrimary
                text: "Text"
            }
        }
        Rectangle {
            width: parent.width
            height: 120 * Style.uiScaleRatio
            radius: Style.radiusM
            color: Color.mSurface
            clip: true
            border.color: Style.capsuleBorderColor
            border.width: Style.capsuleBorderWidth
            Flickable {
                id: qrFlick
                anchors.fill: parent
                anchors.margins: Style.marginS
                contentHeight: qrText.implicitHeight
                clip: true
                interactive: qrText.implicitHeight > qrFlick.height
                TextEdit {
                    id: qrText
                    width: qrFlick.width
                    text: ""
                    wrapMode: TextEdit.WordWrap
                    color: Color.mOnSurface
                    font.pointSize: Style.fontSizeS
                    selectByMouse: true
                    selectionColor: Color.mPrimary
                    selectedTextColor: Color.mOnPrimary
                    WheelHandler {
                        onWheel: event => {
                            qrFlick.flick(0, event.angleDelta.y * 5)
                            event.accepted = false
                        }
                    }
                }
            }
        }
        Row {
            width: parent.width
            spacing: Style.marginS
            Rectangle {
                width: parent.width - 46
                height: 38
                radius: Style.radiusM
                color: Color.mSurface
                border.color: Color.mPrimary
                border.width: Style.capsuleBorderWidth
                Row {
                    anchors.centerIn: parent
                    spacing: Style.marginS
                    NIcon {
                        icon: "copy"
                        color: Color.mPrimary
                    }
                    NText {
                        text: pluginApi?.tr("panel.copy")
                        color: Color.mPrimary
                        font.weight: Font.Bold
                        pointSize: Style.fontSizeS
                    }
                }
            }
            Rectangle {
                width: 38
                height: 38
                radius: Style.radiusM
                color: Color.mSurface
                border.color: Style.capsuleBorderColor
                border.width: Style.capsuleBorderWidth
                NIcon {
                    anchors.centerIn: parent
                    icon: "trash"
                    color: Color.mOnSurfaceVariant
                }
            }
        }
    }
}
