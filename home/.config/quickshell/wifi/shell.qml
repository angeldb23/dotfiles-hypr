//@ pragma IconTheme Adwaita
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    // alto de tu waybar + margen: ajustalo si el panel queda pegado o muy separado
    property int barHeight: 44
    property bool sideMode: false
    property real iconY: 0
    property string fontFamily: "SF Pro Display"

    property bool shown: false
    property bool wifiOn: true
    property string expandedSsid: ""
    property string busySsid: ""
    property string statusText: ""
    property string pendingSsid: ""
    property bool pendingWithPass: false
    property var rawNets: []
    property var savedNames: []
    property string lastSig: ""

    property color cBg: "#1d2021"
    property color cFg: "#d4be98"
    property color cFgBright: "#ebdbb2"
    property color cAccent: "#d79921"

    function show() { shown = true }
    function hide() { shown = false }
    function toggle() { shown = !shown }

    onShownChanged: {
        if (shown) {
            expandedSsid = ""
            statusText = ""
            lastSig = ""
            run(modeProc)
            refreshAll()
            run(rescanProc)
            rescanTimer.restart()
            focusTimer.restart()
        }
    }
    onExpandedSsidChanged: { if (expandedSsid === "") rebuild() }

    IpcHandler {
        target: "wifi"
        function toggle(): void { root.toggle() }
        function open(): void { root.show() }
        function close(): void { root.hide() }
    }

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

    // ---- nmcli ----
    function run(p) { if (!p.running) p.running = true }

    function refreshAll() {
        run(radioProc)
        run(savedProc)
        run(listProc)
    }

    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector { onStreamFinished: root.parseNets(this.text) }
    }
    Process {
        id: savedProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector { onStreamFinished: root.parseSaved(this.text) }
    }
    Process {
        id: radioProc
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector { onStreamFinished: root.wifiOn = (this.text.trim() === "enabled") }
    }
    Process { id: rescanProc; command: ["nmcli", "device", "wifi", "rescan"] }
    Process {
        id: radioSet
        onExited: function(code, status) { rescanTimer.restart(); radioTimer.restart() }
    }
    Process {
        id: connectProc
        onExited: function(code, status) { root.onConnectDone(code) }
    }
    Process {
        id: forgetProc
        onExited: function(code, status) { root.lastSig = ""; refreshSoon.restart() }
    }
    Process {
        id: downProc
        onExited: function(code, status) { root.lastSig = ""; refreshSoon.restart() }
    }

    Process {
        id: modeProc
        command: ["sh", "-c", "cat ~/.cache/bar-mode.txt 2>/dev/null; echo; cat ~/.cache/bar-wifi-y.txt 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.split("\n")
                root.sideMode = (l[0].trim() === "qs")
                root.iconY = parseFloat(l[1]) || 0
            }
        }
    }
    Timer { id: focusTimer; interval: 40; onTriggered: keys.forceActiveFocus() }
    Timer { id: rescanTimer; interval: 2500; onTriggered: { root.run(listProc); root.run(savedProc) } }
    Timer { id: radioTimer; interval: 900; onTriggered: root.run(radioProc) }
    Timer { id: refreshSoon; interval: 700; onTriggered: root.refreshAll() }
    Timer { id: hideTimer; interval: 1200; onTriggered: root.hide() }
    Timer {
        interval: 6000
        repeat: true
        running: root.shown && root.wifiOn
        onTriggered: { if (root.expandedSsid === "" && root.busySsid === "") root.run(listProc) }
    }

    function splitT(line) {
        const out = []
        let cur = ""
        for (let i = 0; i < line.length; i++) {
            const ch = line[i]
            if (ch === "\\" && i + 1 < line.length) { cur += line[i + 1]; i++ }
            else if (ch === ":") { out.push(cur); cur = "" }
            else cur += ch
        }
        out.push(cur)
        return out
    }

    function parseNets(text) {
        const lines = text.split("\n")
        const map = {}
        for (let i = 0; i < lines.length; i++) {
            if (lines[i] === "") continue
            const f = splitT(lines[i])
            if (f.length < 4 || f[1] === "") continue
            const sig = parseInt(f[2]) || 0
            const inuse = f[0] === "*"
            const e = map[f[1]]
            if (!e) map[f[1]] = { ssid: f[1], sig: sig, inuse: inuse, sec: f[3] }
            else { if (sig > e.sig) e.sig = sig; if (inuse) e.inuse = true }
        }
        rawNets = Object.keys(map).map(function(k) { return map[k] })
        rebuild()
    }

    function parseSaved(text) {
        const lines = text.split("\n")
        const names = []
        for (let i = 0; i < lines.length; i++) {
            if (lines[i] === "") continue
            const f = splitT(lines[i])
            if (f.length >= 2 && f[1] === "802-11-wireless") names.push(f[0])
        }
        savedNames = names
        rebuild()
    }

    function barsFor(s) { return s >= 75 ? 4 : s >= 50 ? 3 : s >= 25 ? 2 : s > 0 ? 1 : 0 }

    function rebuild() {
        if (expandedSsid !== "") return
        const arr = rawNets.slice()
        arr.sort(function(a, b) {
            if (a.inuse !== b.inuse) return a.inuse ? -1 : 1
            return b.sig - a.sig
        })
        const items = arr.map(function(n) {
            const secure = n.sec !== "" && n.sec !== "--"
            return { ssid: n.ssid, inuse: n.inuse, bars: barsFor(n.sig), secure: secure,
                     saved: savedNames.indexOf(n.ssid) >= 0, sec: secure ? n.sec : "Open" }
        })
        const sig = items.map(function(x) { return x.ssid + ":" + x.inuse + ":" + x.bars + ":" + x.saved }).join("|")
        if (sig === lastSig) return
        lastSig = sig
        lm.clear()
        for (let i = 0; i < items.length; i++) lm.append(items[i])
    }

    ListModel { id: lm }

    function rowClicked(ssid, saved, secure, inuse) {
        if (inuse || busySsid !== "") return
        if (!secure || saved) connectTo(ssid, saved, "")
        else expandedSsid = (expandedSsid === ssid) ? "" : ssid
    }

    function rowAction(ssid, inuse) {
        if (inuse) downProc.command = ["nmcli", "connection", "down", "id", ssid]
        else forgetProc.command = ["nmcli", "connection", "delete", "id", ssid]
        if (inuse) downProc.running = true
        else forgetProc.running = true
    }

    function connectTo(ssid, saved, pass) {
        if (connectProc.running) return
        busySsid = ssid
        pendingSsid = ssid
        pendingWithPass = (pass !== "")
        statusText = "Connecting to " + ssid + "..."
        if (pass !== "") connectProc.command = ["nmcli", "device", "wifi", "connect", ssid, "password", pass]
        else if (saved) connectProc.command = ["nmcli", "connection", "up", "id", ssid]
        else connectProc.command = ["nmcli", "device", "wifi", "connect", ssid]
        connectProc.running = true
    }

    function onConnectDone(code) {
        busySsid = ""
        if (code === 0) {
            statusText = "Connected to " + pendingSsid
            expandedSsid = ""
            lastSig = ""
            refreshSoon.restart()
            hideTimer.restart()
        } else {
            statusText = pendingWithPass ? "Wrong password?" : "Couldn't connect"
            if (pendingWithPass) {
                forgetProc.command = ["nmcli", "connection", "delete", "id", pendingSsid]
                forgetProc.running = true
            }
        }
    }

    function setRadio(on) {
        wifiOn = on
        if (!on) { lm.clear(); lastSig = ""; expandedSsid = "" }
        radioSet.command = ["nmcli", "radio", "wifi", on ? "on" : "off"]
        radioSet.running = true
    }

    function doRescan() {
        run(rescanProc)
        rescanTimer.restart()
    }

    // ---- ventana ----
    PanelWindow {
        id: win
        visible: root.shown || slot.progress > 0.001
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "qs-wifi"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        MouseArea { anchors.fill: parent; onClicked: root.hide() }

        Item {
            id: keys
            focus: true
            Keys.onEscapePressed: root.hide()
        }

        // zona debajo de la barra: el panel sale desde su borde
        Item {
            id: slot
            property real progress: root.shown ? 1 : 0
            Behavior on progress { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            x: root.sideMode ? 55 : 0
            y: root.sideMode ? 0 : root.barHeight
            width: parent.width - x
            height: parent.height - y
            clip: true

            PopShape {
                visible: root.sideMode
                attach: "left"
                fillColor: Qt.alpha(root.cBg, 0.96)
                lineColor: Qt.alpha(root.cAccent, 0.35)
                radius: 18
                flare: 18
                x: card.x - 1
                y: card.y - 18
                width: card.width + 1
                height: card.height + 36
                opacity: card.opacity
            }
            Rectangle {
                id: card
                width: 340
                x: root.sideMode ? (1 - (1 - slot.progress) * (width + 40)) : (slot.width - width - 10)
                y: root.sideMode
                   ? Math.max(26, Math.min(slot.height - height - 26, slot.height - root.iconY - height + 30))
                   : (6 - (1 - slot.progress) * (height + 14))
                height: col.height + 28
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                opacity: Math.min(1, slot.progress * 3)
                radius: root.sideMode ? 0 : 18
                color: root.sideMode ? "transparent" : Qt.alpha(root.cBg, 0.96)
                border.width: root.sideMode ? 0 : 1
                border.color: Qt.alpha(root.cAccent, 0.35)

                MouseArea { anchors.fill: parent }

                Column {
                    id: col
                    x: 14
                    y: 14
                    width: parent.width - 28
                    spacing: 8

                    // cabecera
                    Item {
                        width: parent.width
                        height: 34
                        Text {
                            anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                            text: "Wi-Fi"
                            color: root.cFgBright
                            font.family: root.fontFamily
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }
                        Rectangle {
                            width: 44
                            height: 24
                            radius: 12
                            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                            color: root.wifiOn ? root.cAccent : Qt.lighter(root.cBg, 1.7)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Rectangle {
                                width: 18
                                height: 18
                                radius: 9
                                y: 3
                                x: root.wifiOn ? 23 : 3
                                color: root.wifiOn ? root.cBg : root.cFg
                                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.setRadio(!root.wifiOn) }
                        }
                    }

                    Text {
                        width: parent.width
                        visible: root.statusText !== ""
                        leftPadding: 4
                        text: root.statusText
                        color: Qt.alpha(root.cFg, 0.85)
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: !root.wifiOn || lm.count === 0
                        leftPadding: 4
                        topPadding: 6
                        bottomPadding: 6
                        text: root.wifiOn ? "Looking for networks..." : "Wi-Fi is off"
                        color: Qt.alpha(root.cFg, 0.6)
                        font.family: root.fontFamily
                        font.pixelSize: 14
                    }

                    ListView {
                        id: list
                        width: parent.width
                        height: root.wifiOn ? Math.min(contentHeight, 290) : 0
                        visible: height > 0
                        model: lm
                        spacing: 4
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height

                        delegate: Item {
                            id: row
                            width: ListView.view.width
                            property bool expanded: root.expandedSsid === model.ssid
                            property bool busy: root.busySsid === model.ssid
                            height: 52 + (expanded ? 56 : 0)
                            clip: true
                            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                            onExpandedChanged: {
                                if (expanded) {
                                    pw.text = ""
                                    Qt.callLater(function() {
                                        pw.forceActiveFocus()
                                        list.positionViewAtIndex(index, ListView.Contain)
                                    })
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 14
                                color: model.inuse ? Qt.alpha(root.cAccent, 0.18)
                                     : (hover.containsMouse || row.expanded) ? Qt.alpha(root.cAccent, 0.10) : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Item {
                                id: top
                                width: parent.width
                                height: 52

                                MouseArea {
                                    id: hover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.rowClicked(model.ssid, model.saved, model.secure, model.inuse)
                                }

                                // barras de senal
                                Item {
                                    x: 14
                                    y: 17
                                    width: 22
                                    height: 18
                                    Repeater {
                                        model: 4
                                        Rectangle {
                                            x: index * 6
                                            width: 4
                                            height: 6 + index * 4
                                            y: 18 - height
                                            radius: 1
                                            color: index < lm.get(row.index !== undefined ? row.index : 0).bars
                                                   ? root.cFgBright : Qt.alpha(root.cFg, 0.25)
                                        }
                                    }
                                }

                                Column {
                                    x: 48
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: top.width - 48 - (act.visible ? act.width + 26 : 14)
                                    spacing: 1
                                    Text {
                                        width: parent.width
                                        text: model.ssid
                                        color: root.cFgBright
                                        font.family: root.fontFamily
                                        font.pixelSize: 15
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: row.busy ? "Connecting..." : model.inuse ? "Connected"
                                              : model.saved ? ("Saved · " + model.sec) : model.sec
                                        color: model.inuse ? root.cAccent : Qt.alpha(root.cFg, 0.7)
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    id: act
                                    visible: model.inuse || model.saved
                                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                                    text: model.inuse ? "Disconnect" : "Forget"
                                    color: actMouse.containsMouse ? root.cFgBright : Qt.alpha(root.cFg, 0.65)
                                    font.family: root.fontFamily
                                    font.pixelSize: 12
                                    MouseArea {
                                        id: actMouse
                                        anchors.fill: parent
                                        anchors.margins: -8
                                        hoverEnabled: true
                                        onClicked: root.rowAction(model.ssid, model.inuse)
                                    }
                                }
                            }

                            // campo de contrasena
                            Rectangle {
                                x: 10
                                y: 54
                                width: parent.width - 20
                                height: 42
                                radius: 12
                                color: Qt.lighter(root.cBg, 1.45)
                                opacity: row.expanded ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                TextInput {
                                    id: pw
                                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                                    verticalAlignment: TextInput.AlignVCenter
                                    echoMode: TextInput.Password
                                    passwordCharacter: "•"
                                    color: root.cFgBright
                                    font.family: root.fontFamily
                                    font.pixelSize: 15
                                    selectionColor: root.cAccent
                                    selectedTextColor: root.cBg
                                    clip: true
                                    onAccepted: { if (text !== "") root.connectTo(model.ssid, false, text) }
                                    Keys.onEscapePressed: { root.expandedSsid = ""; keys.forceActiveFocus() }
                                }
                                Text {
                                    anchors { fill: pw }
                                    verticalAlignment: Text.AlignVCenter
                                    visible: pw.text.length === 0
                                    text: "Password (Enter to connect)"
                                    color: Qt.alpha(root.cFg, 0.5)
                                    font.family: root.fontFamily
                                    font.pixelSize: 14
                                }
                            }
                        }
                    }

                    // pie
                    Item {
                        width: parent.width
                        height: 28
                        Text {
                            anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                            text: "Rescan"
                            color: rescanMouse.containsMouse ? root.cFgBright : Qt.alpha(root.cFg, 0.7)
                            font.family: root.fontFamily
                            font.pixelSize: 12
                            MouseArea {
                                id: rescanMouse
                                anchors.fill: parent
                                anchors.margins: -8
                                hoverEnabled: true
                                onClicked: root.doRescan()
                            }
                        }
                        Text {
                            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                            text: lm.count + (lm.count === 1 ? " network" : " networks")
                            color: Qt.alpha(root.cFg, 0.5)
                            font.family: root.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}
