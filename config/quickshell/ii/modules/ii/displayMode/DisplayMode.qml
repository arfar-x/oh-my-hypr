import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// GNOME-style display mode picker (Super+P). Same card-strip look as the Alt+Tab switcher.
// Hyprland binds drive it over IPC, exactly like the Alt+Tab picker (see custom/keybinds.lua):
//   displayMode open   - show the picker with the current mode selected; again while open = next card
//   displayMode next / prev / left / right
//   displayMode confirm - apply the selected mode (bound to Super release)
//   displayMode cancel
// Hold Super: P cycles, arrows move, release Super applies, Esc cancels. Click a card to apply too.
// Applying runs custom/scripts/display-mode.sh <mode>, which does the actual monitor changes.
Scope {
    id: root

    property bool shown: false
    property int index: 0
    property int monitorCount: 0
    property string primary: ""
    property string secondary: ""
    property string current: "join"
    property bool loading: false   // waiting for monitor info
    property bool aborted: false   // Super was released before the info arrived

    // left/right = state of the two monitor glyphs: "on" | "off"; mirror draws them stacked
    readonly property var modes: [
        { id: "join",      title: Translation.tr("Join Displays"), sub: Translation.tr("Extend across both"), left: "on",  right: "on",  mirror: false },
        { id: "mirror",    title: Translation.tr("Mirror"),        sub: Translation.tr("Same on both"),      left: "on",  right: "on",  mirror: true },
        { id: "primary",   title: Translation.tr("Primary Only"),  sub: root.primary,                        left: "on",  right: "off", mirror: false },
        { id: "secondary", title: Translation.tr("Secondary Only"), sub: root.secondary,                     left: "off", right: "on",  mirror: false }
    ]

    function open() {
        if (root.shown) { root.step(1); return; }
        if (root.loading) return;
        root.loading = true;
        root.aborted = false;
        infoProc.running = true;
    }
    function step(dir) {
        if (!root.shown) return;
        root.index = (root.index + dir + root.modes.length) % root.modes.length;
    }
    function close() {
        if (root.loading) root.aborted = true;
        root.shown = false;
        failsafe.stop();
    }
    function confirm() {
        if (root.shown) root.apply(root.index);
        else if (root.loading) root.aborted = true;
    }
    function apply(i) {
        const mode = root.modes[i];
        root.shown = false;
        failsafe.stop();
        if (mode) Quickshell.execDetached(["bash", "-c", `~/.config/hypr/custom/scripts/display-mode.sh ${mode.id}`]);
    }

    // `display-mode.sh info` -> count / primary / secondary
    Process {
        id: infoProc
        command: ["bash", "-c", "~/.config/hypr/custom/scripts/display-mode.sh info"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                if (root.aborted) { root.aborted = false; return; }
                const info = {};
                for (const line of text.split("\n")) {
                    const eq = line.indexOf("=");
                    if (eq > 0) info[line.slice(0, eq)] = line.slice(eq + 1).trim();
                }
                root.monitorCount = parseInt(info.count) || 0;
                root.primary = info.primary ?? "";
                root.secondary = info.secondary ?? "";
                root.current = info.current ?? "join";
                if (root.monitorCount < 2) {
                    // Nothing to choose from; tell the user with the same OSD pill the layout switch uses.
                    Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "osdVolume", "layoutIcon", "monitor", Translation.tr("Only one display")]);
                    return;
                }
                root.index = Math.max(0, root.modes.findIndex(m => m.id === root.current));
                root.shown = true;
                failsafe.restart();
            }
        }
    }

    Timer { id: failsafe; interval: 15000; onTriggered: root.close() } // missed Super release

    IpcHandler {
        target: "displayMode"
        function open(): void { root.open(); }
        function next(): void { root.step(1); }
        function prev(): void { root.step(-1); }
        function left(): void { root.step(-1); }
        function right(): void { root.step(1); }
        function confirm(): void { root.confirm(); }
        function cancel(): void { root.close(); }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: panel
            required property var modelData
            visible: root.shown || strip.opacity > 0
            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:displayMode"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { top: true; bottom: true; left: true; right: true }

            MouseArea { // click outside cancels
                anchors.fill: parent
                enabled: root.shown
                onClicked: root.close()
            }

            Rectangle {
                id: strip
                anchors.centerIn: parent
                readonly property real cardW: 190
                readonly property real cardH: 170
                width: root.modes.length * (cardW + 12) - 12 + 40
                height: cardH + 40
                radius: Appearance.rounding.large
                color: ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainerLow, 0.2)
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                opacity: root.shown ? 1 : 0
                scale: root.shown ? 1 : 0.94
                Behavior on opacity { NumberAnimation { duration: root.shown ? 120 : 80; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: root.shown ? 140 : 80; easing.type: Easing.OutCubic } }

                Row {
                    anchors.centerIn: parent
                    spacing: 12

                    Repeater {
                        model: root.modes
                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            required property int index
                            readonly property bool selected: index === root.index
                            width: strip.cardW
                            height: strip.cardH
                            radius: Appearance.rounding.normal
                            color: selected ? ColorUtils.transparentize(Appearance.colors.colLayer2Active, 0.25)
                                : ColorUtils.transparentize(Appearance.colors.colLayer1, 0.45)
                            border.width: selected ? 2 : 1
                            border.color: selected ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                            Behavior on color { ColorAnimation { duration: 100 } }

                            ColumnLayout {
                                anchors { fill: parent; margins: 12 }
                                spacing: 8

                                // Monitor glyph: two screens, filled = in use, outline = off, stacked = mirrored
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Item {
                                        id: glyph
                                        anchors.centerIn: parent
                                        width: 120; height: 64
                                        readonly property color onColor: card.selected ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                                        readonly property color offColor: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.65)

                                        component Screen: Rectangle {
                                            property bool lit: true
                                            width: 54; height: 38; radius: 5
                                            color: lit ? ColorUtils.transparentize(glyph.onColor, 0.65) : "transparent"
                                            border.width: 2
                                            border.color: lit ? glyph.onColor : glyph.offColor
                                            Rectangle { // stand
                                                anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: 3 }
                                                width: 18; height: 3; radius: 1.5
                                                color: parent.border.color
                                            }
                                        }

                                        Screen { // left / primary (back one when mirrored)
                                            x: card.modelData.mirror ? 30 : 0
                                            y: card.modelData.mirror ? 0 : 6
                                            lit: card.modelData.left === "on"
                                        }
                                        Screen { // right / secondary (front one when mirrored)
                                            x: card.modelData.mirror ? 36 : 66
                                            y: card.modelData.mirror ? 10 : 6
                                            lit: card.modelData.right === "on"
                                            z: 1
                                        }
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: card.modelData.title
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnLayer1
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: card.modelData.sub
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.index = card.index
                                onClicked: root.apply(card.index)
                            }
                        }
                    }
                }
            }
        }
    }
}
