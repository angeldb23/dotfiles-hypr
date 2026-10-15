//@ pragma IconTheme Adwaita
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

ShellRoot {
    id: root

    property int barW: 56
    property int popW: 310
    property string fontFamily: "SF Pro Display"
    property string iconFont: "CaskaydiaCove Nerd Font"
    property string home: Quickshell.env("HOME")

    property color cBg: "#1d2021"
    property color cFg: "#d4be98"
    property color cFgBright: "#ebdbb2"
    property color cAccent: "#d79921"

    // ---- popouts ----
    property string pop: ""
    property string lastPop: ""
    property real popY: 0
    onPopChanged: { if (pop !== "") lastPop = pop }
    function popAt(name, item) {
        closeTimer.stop()
        popY = item.mapToItem(strip, 0, item.height / 2).y
        pop = name
    }
    function schedClose() { closeTimer.restart() }
    function openWifi(item) {
        pop = ""
        const y = strip.height - item.mapToItem(strip, 0, item.height / 2).y
        Quickshell.execDetached(["sh", "-c", "echo " + Math.round(y) + " > ~/.cache/bar-wifi-y.txt; exec " + home + "/scripts/wifi-menu.sh"])
    }
    Timer { id: closeTimer; interval: 220; onTriggered: root.pop = "" }

    function run(p) { if (!p.running) p.running = true }

    // ---- colores del tema ----
    FileView {
        id: themesFile
        path: Quickshell.env("HOME") + "/.config/themes/themes.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyTheme()
    }
    FileView {
        id: themeNameFile
        path: Quickshell.env("HOME") + "/.cache/theme.txt"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyTheme()
    }
    function applyTheme() {
        try {
            const all = JSON.parse(themesFile.text())
            const name = themeNameFile.text().trim()
            const p = all[name] || all["Gruvbox"]
            if (!p) return
            if (p.bg) cBg = p.bg
            if (p.fg) cFg = p.fg
            if (p.fg_bright) cFgBright = p.fg_bright
            if (p.accent) cAccent = p.accent
        } catch (e) {}
    }

    // ---- workspaces ----
    readonly property int focusedWs: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    property int wsCount: {
        let m = 4
        const v = Hyprland.workspaces.values
        for (let i = 0; i < v.length; i++) if (v[i].id > m && v[i].id <= 10) m = v[i].id
        return m
    }
    function gotoWs(n) {
        Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({ workspace = "' + n + '" })'])
    }

    // ---- audio ----
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }
    readonly property real vol: (sink && sink.audio) ? sink.audio.volume : 0
    readonly property bool muted: (sink && sink.audio) ? sink.audio.muted : false
    function setVol(v) {
        if (sink && sink.audio) {
            sink.audio.muted = false
            sink.audio.volume = Math.max(0, Math.min(1, v))
        }
    }
    function toggleMute() { if (sink && sink.audio) sink.audio.muted = !sink.audio.muted }

    // ---- brillo ----
    property int bright: -1
    property int brTarget: 50
    Process {
        id: brRead
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split(",")
                if (p.length >= 4) root.bright = parseInt(p[3])
            }
        }
    }
    Process { id: brSet }
    Timer {
        id: brTimer
        interval: 90
        onTriggered: {
            if (brSet.running) { brTimer.restart(); return }
            brSet.command = ["brightnessctl", "set", root.brTarget + "%"]
            brSet.running = true
        }
    }
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!brSet.running && !brTimer.running) root.run(brRead) }
    }
    function setBright(pct) {
        pct = Math.round(Math.max(1, Math.min(100, pct)))
        bright = pct
        brTarget = pct
        brTimer.restart()
        osdItem.flash()
    }

    // ---- bateria ----
    readonly property var batt: UPower.displayDevice
    readonly property bool hasBatt: batt ? batt.isLaptopBattery : false
    readonly property int battPct: batt ? Math.round(batt.percentage * 100) : 0
    readonly property bool charging: batt ? batt.state === UPowerDeviceState.Charging : false
    function battGlyph() {
        if (charging) return "\uf0e7"
        const p = battPct
        return p > 85 ? "\uf240" : p > 60 ? "\uf241" : p > 35 ? "\uf242" : p > 12 ? "\uf243" : "\uf244"
    }
    function fmtTime(sec) {
        if (!sec || sec <= 0) return ""
        const h = Math.floor(sec / 3600)
        const m = Math.round((sec % 3600) / 60)
        return h + "h " + (m < 10 ? "0" : "") + m + "m"
    }

    // ---- red ----
    property string ssid: ""
    property int netSig: 0
    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID,SIGNAL device wifi 2>/dev/null | grep '^yes' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim()
                if (t === "") { root.ssid = ""; root.netSig = 0; return }
                const f = t.split(":")
                root.netSig = parseInt(f[f.length - 1]) || 0
                root.ssid = f.slice(1, f.length - 1).join(":").replace(/\\/g, "")
            }
        }
    }
    Timer { interval: 8000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.run(netProc) }

    // ---- notificaciones (swaync) ----
    property int notifCount: 0
    property bool dnd: false
    Process {
        running: true
        command: ["sh", "-c", "tail -n 1 -F \"$HOME/.cache/notif-state.log\" 2>/dev/null"]
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    const j = JSON.parse(line)
                    root.notifCount = parseInt(j.text) || 0
                    root.dnd = (j.alt || "").indexOf("dnd") === 0
                } catch (e) {}
            }
        }
    }

    // ---- reloj y calendario ----
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

    function popHeight() {
        switch (lastPop) {
        case "audio": return audioCol.implicitHeight
        case "bright": return brightCol.implicitHeight
        case "net": return netCol.implicitHeight
        case "batt": return battCol.implicitHeight
        case "clock": return clockCol.implicitHeight
        }
        return 0
    }

    Dashboard {
        cBg: root.cBg; cFg: root.cFg; cFgBright: root.cFgBright; cAccent: root.cAccent
        fontFamily: root.fontFamily; iconFont: root.iconFont
    }
    Osd {
        id: osdItem
        cBg: root.cBg; cFg: root.cFg; cFgBright: root.cFgBright; cAccent: root.cAccent
        fontFamily: root.fontFamily; iconFont: root.iconFont
        value: root.bright >= 0 ? root.bright : 0
        onSetValue: function(v) { root.setBright(v) }
    }

    // ================= ventana =================
    PanelWindow {
        id: bar
        anchors { top: true; bottom: true; left: true }
        implicitWidth: root.barW + root.popW
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: root.barW
        color: "transparent"
        WlrLayershell.namespace: "qs-bar"
        mask: Region { item: strip; Region { item: popBox } }

        Rectangle {
            id: strip
            x: 0
            y: 0
            width: root.barW
            height: parent.height
            color: Qt.alpha(root.cBg, 0.97)

            Rectangle {
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: Qt.alpha(root.cAccent, 0.25)
            }

            ColumnLayout {
                anchors { fill: parent; topMargin: 10; bottomMargin: 10; rightMargin: 1 }
                spacing: 8

                // lanzador
                BarIcon {
                    Layout.alignment: Qt.AlignHCenter
                    glyph: "\uf303"
                    size: 22
                    fg: root.cAccent
                    hi: root.cFgBright
                    accent: root.cAccent
                    iconFont: root.iconFont
                    onClicked: function(m) {
                        Quickshell.execDetached([root.home + "/scripts/launcher-toggle.sh"])
                    }
                }

                // workspaces
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 34
                    implicitHeight: root.wsCount * 30 + 4

                    Rectangle { anchors.fill: parent; radius: 17; color: Qt.lighter(root.cBg, 1.5) }
                    Rectangle {
                        visible: root.focusedWs >= 1
                        x: 2
                        width: 30
                        height: 28
                        radius: 14
                        color: root.cAccent
                        y: 2 + (Math.min(Math.max(root.focusedWs, 1), root.wsCount) - 1) * 30
                        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }
                    Repeater {
                        model: root.wsCount
                        Item {
                            x: 0
                            y: index * 30 + 2
                            width: 34
                            height: 30
                            Text {
                                anchors.centerIn: parent
                                text: index + 1
                                color: (index + 1) === root.focusedWs ? root.cBg : root.cFg
                                font.family: root.fontFamily
                                font.pixelSize: 13
                                font.weight: (index + 1) === root.focusedWs ? Font.Bold : Font.Medium
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.gotoWs(index + 1) }
                        }
                    }
                }

                // ventana activa (texto vertical)
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    Text {
                        anchors.centerIn: parent
                        width: Math.max(0, parent.height - 8)
                        rotation: 90
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
                        color: Qt.alpha(root.cFg, 0.8)
                        font.family: root.fontFamily
                        font.pixelSize: 12
                    }
                }

                // tray
                Column {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    Repeater {
                        model: SystemTray.items
                        delegate: Item {
                            id: ti
                            required property var modelData
                            width: 28
                            height: 28
                            Image {
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                source: ti.modelData.icon
                                sourceSize: Qt.size(40, 40)
                                smooth: true
                            }
                            QsMenuAnchor {
                                id: menuAnchor
                                menu: ti.modelData.menu
                                anchor.item: ti
                                anchor.edges: Edges.Right
                                anchor.gravity: Edges.Right
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                onClicked: function(m) {
                                    if (m.button === Qt.LeftButton && !ti.modelData.onlyMenu) ti.modelData.activate()
                                    else if (m.button === Qt.MiddleButton) ti.modelData.secondaryActivate()
                                    else if (ti.modelData.hasMenu) menuAnchor.open()
                                }
                            }
                        }
                    }
                }

                // reloj
                Item {
                    id: clockBox
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 40
                    implicitHeight: 50
                    Column {
                        anchors.centerIn: parent
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(clock.date, "HH")
                            color: root.cFgBright
                            font.family: root.fontFamily
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(clock.date, "mm")
                            color: Qt.alpha(root.cFg, 0.8)
                            font.family: root.fontFamily
                            font.pixelSize: 15
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.popAt("clock", clockBox)
                        onExited: root.schedClose()
                    }
                }

                // volumen
                BarIcon {
                    id: icAudio
                    Layout.alignment: Qt.AlignHCenter
                    glyph: root.muted ? "\uf026" : (root.vol > 0.5 ? "\uf028" : "\uf027")
                    fg: root.muted ? Qt.alpha(root.cFg, 0.5) : root.cFg
                    hi: root.cFgBright
                    accent: root.cAccent
                    iconFont: root.iconFont
                    onEntered: root.popAt("audio", icAudio)
                    onExited: root.schedClose()
                    onClicked: function(m) {
                        if (m.button === Qt.RightButton) Quickshell.execDetached(["pavucontrol"])
                        else root.toggleMute()
                    }
                    onScrolled: function(w) { root.setVol(root.vol + (w.angleDelta.y > 0 ? 0.05 : -0.05)) }
                }

                // brillo
                BarIcon {
                    id: icBright
                    visible: root.bright >= 0
                    Layout.alignment: Qt.AlignHCenter
                    glyph: "\uf185"
                    fg: root.cFg
                    hi: root.cFgBright
                    accent: root.cAccent
                    iconFont: root.iconFont
                    onEntered: root.popAt("bright", icBright)
                    onExited: root.schedClose()
                    onScrolled: function(w) { root.setBright(root.bright + (w.angleDelta.y > 0 ? 5 : -5)) }
                }

                // wifi
                BarIcon {
                    id: icNet
                    Layout.alignment: Qt.AlignHCenter
                    glyph: "\uf1eb"
                    fg: root.ssid === "" ? Qt.alpha(root.cFg, 0.45) : root.cFg
                    hi: root.cFgBright
                    accent: root.cAccent
                    iconFont: root.iconFont
                    onEntered: root.popAt("net", icNet)
                    onExited: root.schedClose()
                    onClicked: function(m) {
                        root.openWifi(icNet)
                    }
                }

                // bateria
                BattIcon {
                    id: icBatt
                    visible: root.hasBatt
                    Layout.alignment: Qt.AlignHCenter
                    pct: root.battPct
                    charging: root.charging
                    fg: root.cFg
                    hi: root.cFgBright
                    accent: root.cAccent
                    iconFont: root.iconFont
                    fontFamily: root.fontFamily
                    onEntered: root.popAt("batt", icBatt)
                    onExited: root.schedClose()
                }

                // notificaciones
                BarIcon {
                    Layout.alignment: Qt.AlignHCenter
                    glyph: root.dnd ? "\uf1f6" : "\uf0f3"
                    badge: root.notifCount
                    fg: root.cFg
                    hi: root.cFgBright
                    accent: root.cAccent
                    iconFont: root.iconFont
                    onClicked: function(m) {
                        if (m.button === Qt.RightButton) Quickshell.execDetached(["qs", "-c", "notifs", "ipc", "call", "notifs", "dnd"])
                        else Quickshell.execDetached(["qs", "-c", "notifs", "ipc", "call", "notifs", "toggle"])
                    }
                }

                // ajustes
                BarIcon {
                    Layout.alignment: Qt.AlignHCenter
                    glyph: "\uf013"
                    fg: root.cFg
                    hi: root.cFgBright
                    accent: root.cAccent
                    iconFont: root.iconFont
                    onClicked: function(m) { Quickshell.execDetached([root.home + "/scripts/settings-toggle.sh"]) }
                }

                // apagado
                BarIcon {
                    Layout.alignment: Qt.AlignHCenter
                    glyph: "\uf011"
                    fg: "#fb4934"
                    hi: "#fb4934"
                    accent: "#fb4934"
                    iconFont: root.iconFont
                    onClicked: function(m) { Quickshell.execDetached(["qs", "-c", "notifs", "ipc", "call", "power", "toggle"]) }
                }
            }
        }

        // ---------- popout ----------
        Item {
            id: popBox
            property real prog: root.pop !== "" ? 1 : 0
            Behavior on prog { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            x: root.barW - 1
            width: (root.pop !== "" || prog > 0.001) ? root.popW : 0
            height: card.height + 36
            clip: true
            y: Math.max(8, Math.min(parent.height - height - 8, root.popY - height / 2))

            HoverHandler {
                onHoveredChanged: { if (hovered) closeTimer.stop(); else root.schedClose() }
            }

            PopShape {
                attach: "left"
                fillColor: Qt.alpha(root.cBg, 0.97)
                lineColor: Qt.alpha(root.cAccent, 0.35)
                radius: 18
                flare: 18
                x: card.x - 1
                y: 0
                width: card.width + 1
                height: card.height + 36
                opacity: card.opacity
            }
            Rectangle {
                id: card
                x: 1 - (1 - popBox.prog) * 40
                y: 18
                width: root.popW - 20
                height: root.popHeight() + 32
                Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                opacity: Math.min(1, popBox.prog * 2.5)
                color: "transparent"
                clip: true

                // --- volumen ---
                Column {
                    id: audioCol
                    visible: root.lastPop === "audio"
                    x: 16
                    y: 16
                    width: card.width - 32
                    spacing: 12
                    Item {
                        width: parent.width
                        height: 22
                        Text { text: "Volume"; color: root.cFgBright; font.family: root.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold }
                        Text { anchors.right: parent.right; text: root.muted ? "Muted" : Math.round(root.vol * 100) + "%"; color: Qt.alpha(root.cFg, 0.85); font.family: root.fontFamily; font.pixelSize: 14 }
                    }
                    PopSlider {
                        width: parent.width
                        value: root.vol
                        track: Qt.lighter(root.cBg, 1.8)
                        fill: root.cAccent
                        onMoved: function(v) { root.setVol(v) }
                    }
                    Text {
                        width: parent.width
                        text: root.sink ? (root.sink.description || root.sink.name) : "No output device"
                        color: Qt.alpha(root.cFg, 0.65)
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        width: parent.width
                        height: 34
                        radius: 10
                        color: muteMa.containsMouse ? Qt.alpha(root.cAccent, 0.25) : Qt.alpha(root.cAccent, 0.14)
                        Text { anchors.centerIn: parent; text: root.muted ? "Unmute" : "Mute"; color: root.cFgBright; font.family: root.fontFamily; font.pixelSize: 13 }
                        MouseArea { id: muteMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.toggleMute() }
                    }
                }

                // --- brillo ---
                Column {
                    id: brightCol
                    visible: root.lastPop === "bright"
                    x: 16
                    y: 16
                    width: card.width - 32
                    spacing: 12
                    Item {
                        width: parent.width
                        height: 22
                        Text { text: "Brightness"; color: root.cFgBright; font.family: root.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold }
                        Text { anchors.right: parent.right; text: root.bright + "%"; color: Qt.alpha(root.cFg, 0.85); font.family: root.fontFamily; font.pixelSize: 14 }
                    }
                    PopSlider {
                        width: parent.width
                        value: root.bright / 100
                        track: Qt.lighter(root.cBg, 1.8)
                        fill: root.cAccent
                        onMoved: function(v) { root.setBright(v * 100) }
                    }
                }

                // --- red ---
                Column {
                    id: netCol
                    visible: root.lastPop === "net"
                    x: 16
                    y: 16
                    width: card.width - 32
                    spacing: 10
                    Text { text: "Wi-Fi"; color: root.cFgBright; font.family: root.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold }
                    Text {
                        width: parent.width
                        text: root.ssid !== "" ? root.ssid : "Not connected"
                        color: root.ssid !== "" ? root.cAccent : Qt.alpha(root.cFg, 0.7)
                        font.family: root.fontFamily
                        font.pixelSize: 15
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: root.ssid !== ""
                        text: "Signal " + root.netSig + "%"
                        color: Qt.alpha(root.cFg, 0.7)
                        font.family: root.fontFamily
                        font.pixelSize: 12
                    }
                    Rectangle {
                        width: parent.width
                        height: 34
                        radius: 10
                        color: netMa.containsMouse ? Qt.alpha(root.cAccent, 0.25) : Qt.alpha(root.cAccent, 0.14)
                        Text { anchors.centerIn: parent; text: "Open Wi-Fi panel"; color: root.cFgBright; font.family: root.fontFamily; font.pixelSize: 13 }
                        MouseArea {
                            id: netMa
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.openWifi(icNet)
                        }
                    }
                }

                // --- bateria ---
                Column {
                    id: battCol
                    visible: root.lastPop === "batt"
                    x: 16
                    y: 16
                    width: card.width - 32
                    spacing: 6
                    Text { text: root.battPct + "%"; color: root.cFgBright; font.family: root.fontFamily; font.pixelSize: 30; font.weight: Font.DemiBold }
                    Text {
                        text: root.charging ? "Charging" : (root.batt && root.batt.state === UPowerDeviceState.FullyCharged ? "Fully charged" : "On battery")
                        color: root.cAccent
                        font.family: root.fontFamily
                        font.pixelSize: 14
                    }
                    Text {
                        visible: text !== ""
                        text: {
                            if (!root.batt) return ""
                            const t = root.charging ? root.fmtTime(root.batt.timeToFull) : root.fmtTime(root.batt.timeToEmpty)
                            return t === "" ? "" : (root.charging ? t + " until full" : t + " remaining")
                        }
                        color: Qt.alpha(root.cFg, 0.75)
                        font.family: root.fontFamily
                        font.pixelSize: 12
                    }
                }

                // --- calendario ---
                Column {
                    id: clockCol
                    visible: root.lastPop === "clock"
                    x: 16
                    y: 16
                    width: card.width - 32
                    spacing: 8
                    Text {
                        text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                        color: root.cFgBright
                        font.family: root.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: Qt.formatDateTime(clock.date, "MMMM yyyy")
                        color: Qt.alpha(root.cFg, 0.7)
                        font.family: root.fontFamily
                        font.pixelSize: 12
                    }
                    Row {
                        Repeater {
                            model: ["M", "T", "W", "T", "F", "S", "S"]
                            Text {
                                width: 36
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                color: Qt.alpha(root.cFg, 0.55)
                                font.family: root.fontFamily
                                font.pixelSize: 12
                            }
                        }
                    }
                    Grid {
                        columns: 7
                        Repeater {
                            model: root.calCells
                            Item {
                                width: 36
                                height: 30
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 28
                                    height: 26
                                    radius: 9
                                    color: modelData === clock.date.getDate() ? root.cAccent : "transparent"
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: modelData === clock.date.getDate() ? root.cBg : root.cFg
                                    font.family: root.fontFamily
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
