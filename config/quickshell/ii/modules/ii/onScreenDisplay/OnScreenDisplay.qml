import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower

Scope {
    id: root
    property string protectionMessage: ""
    // focusedMonitor is null for a while after a monitor is turned off (Super+P single-display modes),
    // so fall back to a remaining screen instead of leaving the OSD with nowhere to show.
    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    property string currentIndicator: "volume"
    property var indicators: [
        {
            id: "volume",
            sourceUrl: "indicators/VolumeIndicator.qml"
        },
        {
            id: "brightness",
            sourceUrl: "indicators/BrightnessIndicator.qml"
        },
        {
            id: "gamma",
            sourceUrl: "indicators/GammaIndicator.qml"
        },
        {
            id: "layout",
            sourceUrl: "indicators/LayoutIndicator.qml"
        },
    ]

    // Keep the window alive briefly after closing so the exit animation can play
    property bool windowActive: GlobalStates.osdVolumeOpen
    Connections {
        target: GlobalStates
        function onOsdVolumeOpenChanged() {
            if (GlobalStates.osdVolumeOpen) {
                closeDelay.stop();
                root.windowActive = true;
            } else {
                closeDelay.restart();
            }
        }
    }
    Timer {
        id: closeDelay
        interval: 260
        onTriggered: root.windowActive = false
    }

    function triggerOsd() {
        GlobalStates.osdVolumeOpen = true;
        osdTimeout.restart();
    }

    Timer {
        id: osdTimeout
        interval: Config.options.osd.timeout
        repeat: false
        running: false
        onTriggered: {
            GlobalStates.osdVolumeOpen = false;
            root.protectionMessage = "";
        }
    }

    Connections {
        target: Brightness
        function onBrightnessChanged() {
            root.protectionMessage = "";
            root.currentIndicator = "brightness";
            root.triggerOsd();
        }
    }

    Connections {
        target: Hyprsunset
        function onGammaChangeAttempt() {
            root.protectionMessage = "";
            root.currentIndicator = "gamma";
            root.triggerOsd();
        }
    }

    Connections {
        // Announce power profile changes with the same pill used for the keyboard layout
        target: PowerProfiles
        function onProfileChanged() {
            const names = {};
            names[PowerProfile.PowerSaver] = Translation.tr("Power saver");
            names[PowerProfile.Balanced] = Translation.tr("Balanced");
            names[PowerProfile.Performance] = Translation.tr("Performance");
            const icons = {};
            icons[PowerProfile.PowerSaver] = "energy_savings_leaf";
            icons[PowerProfile.Balanced] = "airwave";
            icons[PowerProfile.Performance] = "local_fire_department";
            GlobalStates.osdLayoutIcon = icons[PowerProfiles.profile] ?? "";
            GlobalStates.osdLayoutLabel = Translation.tr("Switched to %1").arg(names[PowerProfiles.profile] ?? "");
            root.protectionMessage = "";
            root.currentIndicator = "layout";
            root.triggerOsd();
        }
    }

    Connections {
        // Listen to volume changes
        target: Audio.sink?.audio ?? null
        function onVolumeChanged() {
            if (!Audio.ready)
                return;
            root.currentIndicator = "volume";
            root.triggerOsd();
        }
        function onMutedChanged() {
            if (!Audio.ready)
                return;
            root.currentIndicator = "volume";
            root.triggerOsd();
        }
    }

    Connections {
        // Listen to protection triggers
        target: Audio
        function onSinkProtectionTriggered(reason) {
            root.protectionMessage = reason;
            root.currentIndicator = "volume";
            root.triggerOsd();
        }
    }

    Loader {
        id: osdLoader
        active: root.windowActive

        sourceComponent: PanelWindow {
            id: osdRoot
            color: "transparent"

            Connections {
                target: root
                function onFocusedScreenChanged() {
                    osdRoot.screen = root.focusedScreen;
                }
            }

            WlrLayershell.namespace: "quickshell:onScreenDisplay"
            WlrLayershell.layer: WlrLayer.Overlay
            anchors {
                top: !Config.options.bar.bottom
                bottom: Config.options.bar.bottom
            }
            mask: Region {
                item: osdValuesWrapper
            }

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            margins {
                top: Appearance.sizes.barHeight
                bottom: Appearance.sizes.barHeight
            }

            implicitWidth: columnLayout.implicitWidth
            implicitHeight: columnLayout.implicitHeight
            visible: osdLoader.active

            ColumnLayout {
                id: columnLayout
                anchors.horizontalCenter: parent.horizontalCenter

                // Unified pop animation for every OSD indicator: fade + spring-scale from the top edge
                property bool shown: GlobalStates.osdVolumeOpen
                transformOrigin: Item.Top
                opacity: shown ? 1 : 0
                scale: shown ? 1 : 0.8
                Behavior on opacity {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: columnLayout.shown ? 320 : 200
                        easing.type: columnLayout.shown ? Easing.OutBack : Easing.InCubic
                        easing.overshoot: 1.6
                    }
                }

                Item {
                    id: osdValuesWrapper
                    // Extra space for shadow
                    implicitHeight: contentColumnLayout.implicitHeight
                    implicitWidth: contentColumnLayout.implicitWidth
                    clip: true

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: GlobalStates.osdVolumeOpen = false
                    }

                    Column {
                        id: contentColumnLayout
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                        }
                        spacing: 0

                        Loader {
                            id: osdIndicatorLoader
                            source: root.indicators.find(i => i.id === root.currentIndicator)?.sourceUrl
                        }

                        Item {
                            id: protectionMessageWrapper
                            anchors.horizontalCenter: parent.horizontalCenter
                            implicitHeight: protectionMessageBackground.implicitHeight
                            implicitWidth: protectionMessageBackground.implicitWidth
                            opacity: root.protectionMessage !== "" ? 1 : 0

                            StyledRectangularShadow {
                                target: protectionMessageBackground
                            }
                            Rectangle {
                                id: protectionMessageBackground
                                anchors.centerIn: parent
                                color: Appearance.m3colors.m3error
                                property real padding: 10
                                implicitHeight: protectionMessageRowLayout.implicitHeight + padding * 2
                                implicitWidth: protectionMessageRowLayout.implicitWidth + padding * 2
                                radius: Appearance.rounding.normal

                                RowLayout {
                                    id: protectionMessageRowLayout
                                    anchors.centerIn: parent
                                    MaterialSymbol {
                                        id: protectionMessageIcon
                                        text: "dangerous"
                                        iconSize: Appearance.font.pixelSize.hugeass
                                        color: Appearance.m3colors.m3onError
                                    }
                                    StyledText {
                                        id: protectionMessageTextWidget
                                        horizontalAlignment: Text.AlignHCenter
                                        color: Appearance.m3colors.m3onError
                                        wrapMode: Text.Wrap
                                        text: root.protectionMessage
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "osdVolume"

        function trigger() {
            root.triggerOsd();
        }

        function layout(label: string) {
            GlobalStates.osdLayoutIcon = "";
            GlobalStates.osdLayoutLabel = label;
            root.protectionMessage = "";
            root.currentIndicator = "layout";
            root.triggerOsd();
        }

        // Same pill as layout(), with a Material symbol before the label
        function layoutIcon(icon: string, label: string) {
            GlobalStates.osdLayoutIcon = icon;
            GlobalStates.osdLayoutLabel = label;
            root.protectionMessage = "";
            root.currentIndicator = "layout";
            root.triggerOsd();
        }

        function hide() {
            GlobalStates.osdVolumeOpen = false;
        }

        function toggle() {
            GlobalStates.osdVolumeOpen = !GlobalStates.osdVolumeOpen;
        }
    }
    GlobalShortcut {
        name: "osdVolumeTrigger"
        description: "Triggers volume OSD on press"

        onPressed: {
            root.triggerOsd();
        }
    }
    GlobalShortcut {
        name: "osdVolumeHide"
        description: "Hides volume OSD on press"

        onPressed: {
            GlobalStates.osdVolumeOpen = false;
        }
    }
}
