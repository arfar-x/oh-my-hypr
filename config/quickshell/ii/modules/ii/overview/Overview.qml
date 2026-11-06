import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt.labs.synchronizer
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: overviewScope
    property bool dontAutoCancelSearch: false

    PanelWindow {
        id: panelWindow
        property string searchingText: ""
        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
        property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
        visible: windowShown

        WlrLayershell.namespace: "quickshell:overview"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: GlobalStates.overviewOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        // While open the whole screen takes input, so a click anywhere outside the launcher closes
        // it (the focus grab alone misses clicks in the pill's padding and on some surfaces)
        mask: Region {
            item: GlobalStates.overviewOpen ? outsideClickCatcher : null
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Only the handlers below change this, so the window is never unmapped and
        // remapped between "overviewOpen turned false" and "the close timer started".
        property bool windowShown: false

        Timer { // Keeps the window mapped while the closing animation plays
            id: closeAnimTimer
            interval: 280
            onTriggered: {
                if (!GlobalStates.overviewOpen)
                    panelWindow.windowShown = false;
            }
        }

        Connections {
            target: GlobalStates
            function onOverviewOpenChanged() {
                if (!GlobalStates.overviewOpen) {
                    closeAnimTimer.restart();
                    searchWidget.disableExpandAnimation();
                    overviewScope.dontAutoCancelSearch = false;
                    GlobalFocusGrab.dismiss();
                } else {
                    closeAnimTimer.stop();
                    panelWindow.windowShown = true;
                    if (!overviewScope.dontAutoCancelSearch) {
                        searchWidget.cancelSearch();
                    }
                    GlobalFocusGrab.addDismissable(panelWindow);
                }
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                GlobalStates.overviewOpen = false;
            }
        }
        implicitWidth: columnLayout.implicitWidth
        implicitHeight: columnLayout.implicitHeight

        function setSearchingText(text) {
            searchWidget.setSearchingText(text);
            searchWidget.focusFirstItem();
        }

        MouseArea {
            id: outsideClickCatcher
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: mouse => { console.log('CATCHTRACE catcher pressed at ' + mouse.x + ',' + mouse.y); GlobalStates.overviewOpen = false; }
        }

        Column {
            id: columnLayout
            visible: panelWindow.windowShown
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
            }
            spacing: -8

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.overviewOpen = false;
                }
            }

            SearchWidget {
                id: searchWidget
                anchors.horizontalCenter: parent.horizontalCenter
                Synchronizer on searchingText {
                    property alias source: panelWindow.searchingText
                }
            }

            Loader {
                id: overviewLoader
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: GlobalStates.overviewOpen ? 1 : 0
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                active: panelWindow.windowShown && GlobalStates.overviewPreviewMode && (Config?.options.overview.enable ?? true)
                sourceComponent: OverviewWidget {
                    screen: panelWindow.screen
                    visible: (panelWindow.searchingText == "")
                }
            }
        }
    }

    function toggleClipboard() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.clipboard);
        GlobalStates.overviewOpen = true;
    }

    function toggleEmojis() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.emojis);
        GlobalStates.overviewOpen = true;
    }

    IpcHandler {
        target: "search"

        function toggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function workspacesToggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function close() {
            GlobalStates.overviewOpen = false;
        }
        function open() {
            GlobalStates.overviewOpen = true;
        }
        function previewOpen() {
            if (GlobalStates.overviewOpen) {
                GlobalStates.overviewPreviewMode = true;
            } else {
                GlobalStates.overviewPreviewRequested = true;
                GlobalStates.overviewOpen = true;
            }
        }
        function toggleReleaseInterrupt() {
            GlobalStates.superReleaseMightTrigger = false;
        }
        function clipboardToggle() {
            overviewScope.toggleClipboard();
        }
    }

    GlobalShortcut {
        name: "searchToggle"
        description: "Toggles search on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesClose"
        description: "Closes overview on press"

        onPressed: {
            GlobalStates.overviewOpen = false;
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesToggle"
        description: "Toggles overview on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    // Tapping Super opens the launcher only after this delay, so a double tap can open the
    // workspace preview directly instead of flashing the launcher first.
    Timer {
        id: singleTapTimer
        interval: 250 // ms: the double-tap window
        onTriggered: GlobalStates.overviewOpen = true
    }
    GlobalShortcut {
        name: "searchToggleRelease"
        description: "Toggles search on release"

        onPressed: {
            GlobalStates.superReleaseMightTrigger = true;
        }

        onReleased: {
            if (!GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = true;
                return;
            }
            if (GlobalStates.overviewOpen) { // Already showing: a tap closes it right away
                singleTapTimer.stop();
                GlobalStates.overviewOpen = false;
            } else if (singleTapTimer.running) { // Second tap in time: straight to the preview
                singleTapTimer.stop();
                GlobalStates.overviewPreviewRequested = true;
                GlobalStates.overviewOpen = true;
            } else {
                singleTapTimer.start();
            }
        }
    }
    GlobalShortcut {
        name: "searchToggleReleaseInterrupt"
        description: "Interrupts possibility of search being toggled on release. " + "This is necessary because GlobalShortcut.onReleased in quickshell triggers whether or not you press something else while holding the key. " + "To make sure this works consistently, use binditn = MODKEYS, catchall in an automatically triggered submap that includes everything."

        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
        }
    }
    GlobalShortcut {
        name: "overviewClipboardToggle"
        description: "Toggle clipboard query on overview widget"

        onPressed: {
            overviewScope.toggleClipboard();
        }
    }

    GlobalShortcut {
        name: "overviewEmojiToggle"
        description: "Toggle emoji query on overview widget"

        onPressed: {
            overviewScope.toggleEmojis();
        }
    }
}
