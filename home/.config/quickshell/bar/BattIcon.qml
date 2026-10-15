import QtQuick

// Bateria estilo iPhone: contorno translucido, relleno segun %, numero adentro.
Item {
    id: ic
    property int pct: 100
    property bool charging: false
    property color fg: "#d4be98"
    property color hi: "#ebdbb2"
    property color accent: "#d79921"
    property string iconFont: "CaskaydiaCove Nerd Font"
    property string fontFamily: "sans-serif"
    property bool active: false
    signal clicked(var mouse)
    signal entered()
    signal exited()
    signal scrolled(var wheel)

    width: 40
    height: 34

    readonly property color level: charging ? "#30d158" : (pct <= 20 ? "#ff453a" : "#f2f2f7")
    readonly property color dark: "#1c1c1e"
    readonly property real innerW: 22

    Rectangle {
        anchors.centerIn: parent
        width: 34
        height: 32
        radius: 10
        color: ic.active ? Qt.alpha(ic.accent, 0.22) : ma.containsMouse ? Qt.alpha(ic.accent, 0.14) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Item {
        id: shape
        anchors.centerIn: parent
        width: 30
        height: 13

        // contorno
        Rectangle {
            id: body
            x: 0
            y: 0
            width: 26
            height: 13
            radius: 4
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(ic.fg, 0.5)
        }
        // puntita
        Rectangle {
            x: 27
            y: 4
            width: 2
            height: 5
            radius: 1
            color: Qt.alpha(ic.fg, 0.5)
        }
        // relleno
        Rectangle {
            id: fill
            x: 2
            y: 2
            height: 9
            radius: 2.5
            width: ic.pct > 0 ? Math.max(5, ic.innerW * Math.min(ic.pct, 100) / 100) : 0
            color: ic.level
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        // texto claro (sobre la parte vacia)
        Text {
            id: tBase
            anchors.centerIn: body
            text: ic.charging ? "\uf0e7" : ic.pct
            color: ic.hi
            font.family: ic.charging ? ic.iconFont : ic.fontFamily
            font.pixelSize: ic.charging ? 9 : 9
            font.weight: Font.Bold
        }
        // texto oscuro (solo sobre el relleno)
        Item {
            x: fill.x
            y: fill.y
            width: fill.width
            height: fill.height
            clip: true
            Text {
                x: tBase.x - fill.x
                y: tBase.y - fill.y
                text: tBase.text
                color: ic.dark
                font.family: tBase.font.family
                font.pixelSize: tBase.font.pixelSize
                font.weight: Font.Bold
            }
        }
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
