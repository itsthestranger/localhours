#!/usr/bin/env python3
"""
Lightweight Time Tracking - Backend D-Bus Daemon
Manages all state, JSON persistence, and exposes a D-Bus API for the Plasma frontend.
"""

import json
import uuid
import signal
import logging
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

try:
    from gi.repository import GLib
    from pydbus import SessionBus
    from pydbus.generic import signal as dbus_signal
except ImportError:
    print("ERROR: Required packages not found. Install with:", file=sys.stderr)
    print("  pip install pydbus PyGObject --break-system-packages", file=sys.stderr)
    sys.exit(1)

# --- Constants ---
DBUS_NAME = "org.kde.plasma.localhours"
DBUS_PATH = "/org/kde/plasma/localhours"
DEFAULT_DATA_PATH = Path.home() / ".local/share/localhours/data.json"
DEFAULT_MAX_HOURS = 12
DEFAULT_DISPLAY_PREFERENCES = {
    "show_total_time": True,
    "show_today": True,
    "show_week": False,
    "show_month": False,
}


class TimeTrackerDaemon:
    """
    <node>
      <interface name='org.kde.plasma.localhours'>

        <method name='GetProjects'>
          <arg type='s' name='result' direction='out'/>
        </method>

        <method name='StartTracker'>
          <arg type='s' name='project_id' direction='in'/>
          <arg type='s' name='result' direction='out'/>
        </method>

        <method name='StopTracker'>
          <arg type='s' name='result' direction='out'/>
        </method>

        <method name='AddProject'>
          <arg type='s' name='name' direction='in'/>
          <arg type='s' name='color' direction='in'/>
          <arg type='s' name='result' direction='out'/>
        </method>

        <method name='UpdateProject'>
          <arg type='s' name='project_id' direction='in'/>
          <arg type='s' name='data_json' direction='in'/>
          <arg type='s' name='result' direction='out'/>
        </method>

        <method name='DeleteProject'>
          <arg type='s' name='project_id' direction='in'/>
          <arg type='s' name='result' direction='out'/>
        </method>

        <method name='UpdateSession'>
          <arg type='s' name='project_id' direction='in'/>
          <arg type='i' name='session_index' direction='in'/>
          <arg type='s' name='start_time' direction='in'/>
          <arg type='s' name='end_time' direction='in'/>
          <arg type='s' name='result' direction='out'/>
        </method>

        <method name='DeleteSession'>
          <arg type='s' name='project_id' direction='in'/>
          <arg type='i' name='session_index' direction='in'/>
          <arg type='s' name='result' direction='out'/>
        </method>

        <method name='GetSettings'>
          <arg type='s' name='result' direction='out'/>
        </method>

        <method name='SetSettings'>
          <arg type='s' name='settings_json' direction='in'/>
          <arg type='s' name='result' direction='out'/>
        </method>

        <signal name='DataChanged'>
          <arg type='s' name='data'/>
        </signal>

      </interface>
    </node>
    """

    DataChanged = dbus_signal()

    def __init__(self):
        self._data_path = DEFAULT_DATA_PATH
        self._max_hours = DEFAULT_MAX_HOURS
        self._data = {"active_tracking": None, "projects": []}
        self._load_data()
        self._check_failsafe()
        # Periodic failsafe check while running; UI keeps its own live second counter.
        GLib.timeout_add_seconds(30, self._tick)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _tick(self):
        """Called periodically by the GLib main loop."""
        if self._data.get("active_tracking"):
            self._check_failsafe()
        return True  # keep repeating

    def _load_data(self):
        if self._data_path.exists():
            try:
                with open(self._data_path, "r", encoding="utf-8") as f:
                    self._data = json.load(f)
                self._normalize_loaded_data()
                logging.info("Loaded data from %s", self._data_path)
            except Exception as exc:
                logging.error("Failed to load data file: %s", exc)
                self._data = {"active_tracking": None, "projects": []}
        else:
            logging.info("No data file found; creating fresh state at %s", self._data_path)
            self._save_data()

    def _save_data(self):
        self._data_path.parent.mkdir(parents=True, exist_ok=True)
        tmp_path = self._data_path.with_suffix(".tmp")
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(self._data, f, indent=2)
        tmp_path.replace(self._data_path)

    def _check_failsafe(self):
        """Cap sessions that have been running longer than max_hours."""
        active = self._data.get("active_tracking")
        if not active or self._max_hours <= 0:
            return
        start_ts = active.get("start_timestamp")
        if not self._is_valid_timestamp(start_ts):
            logging.warning("Invalid active tracker timestamp; clearing active_tracking.")
            self._data["active_tracking"] = None
            self._save_data()
            return
        start = self._parse_timestamp(start_ts)
        now = datetime.now(timezone.utc)
        elapsed_hours = (now - start).total_seconds() / 3600.0
        if elapsed_hours > self._max_hours:
            logging.warning(
                "Session for project %s exceeded %s hours; capping automatically.",
                active["project_id"], self._max_hours,
            )
            cap_end = start + timedelta(hours=self._max_hours)
            self._stop_tracker_internal(active["project_id"], end_time=cap_end)

    def _stop_tracker_internal(self, project_id: str, end_time: datetime = None):
        """Save the active session and clear active_tracking."""
        active = self._data.get("active_tracking")
        if not active:
            return
        start_ts = active.get("start_timestamp")
        if not self._is_valid_timestamp(start_ts):
            logging.warning("Active session has invalid start timestamp; discarding active session.")
            self._data["active_tracking"] = None
            self._save_data()
            return
        if end_time is None:
            end_time = datetime.now(timezone.utc)
        end_ts = end_time.strftime("%Y-%m-%dT%H:%M:%SZ")
        for project in self._data["projects"]:
            if project["id"] == project_id:
                project["sessions"].append({"start": start_ts, "end": end_ts})
                logging.info("Saved session for '%s': %s → %s", project["name"], start_ts, end_ts)
                break
        else:
            logging.warning("Tried to stop tracker for unknown project_id: %s", project_id)
        self._data["active_tracking"] = None
        self._save_data()

    @staticmethod
    def _now_utc_str() -> str:
        return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    @staticmethod
    def _result_ok(**fields) -> str:
        result = {"ok": True}
        result.update(fields)
        return json.dumps(result)

    @staticmethod
    def _result_error(message: str, **fields) -> str:
        result = {"ok": False, "error": message}
        result.update(fields)
        return json.dumps(result)

    @staticmethod
    def _is_valid_timestamp(value) -> bool:
        if not isinstance(value, str) or not value.strip():
            return False
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return False
        return parsed.tzinfo is not None

    @staticmethod
    def _parse_timestamp(value: str) -> datetime:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            raise ValueError("Timestamp must include timezone")
        return parsed.astimezone(timezone.utc)

    @staticmethod
    def _normalize_display_preferences(raw_prefs) -> dict:
        prefs = dict(DEFAULT_DISPLAY_PREFERENCES)
        if isinstance(raw_prefs, dict):
            for key in prefs:
                if key in raw_prefs:
                    prefs[key] = bool(raw_prefs[key])
        return prefs

    def _normalize_loaded_data(self):
        if not isinstance(self._data, dict):
            logging.warning("Data file root must be an object. Resetting state.")
            self._data = {"active_tracking": None, "projects": []}
            return

        raw_projects = self._data.get("projects")
        if not isinstance(raw_projects, list):
            logging.warning("Invalid projects entry in data file. Resetting project list.")
            raw_projects = []

        normalized_projects = []
        for idx, project in enumerate(raw_projects):
            if not isinstance(project, dict):
                logging.warning("Skipping non-object project at index %d.", idx)
                continue

            project_id = project.get("id")
            name = project.get("name")
            if not isinstance(project_id, str) or not project_id.strip():
                logging.warning("Skipping project at index %d with invalid id.", idx)
                continue
            if not isinstance(name, str) or not name.strip():
                logging.warning("Skipping project '%s' with invalid name.", project_id)
                continue

            color = project.get("color")
            if not isinstance(color, str) or not color.strip():
                color = "#3498db"

            raw_sessions = project.get("sessions")
            if not isinstance(raw_sessions, list):
                raw_sessions = []
            sessions = []
            for s_idx, session in enumerate(raw_sessions):
                if not isinstance(session, dict):
                    logging.warning("Skipping non-object session %d for project '%s'.", s_idx, project_id)
                    continue
                start = session.get("start")
                end = session.get("end")
                if not self._is_valid_timestamp(start) or not self._is_valid_timestamp(end):
                    logging.warning(
                        "Skipping invalid session %d for project '%s' due to malformed timestamps.",
                        s_idx, project_id,
                    )
                    continue
                sessions.append({"start": start, "end": end})

            normalized_projects.append({
                "id": project_id,
                "name": name.strip(),
                "color": color.strip(),
                "display_preferences": self._normalize_display_preferences(
                    project.get("display_preferences")
                ),
                "sessions": sessions,
            })

        self._data["projects"] = normalized_projects

        active = self._data.get("active_tracking")
        if not isinstance(active, dict):
            self._data["active_tracking"] = None
            return

        project_id = active.get("project_id")
        start_ts = active.get("start_timestamp")
        valid_project_ids = {p["id"] for p in normalized_projects}
        if (
            isinstance(project_id, str)
            and project_id in valid_project_ids
            and self._is_valid_timestamp(start_ts)
        ):
            self._data["active_tracking"] = {
                "project_id": project_id,
                "start_timestamp": start_ts,
            }
        else:
            logging.warning("Invalid active_tracking entry in data file. Clearing active tracker.")
            self._data["active_tracking"] = None

    # ------------------------------------------------------------------
    # D-Bus API
    # ------------------------------------------------------------------

    def GetProjects(self) -> str:
        """Return the full data structure as a JSON string."""
        self._check_failsafe()
        return json.dumps(self._data)

    def StartTracker(self, project_id: str) -> str:
        """Stop any running tracker, then start one for project_id."""
        # Validate project exists
        project_ids = {p["id"] for p in self._data["projects"]}
        if project_id not in project_ids:
            logging.error("StartTracker: unknown project_id '%s'", project_id)
            return self._result_error(f"Unknown project_id: {project_id}")
        active = self._data.get("active_tracking")
        if active:
            self._stop_tracker_internal(active["project_id"])
        self._data["active_tracking"] = {
            "project_id": project_id,
            "start_timestamp": self._now_utc_str(),
        }
        self._save_data()
        self.DataChanged(json.dumps(self._data))
        logging.info("Tracker started for project_id '%s'", project_id)
        return self._result_ok()

    def StopTracker(self) -> str:
        """Stop the currently running tracker and save the session."""
        active = self._data.get("active_tracking")
        if not active:
            return self._result_error("No active tracker to stop")
        self._stop_tracker_internal(active["project_id"])
        self.DataChanged(json.dumps(self._data))
        logging.info("Tracker stopped")
        return self._result_ok()

    def AddProject(self, name: str, color: str) -> str:
        """Create a new project, return its UUID."""
        if not name.strip():
            logging.warning("AddProject called with empty name; ignoring.")
            return self._result_error("Project name cannot be empty")
        project_id = str(uuid.uuid4())
        project = {
            "id": project_id,
            "name": name.strip(),
            "color": color.strip() if color.strip() else "#3498db",
            "display_preferences": dict(DEFAULT_DISPLAY_PREFERENCES),
            "sessions": [],
        }
        self._data["projects"].append(project)
        self._save_data()
        self.DataChanged(json.dumps(self._data))
        logging.info("Added project '%s' (id=%s)", name, project_id)
        return self._result_ok(id=project_id)

    def UpdateProject(self, project_id: str, data_json: str) -> str:
        """Update name, color, and/or display_preferences for a project."""
        try:
            updates = json.loads(data_json)
        except json.JSONDecodeError as exc:
            logging.error("UpdateProject: invalid JSON: %s", exc)
            return self._result_error(f"Invalid JSON: {exc}")
        for project in self._data["projects"]:
            if project["id"] == project_id:
                if "name" in updates:
                    project["name"] = updates["name"]
                if "color" in updates:
                    project["color"] = updates["color"]
                if "display_preferences" in updates:
                    if not isinstance(updates["display_preferences"], dict):
                        return self._result_error("display_preferences must be an object")
                    merged_prefs = self._normalize_display_preferences(project.get("display_preferences"))
                    for key in merged_prefs:
                        if key in updates["display_preferences"]:
                            merged_prefs[key] = bool(updates["display_preferences"][key])
                    project["display_preferences"] = merged_prefs
                break
        else:
            logging.warning("UpdateProject: unknown project_id '%s'", project_id)
            return self._result_error(f"Unknown project_id: {project_id}")
        self._save_data()
        self.DataChanged(json.dumps(self._data))
        return self._result_ok()

    def DeleteProject(self, project_id: str) -> str:
        """Remove a project and all its session history."""
        active = self._data.get("active_tracking")
        if active and active["project_id"] == project_id:
            self._data["active_tracking"] = None
        before = len(self._data["projects"])
        self._data["projects"] = [p for p in self._data["projects"] if p["id"] != project_id]
        if len(self._data["projects"]) == before:
            logging.warning("DeleteProject: unknown project_id '%s'", project_id)
            return self._result_error(f"Unknown project_id: {project_id}")
        self._save_data()
        self.DataChanged(json.dumps(self._data))
        logging.info("Deleted project_id '%s'", project_id)
        return self._result_ok()

    def UpdateSession(self, project_id: str, session_index: int, start_time: str, end_time: str) -> str:
        """Overwrite a specific session's start/end timestamps."""
        for project in self._data["projects"]:
            if project["id"] == project_id:
                sessions = project["sessions"]
                if 0 <= session_index < len(sessions):
                    sessions[session_index] = {"start": start_time, "end": end_time}
                    logging.info(
                        "Updated session %d for project '%s'", session_index, project["name"]
                    )
                else:
                    logging.error(
                        "UpdateSession: index %d out of range for project '%s' (%d sessions)",
                        session_index, project["name"], len(sessions),
                    )
                    return self._result_error(
                        f"Session index {session_index} out of range for project {project_id}"
                    )
                break
        else:
            logging.warning("UpdateSession: unknown project_id '%s'", project_id)
            return self._result_error(f"Unknown project_id: {project_id}")
        self._save_data()
        self.DataChanged(json.dumps(self._data))
        return self._result_ok()

    def DeleteSession(self, project_id: str, session_index: int) -> str:
        """Remove a specific session from a project."""
        for project in self._data["projects"]:
            if project["id"] == project_id:
                sessions = project["sessions"]
                if 0 <= session_index < len(sessions):
                    removed = sessions.pop(session_index)
                    logging.info(
                        "Deleted session %d (%s→%s) from project '%s'",
                        session_index, removed["start"], removed["end"], project["name"],
                    )
                else:
                    logging.error(
                        "DeleteSession: index %d out of range (%d sessions)", session_index, len(sessions)
                    )
                    return self._result_error(
                        f"Session index {session_index} out of range for project {project_id}"
                    )
                break
        else:
            logging.warning("DeleteSession: unknown project_id '%s'", project_id)
            return self._result_error(f"Unknown project_id: {project_id}")
        self._save_data()
        self.DataChanged(json.dumps(self._data))
        return self._result_ok()

    def GetSettings(self) -> str:
        """Return current daemon settings."""
        return json.dumps({
            "data_path": str(self._data_path),
            "max_session_hours": self._max_hours,
        })

    def SetSettings(self, settings_json: str) -> str:
        """Apply new settings (data path and/or max session hours)."""
        try:
            settings = json.loads(settings_json)
        except json.JSONDecodeError as exc:
            logging.error("SetSettings: invalid JSON: %s", exc)
            return self._result_error(f"Invalid JSON: {exc}")
        reload_needed = False
        if "data_path" in settings and settings["data_path"]:
            new_path = Path(settings["data_path"]).expanduser()
            if new_path != self._data_path:
                self._data_path = new_path
                reload_needed = True
        if "max_session_hours" in settings:
            try:
                self._max_hours = int(settings["max_session_hours"])
            except (TypeError, ValueError):
                return self._result_error("max_session_hours must be an integer")
            logging.info("max_session_hours set to %d", self._max_hours)
        if reload_needed:
            self._load_data()
        self.DataChanged(json.dumps(self._data))
        return self._result_ok()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S",
    )

    loop = GLib.MainLoop()

    bus = SessionBus()
    daemon = TimeTrackerDaemon()

    try:
        bus.publish(DBUS_NAME, (DBUS_PATH, daemon))
    except Exception as exc:
        logging.error("Failed to acquire D-Bus name '%s': %s", DBUS_NAME, exc)
        logging.error("Is another instance already running? Check with: gdbus introspect --session --dest %s --object-path %s", DBUS_NAME, DBUS_PATH)
        sys.exit(1)

    def _handle_signal(*_args):
        logging.info("Shutting down daemon...")
        loop.quit()

    signal.signal(signal.SIGTERM, _handle_signal)
    signal.signal(signal.SIGINT, _handle_signal)

    logging.info("LocalHours Daemon started (D-Bus name: %s)", DBUS_NAME)
    loop.run()
    logging.info("Daemon exited cleanly.")


if __name__ == "__main__":
    main()
