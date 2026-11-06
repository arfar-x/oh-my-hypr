pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Public IP service. Queries several sources in parallel; the default source
 * drives the bar (falling back to the first source that answered). Location
 * details come from ipinfo.io for the resulting IP.
 */
Singleton {
    id: root

    // Each source must return the bare IP as plain text.
    readonly property var sources: [
        { name: "ipify", url: "https://api.ipify.org" },
        { name: "icanhazip", url: "https://icanhazip.com" },
        { name: "ifconfig.me", url: "https://ifconfig.me/ip" },
        { name: "AWS", url: "https://checkip.amazonaws.com" },
        { name: "ipinfo", url: "https://ipinfo.io/ip" }
    ]
    property string defaultSource: "ipify"

    property string ip: ""
    property string city: ""
    property string region: ""
    property string country: ""
    property string org: ""
    property string timezone: ""
    property bool loading: defaultProc.running || geoProc.running
    property bool checkingOthers: othersProc.running
    property bool failed: false
    property string defaultError: ""
    readonly property int timeoutSec: 30

    function cleanError(e) {
        e = (e ?? "").replace(/^curl:\s*(\(\d+\)\s*)?/, "").replace(/\s+/g, " ").trim();
        return e.length > 70 ? e.slice(0, 67) + "…" : e;
    }

    // Results of the non-default sources, filled in on demand (name -> ip, "" = failed)
    property var otherIps: ({})
    property double lastOthersCheck: 0

    // One entry per source: state is "ok" | "failed" | "pending"
    readonly property var results: sources.map(s => {
        if (s.name === defaultSource)
            return { name: s.name, url: s.url, ip: ip, error: defaultError, state: ip !== "" && !failed ? "ok" : (failed ? "failed" : "pending") };
        const v = otherIps[s.name];
        return { name: s.name, url: s.url, ip: v?.ip ?? "", error: v?.error ?? "", state: v === undefined ? "pending" : (v.ip === "" ? "failed" : "ok") };
    })

    // Emoji flag from the 2-letter country code (regional indicator symbols)
    readonly property string flag: /^[A-Za-z]{2}$/.test(country)
        ? String.fromCodePoint(...country.toUpperCase().split("").map(c => 0x1F1E6 + c.charCodeAt(0) - 65))
        : ""

    readonly property var defaultUrl: sources.find(s => s.name === defaultSource)?.url ?? sources[0].url

    function validIp(v) {
        return /^[0-9a-fA-F:.]+$/.test(v ?? "") ? v : "";
    }

    // Check only the default source (periodic / left-click)
    function refresh() {
        if (defaultProc.running || geoProc.running) return;
        defaultProc.running = true;
    }

    // Check the other sources (on hover); throttled to once per 30s
    function refreshOthers() {
        if (othersProc.running || Date.now() - lastOthersCheck < 30000) return;
        lastOthersCheck = Date.now();
        othersProc.running = true;
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Process {
        id: defaultProc
        command: ["curl", "-fsS", "--max-time", String(root.timeoutSec), root.defaultUrl]
        stdout: StdioCollector {
            onStreamFinished: {
                const newIp = root.validIp(text.trim());
                if (newIp === "") {
                    root.failed = true;
                    if (root.defaultError === "") root.defaultError = "invalid response";
                    return;
                }
                root.failed = false;
                root.defaultError = "";
                if (root.ip !== "" && newIp !== root.ip) {
                    Quickshell.execDetached(["notify-send", "Public IP changed",
                        `${root.ip} → ${newIp}`, "-a", "Shell"]);
                }
                if (newIp !== root.ip) {
                    root.city = root.region = root.country = root.org = root.timezone = "";
                    root.otherIps = {}; // stale
                    root.lastOthersCheck = 0;
                }
                root.ip = newIp;
                geoProc.command = ["curl", "-fsS", "--max-time", String(root.timeoutSec), `https://ipinfo.io/${newIp}/json`];
                geoProc.running = true;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "") root.defaultError = root.cleanError(text);
            }
        }
        onStarted: root.defaultError = ""
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) root.failed = true;
        }
    }

    // Other sources in parallel, one "name<TAB>ip" line each
    Process {
        id: othersProc
        command: ["bash", "-c",
            "q(){ out=$(curl -fsS --max-time " + root.timeoutSec + " \"$2\" 2>&1); rc=$?; out=$(printf '%s' \"$out\" | tr -d '\\t\\n'); " +
            "if [ $rc -eq 0 ]; then printf '%s\\t%s\\t\\n' \"$1\" \"$out\"; else printf '%s\\t\\t%s\\n' \"$1\" \"$out\"; fi; }; " +
            root.sources.filter(s => s.name !== root.defaultSource)
                .map(s => `q '${s.name}' '${s.url}' &`).join(" ") + " wait"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                for (const line of text.split("\n")) {
                    const [name, val, err] = line.split("\t");
                    if (!name) continue;
                    const ip = root.validIp(val);
                    m[name] = { ip: ip, error: ip !== "" ? "" : root.cleanError(err || (val ? "invalid response" : "no response")) };
                }
                root.otherIps = m;
            }
        }
    }

    // Location details for the current IP (optional; the IP still shows without it)
    Process {
        id: geoProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (d.ip !== root.ip) return;
                    root.city = d.city ?? "";
                    root.region = d.region ?? "";
                    root.country = d.country ?? "";
                    root.org = d.org ?? "";
                    root.timezone = d.timezone ?? "";
                } catch (e) {}
            }
        }
    }
}
