pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Browsable launcher shown while the search bar is empty:
// category chips, a pinned row (All only) and the app list.
ColumnLayout {
    id: root

    property Item upTarget
    property int maxListHeight: 680
    property string category: "" // "" means All
    readonly property Item list: appList
    readonly property int count: appList.count

    readonly property var categoryLabels: ({
        "AudioVideo": Translation.tr("Media"),
        "Development": Translation.tr("Development"),
        "Education": Translation.tr("Education"),
        "Game": Translation.tr("Games"),
        "Graphics": Translation.tr("Graphics"),
        "Network": Translation.tr("Internet"),
        "Office": Translation.tr("Office"),
        "Science": Translation.tr("Science"),
        "Settings": Translation.tr("Settings"),
        "System": Translation.tr("System"),
        "Utility": Translation.tr("Utilities")
    })
    readonly property var pinnedResults: (Config.options.launcher.pinnedApps ?? [])
        .map(id => LauncherSearch.allApps.find(result => result.id === id))
        .filter(Boolean)
    readonly property var shownApps: LauncherSearch.allApps.filter(result => root.category === "" || (LauncherSearch.appCategoryMap[result.id] ?? []).includes(root.category))
    function letterOf(name) {
        const first = (name ?? "").charAt(0).toUpperCase();
        return /[A-Z]/.test(first) ? first : "#";
    }
    readonly property bool showPinned: category === "" && pinnedResults.length > 0

    spacing: 0

    // Sections cascade in when the overview opens (see `enter` on each section)
    readonly property bool shown: GlobalStates.overviewOpen
    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            if (GlobalStates.overviewOpen) {
                root.category = "";
                appList.currentIndex = -1;
                appList.positionViewAtBeginning();
                chips.positionViewAtBeginning();
            }
        }
    }

    ListView { // Category chips
        id: chips
        Layout.fillWidth: true
        Layout.topMargin: 8
        Layout.leftMargin: 10
        Layout.rightMargin: 10
        implicitHeight: 32
        orientation: ListView.Horizontal
        spacing: 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: [""].concat(LauncherSearch.appCategories)

        property real enter: root.shown ? 1 : 0
        Behavior on enter {
            SequentialAnimation {
                PauseAnimation { duration: root.shown ? 0 : 0 }
                NumberAnimation {
                    duration: 260
                    easing.type: Appearance.animation.elementMove.type
                    easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                }
            }
        }
        opacity: enter
        transform: Translate { y: (1 - chips.enter) * 14 }

        WheelHandler { // Vertical wheel scrolls the chips sideways
            onWheel: event => {
                const max = Math.max(0, chips.contentWidth - chips.width);
                chips.contentX = Math.max(0, Math.min(max, chips.contentX - event.angleDelta.y));
            }
        }

        delegate: RippleButton {
            id: chip
            required property string modelData
            required property int index
            readonly property bool active: root.category === modelData
            implicitHeight: 32
            implicitWidth: chipLabel.implicitWidth + 24
            buttonRadius: Appearance.rounding.full
            toggled: active
            colBackground: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 1)
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            colBackgroundToggled: Appearance.colors.colSecondaryContainer
            colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
            onClicked: root.category = modelData

            contentItem: StyledText {
                id: chipLabel
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Appearance.font.pixelSize.small
                text: chip.modelData === "" ? Translation.tr("All") : (root.categoryLabels[chip.modelData] ?? chip.modelData)
                color: chip.active ? Appearance.colors.colOnSecondaryContainer : Appearance.m3colors.m3onSurfaceVariant
                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
            }
        }
    }

    Item { // Pinned row, folds away outside the All tab
        id: pinnedWrap
        Layout.fillWidth: true
        clip: true
        implicitHeight: root.showPinned ? pinnedRow.implicitHeight + 16 : 0
        property real enter: root.shown ? 1 : 0
        property real pinnedFactor: root.showPinned ? 1 : 0
        Behavior on enter {
            SequentialAnimation {
                PauseAnimation { duration: root.shown ? 45 : 0 }
                NumberAnimation {
                    duration: 260
                    easing.type: Appearance.animation.elementMove.type
                    easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                }
            }
        }
        opacity: enter * pinnedFactor
        transform: Translate { y: (1 - pinnedWrap.enter) * 14 }
        Behavior on implicitHeight {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }
        Behavior on pinnedFactor {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        Row {
            id: pinnedRow
            anchors {
                top: parent.top
                topMargin: 10
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 8

            Repeater {
                model: root.pinnedResults

                delegate: RippleButton {
                    id: pin
                    required property var modelData
                    required property int index
                    readonly property bool shown: GlobalStates.overviewOpen && root.showPinned
                    implicitWidth: 68
                    implicitHeight: 68
                    buttonRadius: Appearance.rounding.normal
                    colBackground: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 1)
                    colBackgroundHover: Appearance.colors.colPrimaryContainer
                    colRipple: Appearance.colors.colPrimaryContainerActive
                    onClicked: {
                        GlobalStates.overviewOpen = false;
                        pin.modelData.execute();
                    }

                    // Staggered pop-in whenever the overview opens
                    opacity: shown ? 1 : 0
                    scale: shown ? 1 : 0.7
                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation { duration: pin.shown ? 40 + pin.index * 35 : 0 }
                            NumberAnimation {
                                duration: Appearance.animation.elementMove.duration
                                easing.type: Appearance.animation.elementMove.type
                                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                            }
                        }
                    }
                    Behavior on scale {
                        SequentialAnimation {
                            PauseAnimation { duration: pin.shown ? 40 + pin.index * 35 : 0 }
                            NumberAnimation {
                                duration: Appearance.animation.elementMove.duration
                                easing.type: Appearance.animation.elementMove.type
                                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                            }
                        }
                    }

                    contentItem: ColumnLayout {
                        spacing: 4
                        IconImage {
                            Layout.alignment: Qt.AlignHCenter
                            implicitSize: 34
                            source: Quickshell.iconPath(pin.modelData.iconName, "image-missing")
                        }
                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.m3colors.m3onSurface
                            text: pin.modelData.name
                        }
                    }
                }
            }
        }
    }

    ListView { // All apps in the current category
        id: appList
        Layout.fillWidth: true
        implicitHeight: Math.min(root.maxListHeight, appList.contentHeight + topMargin + bottomMargin)
        topMargin: 8
        bottomMargin: 10
        spacing: 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        maximumFlickVelocity: 3500
        highlightMoveDuration: 100
        KeyNavigation.up: root.upTarget
        ScrollBar.vertical: StyledScrollBar {}

        property real enter: root.shown ? 1 : 0
        Behavior on enter {
            SequentialAnimation {
                PauseAnimation { duration: root.shown ? 90 : 0 }
                NumberAnimation {
                    duration: 260
                    easing.type: Appearance.animation.elementMove.type
                    easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                }
            }
        }
        opacity: enter
        transform: Translate { y: (1 - appList.enter) * 14 }

        onFocusChanged: {
            if (focus && currentIndex < 0)
                currentIndex = 0;
        }

        // Natural scrolling: content follows the touchpad/wheel 1:1, then keeps gliding
        // with decaying momentum after the fingers lift (the stock list animates every
        // contentY change, which kills the feel of pulling the content).
        property real glideVelocity: 0 // px per ms
        property real glideTauNow: 1100 // ms, set per swipe: faster pulls coast longer
        property real lastWheelTime: 0
        property real lastTickTime: 0
        property var wheelSamples: [] // recent {t, d} movements, used to measure how fast the pull was
        readonly property real glideTau: 1100 // ms; base coast length, higher = longer glide
        readonly property real swipeWindow: 100 // ms of recent movement that defines the pull speed
        function scrollBy(delta) {
            const minY = -appList.topMargin;
            const maxY = Math.max(minY, appList.contentHeight - appList.height + appList.bottomMargin);
            const next = Math.max(minY, Math.min(maxY, appList.contentY + delta));
            if (next === minY || next === maxY)
                appList.glideVelocity = 0;
            appList.contentY = next;
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const now = Date.now();
                const hasPixels = event.pixelDelta.y !== 0;
                const wheelNotch = !hasPixels && Math.abs(event.angleDelta.y) >= 120;
                const delta = hasPixels ? -event.pixelDelta.y : -event.angleDelta.y / 120 * 70;
                appList.scrollBy(delta);

                // Pull speed = distance moved over the last swipeWindow ms
                const samples = appList.wheelSamples.filter(sample => now - sample.t < appList.swipeWindow);
                samples.push({ t: now, d: delta });
                appList.wheelSamples = samples;
                const moved = samples.reduce((sum, sample) => sum + sample.d, 0);
                const speed = wheelNotch ? delta / 100 : moved / appList.swipeWindow;
                appList.glideVelocity = Math.max(-2.5, Math.min(2.5, speed));
                // Slow pulls settle sooner, fast pulls carry on for much longer
                appList.glideTauNow = appList.glideTau * (0.7 + 0.1 * Math.abs(appList.glideVelocity));
                appList.lastWheelTime = now;
                appList.lastTickTime = now;
                glideTimer.start();
            }
        }
        Timer {
            id: glideTimer
            interval: 16
            repeat: true
            onTriggered: {
                const now = Date.now();
                if (now - appList.lastWheelTime < 45) {
                    appList.lastTickTime = now; // fingers still moving
                    return;
                }
                const dt = Math.min(50, now - appList.lastTickTime);
                appList.lastTickTime = now;
                appList.scrollBy(appList.glideVelocity * dt);
                appList.glideVelocity *= Math.exp(-dt / appList.glideTauNow);
                if (Math.abs(appList.glideVelocity) < 0.02) {
                    appList.glideVelocity = 0;
                    appList.wheelSamples = [];
                    glideTimer.stop();
                }
            }
        }

        add: Transition {
            NumberAnimation {
                properties: "opacity,scale"
                from: 0
                to: 1
                duration: 220
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }
        displaced: Transition {
            NumberAnimation {
                properties: "y"
                duration: 220
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }

        model: ScriptModel {
            objectProp: "id"
            values: root.shownApps
        }

        delegate: SearchItem {
            required property var modelData
            required property int index
            anchors.left: parent?.left
            anchors.right: parent?.right
            entry: modelData
            query: ""
            // Alphabetical grouping in the All tab: the first app of each letter carries the header
            sectionLabel: {
                if (root.category !== "")
                    return "";
                const letter = root.letterOf(modelData.name);
                return (index === 0 || root.letterOf(root.shownApps[index - 1]?.name) !== letter) ? letter : "";
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    keyboardDown = true;
                    clicked();
                    event.accepted = true;
                }
            }
        }
    }
}
