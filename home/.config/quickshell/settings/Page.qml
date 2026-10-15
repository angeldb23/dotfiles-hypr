import QtQuick

Flickable {
    id: f
    default property alias items: col.data
    property bool active: false
    visible: active
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight + 12
    boundsBehavior: Flickable.StopAtBounds
    Column {
        id: col
        width: f.width - 10
        spacing: 4
    }
}
