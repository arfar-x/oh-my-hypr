import qs.modules.ii.bar.weather
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item { // Bar content region
    id: root

    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
    property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen?.width) ? 2 : (Appearance.sizes.barShortenScreenWidthThreshold >= screen?.width) ? 1 : 0
    // The two centre groups are narrowed by room for three more icons (3 x 39px) so the right-hand icon container is wider
    readonly property int centerSideModuleWidth: (useShortenedForm == 2) ? Appearance.sizes.barCenterSideModuleWidthHellaShortened : (useShortenedForm == 1) ? Appearance.sizes.barCenterSideModuleWidthShortened : Math.max(Appearance.sizes.barCenterSideModuleWidth - 117, 200)

    component VerticalBarSeparator: Rectangle {
        Layout.topMargin: Appearance.sizes.baseBarHeight / 3
        Layout.bottomMargin: Appearance.sizes.baseBarHeight / 3
        Layout.fillHeight: true
        implicitWidth: 1
        color: Appearance.colors.colOutlineVariant
    }

    // Background shadow
    Loader {
        active: Config.options.bar.showBackground && Config.options.bar.cornerStyle === 1 && Config.options.bar.floatStyleShadow
        anchors.fill: barBackground
        sourceComponent: StyledRectangularShadow {
            anchors.fill: undefined // The loader's anchors act on this, and this should not have any anchor
            target: barBackground
        }
    }
    // Background
    Rectangle {
        id: barBackground
        anchors {
            fill: parent
            margins: Config.options.bar.cornerStyle === 1 ? (Appearance.sizes.hyprlandGapsOut) : 0 // idk why but +1 is needed
        }
        color: Config.options.bar.showBackground ? Appearance.colors.colLayer0 : "transparent"
        radius: Config.options.bar.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: Config.options.bar.cornerStyle === 1 ? 1 : 0
        border.color: Appearance.colors.colLayer0Border
    }

    FocusedScrollMouseArea { // Left side | scroll to change brightness
        id: barLeftSideMouseArea

        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            right: middleSection.left
        }
        implicitWidth: leftSectionRowLayout.implicitWidth
        implicitHeight: Appearance.sizes.baseBarHeight

        onScrollDown: Brightness.decreaseBrightness()
        onScrollUp: Brightness.increaseBrightness()
        onMovedAway: GlobalStates.osdBrightnessOpen = false
        onPressed: event => {
            if (event.button === Qt.LeftButton)
                GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
        }

        // Visual content
        ScrollHint {
            reveal: barLeftSideMouseArea.hovered
            icon: Hyprsunset.gamma === 100 ? "light_mode" : "wb_twilight"
            tooltipText: Translation.tr("Scroll to change brightness")
            side: "left"
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        RowLayout {
            id: leftSectionRowLayout
            anchors.fill: parent
            spacing: 0

            LeftSidebarButton { // Left sidebar button
                id: leftSidebarButton
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: Appearance.rounding.screenRounding
                colBackground: barLeftSideMouseArea.hovered ? Appearance.colors.colLayer1Hover : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
            }

            ActiveWindow {
                Layout.leftMargin: 10 + (leftSidebarButton.visible ? 0 : Appearance.rounding.screenRounding)
                Layout.rightMargin: Appearance.rounding.screenRounding
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.useShortenedForm === 0
            }
        }
    }

    Row { // Middle section
        id: middleSection
        anchors {
            top: parent.top
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }
        spacing: 4

        BarGroup {
            id: leftCenterGroup
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: root.centerSideModuleWidth

            Resources {
                alwaysShowAllResources: root.useShortenedForm === 2
                Layout.fillWidth: root.useShortenedForm === 2
            }

            Media {
                visible: root.useShortenedForm < 2
                Layout.fillWidth: true
            }
        }

        VerticalBarSeparator {
            visible: Config.options?.bar.borderless
        }

        BarGroup {
            id: middleCenterGroup
            anchors.verticalCenter: parent.verticalCenter
            padding: workspacesWidget.widgetPadding

            Workspaces {
                id: workspacesWidget
                Layout.fillHeight: true
                MouseArea {
                    // Right-click to toggle overview
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton

                    onPressed: event => {
                        if (event.button === Qt.RightButton) {
                            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
                        }
                    }
                }
            }
        }

        VerticalBarSeparator {
            visible: Config.options?.bar.borderless
        }

        MouseArea {
            id: rightCenterGroup
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: root.centerSideModuleWidth
            implicitHeight: rightCenterGroupContent.implicitHeight

            onPressed: {
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            }

            BarGroup {
                id: rightCenterGroupContent
                anchors.fill: parent

                ClockWidget {
                    showDate: (Config.options.bar.verbose && root.useShortenedForm < 2)
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                }

                UtilButtons {
                    visible: (Config.options.bar.verbose && root.useShortenedForm === 0)
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }

    FocusedScrollMouseArea { // Right side | scroll to change volume
        id: barRightSideMouseArea

        anchors {
            top: parent.top
            bottom: parent.bottom
            left: middleSection.right
            right: parent.right
        }
        implicitWidth: rightSectionRowLayout.implicitWidth
        implicitHeight: Appearance.sizes.baseBarHeight

        onScrollDown: Audio.decrementVolume();
        onScrollUp: Audio.incrementVolume();
        onMovedAway: GlobalStates.osdVolumeOpen = false;
        onPressed: event => {
            if (event.button === Qt.LeftButton) {
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            }
        }

        // Visual content
        ScrollHint {
            reveal: barRightSideMouseArea.hovered
            icon: "volume_up"
            tooltipText: Translation.tr("Scroll to change volume")
            side: "right"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }

        // The icons that may overflow. Each lives in a slot of the bar, or of the dropdown while hidden.
            RippleButton { // Network button
                parent: rightSectionRowLayout.hiddenFlags[0] ? dropSlot0 : mainSlot0
                anchors.centerIn: parent
                id: networkButton
                implicitWidth: networkIcons.implicitWidth + 16
                implicitHeight: 28
                buttonRadius: Appearance.rounding.full
                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colRipple: Appearance.colors.colLayer1Active
                colBackgroundToggled: Appearance.colors.colSecondaryContainer
                colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                colRippleToggled: Appearance.colors.colSecondaryContainerActive
                toggled: GlobalStates.networkPopupOpen && GlobalStates.networkPopupScreen === (root.screen?.name ?? "")
                onPressed: {
                    const name = root.screen?.name ?? "";
                    // Clicking this screen's icon while its popup is open closes it; otherwise open it on this screen
                    const closing = GlobalStates.networkPopupOpen && GlobalStates.networkPopupScreen === name;
                    GlobalStates.networkPopupScreen = name;
                    GlobalStates.networkPopupOpen = !closing;
                }

                contentItem: Item {
                    implicitWidth: networkIcons.implicitWidth
                    implicitHeight: networkIcons.implicitHeight
                    RowLayout {
                        id: networkIcons
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignVCenter
                            text: Network.materialSymbol
                            iconSize: Appearance.font.pixelSize.larger
                            color: networkButton.toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer0
                        }
                        MaterialSymbol { // VPN connected indicator (part of the same button)
                            Layout.alignment: Qt.AlignVCenter
                            visible: Network.vpnActive
                            text: "vpn_lock"
                            fill: 1
                            iconSize: Appearance.font.pixelSize.larger
                            color: networkButton.toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.m3colors.m3primary
                        }
                    }
                }

                NetworkPopup {
                    anchorItem: networkButton
                }
            }

            MaterialSymbol { // Bluetooth (only while enabled)
                id: btIcon
                parent: rightSectionRowLayout.hiddenFlags[1] ? dropSlot1 : mainSlot1
                anchors.centerIn: parent
                text: BluetoothStatus.connected ? "bluetooth_connected" : "bluetooth"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer0
            }

            MaterialSymbol { // Muted speaker
                id: muteIcon
                parent: rightSectionRowLayout.hiddenFlags[2] ? dropSlot2 : mainSlot2
                anchors.centerIn: parent
                text: "volume_off"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer0
            }

            MaterialSymbol { // Microphone (only while unmuted)
                id: micIcon
                parent: rightSectionRowLayout.hiddenFlags[3] ? dropSlot3 : mainSlot3
                anchors.centerIn: parent
                text: "mic"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer0
            }

            RippleButton { // Notifications (opens the right sidebar)
                parent: rightSectionRowLayout.hiddenFlags[5] ? dropSlot5 : mainSlot5
                anchors.centerIn: parent
                id: notificationButton
                implicitWidth: 34
                implicitHeight: 28
                buttonRadius: Appearance.rounding.full
                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colRipple: Appearance.colors.colLayer1Active
                onPressed: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen

                contentItem: Item {
                    NotificationUnreadCount {
                        anchors.centerIn: parent
                    }
                }
            }

        RowLayout {
            id: rightSectionRowLayout
            anchors.fill: parent
            spacing: 5
            layoutDirection: Qt.RightToLeft

            // Icons that do not fit in the container move into an "etc" dropdown, leftmost first:
            // microphone, notifications, tray items (one by one), muted speaker, bluetooth, network.
            // The language indicator, battery and sidebar toggle never move.
            readonly property var slotItems: [networkButton, btIcon, muteIcon, micIcon, trayItem, notificationButton, rightSidebarButton]
            readonly property var wants: [
                true,
                BluetoothStatus.available && BluetoothStatus.enabled,
                Audio.sink?.audio?.muted ?? false,
                Audio.source !== null && !(Audio.source?.audio?.muted ?? true),
                root.useShortenedForm === 0,
                true,
                HyprlandXkb.layoutCodes.length > 1
            ]
            property var hiddenFlags: [false, false, false, false, false, false, false]
            property int hiddenTray: 0
            readonly property bool anyHidden: hiddenFlags.some(f => f) || hiddenTray > 0
            property bool moreOpen: false

            // Evaluated on a short timer after layout changes, so the measurements are settled
            // (evaluating synchronously while the layout is still updating made the result flip-flop).
            Timer {
                id: overflowTimer
                interval: 40
                onTriggered: rightSectionRowLayout.computeOverflow()
            }
            property real changeWindowStart: 0
            property int changeCount: 0
            property real frozenAtWidth: -1
            function updateOverflow() {
                if (frozenAtWidth >= 0 && Math.abs(barRightSideMouseArea.width - frozenAtWidth) < 1) return;
                frozenAtWidth = -1;
                overflowTimer.restart();
            }

            function computeOverflow() {
                const sp = spacing;
                const trayItemW = 35; // icon (20) + grid spacing (15)
                const w = i => wants[i] ? slotItems[i].implicitWidth + sp : 0;
                const slots = [0, 1, 2, 3, 5];
                const moreW = moreButton.implicitWidth + sp;
                const trayW = wants[4] ? trayItem.implicitWidth + sp : 0;
                const trayCount = wants[4] ? trayItem.pinnedItems.length : 0;
                let current = trayW + (anyHidden ? moreW : 0);
                for (const i of slots) if (!hiddenFlags[i]) current += w(i);
                const base = implicitWidth - current;
                let fullTotal = base + trayW + hiddenTray * trayItemW;
                for (const i of slots) fullTotal += w(i);
                const order = [3, 5, 4, 2, 1, 0]; // hide order; 4 = tray items

                // returns {flags, tray, steps} for the given available width
                const solve = avail => {
                    const flags = [false, false, false, false, false, false, false];
                    let tray = 0, steps = 0, total = fullTotal;
                    if (total > avail) {
                        total += moreW;
                        for (const i of order) {
                            if (total <= avail) break;
                            if (!wants[i]) continue;
                            if (i === 4) {
                                while (tray < trayCount && total > avail) { tray++; steps++; total -= trayItemW; }
                            } else {
                                flags[i] = true; steps++;
                                total -= w(i);
                            }
                        }
                    }
                    return { flags: flags, tray: tray, steps: steps };
                };
                const avail = barRightSideMouseArea.width;
                const currentSteps = hiddenFlags.filter(f => f).length + hiddenTray;
                let result = solve(avail);
                if (result.steps < currentSteps) {
                    // un-hiding needs some spare room (hysteresis), otherwise keep the current state
                    const tight = solve(avail - 12);
                    result = tight.steps < currentSteps ? tight : { flags: hiddenFlags.slice(), tray: hiddenTray, steps: currentSteps };
                }
                const changed = result.flags.some((f, i) => f !== hiddenFlags[i]) || result.tray !== hiddenTray;
                if (changed) {
                    // Safety net: never let a measurement feedback loop spin; after a burst of
                    // changes, stop re-evaluating until the available width changes again.
                    const now = Date.now();
                    if (now - changeWindowStart > 2000) { changeWindowStart = now; changeCount = 0; }
                    if (++changeCount > 6) { frozenAtWidth = barRightSideMouseArea.width; return; }
                    hiddenFlags = result.flags;
                    hiddenTray = result.tray;
                }
                if (result.steps === 0 && moreOpen) moreOpen = false;
            }
            onImplicitWidthChanged: updateOverflow()
            onWantsChanged: updateOverflow()
            Component.onCompleted: updateOverflow()
            Connections {
                target: barRightSideMouseArea
                function onWidthChanged() { rightSectionRowLayout.updateOverflow() }
            }
            Connections {
                target: trayItem
                function onPinnedItemsChanged() { rightSectionRowLayout.updateOverflow() }
            }
            Repeater {
                model: rightSectionRowLayout.slotItems
                delegate: Item {
                    required property var modelData
                    Connections {
                        target: modelData
                        function onImplicitWidthChanged() { rightSectionRowLayout.updateOverflow() }
                    }
                }
            }

            RippleButton { // Right sidebar toggle (rightmost)
                id: sidebarToggleButton
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.fillWidth: false
                Layout.rightMargin: -2
                implicitWidth: 26
                implicitHeight: 28
                buttonRadius: Appearance.rounding.full
                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colRipple: Appearance.colors.colLayer1Active
                colBackgroundToggled: Appearance.colors.colSecondaryContainer
                colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                colRippleToggled: Appearance.colors.colSecondaryContainerActive
                toggled: GlobalStates.sidebarRightOpen
                onPressed: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: GlobalStates.sidebarRightOpen ? "right_panel_close" : "right_panel_open"
                    iconSize: Appearance.font.pixelSize.larger
                    color: sidebarToggleButton.toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer0
                }
            }

            BatteryIndicator {
                visible: (root.useShortenedForm < 2 && Battery.available)
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }

            Item {
                id: mainSlot0
                visible: rightSectionRowLayout.wants[0] && !rightSectionRowLayout.hiddenFlags[0]
                Layout.fillWidth: false
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: rightSectionRowLayout.slotItems[0].implicitWidth
                implicitHeight: Appearance.sizes.baseBarHeight
            }
            Item {
                id: mainSlot1
                visible: rightSectionRowLayout.wants[1] && !rightSectionRowLayout.hiddenFlags[1]
                Layout.fillWidth: false
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: rightSectionRowLayout.slotItems[1].implicitWidth
                implicitHeight: Appearance.sizes.baseBarHeight
            }
            Item {
                id: mainSlot2
                visible: rightSectionRowLayout.wants[2] && !rightSectionRowLayout.hiddenFlags[2]
                Layout.fillWidth: false
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: rightSectionRowLayout.slotItems[2].implicitWidth
                implicitHeight: Appearance.sizes.baseBarHeight
            }
            SysTray {
                id: trayItem
                visible: rightSectionRowLayout.wants[4]
                Layout.alignment: Qt.AlignRight
                Layout.fillWidth: false
                Layout.fillHeight: true
                invertSide: Config?.options.bar.bottom
                hideFirst: rightSectionRowLayout.hiddenTray
            }

            Item {
                id: mainSlot5
                visible: rightSectionRowLayout.wants[5] && !rightSectionRowLayout.hiddenFlags[5]
                Layout.fillWidth: false
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: rightSectionRowLayout.slotItems[5].implicitWidth
                implicitHeight: Appearance.sizes.baseBarHeight
            }
            Item {
                id: mainSlot3
                visible: rightSectionRowLayout.wants[3] && !rightSectionRowLayout.hiddenFlags[3]
                Layout.fillWidth: false
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: rightSectionRowLayout.slotItems[3].implicitWidth
                implicitHeight: Appearance.sizes.baseBarHeight
            }

            RippleButton { // "etc" dropdown button: left end of the icon container
                id: moreButton
                visible: rightSectionRowLayout.anyHidden
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.fillWidth: false
                implicitWidth: 34
                implicitHeight: 28
                buttonRadius: Appearance.rounding.full
                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colRipple: Appearance.colors.colLayer1Active
                colBackgroundToggled: Appearance.colors.colSecondaryContainer
                colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                colRippleToggled: Appearance.colors.colSecondaryContainerActive
                toggled: rightSectionRowLayout.moreOpen
                onPressed: rightSectionRowLayout.moreOpen = !rightSectionRowLayout.moreOpen

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "more_horiz"
                    iconSize: Appearance.font.pixelSize.larger
                    color: moreButton.toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer0
                }
            }

            RippleButton { // Language / keyboard layout button
                id: rightSidebarButton
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.fillWidth: false
                visible: HyprlandXkb.layoutCodes.length > 1
                implicitWidth: indicatorsRowLayout.implicitWidth + 10 * 2
                implicitHeight: indicatorsRowLayout.implicitHeight + 5 * 2

                buttonRadius: Appearance.rounding.full
                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colRipple: Appearance.colors.colLayer1Active
                colBackgroundToggled: Appearance.colors.colSecondaryContainer
                colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                colRippleToggled: Appearance.colors.colSecondaryContainerActive
                toggled: false
                property color colText: toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer0

                Behavior on colText {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }

                onPressed: {
                    if (HyprlandXkb.layoutCodes.length > 1)
                        Quickshell.execDetached(["bash", "-c", "~/.config/hypr/custom/scripts/switch-layout.sh"]);
                }

                RowLayout {
                    id: indicatorsRowLayout
                    anchors.centerIn: parent
                    property real realSpacing: 15
                    spacing: 0

                    HyprlandXkbIndicator {
                        Layout.alignment: Qt.AlignVCenter
                        color: rightSidebarButton.colText
                    }
                }
            }


            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // Public IP
            BarGroup {
                Layout.rightMargin: 4
                PublicIpWidget {}
            }

            // Weather
            Loader {
                Layout.leftMargin: 4
                active: Config.options.bar.weather.enable

                sourceComponent: BarGroup {
                    WeatherBar {}
                }
            }
        }

        PanelWindow { // click-away scrim for the "etc" dropdown (below the bar, so the bar stays usable)
            visible: rightSectionRowLayout.moreOpen
            screen: root.QsWindow.window?.screen ?? null
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            margins.top: Config.options.bar.bottom ? 0 : Appearance.sizes.barHeight
            margins.bottom: Config.options.bar.bottom ? Appearance.sizes.barHeight : 0
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:barOverflowScrim"
            WlrLayershell.layer: WlrLayer.Top
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: rightSectionRowLayout.moreOpen = false
            }
        }

        PanelWindow { // "etc" dropdown: hosts the icons that do not fit in the bar
            id: dropWindow
            screen: root.QsWindow.window?.screen ?? null
            visible: rightSectionRowLayout.moreOpen
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
            implicitHeight: dropBackground.implicitHeight + Appearance.sizes.elevationMargin * 2
            mask: Region { item: dropBackground }

            WlrLayershell.namespace: "quickshell:barOverflow"
            WlrLayershell.layer: WlrLayer.Overlay

            StyledRectangularShadow {
                target: dropBackground
            }

            Rectangle {
                id: dropBackground
                y: Appearance.sizes.elevationMargin
                x: {
                    const center = (dropWindow.visible && root.QsWindow) ? root.QsWindow.mapFromItem(moreButton, moreButton.width / 2, 0).x : dropWindow.width;
                    return Math.max(Appearance.sizes.elevationMargin, Math.min(center - width / 2, dropWindow.width - width - Appearance.sizes.elevationMargin));
                }
                implicitWidth: dropRow.implicitWidth + 20
                implicitHeight: dropRow.implicitHeight + 16
                color: Appearance.m3colors.m3surfaceContainer
                radius: Appearance.rounding.small
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                RowLayout {
                    id: dropRow
                    anchors.centerIn: parent
                    spacing: 5
                Item {
                    id: dropSlot0
                    visible: rightSectionRowLayout.wants[0] && rightSectionRowLayout.hiddenFlags[0]
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: rightSectionRowLayout.slotItems[0].implicitWidth
                    implicitHeight: 32
                }
                Item {
                    id: dropSlot1
                    visible: rightSectionRowLayout.wants[1] && rightSectionRowLayout.hiddenFlags[1]
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: rightSectionRowLayout.slotItems[1].implicitWidth
                    implicitHeight: 32
                }
                Item {
                    id: dropSlot2
                    visible: rightSectionRowLayout.wants[2] && rightSectionRowLayout.hiddenFlags[2]
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: rightSectionRowLayout.slotItems[2].implicitWidth
                    implicitHeight: 32
                }
                SysTray {
                    id: dropTray
                    visible: rightSectionRowLayout.hiddenTray > 0
                    Layout.alignment: Qt.AlignVCenter
                    showBase: false
                    showSeparator: false
                    showOverflowMenu: false
                    showOnlyFirst: rightSectionRowLayout.hiddenTray
                    invertSide: Config?.options.bar.bottom
                }
                Item {
                    id: dropSlot5
                    visible: rightSectionRowLayout.wants[5] && rightSectionRowLayout.hiddenFlags[5]
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: rightSectionRowLayout.slotItems[5].implicitWidth
                    implicitHeight: 32
                }
                Item {
                    id: dropSlot3
                    visible: rightSectionRowLayout.wants[3] && rightSectionRowLayout.hiddenFlags[3]
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: rightSectionRowLayout.slotItems[3].implicitWidth
                    implicitHeight: 32
                }
                }
            }
        }
    }
}
