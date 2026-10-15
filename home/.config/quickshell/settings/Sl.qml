import QtQuick

Item {
    id: s
    property var th
    property real value: 0
    signal moved(real v)
    signal released()
    implicitWidth: 240
    width: 240
    height: 24
    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 8
        radius: 4
        color: Qt.lighter(s.th.bg, 1.9)
        Rectangle {
            width: Math.max(8, parent.width * Math.max(0, Math.min(1, s.value)))
            height: parent.height
            radius: 4
            color: s.th.accent
        }
    }
    Rectangle {
        width: 18
        height: 18
        radius: 9
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(s.width - width, s.width * Math.max(0, Math.min(1, s.value)) - width / 2))
        color: s.th.fgBright
    }
    MouseArea {
        anchors.fill: parent
        function setFrom(mx) { s.moved(Math.max(0, Math.min(1, mx / width))) }
        onPressed: function(m) { setFrom(m.x) }
        onPositionChanged: function(m) { if (pressed) setFrom(m.x) }
        onReleased: s.released()
    }
}
