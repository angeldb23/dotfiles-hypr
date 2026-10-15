import QtQuick

Item {
    id: r
    property string label: ""
    property real value: 0
    property color fg: "#d4be98"
    property color fgBright: "#ebdbb2"
    property color accent: "#d79921"
    property color track: "#3c3836"
    property string fontFamily: "SF Pro Display"
    height: 22

    Text {
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        text: r.label
        color: r.fg
        font.family: r.fontFamily
        font.pixelSize: 13
    }
    Rectangle {
        x: 48
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 48 - 48
        height: 8
        radius: 4
        color: r.track
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, r.value))
            height: parent.height
            radius: 4
            color: r.accent
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
    }
    Text {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        text: Math.round(r.value * 100) + "%"
        color: r.fgBright
        font.family: r.fontFamily
        font.pixelSize: 13
    }
}
