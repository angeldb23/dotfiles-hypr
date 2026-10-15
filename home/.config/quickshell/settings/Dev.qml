import QtQuick

Rectangle {
    id: d
    property var th
    property string label: ""
    property string sub: ""
    property bool active: false
    signal clicked()
    height: 46
    radius: 12
    color: ma.containsMouse ? Qt.alpha(th.accent, 0.16) : (active ? Qt.alpha(th.accent, 0.10) : "transparent")
    Column {
        anchors.verticalCenter: parent.verticalCenter
        x: 14
        width: parent.width - 60
        spacing: 1
        Text {
            width: parent.width
            text: d.label
            color: d.active ? d.th.accent : d.th.fgBright
            font.family: d.th.font
            font.pixelSize: 14
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: d.sub !== ""
            text: d.sub
            color: Qt.alpha(d.th.fg, 0.6)
            font.family: d.th.font
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        visible: d.active
        text: "\uf00c"
        color: d.th.accent
        font.family: d.th.iconFont
        font.pixelSize: 14
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: d.clicked() }
}
