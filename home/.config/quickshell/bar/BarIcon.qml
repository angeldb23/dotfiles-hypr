import QtQuick

Item {
    id: ic
    property string glyph: ""
    property color fg: "#d4be98"
    property color hi: "#ebdbb2"
    property color accent: "#d79921"
    property string iconFont: "CaskaydiaCove Nerd Font"
    property int size: 18
    property bool active: false
    property int badge: 0
    signal clicked(var mouse)
    signal entered()
    signal exited()
    signal scrolled(var wheel)

    width: 40
    height: 34

    Rectangle {
        anchors.centerIn: parent
        width: 34
        height: 32
        radius: 10
        color: ic.active ? Qt.alpha(ic.accent, 0.22) : ma.containsMouse ? Qt.alpha(ic.accent, 0.14) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    Text {
        anchors.centerIn: parent
        text: ic.glyph
        color: (ma.containsMouse || ic.active) ? ic.hi : ic.fg
        font.family: ic.iconFont
        font.pixelSize: ic.size
    }
    Rectangle {
        visible: ic.badge > 0
        width: 8
        height: 8
        radius: 4
        color: ic.accent
        x: parent.width / 2 + 5
        y: 5
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(m) { ic.clicked(m) }
        onEntered: ic.entered()
        onExited: ic.exited()
        onWheel: function(w) { ic.scrolled(w) }
    }
}
