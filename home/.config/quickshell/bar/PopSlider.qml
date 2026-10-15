import QtQuick

Item {
    id: s
    property real value: 0
    property color track: "#3c3836"
    property color fill: "#d79921"
    signal moved(real v)
    height: 24

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 8
        radius: 4
        color: s.track
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, s.value))
            height: parent.height
            radius: 4
            color: s.fill
        }
    }
    Rectangle {
        width: 16
        height: 16
        radius: 8
        anchors.verticalCenter: parent.verticalCenter
        x: (s.width - width) * Math.max(0, Math.min(1, s.value))
        color: s.fill
    }
    MouseArea {
        anchors.fill: parent
        function upd(mx) { s.moved(Math.max(0, Math.min(1, mx / width))) }
        onPressed: function(m) { upd(m.x) }
        onPositionChanged: function(m) { if (pressed) upd(m.x) }
    }
}
