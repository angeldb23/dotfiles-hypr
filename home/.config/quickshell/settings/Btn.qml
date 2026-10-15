import QtQuick

Rectangle {
    id: b
    property var th
    property string text: ""
    property bool active: false
    signal clicked()
    width: lbl.implicitWidth + 30
    height: 34
    radius: 11
    color: active ? th.accent : (ma.containsMouse ? Qt.alpha(th.accent, 0.28) : Qt.alpha(th.accent, 0.14))
    Text {
        id: lbl
        anchors.centerIn: parent
        text: b.text
        color: b.active ? b.th.bg : b.th.fgBright
        font.family: b.th.font
        font.pixelSize: 13
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: b.clicked() }
}
