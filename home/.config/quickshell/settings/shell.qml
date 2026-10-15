import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// App de ajustes estilo Caelestia. Solo para el modo barra Quickshell.
// Se abre con ~/scripts/settings-toggle.sh (Super + I o el engranaje de la barra).
ShellRoot {
    id: root

    property string fontFamily: "SF Pro Display"
    property string iconFont: "CaskaydiaCove Nerd Font"
    readonly property string home: Quickshell.env("HOME")
    readonly property string tool: home + "/scripts/qs-settings.py"

    property int page: 0
    readonly property var pages: [
        { name: "Network", glyph: "\uf1eb" },
        { name: "Bluetooth", glyph: "\uf293" },
        { name: "Audio", glyph: "\uf028" },
        { name: "Display", glyph: "\uf108" },
        { name: "Appearance", glyph: "\uf1fc" },
        { name: "Wallpaper", glyph: "\uf03e" },
        { name: "Notifications", glyph: "\uf0f3" },
        { name: "Power", glyph: "\uf0e7" },
        { name: "Keybinds", glyph: "\uf11c" },
        { name: "System", glyph: "\uf05a" }
    ]

    property var themeData: ({})
    property var themeNames: []
    property string curTheme: ""
    property string themeMsg: ""
    property var hy: ({ gaps_in: 5, gaps_out: 10, border_size: 2, rounding: 10, blur: true })
    property int bright: 50
    property var mons: []
    property var wifi: ({ available: true, enabled: true, ssid: "", signal: 0 })
    property var bt: ({ available: true, powered: false, devices: [] })
    property var notif: ({ count: 0, dnd: false })
    property bool dndNow: false
    property double dndHold: 0
    property var pw: ({ capacity: "", status: "", profile: "", profiles: [] })
    property var sys: ({})
    property var sinkList: []
    property var sourceList: []
    property var streamList: []
    property var walls: ({ current: "", items: [] })
    property var binds: []
    property var bindsShown: []
    property string bindQ: ""
    onBindsChanged: filterBinds()
    onBindQChanged: filterBinds()
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    QtObject {
        id: theme
        property color bg: "#1d2021"
        property color fg: "#d4be98"
        property color fgBright: "#ebdbb2"
        property color accent: "#d79921"
        property string font: root.fontFamily
        property string iconFont: root.iconFont
    }

    // ---- tema ----
    FileView {
        id: themesFile
        path: root.home + "/.config/themes/themes.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyTheme()
    }
    FileView {
        id: themeNameFile
        path: root.home + "/.cache/theme.txt"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyTheme()
    }
    function applyTheme() {
        try {
            const all = JSON.parse(themesFile.text())
            const name = themeNameFile.text().trim()
            curTheme = name
            if (pendingTheme !== "" && name === pendingTheme) { themeMsg = ""; pendingTheme = ""; themeMsgTimer.stop() }
            themeData = all
            themeNames = Object.keys(all)
            const p = all[name] || all["Gruvbox"]
            if (!p) return
            if (p.bg) theme.bg = p.bg
            if (p.fg) theme.fg = p.fg
            if (p.fg_bright) theme.fgBright = p.fg_bright
            if (p.accent) theme.accent = p.accent
        } catch (e) {}
    }
    property string pendingTheme: ""
    Timer { id: themeMsgTimer; interval: 8000; onTriggered: { root.themeMsg = ""; root.pendingTheme = "" } }
    function applyThemeName(n) {
        themeMsg = "Applying " + n + "..."
        pendingTheme = n
        themeMsgTimer.restart()
        Quickshell.execDetached(["sh", "-c",
            "exec python3 \"$HOME/scripts/theme-set.py\" \"$1\" >/dev/null 2>&1 </dev/null", "x", n])
    }

    // ---- utilidades ----
    function run(cmd) { Quickshell.execDetached(cmd) }
    function filterBinds() {
        const q = bindQ.trim().toLowerCase()
        if (q === "") { bindsShown = binds; return }
        bindsShown = binds.filter(function(b) { return (b.keys + " " + b.act + " " + b.desc + " " + b.what).toLowerCase().indexOf(q) >= 0 })
    }
    function setWall(p) {
        run(["bash", home + "/scripts/set-wallpaper.sh", p])
        const o = {}
        for (const x in walls) o[x] = walls[x]
        o.current = p
        walls = o
    }
    function tool_(args) { Quickshell.execDetached(["python3", tool].concat(args)) }
    function parse(t, fb) { try { return JSON.parse(t) } catch (e) { return fb } }
    function poke(p) { if (!p.running) p.running = true }
    function setHy(k, v) {
        const o = {}
        for (const x in hy) o[x] = hy[x]
        o[k] = v
        hy = o
    }
    function saveHy(k) { tool_(["set", k, String(hy[k])]) }

    // ---- consultas al backend ----
    Process { id: pHypr; command: ["python3", root.tool, "hypr-get"]
        stdout: StdioCollector { onStreamFinished: { const j = root.parse(this.text, {}); const o = {}; for (const x in root.hy) o[x] = root.hy[x]; for (const x in j) o[x] = j[x]; root.hy = o } } }
    Process { id: pMon; command: ["python3", root.tool, "monitors"]
        stdout: StdioCollector { onStreamFinished: root.mons = root.parse(this.text, []) } }
    Process { id: pWifi; command: ["python3", root.tool, "wifi"]
        stdout: StdioCollector { onStreamFinished: root.wifi = root.parse(this.text, root.wifi) } }
    Process { id: pBt; command: ["python3", root.tool, "bt"]
        stdout: StdioCollector { onStreamFinished: root.bt = root.parse(this.text, root.bt) } }
    Process { id: pNotif; command: ["python3", root.tool, "notif"]
        stdout: StdioCollector { onStreamFinished: root.notif = root.parse(this.text, root.notif) } }
    Process { id: pPow; command: ["python3", root.tool, "power"]
        stdout: StdioCollector { onStreamFinished: root.pw = root.parse(this.text, root.pw) } }
    Process { id: pInfo; command: ["python3", root.tool, "info"]
        stdout: StdioCollector { onStreamFinished: root.sys = root.parse(this.text, root.sys) } }
    Process { id: pBinds; command: ["python3", root.tool, "binds"]
        stdout: StdioCollector { onStreamFinished: root.binds = root.parse(this.text, []) } }
    Process { id: pWall; command: ["python3", root.tool, "wallpapers"]
        stdout: StdioCollector { onStreamFinished: root.walls = root.parse(this.text, root.walls) } }
    Process { id: pBr; command: ["brightnessctl", "-m"]
        stdout: StdioCollector { onStreamFinished: { const p = this.text.trim().split(","); if (p.length >= 4) root.bright = parseInt(p[3]) } } }
    Process { id: brSet }
    Timer {
        id: brTimer
        interval: 90
        onTriggered: {
            if (brSet.running) { brTimer.restart(); return }
            brSet.command = ["brightnessctl", "set", root.bright + "%"]
            brSet.running = true
        }
    }

    function refresh() {
        switch (page) {
        case 0: poke(pHypr); break
        case 1: rebuildAudio(); break
        case 2: poke(pBr); poke(pMon); break
        case 3: poke(pWifi); break
        case 4: poke(pBt); break
        case 5: poke(pNotif); break
        case 6: poke(pPow); break
        case 7: poke(pInfo); break
        case 8: poke(pWall); break
        case 9: poke(pBinds); break
        }
    }
    onPageChanged: refresh()
    Timer { id: soon; interval: 1400; onTriggered: root.refresh() }
    Timer {
        interval: 2500
        running: true
        repeat: true
        onTriggered: { if ([2, 0, 1, 6, 7].indexOf(root.page) >= 0 || (root.page === 5 && root.walls.pending > 0)) root.refresh() }
    }
    Component.onCompleted: { refresh(); rebuildAudio() }

    // ---- estado real de No molestar (daemon notifs) ----
    Process {
        id: dndProbe
        command: ["qs", "-c", "notifs", "ipc", "call", "notifs", "dndstate"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (Date.now() < root.dndHold) return
                root.dndNow = (this.text.trim() === "true")
            }
        }
    }
    Timer {
        id: dndPoll
        interval: 700
        repeat: true
        running: root.page === 6
        triggeredOnStart: true
        onTriggered: dndProbe.running = true
    }

    // ---- audio ----
    PwObjectTracker { objects: Pipewire.nodes.values }
    Connections {
        target: Pipewire.nodes
        function onValuesChanged() { root.rebuildAudio() }
    }
    function rebuildAudio() {
        const v = Pipewire.nodes.values
        const a = []
        const b = []
        const c = []
        for (let i = 0; i < v.length; i++) {
            const n = v[i]
            const mc0 = n.properties ? String(n.properties["media.class"] || "") : ""
            if (n.isStream) { if (mc0 === "Stream/Output/Audio") c.push(n); continue }
            const mc = n.properties ? String(n.properties["media.class"] || "") : ""
            if (mc === "Audio/Sink") a.push(n)
            else if (mc === "Audio/Source") b.push(n)
        }
        sinkList = a
        sourceList = b
        streamList = c
    }

    // ================= ventana =================
    PanelWindow {
        id: win
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "qs-settings"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
        Item {
            id: escCatcher
            focus: true
            Keys.onEscapePressed: Qt.quit()
            Component.onCompleted: forceActiveFocus()
        }

        Rectangle {
            id: card
            property real prog: 0
            anchors.centerIn: parent
            width: Math.min(900, parent.width - 120)
            height: Math.min(580, parent.height - 80)
            radius: 22
            color: Qt.alpha(theme.bg, 0.98)
            border.width: 1
            border.color: Qt.alpha(theme.accent, 0.35)
            opacity: prog
            scale: 0.96 + 0.04 * prog
            NumberAnimation on prog { from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
            MouseArea { anchors.fill: parent }

            // ---------- barra lateral ----------
            Rectangle {
                id: side
                x: 0
                y: 0
                width: 200
                height: parent.height
                radius: 22
                color: Qt.alpha(Qt.lighter(theme.bg, 1.3), 0.7)
                Rectangle { anchors.right: parent.right; width: 22; height: parent.height; color: parent.color }
                Text {
                    x: 24
                    y: 22
                    text: "Settings"
                    color: theme.fgBright
                    font.family: root.fontFamily
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                }
                Column {
                    x: 12
                    y: 72
                    width: parent.width - 24
                    spacing: 4
                    Repeater {
                        model: root.pages
                        delegate: Rectangle {
                            id: nav
                            required property var modelData
                            required property int index
                            width: parent.width
                            height: 42
                            radius: 12
                            color: root.page === index ? Qt.alpha(theme.accent, 0.22)
                                   : (navMa.containsMouse ? Qt.alpha(theme.accent, 0.10) : "transparent")
                            Row {
                                x: 14
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12
                                Text {
                                    width: 18
                                    horizontalAlignment: Text.AlignHCenter
                                    text: nav.modelData.glyph
                                    color: root.page === nav.index ? theme.accent : theme.fg
                                    font.family: root.iconFont
                                    font.pixelSize: 15
                                }
                                Text {
                                    text: nav.modelData.name
                                    color: root.page === nav.index ? theme.fgBright : theme.fg
                                    font.family: root.fontFamily
                                    font.pixelSize: 14
                                    font.weight: root.page === nav.index ? Font.DemiBold : Font.Normal
                                }
                            }
                            MouseArea { id: navMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.page = nav.index }
                        }
                    }
                }
            }

            // ---------- contenido ----------
            Item {
                id: content
                x: 224
                y: 22
                width: parent.width - 224 - 24
                height: parent.height - 44

                Text {
                    text: root.pages[root.page].name
                    color: theme.fgBright
                    font.family: root.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    anchors.right: parent.right
                    width: 32
                    height: 32
                    radius: 10
                    color: closeMa.containsMouse ? Qt.alpha(theme.accent, 0.28) : Qt.alpha(theme.accent, 0.14)
                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        color: theme.fgBright
                        font.family: root.iconFont
                        font.pixelSize: 13
                    }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; onClicked: Qt.quit() }
                }

                Item {
                    id: body
                    y: 50
                    width: parent.width
                    height: parent.height - 50
                    clip: true

                    // ===== Appearance =====
                    Page {
                        anchors.fill: parent
                        active: root.page === 4
                        Sec { th: theme; text: "Theme" }
                        Flow {
                            width: parent.width
                            spacing: 10
                            Repeater {
                                model: root.themeNames
                                delegate: Rectangle {
                                    id: tc
                                    required property var modelData
                                    readonly property var pal: root.themeData[modelData] || ({})
                                    width: 124
                                    height: 68
                                    radius: 14
                                    color: pal.bg || "#222222"
                                    border.width: root.curTheme === modelData ? 2 : 1
                                    border.color: root.curTheme === modelData ? (pal.accent || "#ffffff") : Qt.alpha(pal.fg || "#ffffff", 0.2)
                                    Row {
                                        x: 12
                                        y: 12
                                        spacing: 6
                                        Rectangle { width: 14; height: 14; radius: 7; color: tc.pal.accent || "#ffffff" }
                                        Rectangle { width: 14; height: 14; radius: 7; color: tc.pal.fg || "#ffffff" }
                                        Rectangle { width: 14; height: 14; radius: 7; color: tc.pal.fg_bright || tc.pal.fg || "#ffffff" }
                                    }
                                    Text {
                                        x: 12
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 10
                                        width: parent.width - 24
                                        text: tc.modelData
                                        color: tc.pal.fg_bright || tc.pal.fg || "#ffffff"
                                        font.family: root.fontFamily
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: root.applyThemeName(tc.modelData) }
                                }
                            }
                        }
                        Text {
                            visible: root.themeMsg !== ""
                            topPadding: 6
                            text: root.themeMsg
                            color: Qt.alpha(theme.fg, 0.65)
                            font.family: root.fontFamily
                            font.pixelSize: 12
                        }
                        Sec { th: theme; text: "Windows" }
                        SRow {
                            th: theme; label: "Inner gaps"; desc: root.hy.gaps_in + " px"; contentWidth: 240
                            Sl { th: theme; value: root.hy.gaps_in / 30
                                onMoved: function(v) { root.setHy("gaps_in", Math.round(v * 30)) }
                                onReleased: root.saveHy("gaps_in") }
                        }
                        SRow {
                            th: theme; label: "Outer gaps"; desc: root.hy.gaps_out + " px"; contentWidth: 240
                            Sl { th: theme; value: root.hy.gaps_out / 40
                                onMoved: function(v) { root.setHy("gaps_out", Math.round(v * 40)) }
                                onReleased: root.saveHy("gaps_out") }
                        }
                        SRow {
                            th: theme; label: "Border size"; desc: root.hy.border_size + " px"; contentWidth: 240
                            Sl { th: theme; value: root.hy.border_size / 6
                                onMoved: function(v) { root.setHy("border_size", Math.round(v * 6)) }
                                onReleased: root.saveHy("border_size") }
                        }
                        SRow {
                            th: theme; label: "Corner rounding"; desc: root.hy.rounding + " px"; contentWidth: 240
                            Sl { th: theme; value: root.hy.rounding / 24
                                onMoved: function(v) { root.setHy("rounding", Math.round(v * 24)) }
                                onReleased: root.saveHy("rounding") }
                        }
                        SRow {
                            th: theme; label: "Blur"
                            Sw { th: theme; checked: !!root.hy.blur
                                onToggled: { root.setHy("blur", !root.hy.blur); root.saveHy("blur") } }
                        }
                    }

                    // ===== Audio =====
                    Page {
                        anchors.fill: parent
                        active: root.page === 2
                        Sec { th: theme; text: "Output" }
                        SRow {
                            th: theme; label: "Volume"; contentWidth: 240
                            desc: root.sink ? (root.sink.description || root.sink.name) : "No output device"
                            Sl { th: theme; value: (root.sink && root.sink.audio) ? root.sink.audio.volume : 0
                                onMoved: function(v) { if (root.sink && root.sink.audio) { root.sink.audio.muted = false; root.sink.audio.volume = v } } }
                        }
                        SRow {
                            th: theme; label: "Mute"
                            Sw { th: theme; checked: (root.sink && root.sink.audio) ? root.sink.audio.muted : false
                                onToggled: { if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted } }
                        }
                        Sec { th: theme; text: "Output device" }
                        Repeater {
                            model: root.sinkList
                            delegate: Dev {
                                required property var modelData
                                th: theme
                                width: parent.width
                                label: modelData.description || modelData.name
                                active: root.sink ? root.sink.id === modelData.id : false
                                onClicked: root.run(["wpctl", "set-default", String(modelData.id)])
                            }
                        }
                        Sec { th: theme; text: "Applications" }
                        Text {
                            visible: root.streamList.length === 0
                            text: "Nothing is playing right now"
                            color: Qt.alpha(theme.fg, 0.65)
                            font.family: root.fontFamily
                            font.pixelSize: 13
                        }
                        Repeater {
                            model: root.streamList
                            delegate: SRow {
                                id: ar
                                required property var modelData
                                th: theme
                                width: parent.width
                                contentWidth: 240
                                label: (ar.modelData.properties && (ar.modelData.properties["application.name"] || ar.modelData.properties["media.name"])) || ar.modelData.description || ar.modelData.name
                                desc: (ar.modelData.properties && ar.modelData.properties["media.name"]) ? String(ar.modelData.properties["media.name"]) : ""
                                Sl { th: theme; value: ar.modelData.audio ? ar.modelData.audio.volume : 0
                                    onMoved: function(v) { if (ar.modelData.audio) { ar.modelData.audio.muted = false; ar.modelData.audio.volume = v } } }
                            }
                        }
                        Sec { th: theme; text: "Input" }
                        SRow {
                            th: theme; label: "Microphone"; contentWidth: 240
                            desc: root.source ? (root.source.description || root.source.name) : "No input device"
                            Sl { th: theme; value: (root.source && root.source.audio) ? root.source.audio.volume : 0
                                onMoved: function(v) { if (root.source && root.source.audio) { root.source.audio.muted = false; root.source.audio.volume = v } } }
                        }
                        SRow {
                            th: theme; label: "Mute microphone"
                            Sw { th: theme; checked: (root.source && root.source.audio) ? root.source.audio.muted : false
                                onToggled: { if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted } }
                        }
                        Sec { th: theme; text: "Input device" }
                        Repeater {
                            model: root.sourceList
                            delegate: Dev {
                                required property var modelData
                                th: theme
                                width: parent.width
                                label: modelData.description || modelData.name
                                active: root.source ? root.source.id === modelData.id : false
                                onClicked: root.run(["wpctl", "set-default", String(modelData.id)])
                            }
                        }
                    }

                    // ===== Display =====
                    Page {
                        anchors.fill: parent
                        active: root.page === 3
                        Sec { th: theme; text: "Brightness" }
                        SRow {
                            th: theme; label: "Screen brightness"; desc: root.bright + "%"; contentWidth: 240
                            Sl { th: theme; value: root.bright / 100
                                onMoved: function(v) { root.bright = Math.max(1, Math.round(v * 100)); brTimer.restart() } }
                        }
                        Sec { th: theme; text: "Monitors" }
                        Repeater {
                            model: root.mons
                            delegate: SRow {
                                required property var modelData
                                th: theme
                                width: parent.width
                                label: modelData.name
                                desc: modelData.w + "x" + modelData.h + " @ " + modelData.hz + " Hz  ·  scale " + modelData.scale
                            }
                        }
                    }

                    // ===== Network =====
                    Page {
                        anchors.fill: parent
                        active: root.page === 0
                        Sec { th: theme; text: "Wi-Fi" }
                        SRow {
                            th: theme; label: "Wi-Fi"
                            desc: !root.wifi.available ? "NetworkManager not available" : (root.wifi.enabled ? "On" : "Off")
                            Sw { th: theme; checked: !!root.wifi.enabled
                                onToggled: {
                                    root.tool_(["wifi-power", root.wifi.enabled ? "off" : "on"])
                                    root.wifi = { available: root.wifi.available, enabled: !root.wifi.enabled, ssid: root.wifi.ssid, signal: root.wifi.signal }
                                    soon.restart()
                                } }
                        }
                        SRow {
                            th: theme; label: "Connected network"
                            desc: root.wifi.ssid !== "" ? (root.wifi.ssid + "  ·  " + root.wifi.signal + "%") : "Not connected"
                            Btn { th: theme; text: "Wi-Fi networks"
                                onClicked: { root.run(["sh", "-c", "sleep 0.15; exec " + root.home + "/scripts/wifi-menu.sh"]); Qt.quit() } }
                        }
                    }

                    // ===== Bluetooth =====
                    Page {
                        anchors.fill: parent
                        active: root.page === 1
                        Sec { th: theme; text: "Bluetooth" }
                        SRow {
                            th: theme; label: "Bluetooth"
                            desc: !root.bt.available ? "bluetoothctl not available (install bluez-utils)" : (root.bt.powered ? "On" : "Off")
                            Sw { th: theme; checked: !!root.bt.powered
                                onToggled: {
                                    root.tool_(["bt-power", root.bt.powered ? "off" : "on"])
                                    root.bt = { available: root.bt.available, powered: !root.bt.powered, devices: root.bt.devices }
                                    soon.restart()
                                } }
                        }
                        SRow {
                            th: theme; label: "Scan for devices"; desc: "Looks for nearby devices for 10 seconds"
                            Btn { th: theme; text: "Scan"
                                onClicked: { root.tool_(["bt-scan"]); soon.interval = 4000; soon.restart() } }
                        }
                        Sec { th: theme; text: "Devices" }
                        Repeater {
                            model: root.bt.devices
                            delegate: Dev {
                                required property var modelData
                                th: theme
                                width: parent.width
                                label: modelData.name
                                sub: modelData.connected ? "Connected" : (modelData.paired ? "Paired" : "Available")
                                active: modelData.connected
                                onClicked: { root.tool_(["bt-toggle", modelData.mac, modelData.connected ? "1" : "0"]); soon.interval = 2500; soon.restart() }
                            }
                        }
                    }

                    // ===== Notifications =====
                    Page {
                        anchors.fill: parent
                        active: root.page === 6
                        Sec { th: theme; text: "Notifications" }
                        SRow {
                            th: theme; label: "Do not disturb"; desc: "Hides pop-ups, keeps them in the list"
                            Sw { th: theme; checked: root.dndNow
                                onToggled: { root.dndNow = !root.dndNow; root.dndHold = Date.now() + 900; root.run(["qs", "-c", "notifs", "ipc", "call", "notifs", "dnd"]); soon.interval = 500; soon.restart() } }
                        }
                        SRow {
                            th: theme; label: "Pending notifications"; desc: root.notif.count + " in the list"
                            Btn { th: theme; text: "Clear all"
                                onClicked: { root.run(["qs", "-c", "notifs", "ipc", "call", "notifs", "clear"]); soon.interval = 500; soon.restart() } }
                        }
                        SRow {
                            th: theme; label: "Test"; desc: "Sends a sample notification"
                            Btn { th: theme; text: "Send test"
                                onClicked: root.run(["notify-send", "Test", "This is a test notification"]) }
                        }
                    }

                    // ===== Power =====
                    Page {
                        anchors.fill: parent
                        active: root.page === 7
                        Sec { th: theme; text: "Battery" }
                        SRow {
                            th: theme; label: "Battery"
                            desc: root.pw.capacity !== "" ? root.pw.status : "No battery found"
                            Text {
                                visible: root.pw.capacity !== ""
                                text: root.pw.capacity + "%"
                                color: theme.fgBright
                                font.family: root.fontFamily
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                            }
                        }
                        Sec { th: theme; text: "Power profile" }
                        SRow {
                            th: theme; label: "Profile"
                            desc: root.pw.profiles.length === 0 ? "power-profiles-daemon not available" : ""
                            Row {
                                spacing: 8
                                Repeater {
                                    model: root.pw.profiles
                                    delegate: Btn {
                                        required property var modelData
                                        th: theme
                                        text: modelData
                                        active: root.pw.profile === modelData
                                        onClicked: { root.tool_(["power-profile", modelData]); soon.interval = 700; soon.restart() }
                                    }
                                }
                            }
                        }
                    }

                    // ===== Wallpaper =====
                    Item {
                        anchors.fill: parent
                        visible: root.page === 5
                        Text {
                            id: wallHead
                            topPadding: 12
                            bottomPadding: 8
                            text: root.walls.pending > 0 ? "WALLPAPERS  ·  " + root.walls.items.length + "  ·  GENERATING THUMBNAILS..." : "WALLPAPERS  ·  " + root.walls.items.length
                            color: Qt.alpha(theme.accent, 0.9)
                            font.family: root.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1
                        }
                        GridView {
                            id: wallGrid
                            anchors.top: wallHead.bottom
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            cacheBuffer: 200
                            cellWidth: Math.floor(width / 3)
                            cellHeight: 126
                            model: root.walls.items
                            delegate: Item {
                                id: wc
                                required property var modelData
                                readonly property bool cur: root.walls.current === modelData.path
                                width: wallGrid.cellWidth
                                height: wallGrid.cellHeight
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 5
                                    radius: 10
                                    color: Qt.lighter(theme.bg, 1.3)
                                    border.width: wc.cur ? 2 : 1
                                    border.color: wc.cur ? theme.accent : Qt.alpha(theme.fg, 0.2)
                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        source: wc.modelData.thumb
                                        asynchronous: true
                                        cache: false
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize.width: 380
                                    }
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 3
                                        height: 22
                                        color: Qt.alpha(theme.bg, 0.78)
                                        Text {
                                            x: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 16
                                            text: wc.modelData.name
                                            color: theme.fgBright
                                            font.family: root.fontFamily
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }
                                    Rectangle {
                                        visible: wc.cur
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: theme.accent
                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf00c"
                                            color: theme.bg
                                            font.family: root.iconFont
                                            font.pixelSize: 11
                                        }
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: root.setWall(wc.modelData.path) }
                                }
                            }
                        }
                    }

                    // ===== Keybinds =====
                    Item {
                        anchors.fill: parent
                        visible: root.page === 8
                        onVisibleChanged: { if (!visible) escCatcher.forceActiveFocus() }
                        Rectangle {
                            id: kbSearch
                            y: 8
                            width: parent.width - 10
                            height: 36
                            radius: 11
                            color: Qt.alpha(theme.accent, 0.12)
                            border.width: kbIn.activeFocus ? 1 : 0
                            border.color: theme.accent
                            Text {
                                x: 14
                                anchors.verticalCenter: parent.verticalCenter
                                visible: kbIn.text === ""
                                text: "Search keybinds..."
                                color: Qt.alpha(theme.fg, 0.5)
                                font.family: root.fontFamily
                                font.pixelSize: 13
                            }
                            TextInput {
                                id: kbIn
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                verticalAlignment: TextInput.AlignVCenter
                                color: theme.fgBright
                                font.family: root.fontFamily
                                font.pixelSize: 13
                                clip: true
                                selectByMouse: true
                                onTextChanged: root.bindQ = text
                                Keys.onEscapePressed: Qt.quit()
                            }
                        }
                        Text {
                            id: kbCount
                            anchors.top: kbSearch.bottom
                            topPadding: 10
                            bottomPadding: 6
                            text: root.bindsShown.length + " KEYBINDS"
                            color: Qt.alpha(theme.accent, 0.9)
                            font.family: root.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1
                        }
                        ListView {
                            id: kbList
                            anchors.top: kbCount.bottom
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            width: parent.width - 10
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.bindsShown
                            delegate: Item {
                                id: kr
                                required property var modelData
                                width: kbList.width
                                height: 44
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 230
                                    height: 28
                                    radius: 8
                                    color: Qt.alpha(theme.accent, 0.16)
                                    Text {
                                        anchors.centerIn: parent
                                        width: parent.width - 16
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        text: kr.modelData.keys
                                        color: theme.accent
                                        font.family: root.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                    }
                                }
                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 246
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1
                                    Text {
                                        width: parent.width
                                        text: kr.modelData.desc !== "" ? kr.modelData.desc : kr.modelData.what
                                        color: theme.fgBright
                                        font.family: root.fontFamily
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        visible: false
                                        text: kr.modelData.act
                                        color: Qt.alpha(theme.fg, 0.6)
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 1
                                    color: Qt.alpha(theme.fg, 0.08)
                                }
                            }
                        }
                    }

                    // ===== System =====
                    Page {
                        anchors.fill: parent
                        active: root.page === 9
                        Sec { th: theme; text: "This computer" }
                        Repeater {
                            model: [["Host", "host"], ["Kernel", "kernel"], ["CPU", "cpu"], ["Memory", "mem"],
                                    ["Disk", "disk"], ["Uptime", "uptime"], ["Quickshell", "quickshell"], ["Hyprland", "hyprland"]]
                            delegate: SRow {
                                required property var modelData
                                th: theme
                                width: parent.width
                                label: modelData[0]
                                Text {
                                    text: root.sys[modelData[1]] || "-"
                                    color: Qt.alpha(theme.fg, 0.85)
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
