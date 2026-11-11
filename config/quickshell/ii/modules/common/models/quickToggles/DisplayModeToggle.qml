import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("Display mode")
    hasStatusText: false
    toggled: false
    icon: "display_settings"

    mainAction: () => {
        GlobalStates.sidebarRightOpen = false;
        delayedActionTimer.start();
    }
    Timer {
        id: delayedActionTimer
        interval: 300
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["bash", "-c", "~/.config/hypr/custom/scripts/display-mode.sh"]);
        }
    }

    tooltipText: Translation.tr("Display mode (join / mirror / single)")
}
