import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

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
        implicitWidth: row.implicitWidth + 40
        implicitHeight: row.implicitHeight + 20

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 8

            MaterialSymbol {
                visible: GlobalStates.osdLayoutIcon !== ""
                text: GlobalStates.osdLayoutIcon
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colOnLayer0
            }
            StyledText {
                color: Appearance.colors.colOnLayer0
                font.pixelSize: Appearance.font.pixelSize.larger
                text: GlobalStates.osdLayoutLabel
            }
        }
    }
}
