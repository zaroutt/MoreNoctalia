import QtQuick
import qs.Commons
import qs.Widgets
Item {
    id: root
    property var pluginApi: null
    property var mainInstance: null
    implicitWidth: parent?.width ?? 0
    implicitHeight: contentCol.implicitHeight
    readonly property var paletteColors: []
    Column {
        id: contentCol
        width: parent.width
        spacing: Style.marginM
        Rectangle {
            width: parent.width
            height: 36
            radius: Style.radiusM
            color: Color.mSurface
            border.color: Color.mPrimary
            border.width: Style.capsuleBorderWidth
            Row {
                anchors.centerIn: parent
                spacing: Style.marginS
                NIcon {
                    icon: "palette"
                    color: Color.mPrimary
                }
                NText {
                    text: pluginApi?.tr("panel.pickAgain")
                    color: Color.mPrimary
                    pointSize: Style.fontSizeS
                }
            }
        }
        Column {
            visible: false
            width: parent.width
            spacing: Style.marginM
            Rectangle {
                width: parent.width
                height: 36
                radius: Style.radiusM
                color: Color.mSurface
                border.color: Color.mPrimary
                border.width: Style.capsuleBorderWidth
                Row {
                    anchors.centerIn: parent
                    spacing: Style.marginS
                    NIcon {
                        icon: "palette"
                        color: Color.mPrimary
                    }
                    NText {
                        text: pluginApi?.tr("panel.pickAgain")
                        color: Color.mPrimary
                        pointSize: Style.fontSizeS
                    }
                }
            }
            Rectangle {
                width: parent.width
                height: 36
                radius: Style.radiusM
                color: Color.mSurface
                border.color: Style.capsuleBorderColor
                border.width: Style.capsuleBorderWidth
                Row {
                    anchors.centerIn: parent
                    spacing: Style.marginS
                    NIcon {
                        icon: "copy"
                        color: Color.mOnSurfaceVariant
                    }
                    NText {
                        text: pluginApi?.tr("palette.cssVars")
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeS
                    }
                }
            }
            Rectangle {
                width: parent.width
                height: 36
                radius: Style.radiusM
                color: Color.mSurface
                border.color: Style.capsuleBorderColor
                border.width: Style.capsuleBorderWidth
                Row {
                    anchors.centerIn: parent
                    spacing: Style.marginS
                    NIcon {
                        icon: "list"
                        color: Color.mOnSurfaceVariant
                    }
                    NText {
                        text: pluginApi?.tr("palette.hexList")
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeS
                    }
                }
            }
            Rectangle {
                width: parent.width
                height: 36
                radius: Style.radiusM
                color: Color.mSurface
                border.color: Style.capsuleBorderColor
                border.width: Style.capsuleBorderWidth
                Row {
                    anchors.centerIn: parent
                    spacing: Style.marginS
                    NIcon {
                        icon: "trash"
                        color: Color.mOnSurfaceVariant
                    }
                    NText {
                        text: pluginApi?.tr("panel.clearResult")
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeS
                    }
                }
            }
        }
    }
}
