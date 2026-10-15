import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

Scope {
    id: dash
    property color cBg: "#1d2021"
    property color cFg: "#d4be98"
    property color cFgBright: "#ebdbb2"
    property color cAccent: "#d79921"
    property string fontFamily: "SF Pro Display"
    property string iconFont: "CaskaydiaCove Nerd Font"

    property bool open: false
    property bool hovered: false
    property real cpu: 0
    property real mem: 0
    property real disk: 0
    property real prevIdle: -1
    property real prevTotal: -1

    readonly property var player: {
        const v = Mpris.players.values
        for (let i = 0; i < v.length; i++) if (v[i].isPlaying) return v[i]
        return v.length > 0 ? v[0] : null
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    function buildCal(d) {
        const first = new Date(d.getFullYear(), d.getMonth(), 1)
        const off = (first.getDay() + 6) % 7
        const days = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate()
        const cells = []
        for (let i = 0; i < off; i++) cells.push("")
        for (let k = 1; k <= days; k++) cells.push(k)
        return cells
    }
    property var calCells: buildCal(clock.date)

    function openKey() { open = true; closeTimer.interval = 4000; closeTimer.restart() }
    function toggleKey() { if (open) open = false; else openKey() }

    IpcHandler {
        target: "dashboard"
        function toggle(): void { dash.toggleKey() }
        function open(): void { dash.openKey() }
        function close(): void { dash.open = false }
    }
    Timer { id: closeTimer; interval: 450; onTriggered: { if (!dash.hovered) dash.open = false } }
    Timer { id: openTimer; interval: 160; onTriggered: dash.open = true }

    // recursos (solo mientras esta abierto)
    Process {
        id: resProc
        command: ["sh", "-c", "head -1 /proc/stat; awk '/MemTotal|MemAvailable/{print $2}' /proc/meminfo; df -P / | awk 'NR==2{print $5}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.trim().split("\n")
                if (l.length < 4) return
                const c = l[0].trim().split(/\s+/).slice(1).map(Number)
                const idle = c[3] + (c[4] || 0)
                const total = c.reduce(function(a, b) { return a + b }, 0)
                if (dash.prevTotal > 0) {
                    const dt = total - dash.prevTotal
                    const di = idle - dash.prevIdle
                    dash.cpu = dt > 0 ? Math.max(0, Math.min(1, 1 - di / dt)) : 0
                }
                dash.prevIdle = idle
                dash.prevTotal = total
                const mt = parseFloat(l[1])
                const ma = parseFloat(l[2])
                dash.mem = mt > 0 ? 1 - ma / mt : 0
                dash.disk = (parseInt(l[3]) || 0) / 100
            }
        }
    }
    Timer {
        interval: 2000
        running: dash.open
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!resProc.running) resProc.running = true }
    }
    Timer {
        interval: 1000
        running: dash.open && dash.player !== null && dash.player.isPlaying
        repeat: true
        onTriggered: dash.player.positionChanged()
    }

    PanelWindow {
        id: win
        anchors { top: true }
        implicitWidth: 700
        implicitHeight: 420
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "qs-dashboard"
        mask: Region { item: hit }

        Item {
            id: hit
            readonly property bool shown: dash.open || card.prog > 0.001
            width: shown ? card.width + 36 : 420
            height: shown ? Math.max(3, card.y + card.height) : 3
            x: (parent.width - width) / 2
        }
        // zona sensible del borde superior (solo cuando esta cerrado)
        MouseArea {
            x: (parent.width - 420) / 2
            y: 0
            width: 420
            height: 3
            hoverEnabled: true
            visible: !hit.shown
            onEntered: openTimer.restart()
            onExited: openTimer.stop()
        }

        PopShape {
            attach: "top"
            fillColor: Qt.alpha(dash.cBg, 0.97)
            lineColor: Qt.alpha(dash.cAccent, 0.35)
            radius: 22
            flare: 18
            x: card.x - 18
            y: card.y
            width: card.width + 36
            height: card.height
            opacity: card.opacity
        }
        Rectangle {
            id: card
            property real prog: dash.open ? 1 : 0
            Behavior on prog { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            width: 640
            height: content.implicitHeight + 40
            x: (parent.width - width) / 2
            y: -height * (1 - prog)
            color: "transparent"
            opacity: Math.min(1, prog * 3)
            visible: opacity > 0.01

            HoverHandler {
                onHoveredChanged: {
                    dash.hovered = hovered
                    if (hovered) closeTimer.stop()
                    else { closeTimer.interval = 450; closeTimer.restart() }
                }
            }

            Row {
                id: content
                x: 20
                y: 20
                spacing: 20

                // ---- izquierda: reloj y calendario ----
                Column {
                    width: 260
                    spacing: 8
                    Text {
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: dash.cFgBright
                        font.family: dash.fontFamily
                        font.pixelSize: 46
                        font.weight: Font.Bold
                    }
                    Text {
                        text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                        color: dash.cAccent
                        font.family: dash.fontFamily
                        font.pixelSize: 15
                    }
                    Rectangle { width: parent.width; height: 1; color: Qt.alpha(dash.cFg, 0.15) }
                    Text {
                        text: Qt.formatDateTime(clock.date, "MMMM yyyy")
                        color: Qt.alpha(dash.cFg, 0.75)
                        font.family: dash.fontFamily
                        font.pixelSize: 13
                    }
                    Row {
                        Repeater {
                            model: ["M", "T", "W", "T", "F", "S", "S"]
                            Text {
                                width: 36
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                color: Qt.alpha(dash.cFg, 0.55)
                                font.family: dash.fontFamily
                                font.pixelSize: 12
                            }
                        }
                    }
                    Grid {
                        columns: 7
                        Repeater {
                            model: dash.calCells
                            Item {
                                width: 36
                                height: 28
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 28
                                    height: 25
                                    radius: 9
                                    color: modelData === clock.date.getDate() ? dash.cAccent : "transparent"
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: modelData === clock.date.getDate() ? dash.cBg : dash.cFg
                                    font.family: dash.fontFamily
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }
                }

                // ---- derecha: musica y recursos ----
                Column {
                    width: 320
                    spacing: 14

                    Rectangle {
                        width: parent.width
                        height: 124
                        radius: 16
                        color: Qt.lighter(dash.cBg, 1.35)

                        Rectangle {
                            x: 12
                            y: 14
                            width: 96
                            height: 96
                            radius: 12
                            color: Qt.alpha(dash.cAccent, 0.2)
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: dash.player ? dash.player.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }
                        Column {
                            x: 120
                            y: 14
                            width: parent.width - 132
                            spacing: 3
                            Text {
                                width: parent.width
                                text: dash.player ? (dash.player.trackTitle || "Unknown track") : "Nothing playing"
                                color: dash.cFgBright
                                font.family: dash.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: dash.player ? (dash.player.trackArtist || "") : ""
                                color: Qt.alpha(dash.cFg, 0.75)
                                font.family: dash.fontFamily
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                        Row {
                            x: 114
                            y: 60
                            BarIcon {
                                glyph: "\uf048"
                                size: 15
                                fg: dash.cFg
                                hi: dash.cFgBright
                                accent: dash.cAccent
                                iconFont: dash.iconFont
                                onClicked: function(m) { if (dash.player) dash.player.previous() }
                            }
                            BarIcon {
                                glyph: (dash.player && dash.player.isPlaying) ? "\uf04c" : "\uf04b"
                                size: 17
                                fg: dash.cAccent
                                hi: dash.cFgBright
                                accent: dash.cAccent
                                iconFont: dash.iconFont
                                onClicked: function(m) { if (dash.player) dash.player.togglePlaying() }
                            }
                            BarIcon {
                                glyph: "\uf051"
                                size: 15
                                fg: dash.cFg
                                hi: dash.cFgBright
                                accent: dash.cAccent
                                iconFont: dash.iconFont
                                onClicked: function(m) { if (dash.player) dash.player.next() }
                            }
                        }
                        Rectangle {
                            x: 120
                            y: 106
                            width: parent.width - 132
                            height: 4
                            radius: 2
                            color: Qt.lighter(dash.cBg, 1.9)
                            Rectangle {
                                height: parent.height
                                radius: 2
                                color: dash.cAccent
                                width: parent.width * ((dash.player && dash.player.length > 0)
                                       ? Math.max(0, Math.min(1, dash.player.position / dash.player.length)) : 0)
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 3 * 22 + 2 * 10 + 28
                        radius: 16
                        color: Qt.lighter(dash.cBg, 1.35)
                        Column {
                            x: 14
                            y: 14
                            width: parent.width - 28
                            spacing: 10
                            ResBar { width: parent.width; label: "CPU"; value: dash.cpu; fg: dash.cFg; fgBright: dash.cFgBright; accent: dash.cAccent; track: Qt.lighter(dash.cBg, 1.9); fontFamily: dash.fontFamily }
                            ResBar { width: parent.width; label: "RAM"; value: dash.mem; fg: dash.cFg; fgBright: dash.cFgBright; accent: dash.cAccent; track: Qt.lighter(dash.cBg, 1.9); fontFamily: dash.fontFamily }
                            ResBar { width: parent.width; label: "Disk"; value: dash.disk; fg: dash.cFg; fgBright: dash.cFgBright; accent: dash.cAccent; track: Qt.lighter(dash.cBg, 1.9); fontFamily: dash.fontFamily }
                        }
                    }
                }
            }
        }
    }
}
