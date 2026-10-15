import QtQuick

Item {
    id: r
    property var th
    property string label: ""
    property string desc: ""
    property int contentWidth: 0
    default property alias content: slot.data
    width: parent ? parent.width : 400
    height: Math.max(48, txt.implicitHeight + 16)
    Column {
        id: txt
        anchors.left: parent.left
        anchors.right: slot.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
            width: parent.width
            text: r.label
            color: r.th.fgBright
            font.family: r.th.font
            font.pixelSize: 14
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: r.desc !== ""
            text: r.desc
            color: Qt.alpha(r.th.fg, 0.6)
            font.family: r.th.font
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }
    Item {
        id: slot
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: r.contentWidth > 0 ? r.contentWidth : childrenRect.width
        height: childrenRect.height
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Qt.alpha(r.th.fg, 0.08)
    }
}
