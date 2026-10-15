import QtQuick

// Panel "pegado" al borde (barra / pantalla) con empalme concavo, estilo Caelestia.
// attach: "left" (pegado a la barra), "top" (borde de arriba), "right" (borde derecho)
Canvas {
    id: c
    property color fillColor: "#1d2021"
    property color lineColor: "#d79921"
    property real radius: 18
    property real flare: 18
    property string attach: "left"

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onFillColorChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onAttachChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var W = width, H = height
        if (W < 2 || H < 2) return
        var D, L
        ctx.save()
        if (attach === "left") { D = W; L = H }
        else if (attach === "right") { D = W; L = H; ctx.translate(W, 0); ctx.scale(-1, 1) }
        else { D = H; L = W; ctx.transform(0, 1, 1, 0, 0, 0) }   // top
        var R = Math.min(radius, D / 2, (L - 2 * flare) / 2)
        var F = flare
        ctx.beginPath()
        ctx.moveTo(0, 0)
        ctx.arc(F, 0, F, Math.PI, Math.PI / 2, true)
        ctx.lineTo(D - R, F)
        ctx.arc(D - R, F + R, R, -Math.PI / 2, 0, false)
        ctx.lineTo(D, L - F - R)
        ctx.arc(D - R, L - F - R, R, 0, Math.PI / 2, false)
        ctx.lineTo(F, L - F)
        ctx.arc(F, L, F, 1.5 * Math.PI, Math.PI, true)
        ctx.fillStyle = Qt.rgba(fillColor.r, fillColor.g, fillColor.b, fillColor.a)
        ctx.fill()
        ctx.lineWidth = 1
        ctx.strokeStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, lineColor.a)
        ctx.stroke()
        ctx.restore()
    }
}
