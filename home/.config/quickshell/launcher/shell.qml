//@ pragma IconTheme Adwaita
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property bool shown: false
    property var matches: []
    property string lastIds: "-"
    property bool cardOpen: false
    property bool wallMode: false
    property bool themeMode: false
    property var themes: []
    property string currentTheme: ""
    property var walls: []
    property var wallsAll: []
    property string wallFilter: ""
    property string currentWall: ""
    property string fontFamily: "SF Pro Display"

    property color cBg: "#1d2021"
    property color cFg: "#d4be98"
    property color cFgBright: "#ebdbb2"
    property color cAccent: "#d79921"

    function show() { shown = true }
    function hide() { shown = false }
    function toggle() { shown = !shown }

    onShownChanged: {
        if (shown) {
            input.text = ""
            lastIds = "-"
            lm.clear()
            matches = []
            focusTimer.restart()
            glowLayer.start()
        } else {
            openSeq.stop()
            cardOpen = false
            glowLayer.fade = 0
        }
    }

    onCardOpenChanged: {
        if (cardOpen) {
            refilter()
            refreshTimer.restart()
        }
    }

    Timer { id: topTimer; interval: 260; onTriggered: { if (list.currentIndex === 0) list.positionViewAtBeginning() } }
    Timer { id: focusTimer; interval: 40; onTriggered: input.forceActiveFocus() }
    Timer { id: refreshTimer; interval: 500; onTriggered: { if (root.shown && input.text === "") root.refilter() } }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle() }
        function open(): void { root.show() }
        function close(): void { root.hide() }
        function wallpapers(): void { root.openWall() }
        function themes(): void { root.openThemes() }
    }

    // ---- colores del tema ----
    FileView {
        id: themesFile
        path: Quickshell.env("HOME") + "/.config/themes/themes.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.applyTheme()
            root.parseThemes()
        }
    }
    FileView {
        id: themeNameFile
        path: Quickshell.env("HOME") + "/.cache/theme.txt"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.applyTheme()
            root.refreshDynamicTheme()
        }
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

    // ---- busqueda ----
    ListModel { id: lm }

    function refilter() {
        const q = input.text.trim().toLowerCase()
        const all = DesktopEntries.applications.values
        let scored = []
        for (let i = 0; i < all.length; i++) {
            const a = all[i]
            if (a.noDisplay) continue
            const n = (a.name || "").toLowerCase()
            let s = 0
            if (q === "") s = 1
            else if (n.startsWith(q)) s = 100
            else if (n.indexOf(q) >= 0) s = 60
            else if (((a.genericName || "") + " " + (a.keywords ? String(a.keywords) : "")).toLowerCase().indexOf(q) >= 0) s = 30
            else if ((a.comment || "").toLowerCase().indexOf(q) >= 0) s = 15
            if (s > 0) scored.push({ a: a, s: s })
        }
        scored.sort(function(x, y) { return (y.s - x.s) || x.a.name.localeCompare(y.a.name) })
        const top = scored.map(function(x) { return x.a })
        const ids = top.map(function(a) { return a.id }).join("|")
        if (ids === lastIds) return
        lastIds = ids
        matches = top
        lm.clear()
        for (let k = 0; k < top.length; k++) lm.append({ idx: k })
        list.currentIndex = 0
        list.positionViewAtBeginning()
        topTimer.restart()
    }

    function iconFor(name) {
        if (name && name.charAt(0) === "/") return "file://" + name
        const p = name ? Quickshell.iconPath(name, true) : ""
        return p !== "" ? p : Quickshell.iconPath("application-x-executable", true)
    }

    // ---- modo wallpaper ----
    FileView {
        id: curWallFile
        path: Quickshell.env("HOME") + "/.cache/current_wallpaper.txt"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.currentWall = curWallFile.text().trim()
    }

    Process {
        id: wallLister
        command: [Quickshell.env("HOME") + "/scripts/wallpaper-list.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                const lines = this.text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const p = lines[i].split("\t")
                    if (p.length >= 2 && p[0] !== "") out.push({ path: p[0], thumb: p[1] })
                }
                root.wallsAll = out
                root.applyWallFilter()
            }
        }
    }

    function isWallQuery(t) {
        const q = t.trim().toLowerCase().replace(/^[<>]+/, "").trim()
        return q === "wallpaper" || q === "wallpapers" ||
               q.indexOf("wallpaper ") === 0 || q.indexOf("wallpapers ") === 0
    }

    function wallName(p) {
        const s = p.split("/").pop().replace(/\.[a-z0-9]+$/i, "")
        return s.replace(/[-_]+/g, " ").replace(/\s+/g, " ").trim()
    }

    function applyWallFilter() {
        const f = root.wallFilter
        if (f === "") root.walls = root.wallsAll
        else root.walls = root.wallsAll.filter(function(w) { return root.wallName(w.path).toLowerCase().indexOf(f) >= 0 })
        Qt.callLater(root.selectCurrentWall)
    }

    function updateWallFilter() {
        const q = input.text.trim().toLowerCase().replace(/^[<>]+/, "").trim()
        let f = ""
        const m = q.match(/^wallpapers?\s+(.*)$/)
        if (m) f = m[1].trim()
        if (f !== root.wallFilter) {
            root.wallFilter = f
            root.applyWallFilter()
        }
    }

    function updateMode() {
        const w = isWallQuery(input.text)
        const t = isThemeQuery(input.text)
        if (t !== themeMode) {
            themeMode = t
            if (t) loadThemes()
        }
        if (w === wallMode) return
        wallMode = w
        if (w) wallLister.running = true
    }

    // ---- modo themes ----
    FileView {
        id: curThemeFile
        path: Quickshell.env("HOME") + "/.cache/theme.txt"
        watchChanges: true
        onFileChanged: reload()
       onLoaded: { root.currentTheme = curThemeFile.text().trim(); root.refreshDynamicTheme() }
    }

    function isThemeQuery(t) {
        const q = t.trim().toLowerCase().replace(/^[<>]+/, "").trim()
        return q === "theme" || q === "themes" || q === "tema" || q === "temas"
    }

    function parseThemes() {
        let d = {}

        try {
            d = JSON.parse(themesFile.text())
        } catch (e) {
            themes = []
            return
        }

        const out = []
        const seen = {}

        // Temas estáticos.
        // Dynamic% queda excluido SIEMPRE, incluso si aparece
        // con espacios o distinta capitalización dentro del JSON.
        for (const rawName in d) {
            const name = String(rawName).trim()

            if (name.toLowerCase() === "dynamic" ||
                name.toLowerCase() === "dynamic%")
                continue

            if (seen[name])
                continue

            seen[name] = true

            const p = d[rawName]

            out.push({
                name: name,
                key: name,
                dynamic: false,
                cols: [
                    p.bg,
                    p.c3 || p.accent,
                    p.c1 || p.red,
                    p.c2 || p.accent_hi,
                    p.c4 || p.accent
                ]
            })
        }

        // EXACTAMENTE UN Dynamic%, siempre primero.
        out.unshift({
            name: "Dynamic",
            key: "Dynamic",
            dynamic: true,
            cols: [
                root.cBg,
                root.cAccent,
                root.cFgBright,
                root.cFg,
                root.cAccent
            ]
        })

        themes = out
        Qt.callLater(root.selectCurrentTheme)
    }

    function refreshDynamicTheme() {
        if (themes.length === 0)
            return

        if (themes[0].name !== "Dynamic")
            return

        const updated = themes.slice()

        updated[0] = {
            name: "Dynamic",
            key: "Dynamic",
            dynamic: true,
            cols: [
                root.cBg,
                root.cAccent,
                root.cFgBright,
                root.cFg,
                root.cAccent
            ]
        }

        themes = updated
    }

    function loadThemes() {
        themesFile.reload()
        curThemeFile.reload()
    }

    function openThemes() {
        if (!shown) show()
        input.text = "themes"
    }

    function selectCurrentTheme() {
        let idx = 0
        for (let i = 0; i < themes.length; i++) {
           if ((themes[i].key || themes[i].name) === (currentTheme === "Dynamic%" ? "Dynamic" : currentTheme)) { idx = i; break }
        }
        themeScroll.stop()
        themeList.currentIndex = idx
        themeList.positionViewAtIndex(idx, ListView.Contain)
    }

    function themeMove(d) {
        const n = themes.length
        if (n === 0) return
        const i = Math.max(0, Math.min(n - 1, themeList.currentIndex + d))
        themeList.currentIndex = i
        const left = i * 158
        const right = left + 150
        let target = themeList.contentX
        if (left < target) target = left
        else if (right > target + themeList.width) target = right - themeList.width
        if (target !== themeList.contentX) {
            themeScroll.stop()
            themeScroll.to = target
            themeScroll.start()
        }
    }

    function selectTheme(i) {
        const t = themes[i]
        if (!t) return
        const themeKey = t.key || t.name
        Quickshell.execDetached(["python3", Quickshell.env("HOME") + "/scripts/theme-set.py", themeKey])
        currentTheme = themeKey
        hide()
    }

    function openWall() {
        if (!shown) show()
        input.text = "wallpapers"
    }

    function selectCurrentWall() {
        let idx = 0
        for (let i = 0; i < walls.length; i++) {
            if (walls[i].path === currentWall) { idx = i; break }
        }
        wallScroll.stop()
        wallList.currentIndex = idx
        wallList.positionViewAtIndex(idx, ListView.Contain)
    }

    function wallMove(d) {
        const n = walls.length
        if (n === 0) return
        const i = Math.max(0, Math.min(n - 1, wallList.currentIndex + d))
        wallList.currentIndex = i
        const left = i * 180
        const right = left + 172
        let target = wallList.contentX
        if (left < target) target = left
        else if (right > target + wallList.width) target = right - wallList.width
        if (target !== wallList.contentX) {
            wallScroll.stop()
            wallScroll.to = target
            wallScroll.start()
        }
    }

    function applyWall(i) {
        const w = walls[i]
        if (!w) return
        Quickshell.execDetached([Quickshell.env("HOME") + "/scripts/set-wallpaper.sh", w.path])
        currentWall = w.path
        hide()
    }

    function launch(i) {
        const a = matches[i]
        if (!a) return
        hide()
        a.execute()
    }

    // ---- ventana ----
    PanelWindow {
        id: win
        visible: root.shown || slot.progress > 0.001
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "qs-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        MouseArea { anchors.fill: parent; onClicked: root.hide() }

        Item {
            id: glowLayer
            anchors.fill: parent
            property real p: 0
            property real fade: 0
            opacity: fade
            visible: fade > 0.01
            function start() { openSeq.stop(); fade = 1; p = 0; openSeq.start() }

            SequentialAnimation {
                id: openSeq
                NumberAnimation { target: glowLayer; property: "p"; from: 0; to: 1; duration: 340; easing.type: Easing.InOutCubic }
                ScriptAction { script: root.cardOpen = true }
                PauseAnimation { duration: 160 }
                NumberAnimation { target: glowLayer; property: "fade"; to: 0; duration: 420 }
            }

            // desde el borde izquierdo hacia el centro
            Item {
                width: 340
                height: 16
                anchors.bottom: parent.bottom
                x: -width + glowLayer.p * (glowLayer.width / 2)
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.alpha(root.cAccent, 0) }
                        GradientStop { position: 1.0; color: Qt.alpha(root.cAccent, 0.3) }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 3
                    anchors.bottom: parent.bottom
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.alpha(root.cAccent, 0) }
                        GradientStop { position: 1.0; color: root.cAccent }
                    }
                }
            }

            // desde el borde derecho hacia el centro
            Item {
                width: 340
                height: 16
                anchors.bottom: parent.bottom
                x: glowLayer.width - glowLayer.p * (glowLayer.width / 2)
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.alpha(root.cAccent, 0.3) }
                        GradientStop { position: 1.0; color: Qt.alpha(root.cAccent, 0) }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 3
                    anchors.bottom: parent.bottom
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.cAccent }
                        GradientStop { position: 1.0; color: Qt.alpha(root.cAccent, 0) }
                    }
                }
            }
        }

        Item {
            id: sideGlow
            anchors.fill: parent
            opacity: (root.cardOpen && glowLayer.fade < 0.01) ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 250 } }

            component GlowStrip: Item {
                id: strip
                property bool leftSide: true
                property color accent: "#d79921"
                width: 380
                height: 44
                anchors.bottom: parent.bottom

                Canvas {
                    id: cv
                    anchors.fill: parent
                    onWidthChanged: requestPaint()
                    Component.onCompleted: requestPaint()
                    Connections { target: strip; function onAccentChanged() { cv.requestPaint() } }
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.globalCompositeOperation = "source-over"
                        ctx.clearRect(0, 0, width, height)
                        var a = strip.accent
                        var h = ctx.createLinearGradient(0, 0, width, 0)
                        h.addColorStop(0, Qt.rgba(a.r, a.g, a.b, strip.leftSide ? 0 : 0.30))
                        h.addColorStop(1, Qt.rgba(a.r, a.g, a.b, strip.leftSide ? 0.30 : 0))
                        ctx.fillStyle = h
                        ctx.fillRect(0, 0, width, height)
                        ctx.globalCompositeOperation = "destination-in"
                        var v = ctx.createLinearGradient(0, 0, 0, height)
                        v.addColorStop(0, Qt.rgba(0, 0, 0, 0))
                        v.addColorStop(0.6, Qt.rgba(0, 0, 0, 0.25))
                        v.addColorStop(1, Qt.rgba(0, 0, 0, 1))
                        ctx.fillStyle = v
                        ctx.fillRect(0, 0, width, height)
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 3
                    anchors.bottom: parent.bottom
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: strip.leftSide ? Qt.alpha(strip.accent, 0) : strip.accent }
                        GradientStop { position: 1.0; color: strip.leftSide ? strip.accent : Qt.alpha(strip.accent, 0) }
                    }
                }
            }

            Item {
                id: pulser
                anchors.fill: parent
                opacity: 0
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: root.cardOpen
                    NumberAnimation { to: 1; duration: 800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.25; duration: 800; easing.type: Easing.InOutSine }
                }
                GlowStrip { leftSide: true;  accent: root.cAccent; x: (sideGlow.width - slot.width) / 2 - width }
                GlowStrip { leftSide: false; accent: root.cAccent; x: (sideGlow.width + slot.width) / 2 }
            }
        }

        Item {
            id: slot
            property real progress: root.cardOpen ? 1 : 0
            Behavior on progress { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            width: 560
            height: card.height - 22
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 0
            opacity: Math.min(1, progress * 3)
            transform: Translate { y: (1 - slot.progress) * (slot.height + 24) }

            Rectangle {
                id: card
                width: parent.width
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -22
                height: 50 + searchBox.height + (list.height + Math.min(10, list.height)) + (wallStrip.height + Math.min(10, wallStrip.height))
                radius: 22
                color: Qt.alpha(root.cBg, 0.95)
                border.width: 1
                border.color: Qt.alpha(root.cAccent, 0.35)
                clip: true

                MouseArea { anchors.fill: parent }

                // resultados (crecen hacia arriba)
                ListView {
                    id: list
                    anchors { left: parent.left; right: parent.right; bottom: searchBox.top; margins: 14; bottomMargin: 10 }
                    height: (root.wallMode || root.themeMode) ? 0 : (Math.min(lm.count, 7) > 0 ? Math.min(lm.count, 7) * 48 + (Math.min(lm.count, 7) - 1) * 4 : 0)
                    Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    model: lm
                    spacing: 4
                    interactive: true
                    opacity: (root.wallMode || root.themeMode) ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    clip: true
                    verticalLayoutDirection: ListView.TopToBottom
                    currentIndex: 0
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Item {
                        id: row
                        width: ListView.view.width
                        height: 48
                        property var entry: root.matches[model.idx]
                        opacity: 0
                        transform: Translate { id: rowShift; y: 14 }

                        Component.onCompleted: enterAnim.start()
                        SequentialAnimation {
                            id: enterAnim
                            PauseAnimation { duration: Math.max(0, Math.min(index, 7)) * 30 }
                            ParallelAnimation {
                                NumberAnimation { target: row; property: "opacity"; to: 1; duration: 170 }
                                NumberAnimation { target: rowShift; property: "y"; to: 0; duration: 220; easing.type: Easing.OutCubic }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: row.ListView.isCurrentItem ? Qt.alpha(root.cAccent, 0.22) : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        Image {
                            id: ico
                            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                            width: 30
                            height: 30
                            sourceSize: Qt.size(64, 64)
                            asynchronous: true
                            source: row.entry ? root.iconFor(row.entry.icon) : ""
                        }
                        Rectangle {
                            visible: ico.source.toString() === ""
                            anchors.fill: ico
                            radius: 8
                            color: Qt.alpha(root.cAccent, 0.25)
                            Text {
                                anchors.centerIn: parent
                                text: row.entry ? row.entry.name.charAt(0).toUpperCase() : ""
                                color: root.cFgBright
                                font.family: root.fontFamily
                                font.pixelSize: 16
                                font.weight: Font.Medium
                            }
                        }
                        Column {
                            anchors { left: ico.right; leftMargin: 14; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                            spacing: 1
                            Text {
                                width: parent.width
                                text: row.entry ? row.entry.name : ""
                                color: root.cFgBright
                                font.family: root.fontFamily
                                font.pixelSize: 16
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: row.entry ? (row.entry.comment || row.entry.genericName || "") : ""
                                color: Qt.alpha(root.cFg, 0.75)
                                font.family: root.fontFamily
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onPositionChanged: row.ListView.view.currentIndex = index
                            onClicked: root.launch(index)
                        }
                    }
                }

                // modo wallpaper: miniaturas sin nombre
                Item {
                    id: wallStrip
                    anchors { left: parent.left; right: parent.right; bottom: searchBox.top; margins: 14; bottomMargin: 10 }
                    height: (root.wallMode || root.themeMode) ? 134 : 0
                    Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    opacity: (root.wallMode || root.themeMode) ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    clip: true

                    ListView {
                        id: themeList
                        visible: root.themeMode
                        anchors.fill: parent
                        orientation: ListView.Horizontal
                        spacing: 8
                        interactive: false
                        model: root.themes
                        currentIndex: 0

                        NumberAnimation { id: themeScroll; target: themeList; property: "contentX"; duration: 220; easing.type: Easing.OutCubic }

                        delegate: Item {
                            id: tcell
                            width: 150
                            height: themeList.height
                            property bool sel: ListView.isCurrentItem
                           property bool cur: modelData.name === (root.currentTheme === "Dynamic%" ? "Dynamic" : root.currentTheme)

                            Rectangle {
                                anchors.centerIn: parent
                                width: 150
                                height: 98
                                radius: 14
                                color: tcell.sel ? Qt.alpha(root.cAccent, 0.22) : Qt.lighter(root.cBg, 1.45)
                                border.width: tcell.sel ? 2 : 0
                                border.color: root.cAccent
                            }
                            Column {
                                anchors.centerIn: parent
                                spacing: 12
                                opacity: tcell.sel ? 1 : 0.75
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                transform: Translate {
                                    id: themeLift
                                    y: tcell.sel ? 0 : 5
                                    Behavior on y {
                                        NumberAnimation {
                                            duration: 190
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: (tcell.cur ? "● " : "") + modelData.name
                                    color: tcell.sel ? root.cFgBright : root.cFg
                                    font.family: root.fontFamily
                                    font.pixelSize: 14
                                    font.weight: tcell.sel ? Font.DemiBold : Font.Normal
                                }
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 5
                                    Repeater {
                                        model: modelData.cols
                                        delegate: Rectangle {
                                            width: 16
                                            height: 16
                                            radius: 8
                                            color: modelData
                                        }
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { themeList.currentIndex = index; root.selectTheme(index) }
                            }
                        }
                    }

                    ListView {
                        id: wallList
                        visible: root.wallMode
                        anchors.fill: parent
                        orientation: ListView.Horizontal
                        spacing: 8
                        interactive: false
                        model: root.walls
                        currentIndex: 0

                        NumberAnimation { id: wallScroll; target: wallList; property: "contentX"; duration: 220; easing.type: Easing.OutCubic }

                        delegate: Item {
                            id: wcell
                            width: 172
                            height: wallList.height
                            property bool sel: ListView.isCurrentItem

                            Rectangle {
                                anchors.centerIn: parent
                                width: 172
                                height: 124
                                radius: 14
                                color: wcell.sel ? Qt.alpha(root.cAccent, 0.22) : "transparent"
                                border.width: wcell.sel ? 2 : 0
                                border.color: root.cAccent
                            }
                            Column {
                                anchors.centerIn: parent
                                spacing: 5
                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 160
                                    height: 84
                                    source: "file://" + modelData.thumb
                                    sourceSize: Qt.size(320, 180)
                                    asynchronous: true
                                    smooth: true
                                    opacity: wcell.sel ? 1 : 0.7
                                    scale: wcell.sel ? 1 : 0.94
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 164
                                    text: root.wallName(modelData.path)
                                    color: wcell.sel ? root.cFgBright : root.cFg
                                    font.family: root.fontFamily
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { wallList.currentIndex = index; root.applyWall(index) }
                            }
                        }
                    }
                }

                // barra de busqueda (abajo)
                Item {
                    id: searchBox
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 14; bottomMargin: 36 }
                    height: 52
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: Qt.lighter(root.cBg, 1.45)
                    }
                    Text {
                        id: glyph
                        anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                        text: "❯"
                        color: root.cAccent
                        font.pixelSize: 18
                    }
                    TextInput {
                        id: input
                        anchors { left: glyph.right; leftMargin: 12; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        color: root.cFgBright
                        font.family: root.fontFamily
                        font.pixelSize: 18
                        selectionColor: root.cAccent
                        selectedTextColor: root.cBg
                        cursorDelegate: Rectangle {
                            width: 2
                            radius: 1
                            color: root.cAccent
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: root.shown
                                PauseAnimation { duration: 500 }
                                NumberAnimation { to: 0; duration: 160 }
                                PauseAnimation { duration: 400 }
                                NumberAnimation { to: 1; duration: 160 }
                            }
                        }
                        clip: true
                        onTextChanged: { root.updateMode(); root.updateWallFilter(); root.refilter(); sweepAnim.restart() }
                        Keys.onPressed: function(event) {
                            if (root.themeMode) {
                                if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) { root.themeMove(-1); event.accepted = true; return }
                                if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) { root.themeMove(1); event.accepted = true; return }
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.selectTheme(themeList.currentIndex); event.accepted = true; return }
                                if (event.key === Qt.Key_Escape) { input.text = ""; event.accepted = true; return }
                            }
                            if (root.wallMode) {
                                if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) { root.wallMove(-1); event.accepted = true; return }
                                if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) { root.wallMove(1); event.accepted = true; return }
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.applyWall(wallList.currentIndex); event.accepted = true; return }
                                if (event.key === Qt.Key_Escape) { input.text = ""; event.accepted = true; return }
                            }
                            if (event.key === Qt.Key_Escape) {
                                root.hide(); event.accepted = true
                            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                                list.currentIndex = Math.min(list.currentIndex + 1, lm.count - 1); event.accepted = true
                            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                                list.currentIndex = Math.max(list.currentIndex - 1, 0); event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.launch(list.currentIndex); event.accepted = true
                            }
                        }
                    }
                    Text {
                        anchors.fill: input
                        verticalAlignment: Text.AlignVCenter
                        visible: input.text.length === 0
                        text: "Search apps..."
                        color: Qt.alpha(root.cFg, 0.5)
                        font.family: root.fontFamily
                        font.pixelSize: 18
                    }

                    // destello mientras buscas
                    Rectangle {
                        id: sweep
                        width: 90
                        height: 2
                        radius: 1
                        color: root.cAccent
                        anchors.bottom: parent.bottom
                        x: -width
                        opacity: 0
                        SequentialAnimation {
                            id: sweepAnim
                            PropertyAction { target: sweep; property: "opacity"; value: 1 }
                            NumberAnimation { target: sweep; property: "x"; from: -90; to: searchBox.width; duration: 380; easing.type: Easing.InOutCubic }
                            PropertyAction { target: sweep; property: "opacity"; value: 0 }
                        }
                    }
                }
            }
        }
    }
}
