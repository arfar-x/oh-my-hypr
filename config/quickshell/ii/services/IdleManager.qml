import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.modules.common

// Keeps hypridle.conf in sync with the idle settings of the active power profile.
Item {
    id: root

    readonly property string profileKey: {
        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver: return "powerSaver";
        case PowerProfile.Performance: return "performance";
        default: return "balanced";
        }
    }
    readonly property var cfg: Config.ready ? Config.options.idle[profileKey] : null

    function apply() {
        if (!cfg) return;
        Quickshell.execDetached([
            Quickshell.shellPath("scripts/idle/apply.sh"),
            String(cfg.dimTimeout), String(cfg.dimBrightness),
            String(cfg.lockTimeout), String(cfg.screenOffTimeout), String(cfg.suspendTimeout),
            String(cfg.screensaverTimeout), Config.options.idle.screensaverStyle
        ]);
    }

    // Re-evaluated whenever the profile or any of its values change
    readonly property string signature: cfg
        ? [profileKey, cfg.dimTimeout, cfg.dimBrightness, cfg.lockTimeout, cfg.screenOffTimeout, cfg.suspendTimeout, cfg.screensaverTimeout, Config.options.idle.screensaverStyle].join(",")
        : ""
    onSignatureChanged: if (signature !== "") applyTimer.restart()

    Timer {
        id: applyTimer
        interval: 800
        onTriggered: root.apply()
    }
}
