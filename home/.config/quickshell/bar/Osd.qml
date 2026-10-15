import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: osd
    property color cBg: "#1d2021"
    property color cFg: "#d4be98"
    property color cFgBright: "#ebdbb2"
    property color cAccent: "#d79921"
    property string fontFamily: "SF Pro Display"
    property string iconFont: "CaskaydiaCove Nerd Font"
    property int value: 50
    property bool open: false
    property bool hovered: false
    signal setValue(real pct)

    function flash() { open = true; closeTimer.interval = 1600; closeTimer.restart() }

    IpcHandler {
        target: "osd"
        function show(): void { osd.flash() }
    }
    Timer { id: closeTimer; interval: 700; onTriggered: { if (!osd.hovered) osd.open = false } }
    Timer { id: openTimer; interval: 120; onTriggered: osd.open = true }

    PanelWindow {
        anchors { right: true }
        implicitWidth: 110
        implicitHeight: 340
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "qs-osd"
        mask: Region { item: hit }

        Item {
            id: hit
            readonly property bool shown: osd.open || card.prog > 0.001
            width: shown ? 100 : 4
            height: shown ? 330 : 160
            x: parent.width - width
            y: (parent.height - height) / 2
        }

        // zona sensible del borde (solo cuando esta cerrado)
        MouseArea {
            x: parent.width - 4
            y: (parent.height - 160) / 2
            width: 4
            height: 160
            hoverEnabled: true
            visible: !hit.shown
            onEntered: openTimer.restart()
            onExited: openTimer.stop()
        }

        PopShape {
            attach: "right"
            fillColor: Qt.alpha(osd.cBg, 0.97)
            lineColor: Qt.alpha(osd.cAccent, 0.35)
            radius: 22
            flare: 18
            x: card.x
            y: card.y - 18
            width: card.width
            height: card.height + 36
            opacity: card.opacity
        }
        Rectangle {
            id: card
            property real prog: osd.open ? 1 : 0
            Behavior on prog { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            width: 64
            height: 280
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width - width + (1 - prog) * (width + 24)
            color: "transparent"
            opacity: Math.min(1, prog * 3)
            visible: opacity > 0.01

            HoverHandler {
                onHoveredChanged: {
                    osd.hovered = hovered
                    if (hovered) closeTimer.stop()
                    else { closeTimer.interval = 700; closeTimer.restart() }
                }
            }

            Text {
                anchors { top: parent.top; topMargin: 14; horizontalCenter: parent.horizontalCenter }
                text: osd.value
                color: osd.cFgBright
                font.family: osd.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            Rectangle {
                id: trk
                x: (parent.width - width) / 2
                y: 40
                width: 28
                height: parent.height - 40 - 52
                radius: 14
                color: Qt.lighter(osd.cBg, 1.8)
                clip: true
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.height * Math.max(0, Math.min(100, osd.value)) / 100
                    radius: 14
                    color: osd.cAccent
                    Behavior on height { NumberAnimation { duration: 90 } }
                }
            }
            MouseArea {
                x: trk.x - 8
                y: trk.y
                width: trk.width + 16
                height: trk.height
                function upd(my) { osd.setValue(Math.max(1, Math.min(100, (1 - my / height) * 100))) }
                onPressed: function(m) { upd(m.y) }
                onPositionChanged: function(m) { if (pressed) upd(m.y) }
                onWheel: function(w) { osd.setValue(osd.value + (w.angleDelta.y > 0 ? 5 : -5)) }
            }
            Text {
                anchors { bottom: parent.bottom; bottomMargin: 14; horizontalCenter: parent.horizontalCenter }
                text: "\uf185"
                color: osd.cAccent
                font.family: osd.iconFont
                font.pixelSize: 20
            }
        }
    }
}
