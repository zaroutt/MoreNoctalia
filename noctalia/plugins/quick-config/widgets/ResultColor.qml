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
                    icon: "color-picker"
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
            width: parent.width
            spacing: Style.marginM
            Row {
                width: parent.width
                spacing: Style.marginM
                Rectangle {
                    width: 110
                    height: 110
                    radius: Style.radiusM
                    color: Color.mSurfaceVariant
                    clip: true
                    border.color: Style.capsuleBorderColor
                    border.width: Style.capsuleBorderWidth
                    Rectangle {
                        anchors.centerIn: parent
                        width:  12
                        height: 12
                        radius: 6
                        color: "transparent"
                        border.color: "white"
                        border.width: 2
                        z:1
                    }
                }
                Column {
                    width: parent.width - 110 - Style.marginM
                    spacing: Style.marginS
                    Rectangle {
                        id: colorSwatch
                        width: parent.width
                        height: 72
                        radius: Style.radiusM
                        color: "#888888"
                        border.color: Style.capsuleBorderColor
                        border.width: Style.capsuleBorderWidth
                    }
                    NText {
                        width: parent.width
                        text: "#888888"
                        color: Color.mOnSurface
                        font.weight: Font.Bold
                        pointSize: Style.fontSizeM
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
            Repeater {
                model: [
                    { label: pluginApi?.tr("panel.labelHex"), value: "#888888" },
                    { label: pluginApi?.tr("panel.labelRgb"), value: "—" },
                    { label: pluginApi?.tr("panel.labelHsl"), value: "—" },
                    { label: pluginApi?.tr("panel.labelHsv"), value: "—" }
                ]
                delegate: Rectangle {
                    width: root.width
                    height: 36
                    radius: Style.radiusM
                    color: Color.mSurface
                    border.color: Style.capsuleBorderColor
                    border.width: Style.capsuleBorderWidth
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Style.marginS
                        anchors.rightMargin: Style.marginS
                        spacing: Style.marginS
                        NText {
                            text: modelData.label
                            color: Color.mPrimary
                            font.weight: Font.Bold
                            pointSize: Style.fontSizeS
                            width: 36
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                        }
                        NText {
                            text: modelData.value || "—"
                            color: Color.mOnSurface
                            pointSize: Style.fontSizeS
                            width: root.width - 90
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                    NIcon {
                        icon: "copy"
                        color: Color.mOnSurfaceVariant
                        anchors.right: parent.right
                        anchors.rightMargin: Style.marginS
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
            Column {
                width: parent.width
                spacing: Style.marginS
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
                            text: pluginApi?.tr("panel.copyAll")
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
}
