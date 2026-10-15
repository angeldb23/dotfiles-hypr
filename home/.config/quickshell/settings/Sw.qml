import QtQuick

Rectangle {
    id: sw
    property var th
    property bool checked: false
    signal toggled()
    width: 46
    height: 26
    radius: 13
    color: checked ? th.accent : Qt.lighter(th.bg, 1.9)
    Behavior on color { ColorAnimation { duration: 120 } }
    Rectangle {
        width: 20
        height: 20
        radius: 10
        y: 3
        x: sw.checked ? sw.width - 23 : 3
        color: sw.checked ? sw.th.bg : sw.th.fg
        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }
    MouseArea { anchors.fill: parent; onClicked: sw.toggled() }
}
