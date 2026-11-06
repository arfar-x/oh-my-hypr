import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Minimize animation: a snapshot of the window shrinks toward the dock and fades out.
//   minimizeFx run <address> <x> <y> <w> <h> <monitorName>
// x/y are relative to the monitor. window-state.sh calls this just before parking the window.
Scope {
    id: root

    property var toplevel: null
    property string monitorName: ""
    property real fromX: 0
    property real fromY: 0
    property real fromW: 0
    property real fromH: 0

    function run(address, x, y, w, h, monitor) {
        let found = null;
        for (const t of ToplevelManager.toplevels.values) {
            if (`0x${t.HyprlandToplevel?.address}` === address) { found = t; break; }
        }
        if (!found || w < 20 || h < 20) return;
        root.monitorName = monitor;
        root.fromX = x; root.fromY = y; root.fromW = w; root.fromH = h;
        root.toplevel = found;
        failsafe.restart();
    }

    IpcHandler {
        target: "minimizeFx"
        function run(address: string, x: int, y: int, w: int, h: int, monitor: string): void {
            root.run(address, x, y, w, h, monitor);
        }
    }

    Timer { id: failsafe; interval: 1500; onTriggered: root.toplevel = null }

    PanelWindow {
        id: panel
        visible: root.toplevel !== null
        screen: Quickshell.screens.find(s => s.name === root.monitorName) ?? Quickshell.screens[0]
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:minimizeFx"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }
        mask: Region {} // never takes input

        // Grabs one frame of the window; the window is parked right after, which ends the capture.
        ScreencopyView {
            id: grabber
            captureSource: root.toplevel
            live: false
            x: root.fromX; y: root.fromY
            width: root.fromW; height: root.fromH
            visible: !snap.visible // sits exactly over the real window until the still takes over
            onHasContentChanged: {
                if (!hasContent || snap.visible) return;
                grabber.grabToImage(function(result) {
                    snap.source = result.url;
                    anim.restart();
                });
            }
        }

        Image {
            id: snap
            visible: false
            x: root.fromX; y: root.fromY
            width: root.fromW; height: root.fromH
            transformOrigin: Item.Center
            cache: false

            ParallelAnimation {
                id: anim
                onStarted: snap.visible = true
                NumberAnimation { target: snap; property: "x"; to: panel.width / 2 - root.fromW / 2; duration: 320; easing.type: Easing.InCubic }
                NumberAnimation { target: snap; property: "y"; to: panel.height - 50 - root.fromH / 2; duration: 320; easing.type: Easing.InCubic }
                NumberAnimation { target: snap; property: "scale"; to: 0.06; duration: 320; easing.type: Easing.InCubic }
                NumberAnimation { target: snap; property: "opacity"; to: 0; duration: 320; easing.type: Easing.InQuad }
                onFinished: {
                    snap.visible = false;
                    root.toplevel = null;
                    snap.x = root.fromX; snap.y = root.fromY; snap.scale = 1; snap.opacity = 1;
                    snap.source = "";
                }
            }
        }
    }
}
