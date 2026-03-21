import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

/**
 * Root PlasmoidItem for the LocalHours.
 *
 * Responsibilities:
 *   - Maintain the canonical in-memory copy of data (projects, activeTracking)
 *   - Communicate with the Python daemon via the executable data engine
 *   - Provide helper functions (time computation, formatting) to child views
 *   - Drive the compact-icon colour and tooltip text
 */
PlasmoidItem {
    id: root

    // -------------------------------------------------------------------------
    // Configuration
    // -------------------------------------------------------------------------
    readonly property string configDataFilePath: Plasmoid.configuration.dataFilePath
    readonly property int    configMaxSessionHours: Plasmoid.configuration.maxSessionHours

    // Qt.resolvedUrl("../..") from contents/ui/main.qml resolves to the
    // plasmoid root (org.kde.plasma.localhours/) with a trailing slash,
    // so we append "contents/backend" directly.
    readonly property string clientScriptDir:
        Qt.resolvedUrl("../..").toString().replace("file://", "") + "contents/backend"

    readonly property string clientScript: clientScriptDir + "/tracker-client.py"

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------
    property var  projects:       []
    property var  activeTracking: null   // { project_id, start_timestamp } or null
    property int  elapsedSeconds: 0
    property bool inListView:     true
    property string editingProjectId: ""
    property var  editingProject: null
    property bool daemonAvailable: false

    // Internal: pending refresh requested by a mutation command
    property bool _refreshPending: false

    // Internal: monotonically increasing sequence number for unique exec source IDs
    property int  _cmdSeq: 0
    property var  _pendingCmdCallbacks: ({})

    // -------------------------------------------------------------------------
    // D-Bus / process bridge via P5Support executable engine
    // -------------------------------------------------------------------------
    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: function(source, data) {
            var stdout = (data["stdout"] || "").trim()
            var stderr = (data["stderr"] || "").trim()
            var parsed = null

            if (stderr) {
                console.warn("[TimeTracker] stderr:", stderr)
            }

            if (stdout) {
                try {
                    parsed = JSON.parse(stdout)
                    if (parsed.projects !== undefined) {
                        root._applyData(parsed)
                        root.daemonAvailable = true
                        root._refreshPending = false
                        root._resolveCmdCallback(source, { ok: true, data: parsed })
                    } else if (parsed.ok === true) {
                        root.daemonAvailable = true
                        root._resolveCmdCallback(source, parsed)
                        // Schedule a follow-up refresh to pick up the mutation result.
                        // Qt.callLater defers until the current event loop iteration
                        // completes, avoiding any re-entrancy issues.
                        root._refreshPending = true
                        Qt.callLater(function() { root._run(["get"]) })
                    } else if (parsed.ok === false) {
                        console.warn("[LocalHours] operation failed:", parsed.error || "Unknown error")
                        root.daemonAvailable = true
                        root._resolveCmdCallback(source, parsed)
                        root._refreshPending = true
                        Qt.callLater(function() { root._run(["get"]) })
                    } else if (parsed.error) {
                        console.warn("[LocalHours] daemon error:", parsed.error)
                        root.daemonAvailable = false
                        root._resolveCmdCallback(source, { ok: false, error: parsed.error })
                        root._refreshPending = false
                    }
                } catch (e) {
                    // Non-JSON stdout is acceptable (e.g. empty output on stop)
                }
            }

            if (parsed === null) {
                root._resolveCmdCallback(source, {
                    ok: false,
                    error: i18n("No parseable daemon response")
                })
            }

            executable.disconnectSource(source)
        }
    }

    function _extractCmdSeq(source) {
        var m = /#seq=(\d+)$/.exec(source || "")
        return m ? m[1] : ""
    }

    function _resolveCmdCallback(source, result) {
        var seqKey = root._extractCmdSeq(source)
        if (!seqKey) return
        var cb = root._pendingCmdCallbacks[seqKey]
        if (!cb) return
        delete root._pendingCmdCallbacks[seqKey]
        try {
            cb(result)
        } catch (e) {
            console.warn("[LocalHours] callback handling failed:", e)
        }
    }

    function _shellQuote(value) {
        var s = String(value)
        return "'" + s.replace(/'/g, "'\\''") + "'"
    }

    function _run(args, onDone) {
        var argv = []
        if (Array.isArray(args)) {
            argv = args
        } else if (args !== undefined && args !== null && String(args).trim() !== "") {
            argv = [args]
        }

        root._cmdSeq += 1
        var seqKey = String(root._cmdSeq)
        var parts = [_shellQuote("python3"), _shellQuote(clientScript)]
        for (var i = 0; i < argv.length; i++) {
            parts.push(_shellQuote(argv[i]))
        }
        var cmd = parts.join(" ") + " #seq=" + seqKey
        if (onDone) {
            root._pendingCmdCallbacks[seqKey] = onDone
        }
        executable.connectSource(cmd)
    }

    // -------------------------------------------------------------------------
    // Single ticker — drives the live counter and background polling.
    // Only ONE Timer with ONE onTriggered exists in this file.
    // -------------------------------------------------------------------------
    Timer {
        id: ticker
        interval: 1000
        running:  true
        repeat:   true

        property int tickCount: 0

        onTriggered: {
            tickCount += 1

            // Update the live elapsed counter whenever a tracker is running
            if (root.activeTracking) {
                var start = new Date(root.activeTracking.start_timestamp)
                root.elapsedSeconds = Math.max(0,
                    Math.floor((Date.now() - start.getTime()) / 1000))
            }

            // Poll the daemon:
            //   - Every 5 seconds while tracking (resync with daemon/failsafe state)
            //   - Every 15 seconds when idle (background freshness)
            //   - Skip if a refresh is already in-flight to avoid queue build-up
            if (!root._refreshPending) {
                var pollInterval = root.activeTracking ? 5 : 15
                if (tickCount % pollInterval === 0) {
                    root._run(["get"])
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Data helpers
    // -------------------------------------------------------------------------
    function _findProjectById(projectId) {
        for (var i = 0; i < root.projects.length; i++) {
            if (root.projects[i].id === projectId) {
                return root.projects[i]
            }
        }
        return null
    }

    function openProjectEditor(projectId) {
        root.editingProjectId = projectId
        root.editingProject = root._findProjectById(projectId)
        if (root.editingProject) {
            root.inListView = false
        }
    }

    function closeProjectEditor() {
        root.inListView = true
        root.editingProjectId = ""
        root.editingProject = null
    }

    function _applyData(data) {
        root.projects = data.projects || []
        root.activeTracking = data.active_tracking || null

        if (root.editingProjectId !== "") {
            var freshProject = root._findProjectById(root.editingProjectId)
            if (freshProject) {
                root.editingProject = freshProject
            } else {
                root.closeProjectEditor()
            }
        } else {
            root.editingProject = null
        }

        if (root.activeTracking) {
            var start = new Date(root.activeTracking.start_timestamp)
            root.elapsedSeconds = Math.max(0,
                Math.floor((Date.now() - start.getTime()) / 1000))
        } else {
            root.elapsedSeconds = 0
        }
    }

    function formatDuration(secs) {
        if (secs < 0) secs = 0
        var h = Math.floor(secs / 3600)
        var m = Math.floor((secs % 3600) / 60)
        var s = secs % 60
        if (h > 0) {
            return h + "h " + String(m).padStart(2, "0") + "m"
        }
        return String(m).padStart(2, "0") + "m " + String(s).padStart(2, "0") + "s"
    }

    function formatTimestamp(isoStr) {
        if (!isoStr) return ""
        try {
            var d = new Date(isoStr)
            return d.toLocaleDateString(Qt.locale(), Locale.ShortFormat) +
                   "  " +
                   d.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
        } catch (e) {
            return isoStr
        }
    }

    function totalSeconds(project) {
        var total = 0
        var sessions = project.sessions || []
        for (var i = 0; i < sessions.length; i++) {
            total += (new Date(sessions[i].end) - new Date(sessions[i].start)) / 1000
        }
        if (root.activeTracking && root.activeTracking.project_id === project.id) {
            total += root.elapsedSeconds
        }
        return Math.max(0, Math.floor(total))
    }

    function todaySeconds(project) {
        var now = new Date()
        var dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        return _rangeSeconds(project, dayStart, new Date())
    }

    function weekSeconds(project) {
        var now  = new Date()
        var day  = now.getDay()
        var diff = (day === 0) ? 6 : (day - 1)   // Monday = week start
        var weekStart = new Date(now.getFullYear(), now.getMonth(), now.getDate() - diff)
        return _rangeSeconds(project, weekStart, new Date())
    }

    function monthSeconds(project) {
        var now = new Date()
        var monthStart = new Date(now.getFullYear(), now.getMonth(), 1)
        return _rangeSeconds(project, monthStart, new Date())
    }

    function _rangeSeconds(project, rangeStart, rangeEnd) {
        var total = 0
        var sessions = project.sessions || []
        for (var i = 0; i < sessions.length; i++) {
            var s = new Date(sessions[i].start)
            var e = new Date(sessions[i].end)
            if (e <= rangeStart) continue
            var effS = (s < rangeStart) ? rangeStart : s
            var effE = (e > rangeEnd)   ? rangeEnd   : e
            total += (effE - effS) / 1000
        }
        if (root.activeTracking && root.activeTracking.project_id === project.id) {
            var as = new Date(root.activeTracking.start_timestamp)
            if (as < rangeEnd) {
                var effS2 = (as < rangeStart) ? rangeStart : as
                total += (rangeEnd - effS2) / 1000
            }
        }
        return Math.max(0, Math.floor(total))
    }

    function buildMetricLabel(project) {
        if (!project) return ""
        var prefs = project.display_preferences || {}
        var parts = []
        if (prefs.show_total_time) parts.push(i18n("Total: ") + formatDuration(totalSeconds(project)))
        if (prefs.show_today)      parts.push(i18n("Today: ") + formatDuration(todaySeconds(project)))
        if (prefs.show_week)       parts.push(i18n("Week: ")  + formatDuration(weekSeconds(project)))
        if (prefs.show_month)      parts.push(i18n("Month: ") + formatDuration(monthSeconds(project)))
        return parts.join("   ")
    }

    // -------------------------------------------------------------------------
    // D-Bus command wrappers
    // -------------------------------------------------------------------------
    function cmdStartTracker(projectId) {
        root.activeTracking = {
            project_id: projectId,
            start_timestamp: new Date().toISOString().replace(/\.\d{3}Z$/, "Z")
        }
        root.elapsedSeconds = 0
        _run(["start", projectId])
    }

    function cmdStopTracker() {
        root.activeTracking = null
        root.elapsedSeconds = 0
        _run(["stop"])
    }

    function cmdAddProject(name, color) {
        _run(["add", name, color])
    }

    function cmdUpdateProject(projectId, dataObj, onDone) {
        _run(["update", projectId, JSON.stringify(dataObj)], onDone)
    }

    function cmdDeleteProject(projectId) {
        _run(["delete", projectId])
    }

    function cmdUpdateSession(projectId, index, startIso, endIso) {
        _run(["update-session", projectId, String(index), startIso, endIso])
    }

    function cmdDeleteSession(projectId, index) {
        _run(["delete-session", projectId, String(index)])
    }

    function cmdSetSettings() {
        var settingsObj = {
            data_path: (root.configDataFilePath || "").trim(),
            max_session_hours: root.configMaxSessionHours
        }
        _run(["set-settings", JSON.stringify(settingsObj)])
    }

    // -------------------------------------------------------------------------
    // Tooltip
    // -------------------------------------------------------------------------
    toolTipMainText: {
        if (!root.daemonAvailable)
            return i18n("LocalHours — daemon not running")
        if (root.activeTracking) {
            var p = root.projects.find(function(x) {
                return x.id === root.activeTracking.project_id
            })
            return p ? p.name : i18n("Tracking…")
        }
        return i18n("LocalHours")
    }

    toolTipSubText: {
        if (!root.daemonAvailable)
            return i18n("Start the daemon:\n  systemctl --user start localhours")
        if (root.activeTracking)
            return i18n("Current session: ") + root.formatDuration(root.elapsedSeconds)
        // Idle: show top 2 projects by this-week time
        var sorted = root.projects.slice().sort(function(a, b) {
            return root.weekSeconds(b) - root.weekSeconds(a)
        })
        if (sorted.length === 0)
            return i18n("No projects yet. Click to get started.")
        var lines = []
        for (var i = 0; i < Math.min(2, sorted.length); i++) {
            lines.push(sorted[i].name + ": " +
                root.formatDuration(root.weekSeconds(sorted[i])) +
                i18n(" this week"))
        }
        return lines.join("\n")
    }

    // -------------------------------------------------------------------------
    // Representations
    // -------------------------------------------------------------------------
    compactRepresentation: CompactRepresentation { }
    fullRepresentation:    FullRepresentation    { }

    onConfigDataFilePathChanged: root.cmdSetSettings()
    onConfigMaxSessionHoursChanged: root.cmdSetSettings()

    // -------------------------------------------------------------------------
    // Init
    // -------------------------------------------------------------------------
    Component.onCompleted: {
        root.cmdSetSettings()
        root._run(["get"])
    }
}
