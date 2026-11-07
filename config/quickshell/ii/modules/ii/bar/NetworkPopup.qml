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
    // Every screen's bar instantiates this popup; only the one on the screen whose
    // icon was clicked opens (otherwise the popups' focus grabs clear each other).
    readonly property string screenName: root.anchorItem?.QsWindow?.window?.screen?.name ?? ""
    readonly property bool wanted: GlobalStates.networkPopupOpen && screenName === GlobalStates.networkPopupScreen
    // Keep the window alive while the close animation plays
    property bool keepAlive: false
    active: wanted || keepAlive
    onWantedChanged: {
        if (wanted) {
            root.closeTimer.stop();
            keepAlive = true;
        } else {
            root.closeTimer.restart();
        }
    }
    // (a property, not a child: LazyLoader's default property is the lazy component)
    readonly property Timer closeTimer: Timer {
        interval: 220
        onTriggered: root.keepAlive = false
    }

    component: PanelWindow {
        id: popupWindow
        screen: root.anchorItem?.QsWindow?.window?.screen ?? null
        color: "transparent"

        // false at creation, flipped on so the enter animation plays; follows the loader afterwards
        property bool show: false
        // The window has no size on its first frame, which makes the popup's x jump from the left
        // edge to its anchor; stay invisible until it has been laid out.
        readonly property bool ready: width > 0 && popupBackground.width > 0

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
        // Fixed height (the popup's maximum): resizing a layer surface while it is open makes it blink.
        // The mask below keeps clicks outside the visible popup going to the windows behind it.
        implicitHeight: 560 + Appearance.sizes.elevationMargin * 2
        mask: Region { item: popupBackground }

        WlrLayershell.namespace: "quickshell:networkPopup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        HyprlandFocusGrab {
            windows: [popupWindow]
            active: popupWindow.show
            onCleared: GlobalStates.networkPopupOpen = false
        }

        Component.onCompleted: {
            show = Qt.binding(() => root.wanted);
            scanTimer.start();
        }

        // Rescanning rebuilds the list and would stall the enter animation, so do it right after
        Timer {
            id: scanTimer
            interval: 260
            onTriggered: {
                Network.refreshVpns();
                Network.rescanWifi();
            }
        }

        StyledRectangularShadow {
            target: popupBackground
            opacity: popupBackground.opacity
        }

        Rectangle {
            id: popupBackground
            readonly property real pad: 10
            x: Math.max(Appearance.sizes.elevationMargin,
                Math.min(popupWindow.width - width - Appearance.sizes.elevationMargin,
                    (root.anchorItem && root.QsWindow ? root.QsWindow.mapFromItem(root.anchorItem, root.anchorItem.width / 2, 0).x : popupWindow.width) - width / 2))
            y: Appearance.sizes.elevationMargin + ((popupWindow.show && popupWindow.ready) ? 0 : -8)
            // No opacity fade: while translucent, Hyprland's layer blur shows a bright blurred
            // wallpaper through the popup, which reads as a flash. Slide/scale only.
            opacity: popupWindow.ready ? 1 : 0
            scale: popupWindow.show ? 1 : 0.97
            transformOrigin: Item.Top
            Behavior on y { animation: popupAnim.createObject(this) }
            Behavior on scale { animation: popupAnim.createObject(this) }
            Component {
                id: popupAnim
                NumberAnimation {
                    duration: popupWindow.show ? 220 : 150
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: popupWindow.show ? Appearance.animationCurves.emphasizedDecel : Appearance.animationCurves.emphasizedAccel
                }
            }
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
                    // always takes its space so the popup doesn't change height when a scan starts/ends
                    opacity: Network.wifiScanning ? 1 : 0
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
