import QtQuick
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI
Item {
    id: root
    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section:  ""
    readonly property string screenName: screen?.name ?? ""
    implicitWidth:  btn.implicitWidth
    implicitHeight: btn.implicitHeight
    NIconButtonHot {
        id: btn
        anchors.fill: parent
        icon:        "crosshair"
        tooltipText: pluginApi?.tr("widget.tooltip")
    }
}
