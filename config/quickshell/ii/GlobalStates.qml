import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    property bool barOpen: true
    property bool crosshairOpen: false
    property bool sidebarLeftOpen: false
    property bool sidebarRightOpen: false
    property bool networkPopupOpen: false
    property string networkPopupScreen: "" // name of the screen whose bar opened the network popup
    property bool mediaControlsOpen: false
    property bool osdBrightnessOpen: false
    property bool osdVolumeOpen: false
    property string osdLayoutLabel: ""
    property bool oskOpen: false
    property bool overlayOpen: false
    property bool overviewOpen: false
    property bool overviewPreviewMode: false // true: search bar + workspace preview (Super+Tab); false: search bar + app list (Super)
    property bool overviewPreviewRequested: false // set by previewOpen, consumed on the next open
    // The mode is kept while closing so the fade-out keeps its layout
    onOverviewOpenChanged: {
        if (overviewOpen) {
            overviewPreviewMode = overviewPreviewRequested;
            overviewPreviewRequested = false;
        }
    }
    property bool regionSelectorOpen: false
    property bool searchOpen: false
    property bool screenLocked: false
    property bool screenLockContainsCharacters: false
    property bool screenUnlockFailed: false
    property bool screenTranslatorOpen: false
    property bool sessionOpen: false
    property bool superDown: false
    property bool superReleaseMightTrigger: true
    property bool wallpaperSelectorOpen: false
    property bool workspaceShowNumbers: false

    onSidebarRightOpenChanged: {
        if (GlobalStates.sidebarRightOpen) {
            Notifications.timeoutAll();
            Notifications.markAllRead();
        }
    }

    GlobalShortcut {
        name: "workspaceNumber"
        description: "Hold to show workspace numbers, release to show icons"

        onPressed: {
            root.superDown = true
        }
        onReleased: {
            root.superDown = false
        }
    }
}