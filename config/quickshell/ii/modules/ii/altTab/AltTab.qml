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
import Quickshell.Hyprland

// Alt+Tab window switcher. Hyprland binds drive it over IPC:
//   altTab next / prev  - open (if closed) and move the selection
//   altTab confirm      - focus the selected window (bound to Alt release)
//   altTab cancel
//   altTab left / right / up / down - move the selection with the arrow keys
// Minimized windows are listed too; focusing one restores it (see window.active hook).
Scope {
    id: root

    property bool active: false   // a switching session is in progress
    property bool shown: false    // card strip is visible (delayed so quick taps don't flash)
    property var entries: []
    property int index: 0

    function buildEntries() {
        HyprlandData.updateAll();
        const list = [];
        for (const t of ToplevelManager.toplevels.values) {
            const address = `0x${t.HyprlandToplevel?.address}`;
            const data = HyprlandData.windowByAddress[address];
            if (!data) continue;
            list.push({
                toplevel: t,
                address: address,
                title: data.title || t.title || data.class,
                appClass: data.class,
                minimized: data.workspace?.name === "special:minimized",
                workspace: data.workspace?.name ?? "",
                order: data.focusHistoryID ?? 9999
            });
        }
        list.sort((a, b) => a.order - b.order);
        return list;
    }

    function step(dir) {
        if (!root.active) {
            root.entries = root.buildEntries();
            if (root.entries.length === 0) return;
            root.active = true;
            root.index = dir > 0 ? Math.min(1, root.entries.length - 1) : root.entries.length - 1;
            showTimer.restart();
            failsafe.restart();
            return;
        }
        const n = root.entries.length;
        root.index = (root.index + dir + n) % n;
        root.shown = true; // cycling again means the user wants to see it
    }

    // Arrow-key navigation while Alt is held: dx moves along the row (wraps), dy moves by rows (clamped).
    function move(dx, dy) {
        if (!root.active) return;
        const n = root.entries.length;
        if (dx !== 0) root.index = (root.index + dx + n) % n;
        if (dy !== 0) {
            const target = root.index + dy * strip.perRow;
            if (target >= 0 && target < n) root.index = target;
        }
        root.shown = true;
    }

    function finish(focusSelected) {
        if (!root.active) return;
        const target = root.entries[root.index];
        root.active = false;
        root.shown = false;
        showTimer.stop();
        failsafe.stop();
        if (focusSelected && target)
            Hyprland.dispatch(`hl.dsp.focus({ window = 'address:${target.address}' })`);
    }

    function closeEntry(i) {
        const target = root.entries[i];
        if (!target) return;
        Hyprland.dispatch(`hl.dsp.window.close({ window = 'address:${target.address}' })`);
        const next = root.entries.filter((_, j) => j !== i);
        if (next.length === 0) { root.finish(false); return; }
        root.entries = next;
        if (root.index >= i && root.index > 0) root.index -= 1;
        root.index = Math.min(root.index, next.length - 1);
    }

    Timer { id: showTimer; interval: 130; onTriggered: root.shown = root.active }
    Timer { id: failsafe; interval: 15000; onTriggered: root.finish(false) } // missed Alt release

    IpcHandler {
        target: "altTab"
        function next(): void { root.step(1); }
        function prev(): void { root.step(-1); }
        function confirm(): void { root.finish(true); }
        function cancel(): void { root.finish(false); }
        function left(): void { root.move(-1, 0); }
        function right(): void { root.move(1, 0); }
        function up(): void { root.move(0, -1); }
        function down(): void { root.move(0, 1); }
    }

    Variants { // one picker per monitor, so nothing has to move when focus jumps between screens
    model: Quickshell.screens
    PanelWindow {
        id: panel
        required property var modelData
        visible: root.shown || strip.opacity > 0
        screen: modelData
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:altTab"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea { // click outside the strip cancels
            anchors.fill: parent
            enabled: root.shown
            onClicked: root.finish(false)
        }

        Rectangle {
            id: strip
            anchors.centerIn: parent
            readonly property real cardW: 230
            readonly property real cardH: 190
            readonly property int perRow: Math.max(1, Math.min(root.entries.length, Math.floor((panel.width * 0.9 - 40) / (cardW + 12))))
            width: perRow * (cardW + 12) - 12 + 40
            height: Math.ceil(root.entries.length / perRow) * (cardH + 12) - 12 + 40
            radius: Appearance.rounding.large
            color: ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainerLow, 0.2)
            border.width: 1
            border.color: Appearance.colors.colLayer0Border
            opacity: root.shown ? 1 : 0
            scale: root.shown ? 1 : 0.94
            // open eases in; close is deliberately short because Hyprland's layer blur
            // stays at full strength until the window unmaps
            Behavior on opacity { NumberAnimation { duration: root.shown ? 120 : 80; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: root.shown ? 140 : 80; easing.type: Easing.OutCubic } }

            Flow {
                anchors.centerIn: parent
                width: strip.perRow * (strip.cardW + 12) - 12
                spacing: 12

                Repeater {
                    model: root.entries
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
                        opacity: modelData.minimized && !selected ? 0.65 : 1
                        Behavior on color { ColorAnimation { duration: 100 } }

                        ColumnLayout {
                            anchors { fill: parent; margins: 10 }
                            spacing: 8

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                ScreencopyView {
                                    anchors.fill: parent
                                    captureSource: root.shown ? card.modelData.toplevel : null
                                    live: false
                                }
                                StyledImage {
                                    anchors { right: parent.right; bottom: parent.bottom }
                                    width: 36; height: 36
                                    mipmap: true
                                    source: Quickshell.iconPath(AppSearch.guessIcon(card.modelData.appClass), "image-missing")
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                StyledText {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: card.modelData.title
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer1
                                }
                                StyledText {
                                    visible: card.modelData.minimized
                                    text: "minimized"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: { root.index = card.index; root.finish(true); }
                        }

                        Rectangle { // close button, shown while hovering the card
                            id: closeButton
                            readonly property bool hot: closeMouse.containsMouse
                            anchors { top: parent.top; right: parent.right; margins: 6 }
                            width: 26; height: 26; radius: 13
                            visible: opacity > 0
                            opacity: cardMouse.containsMouse || closeMouse.containsMouse ? 1 : 0
                            color: hot ? Appearance.colors.colError : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.15)
                            border.width: 1
                            border.color: Appearance.colors.colLayer0Border
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 100 } }
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "close"
                                iconSize: 16
                                color: closeButton.hot ? Appearance.colors.colOnError : Appearance.colors.colOnLayer1
                            }
                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.closeEntry(card.index)
                            }
                        }
                    }
                }
            }
        }
    }
    }
}
