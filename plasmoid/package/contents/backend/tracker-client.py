#!/usr/bin/env python3
"""
tracker-client.py  –  Thin D-Bus client called by the Plasma QML frontend.

Usage:
  tracker-client.py get
  tracker-client.py start   <project_id>
  tracker-client.py stop
  tracker-client.py add     <name> <color>
  tracker-client.py update  <project_id> <json_data>
  tracker-client.py delete  <project_id>
  tracker-client.py update-session  <project_id> <index> <start_iso> <end_iso>
  tracker-client.py delete-session  <project_id> <index>
  tracker-client.py get-settings
  tracker-client.py set-settings <json_settings>
"""

import sys
import json

try:
    from pydbus import SessionBus
except ImportError:
    print(json.dumps({"error": "pydbus not installed"}))
    sys.exit(1)

DBUS_NAME = "org.kde.plasma.localhours"
DBUS_PATH = "/org/kde/plasma/localhours"


def get_proxy():
    bus = SessionBus()
    return bus.get(DBUS_NAME, DBUS_PATH)


def print_json_result(result):
    """Print daemon JSON result (or a structured fallback error)."""
    if isinstance(result, str):
        try:
            json.loads(result)
            print(result)
            return
        except json.JSONDecodeError:
            pass
    print(json.dumps({"ok": False, "error": f"Invalid daemon response: {result!r}"}))


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1].lower()

    try:
        tracker = get_proxy()
    except Exception as exc:
        print(json.dumps({"error": f"Cannot connect to daemon: {exc}"}))
        sys.exit(1)

    try:
        if cmd == "get":
            print(tracker.GetProjects())

        elif cmd == "start":
            if len(sys.argv) < 3:
                print(json.dumps({"error": "start requires <project_id>"}))
                sys.exit(1)
            print_json_result(tracker.StartTracker(sys.argv[2]))

        elif cmd == "stop":
            print_json_result(tracker.StopTracker())

        elif cmd == "add":
            if len(sys.argv) < 4:
                print(json.dumps({"error": "add requires <name> <color>"}))
                sys.exit(1)
            print_json_result(tracker.AddProject(sys.argv[2], sys.argv[3]))

        elif cmd == "update":
            if len(sys.argv) < 4:
                print(json.dumps({"error": "update requires <project_id> <json_data>"}))
                sys.exit(1)
            print_json_result(tracker.UpdateProject(sys.argv[2], sys.argv[3]))

        elif cmd == "delete":
            if len(sys.argv) < 3:
                print(json.dumps({"error": "delete requires <project_id>"}))
                sys.exit(1)
            print_json_result(tracker.DeleteProject(sys.argv[2]))

        elif cmd == "update-session":
            if len(sys.argv) < 6:
                print(json.dumps({"error": "update-session requires <project_id> <index> <start> <end>"}))
                sys.exit(1)
            print_json_result(tracker.UpdateSession(sys.argv[2], int(sys.argv[3]), sys.argv[4], sys.argv[5]))

        elif cmd == "delete-session":
            if len(sys.argv) < 4:
                print(json.dumps({"error": "delete-session requires <project_id> <index>"}))
                sys.exit(1)
            print_json_result(tracker.DeleteSession(sys.argv[2], int(sys.argv[3])))

        elif cmd == "get-settings":
            print(tracker.GetSettings())

        elif cmd == "set-settings":
            if len(sys.argv) < 3:
                print(json.dumps({"error": "set-settings requires <json_settings>"}))
                sys.exit(1)
            print_json_result(tracker.SetSettings(sys.argv[2]))

        else:
            print(json.dumps({"error": f"Unknown command: {cmd}"}))
            sys.exit(1)

    except Exception as exc:
        print(json.dumps({"error": str(exc)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
