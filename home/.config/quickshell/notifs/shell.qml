import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications

// Centro de notificaciones propio para el modo barra Quickshell (reemplaza a swaync).
// Panel pegado a la barra con empalme concavo + toasts al lado de la barra.
ShellRoot {
    id: root

    property int barW: 56
    property string fontFamily: "SF Pro Display"
    property string iconFont: "CaskaydiaCove Nerd Font"

    property bool shown: false
    property bool powerShown: false
    readonly property var powerActions: [
        { glyph: "\uf023", label: "Lock", cmd: ["hyprlock"], danger: false },
        { glyph: "\uf186", label: "Suspend", cmd: ["systemctl", "suspend"], danger: false },
        { glyph: "\uf021", label: "Restart", cmd: ["systemctl", "reboot"], danger: false },
        { glyph: "\uf011", label: "Shut down", cmd: ["systemctl", "poweroff"], danger: true },
        { glyph: "\uf08b", label: "Log out", cmd: ["loginctl", "terminate-user", Quickshell.env("USER")], danger: false }
    ]
    property bool dndOn: false
    property int total: 0
    property var groups: []
    property var toasts: []
    property var popupIds: []
    property var openGroups: ({})

    property color cBg: "#1d2021"
    property color cFg: "#d4be98"
    property color cFgBright: "#ebdbb2"
    property color cAccent: "#d79921"

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

    // ---- servidor de notificaciones ----
    NotificationServer {
        id: server
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: function(n) {
            n.tracked = true
            n.closed.connect(function(reason) { root.scheduleRebuild() })
            if (!root.dndOn || n.urgency === NotificationUrgency.Critical)
                root.popupIds = [n.id].concat(root.popupIds).slice(0, 4)
            root.scheduleRebuild()
        }
    }
    Connections {
        target: server.trackedNotifications
        function onValuesChanged() { root.scheduleRebuild() }
    }
    Timer { id: rebuildTimer; interval: 40; onTriggered: root.rebuild() }
    Timer {
        interval: 1500
        running: root.shown
        repeat: true
        onTriggered: { if (root.total !== server.trackedNotifications.values.length) root.rebuild() }
    }
    function scheduleRebuild() { rebuildTimer.restart() }

    function rebuild() {
        const vals = server.trackedNotifications.values
        const map = {}
        const order = []
        for (let i = vals.length - 1; i >= 0; i--) {
            const n = vals[i]
            const k = (n.appName && n.appName !== "") ? n.appName : "App"
            if (!map[k]) { map[k] = { app: k, items: [] }; order.push(k) }
            map[k].items.push(n)
        }
        const y = lv.contentY
        const g = []
        for (let j = 0; j < order.length; j++) g.push(map[order[j]])
        groups = g
        total = vals.length
        refreshToasts()
        publish()
        Qt.callLater(function() { lv.contentY = Math.max(0, Math.min(y, lv.contentHeight - lv.height)) })
    }
    function refreshToasts() {
        const vals = server.trackedNotifications.values
        const out = []
        for (let i = vals.length - 1; i >= 0; i--)
            if (popupIds.indexOf(vals[i].id) >= 0) out.push(vals[i])
        toasts = out
    }
    function hidePopup(id) { popupIds = popupIds.filter(function(x) { return x !== id }) }
    onPopupIdsChanged: refreshToasts()
    onDndOnChanged: publish()

    function clearAll() {
        const vals = server.trackedNotifications.values
        const arr = []
        for (let i = 0; i < vals.length; i++) arr.push(vals[i])
        for (let j = 0; j < arr.length; j++) arr[j].dismiss()
    }
    function clearGroup(g) {
        for (let i = 0; i < g.items.length; i++) g.items[i].dismiss()
    }
    function toggleGroup(app) {
        const o = {}
        for (const k in openGroups) o[k] = openGroups[k]
        o[app] = !o[app]
        openGroups = o
    }
    function iconFor(n) {
        if (!n) return ""
        if (n.image && n.image !== "") return n.image
        if (n.appIcon && n.appIcon !== "") {
            if (n.appIcon.indexOf("/") === 0) return "file://" + n.appIcon
            return Quickshell.iconPath(n.appIcon, true)
        }
        return ""
    }
    // la barra lee la ultima linea de este archivo para el contador de la campana
    function publish() {
        const alt = dndOn ? "dnd-notification" : "notification"
        Quickshell.execDetached(["sh", "-c",
            "echo '{\"text\":\"" + total + "\",\"alt\":\"" + alt + "\"}' >> \"$HOME/.cache/notif-state.log\""])
    }
    Component.onCompleted: {
        Quickshell.execDetached(["sh", "-c", ": > \"$HOME/.cache/notif-state.log\""])
        publish()
    }

    IpcHandler {
        target: "notifs"
        function toggle(): void { root.shown = !root.shown }
        function open(): void { root.shown = true }
        function close(): void { root.shown = false }
        function dnd(): void { root.dndOn = !root.dndOn }
        function dndstate(): string { return root.dndOn ? "true" : "false" }
        function clear(): void { root.clearAll() }
    }

    // ================= tarjeta de notificacion =================
    component NotifCard: Rectangle {
        id: nc
        property var n: null
        property string iconSrc: ""
        property color cBg
        property color cFg
        property color cFgBright
        property color cAccent
        property string fontFamily
        property string iconFont
        signal activated()

        readonly property bool critical: n ? n.urgency === NotificationUrgency.Critical : false

        height: row.implicitHeight + 24
        radius: 16
        color: hov.hovered ? Qt.lighter(cBg, 1.6) : Qt.lighter(cBg, 1.3)
        border.width: critical ? 1 : 0
        border.color: "#fb4934"

        HoverHandler { id: hov }
        TapHandler { onTapped: nc.activated() }

        RowLayout {
            id: row
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 10

            Rectangle {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 12
                color: Qt.alpha(nc.cAccent, 0.16)
                clip: true
                Image {
                    id: ico
                    anchors.fill: parent
                    anchors.margins: 4
                    fillMode: Image.PreserveAspectFit
                    source: nc.iconSrc
                    asynchronous: true
                    sourceSize.width: 80
                    sourceSize.height: 80
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: !ico.visible
                    text: (nc.n && nc.n.appName) ? nc.n.appName.charAt(0).toUpperCase() : "!"
                    color: nc.cAccent
                    font.family: nc.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: nc.n ? nc.n.summary : ""
                        color: nc.cFgBright
                        font.family: nc.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        text: "\uf00d"
                        color: closeMa.containsMouse ? nc.cFgBright : Qt.alpha(nc.cFg, 0.55)
                        font.family: nc.iconFont
                        font.pixelSize: 12
                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            onClicked: { if (nc.n) nc.n.dismiss() }
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: nc.n ? nc.n.body : ""
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    color: Qt.alpha(nc.cFg, 0.9)
                    font.family: nc.fontFamily
                    font.pixelSize: 13
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: actRep.count > 0
                    Repeater {
                        id: actRep
                        model: nc.n ? nc.n.actions : []
                        delegate: Rectangle {
                            id: act
                            required property var modelData
                            height: 28
                            width: atext.implicitWidth + 24
                            radius: 9
                            color: aMa.containsMouse ? Qt.alpha(nc.cAccent, 0.30) : Qt.alpha(nc.cAccent, 0.16)
                            Text {
                                id: atext
                                anchors.centerIn: parent
                                text: act.modelData.text
                                color: nc.cFgBright
                                font.family: nc.fontFamily
                                font.pixelSize: 12
                            }
                            MouseArea {
                                id: aMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: act.modelData.invoke()
                            }
                        }
                    }
                }
            }
        }
    }

    // ================= toasts (al lado de la barra) =================
    PanelWindow {
        id: toastWin
        visible: root.toasts.length > 0 && !root.shown
        anchors { top: true; left: true }
        margins { left: root.barW + 6; top: 12 }
        implicitWidth: 330
        implicitHeight: Math.max(1, toastCol.implicitHeight)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "qs-notifs-toast"
        WlrLayershell.layer: WlrLayer.Overlay
        mask: Region { item: toastCol }

        Column {
            id: toastCol
            width: 330
            spacing: 8

            Repeater {
                model: root.toasts
                delegate: Item {
                    id: tw
                    required property var modelData
                    width: toastCol.width
                    height: tcard.height
                    property bool ready: false
                    Component.onCompleted: ready = true

                    HoverHandler { id: thov }
                    Timer {
                        running: !tw.modelData || (tw.modelData.urgency !== NotificationUrgency.Critical && !thov.hovered)
                        interval: {
                            const t = (tw.modelData && tw.modelData.expireTimeout > 0) ? tw.modelData.expireTimeout * 1000 : 6000
                            return Math.max(4000, Math.min(10000, t))
                        }
                        onTriggered: root.hidePopup(tw.modelData ? tw.modelData.id : -1)
                    }

                    NotifCard {
                        id: tcard
                        width: tw.width
                        x: tw.ready ? 0 : -(width + 20)
                        opacity: tw.ready ? 1 : 0
                        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        n: tw.modelData
                        iconSrc: root.iconFor(tw.modelData)
                        cBg: Qt.alpha(root.cBg, 0.97)
                        cFg: root.cFg
                        cFgBright: root.cFgBright
                        cAccent: root.cAccent
                        fontFamily: root.fontFamily
                        iconFont: root.iconFont
                        border.width: 1
                        border.color: critical ? "#fb4934" : Qt.alpha(root.cAccent, 0.35)
                        onActivated: root.hidePopup(tw.modelData ? tw.modelData.id : -1)
                    }
                }
            }
        }
    }

    // ================= centro de notificaciones (pegado a la barra) =================
    PanelWindow {
        id: win
        visible: root.shown || clipper.prog > 0.001
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "qs-notifs"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        MouseArea { anchors.fill: parent; onClicked: root.shown = false }

        Item {
            id: keys
            focus: true
            Keys.onEscapePressed: root.shown = false
        }
        Connections {
            target: root
            function onShownChanged() { if (root.shown) keys.forceActiveFocus() }
        }

        Item {
            id: clipper
            property real prog: root.shown ? 1 : 0
            Behavior on prog { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            x: root.barW - 1
            y: 0
            width: 360
            height: parent.height
            clip: true

            Item {
                id: panel
                x: -1 - (1 - clipper.prog) * (width + 8)
                width: 340
                height: Math.max(220, Math.min(clipper.height - 40, 32 + 12 + lv.contentHeight + 64))
                y: clipper.height - 20 - height
                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                opacity: Math.min(1, clipper.prog * 2.5)

                PopShape {
                    anchors.fill: parent
                    attach: "left"
                    fillColor: Qt.alpha(root.cBg, 0.97)
                    lineColor: Qt.alpha(root.cAccent, 0.35)
                    radius: 18
                    flare: 18
                }
                MouseArea { anchors.fill: parent }

                Item {
                    id: inner
                    x: 16
                    y: 30
                    width: panel.width - 30
                    height: panel.height - 60

                    // ---- encabezado ----
                    Item {
                        id: head
                        width: parent.width
                        height: 32

                        Text {
                            id: ttl
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Notifications"
                            color: root.cFgBright
                            font.family: root.fontFamily
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: ttl.right
                            anchors.leftMargin: 8
                            visible: root.total > 0
                            text: root.total
                            color: Qt.alpha(root.cFg, 0.6)
                            font.family: root.fontFamily
                            font.pixelSize: 14
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Rectangle {
                                width: 32
                                height: 32
                                radius: 10
                                color: root.dndOn ? root.cAccent
                                       : (dndMa.containsMouse ? Qt.alpha(root.cAccent, 0.28) : Qt.alpha(root.cAccent, 0.14))
                                Text {
                                    anchors.centerIn: parent
                                    text: root.dndOn ? "\uf1f6" : "\uf0f3"
                                    color: root.dndOn ? root.cBg : root.cFgBright
                                    font.family: root.iconFont
                                    font.pixelSize: 14
                                }
                                MouseArea { id: dndMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.dndOn = !root.dndOn }
                            }
                            Rectangle {
                                visible: root.total > 0
                                width: clrTxt.implicitWidth + 24
                                height: 32
                                radius: 10
                                color: clrMa.containsMouse ? Qt.alpha(root.cAccent, 0.28) : Qt.alpha(root.cAccent, 0.14)
                                Text {
                                    id: clrTxt
                                    anchors.centerIn: parent
                                    text: "Clear all"
                                    color: root.cFgBright
                                    font.family: root.fontFamily
                                    font.pixelSize: 13
                                }
                                MouseArea { id: clrMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.clearAll() }
                            }
                        }
                    }

                    // ---- estado vacio ----
                    Column {
                        anchors.centerIn: parent
                        visible: root.total === 0
                        spacing: 10
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.dndOn ? "\uf1f6" : "\uf0f3"
                            color: Qt.alpha(root.cFg, 0.3)
                            font.family: root.iconFont
                            font.pixelSize: 44
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.dndOn ? "Do not disturb is on" : "No notifications"
                            color: Qt.alpha(root.cFg, 0.55)
                            font.family: root.fontFamily
                            font.pixelSize: 14
                        }
                    }

                    // ---- lista agrupada por app ----
                    ListView {
                        id: lv
                        anchors { top: head.bottom; topMargin: 12; left: parent.left; right: parent.right; bottom: parent.bottom }
                        clip: true
                        spacing: 14
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.groups

                        delegate: Item {
                            id: grp
                            required property var modelData
                            width: lv.width
                            height: gcol.implicitHeight
                            readonly property bool isOpen: !!root.openGroups[modelData.app]
                            readonly property int nShown: isOpen ? modelData.items.length : 1

                            Column {
                                id: gcol
                                width: parent.width
                                spacing: 6

                                Item {
                                    width: parent.width
                                    height: 22
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: grp.modelData.app
                                        color: Qt.alpha(root.cFg, 0.7)
                                        font.family: root.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                    }
                                    Row {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 12
                                        Text {
                                            visible: grp.modelData.items.length > 1
                                            text: grp.isOpen ? "Show less" : (grp.modelData.items.length - 1) + " more"
                                            color: moreMa.containsMouse ? root.cFgBright : Qt.alpha(root.cFg, 0.65)
                                            font.family: root.fontFamily
                                            font.pixelSize: 12
                                            MouseArea { id: moreMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.toggleGroup(grp.modelData.app) }
                                        }
                                        Text {
                                            text: "\uf00d"
                                            color: gclMa.containsMouse ? root.cFgBright : Qt.alpha(root.cFg, 0.5)
                                            font.family: root.iconFont
                                            font.pixelSize: 11
                                            MouseArea { id: gclMa; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: root.clearGroup(grp.modelData) }
                                        }
                                    }
                                }

                                Repeater {
                                    model: grp.nShown
                                    delegate: NotifCard {
                                        id: card
                                        required property int index
                                        width: gcol.width
                                        n: grp.modelData.items[index]
                                        iconSrc: root.iconFor(grp.modelData.items[index])
                                        cBg: root.cBg
                                        cFg: root.cFg
                                        cFgBright: root.cFgBright
                                        cAccent: root.cAccent
                                        fontFamily: root.fontFamily
                                        iconFont: root.iconFont
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ================= menu de apagado (pegado a la barra, columna de iconos) =================
    Connections {
        target: root
        function onShownChanged() { if (root.shown) root.powerShown = false }
    }
    IpcHandler {
        target: "power"
        function toggle(): void { root.shown = false; root.powerShown = !root.powerShown }
        function open(): void { root.shown = false; root.powerShown = true }
        function close(): void { root.powerShown = false }
    }
    PanelWindow {
        id: pwin
        visible: root.powerShown || pclip.prog > 0.001
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "qs-power"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.powerShown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        MouseArea { anchors.fill: parent; onClicked: root.powerShown = false }
        Item {
            id: pkeys
            focus: true
            Keys.onEscapePressed: root.powerShown = false
        }
        Connections {
            target: root
            function onPowerShownChanged() { if (root.powerShown) pkeys.forceActiveFocus() }
        }

        Item {
            id: pclip
            property real prog: root.powerShown ? 1 : 0
            Behavior on prog { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            x: root.barW - 1
            y: 0
            width: 260
            height: parent.height
            clip: true

            Item {
                id: ppanel
                x: -1 - (1 - pclip.prog) * (width + 8)
                width: 88
                height: pcol.implicitHeight + 60
                y: pclip.height - 20 - height
                opacity: Math.min(1, pclip.prog * 2.5)

                PopShape {
                    anchors.fill: parent
                    attach: "left"
                    fillColor: Qt.alpha(root.cBg, 0.97)
                    lineColor: Qt.alpha(root.cAccent, 0.35)
                    radius: 18
                    flare: 18
                }
                MouseArea { anchors.fill: parent }

                Column {
                    id: pcol
                    x: 16
                    y: 30
                    spacing: 8
                    Repeater {
                        model: root.powerActions
                        delegate: Rectangle {
                            id: pb
                            required property var modelData
                            width: 56
                            height: 56
                            radius: 16
                            color: pma.containsMouse ? Qt.alpha(root.cAccent, 0.30) : Qt.alpha(root.cAccent, 0.12)
                            Text {
                                anchors.centerIn: parent
                                text: pb.modelData.glyph
                                color: pb.modelData.danger ? "#fb4934" : root.cFgBright
                                font.family: root.iconFont
                                font.pixelSize: 22
                            }
                            MouseArea {
                                id: pma
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.powerShown = false
                                    Quickshell.execDetached(pb.modelData.cmd)
                                }
                            }
                            Rectangle {
                                visible: pma.containsMouse
                                x: pb.width + 22
                                anchors.verticalCenter: parent.verticalCenter
                                width: ptip.implicitWidth + 20
                                height: 30
                                radius: 10
                                color: Qt.alpha(root.cBg, 0.97)
                                border.width: 1
                                border.color: Qt.alpha(root.cAccent, 0.35)
                                Text {
                                    id: ptip
                                    anchors.centerIn: parent
                                    text: pb.modelData.label
                                    color: root.cFgBright
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
