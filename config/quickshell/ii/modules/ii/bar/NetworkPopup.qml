import qs
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarRight.wifiNetworks
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

LazyLoader {
    id: root
    property Item anchorItem
    active: GlobalStates.networkPopupOpen

    component: PanelWindow {
        id: popupWindow
        color: "transparent"

        anchors.top: !Config.options.bar.bottom
        anchors.bottom: Config.options.bar.bottom
        anchors.left: true
        anchors.right: true
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        margins {
            top: Appearance.sizes.barHeight
            bottom: Appearance.sizes.barHeight
        }
        implicitHeight: popupBackground.implicitHeight + Appearance.sizes.elevationMargin * 2
        mask: Region { item: popupBackground }

        WlrLayershell.namespace: "quickshell:networkPopup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        HyprlandFocusGrab {
            windows: [popupWindow]
            active: true
            onCleared: GlobalStates.networkPopupOpen = false
        }

        Component.onCompleted: {
            Network.refreshVpns();
            Network.rescanWifi();
        }

        StyledRectangularShadow { target: popupBackground }

        Rectangle {
            id: popupBackground
            readonly property real pad: 10
            x: Math.max(Appearance.sizes.elevationMargin,
                Math.min(popupWindow.width - width - Appearance.sizes.elevationMargin,
                    (root.anchorItem && root.QsWindow ? root.QsWindow.mapFromItem(root.anchorItem, root.anchorItem.width / 2, 0).x : popupWindow.width) - width / 2))
            y: Appearance.sizes.elevationMargin
            implicitWidth: 340
            implicitHeight: Math.min(560, content.implicitHeight + pad * 2)
            color: Appearance.m3colors.m3surfaceContainer
            radius: Appearance.rounding.normal
            border.width: 1
            border.color: Appearance.colors.colLayer0Border
            clip: true

            Keys.onEscapePressed: GlobalStates.networkPopupOpen = false

            ColumnLayout {
                id: content
                anchors { fill: parent; margins: popupBackground.pad }
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    MaterialSymbol {
                        text: Network.materialSymbol
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Wi-Fi")
                        font.pixelSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    StyledSwitch {
                        checked: Network.wifiEnabled
                        onClicked: Network.toggleWifi()
                    }
                }

                StyledIndeterminateProgressBar {
                    visible: Network.wifiScanning
                    Layout.fillWidth: true
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 260)
                    clip: true
                    spacing: 0
                    model: ScriptModel { values: Network.friendlyWifiNetworks }
                    delegate: WifiNetworkItem {
                        required property WifiAccessPoint modelData
                        wifiNetwork: modelData
                        width: ListView.view.width
                    }
                }

                Rectangle {
                    visible: Network.vpns.length > 0
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Appearance.colors.colOutlineVariant
                }

                StyledText {
                    visible: Network.vpns.length > 0
                    text: Translation.tr("VPN")
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSurfaceVariant
                }

                Repeater {
                    model: Network.vpns
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        MaterialSymbol {
                            text: modelData.active ? "vpn_lock" : "vpn_key"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                        StyledText {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: modelData.name
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                        StyledSwitch {
                            checked: modelData.active
                            onClicked: Network.toggleVpn(modelData)
                        }
                    }
                }

                DialogButton {
                    Layout.alignment: Qt.AlignRight
                    buttonText: Translation.tr("Details")
                    onClicked: {
                        Quickshell.execDetached(["bash", "-c", `${Network.ethernet ? Config.options.apps.networkEthernet : Config.options.apps.network}`]);
                        GlobalStates.networkPopupOpen = false;
                    }
                }
            }
        }
    }
}
