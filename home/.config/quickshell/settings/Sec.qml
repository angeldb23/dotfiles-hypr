import QtQuick

Text {
    property var th
    width: parent ? parent.width : 100
    topPadding: 12
    bottomPadding: 4
    color: Qt.alpha(th.accent, 0.9)
    font.family: th.font
    font.pixelSize: 12
    font.weight: Font.DemiBold
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 1
}
