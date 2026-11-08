import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

Item {
    implicitWidth: pill.implicitWidth + 2 * Appearance.sizes.elevationMargin
    implicitHeight: pill.implicitHeight + 2 * Appearance.sizes.elevationMargin

    StyledRectangularShadow {
        target: pill
    }
    Rectangle {
        id: pill
        anchors.centerIn: parent
        radius: Appearance.rounding.full
        color: Appearance.colors.colLayer0
        implicitWidth: label.implicitWidth + 40
        implicitHeight: label.implicitHeight + 20

        StyledText {
            id: label
            anchors.centerIn: parent
            color: Appearance.colors.colOnLayer0
            font.pixelSize: Appearance.font.pixelSize.larger
            text: GlobalStates.osdLayoutLabel
        }
    }
}
