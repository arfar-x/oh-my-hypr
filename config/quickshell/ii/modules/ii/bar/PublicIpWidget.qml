import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    implicitWidth: rowLayout.implicitWidth + 10 * 2
    implicitHeight: Appearance.sizes.barHeight
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    onContainsMouseChanged: if (containsMouse) PublicIp.refreshOthers()

    onPressed: mouse => {
        if (mouse.button === Qt.LeftButton) {
            PublicIp.refresh();
        } else if (PublicIp.ip !== "") {
            Quickshell.execDetached(["wl-copy", PublicIp.ip]);
            Quickshell.execDetached(["notify-send", Translation.tr("Public IP"),
                Translation.tr("Copied %1").arg(PublicIp.ip), "-a", "Shell"]);
        }
    }

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 4

        StyledText {
            visible: PublicIp.flag !== ""
            text: PublicIp.flag
            font.pixelSize: Appearance.font.pixelSize.normal
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: 4
        }
        MaterialSymbol {
            visible: PublicIp.flag === ""
            fill: 0
            text: PublicIp.failed ? "public_off" : "public"
            iconSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colOnLayer1
            Layout.alignment: Qt.AlignVCenter
        }
        StyledText {
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.Medium
            font.letterSpacing: 0.3
            color: Appearance.colors.colOnLayer1
            text: PublicIp.ip !== "" ? PublicIp.ip : (PublicIp.loading ? "…" : "offline")
            Layout.alignment: Qt.AlignVCenter
        }
        MaterialSymbol {
            visible: PublicIp.loading
            text: "progress_activity"
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnLayer1
            Layout.alignment: Qt.AlignVCenter
            RotationAnimator on rotation {
                running: PublicIp.loading
                from: 0; to: 360; duration: 900
                loops: Animation.Infinite
            }
        }
    }

    StyledPopup {
        hoverTarget: root

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4

            StyledPopupHeaderRow {
                icon: "public"
                label: Translation.tr("Public IP")
            }
            StyledPopupValueRow {
                icon: "language"
                label: Translation.tr("IP:")
                value: PublicIp.ip || "—"
            }
            StyledPopupValueRow {
                icon: "location_on"
                label: Translation.tr("Location:")
                value: ([PublicIp.flag, PublicIp.city, PublicIp.region, PublicIp.country].filter(s => s).join(" ")) || "—"
            }
            StyledPopupValueRow {
                icon: "dns"
                label: Translation.tr("ISP:")
                value: PublicIp.org || "—"
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                implicitHeight: 1
                color: Appearance.colors.colOutlineVariant
            }
            Repeater {
                model: PublicIp.results
                delegate: StyledPopupValueRow {
                    required property var modelData
                    Layout.fillWidth: true
                    icon: modelData.state === "pending" ? "more_horiz"
                        : modelData.state === "failed" ? "error"
                        : modelData.ip === PublicIp.ip ? "check_circle" : "warning"
                    label: modelData.url.replace(/^https?:\/\//, "") + (modelData.name === PublicIp.defaultSource ? " ★" : "") + ":"
                    value: modelData.state === "pending" ? (PublicIp.checkingOthers ? Translation.tr("checking…") : "—")
                         : modelData.state === "failed" ? (modelData.error || Translation.tr("failed")) : modelData.ip
                }
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSurfaceVariant
                text: Translation.tr("Left-click to refresh • Right-click to copy")
            }
        }
    }
}
