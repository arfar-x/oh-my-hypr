import QtQuick
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.modules.common as C

NestableObject {
    id: root

    required property HyprlandMonitor monitor
    readonly property var liveMonitorData: HyprlandData.monitors.find(m => m.id === monitor.id)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    readonly property int activeWorkspace: monitor?.activeWorkspace?.id ?? 1
    readonly property bool currentWorkspaceNotFake: activeWindow?.activated ?? false // Active empty workspace = fake. At least, that's how I like to call it.
    readonly property int fakeWorkspace: currentWorkspaceNotFake ? -9999 : activeWorkspace
    readonly property int shownCount: C.Config.options.bar.workspaces.shown
    readonly property int group: Math.floor((activeWorkspace - 1) / shownCount)
    readonly property var specialWorkspace: liveMonitorData?.specialWorkspace
    readonly property string specialWorkspaceName: specialWorkspace?.name?.replace("special:", "") ?? ""
    readonly property bool specialWorkspaceActive: specialWorkspaceName !== ""

    property list<bool> occupied: []
    property list<var> biggestWindow: occupied.map((_, index) => {
        const wsId = getWorkspaceIdAt(index);
        // Fall back to windows parked on special:desktop (show-desktop active)
        return HyprlandData.biggestWindowForWorkspace(wsId) || parkedDesktopWindowFor(wsId);
    })
    // Per index: the icon source is a parked show-desktop window, so the bar
    // renders it shrinked, as if Super were held
    readonly property list<bool> fromParkedDesktop: occupied.map((_, index) => {
        const wsId = getWorkspaceIdAt(index);
        return !HyprlandData.biggestWindowForWorkspace(wsId) && parkedDesktopWindowFor(wsId) !== null;
    })

    // Biggest window parked on special:desktop that originated from workspaceId
    function parkedDesktopWindowFor(workspaceId) {
        const origins = HyprlandData.desktopParkedOrigins;
        const wins = HyprlandData.windowList;
        let best = null;
        for (var i = 0; i < wins.length; ++i) {
            const win = wins[i];
            if (origins[win.address] !== workspaceId) continue;
            if (!win.workspace || win.workspace.name !== "special:desktop") continue;
            if (!best || win.size[0] * win.size[1] > best.size[0] * best.size[1]) best = win;
        }
        return best;
    }

    function getWorkspaceId(group, index) {
        return group * root.shownCount + index + 1;
    }
    function getWorkspaceIdAt(index) {
        return root.getWorkspaceId(root.group, index);
    }

    // Function to update workspaceOccupied
    function updateWorkspaceOccupied() {
        root.occupied = Array.from({
            length: root.shownCount
        }, (_, i) => {
            const thisWorkspaceId = getWorkspaceId(root.group, i);
            return Hyprland.workspaces.values.some(ws => ws.id === thisWorkspaceId)
                || parkedDesktopWindowFor(thisWorkspaceId) !== null;
        });
    }

    // Occupied workspace updates (a workspace whose windows are all parked on
    // special:desktop still counts as occupied while the desktop is shown)
    Component.onCompleted: updateWorkspaceOccupied()
    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() {
            root.updateWorkspaceOccupied();
        }
    }
    Connections {
        target: HyprlandData
        function onWindowListChanged() {
            root.updateWorkspaceOccupied();
        }
        function onDesktopParkedOriginsChanged() {
            root.updateWorkspaceOccupied();
        }
    }
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            root.updateWorkspaceOccupied();
        }
    }
    onGroupChanged: {
        updateWorkspaceOccupied();
    }
}
