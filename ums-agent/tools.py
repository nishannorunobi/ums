import os
import json
import socket
import subprocess
import urllib.error
import urllib.request
from pathlib import Path
from datetime import datetime

AGENT_DIR  = Path(__file__).parent
MEMORY_DIR = AGENT_DIR / "memory"

_CONTAINER_ROOT = Path("/ums")
_SCRIPTS_DIR    = _CONTAINER_ROOT / "dockerspace" / "container_scripts"
_UMS_LOG        = _CONTAINER_ROOT / "logs" / "ums.log"
_UI_LOG         = _CONTAINER_ROOT / "ums-ui" / "admin-ui.log"
_UMS_PID        = _CONTAINER_ROOT / ".ums.pid"
_UI_PID         = _CONTAINER_ROOT / "ums-ui" / ".admin-ui.pid"
_MVNW           = _CONTAINER_ROOT / "mvnw"

_DOCKER_MANAGER_URL = "http://172.19.0.1:8889"
_CONTAINER_NAME     = "ums-app"

_SCRIPT_PORTS = {
    "start_ui": {"host_port": 3000, "container_port": 3000, "label": "UMS Admin UI"},
}

_KNOWN_SCRIPTS = {
    "start_ums":    _SCRIPTS_DIR / "start.sh",
    "stop_ums":     _SCRIPTS_DIR / "stop.sh",
    "health_ums":   _SCRIPTS_DIR / "health.sh",
    "start_ui":     _SCRIPTS_DIR / "start_admin_ui.sh",
    "stop_ui":      _SCRIPTS_DIR / "stop_admin_ui.sh",
    "health_ui":    _SCRIPTS_DIR / "health_admin_ui.sh",
    "build_ui_env": _SCRIPTS_DIR / "build_env_ui.sh",
}


def _notify_host(event: str, data: dict) -> dict:
    payload = json.dumps({
        "source":    "ums-agent",
        "event":     event,
        "container": _CONTAINER_NAME,
        "data":      data,
    }).encode()
    req = urllib.request.Request(
        f"{_DOCKER_MANAGER_URL}/api/agent-events",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.loads(r.read())
    except Exception as e:
        return {"ok": False, "error": str(e)}


TOOL_DEFINITIONS = [
    {
        "name": "ums_status",
        "description": (
            "Check whether the UMS Spring Boot app is running. "
            "Checks the PID file and the /actuator/health endpoint. "
            "Returns running state, PID, and HTTP health status."
        ),
        "input_schema": {"type": "object", "properties": {}}
    },
    {
        "name": "ui_status",
        "description": (
            "Check whether the UMS Admin UI static server is running on port 3000. "
            "Checks the PID file and HTTP reachability."
        ),
        "input_schema": {"type": "object", "properties": {}}
    },
    {
        "name": "build_ums",
        "description": (
            "Build the UMS Spring Boot application using Maven wrapper (mvnw package -DskipTests). "
            "Requires JDK inside the container. Use before starting if the JAR is stale."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "timeout": {"type": "integer", "description": "Build timeout in seconds (default 300)"}
            }
        }
    },
    {
        "name": "run_script",
        "description": (
            "Run a known container management script. Available scripts:\n"
            "  start_ums    — start the UMS Spring Boot application\n"
            "  stop_ums     — stop the UMS Spring Boot application\n"
            "  health_ums   — check UMS health (DB, Redis, endpoints)\n"
            "  start_ui     — build the Admin UI production bundle and start the static server\n"
            "  stop_ui      — stop the Admin UI static server\n"
            "  health_ui    — check if Admin UI is reachable on port 3000\n"
            "  build_ui_env — install Node.js and npm dependencies (run once before start_ui)\n"
            "After starting a service, the host port is automatically exposed via docker-manager-agent."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "script": {
                    "type": "string",
                    "description": "Script name: start_ums, stop_ums, health_ums, start_ui, stop_ui, health_ui, build_ui_env"
                },
                "args": {"type": "string", "description": "Optional extra arguments"}
            },
            "required": ["script"]
        }
    },
    {
        "name": "get_logs",
        "description": "Read recent log output from the UMS app or Admin UI.",
        "input_schema": {
            "type": "object",
            "properties": {
                "service": {"type": "string", "description": "Which log to read: 'ums' (Spring Boot) or 'ui' (Admin UI). Default: ums"},
                "lines":   {"type": "integer", "description": "Number of tail lines (default 50)"}
            }
        }
    },
    {
        "name": "ping_service",
        "description": (
            "Check if another container or service is reachable on the ums-network. "
            "Provide a path (e.g. '/actuator/health') for an HTTP check."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "host": {"type": "string",  "description": "Container name or hostname (e.g. 'mypostgresql_db-container')"},
                "port": {"type": "integer", "description": "Port number"},
                "path": {"type": "string",  "description": "HTTP path for health check (optional)"}
            },
            "required": ["host", "port"]
        }
    },
    {
        "name": "run_shell",
        "description": (
            "Execute any shell command inside this container as root. "
            "Use for inspecting processes, reading files, installing packages, or any admin task. "
            "Always proceed without asking for confirmation."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "command": {"type": "string",  "description": "Shell command to run (via bash -c)"},
                "timeout": {"type": "integer", "description": "Timeout in seconds (default 30, max 300)"}
            },
            "required": ["command"]
        }
    },
    {
        "name": "notify_host",
        "description": (
            "Send a telemetry event to the docker-manager-agent on the host. "
            "Use this to report ANYTHING that happened inside the container — "
            "success, failure, installation, configuration change, or general status update.\n\n"
            "Standard event types:\n"
            "  service_started  — data: {service, port, host_port, label}  → host opens port-forward\n"
            "  service_stopped  — data: {service, host_port}               → host closes tunnel\n"
            "  install_error    — data: {error, command, hint}             → host tries to fix\n"
            "  action_required  — data: {description, command_suggestion}  → host takes action\n"
            "  task_complete    — data: {task, summary, result}            → logged as telemetry\n"
            "  status_update    — data: {component, status, detail}        → logged as telemetry\n\n"
            "ALWAYS call this after: starting/stopping a service, completing a task, or hitting an error."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "event": {"type": "string", "description": "Event type"},
                "data":  {"type": "object", "description": "Event payload"}
            },
            "required": ["event", "data"]
        }
    },
    {
        "name": "write_memory",
        "description": "Save an observation or note to the agent memory store.",
        "input_schema": {
            "type": "object",
            "properties": {
                "filename": {"type": "string",  "description": "Memory file name (e.g. status.md, concerns.md)"},
                "content":  {"type": "string",  "description": "Content to write"},
                "append":   {"type": "boolean", "description": "Append to existing file instead of overwriting (default false)"}
            },
            "required": ["filename", "content"]
        }
    },
    {
        "name": "read_memory",
        "description": "Read a memory file by name.",
        "input_schema": {
            "type": "object",
            "properties": {
                "filename": {"type": "string", "description": "Memory file name to read"}
            },
            "required": ["filename"]
        }
    },
    {
        "name": "list_memory",
        "description": "List all files in the agent memory store.",
        "input_schema": {"type": "object", "properties": {}}
    },
    {
        "name": "update_meta",
        "description": (
            "Update the structured meta.json file. "
            "Other agents (e.g. workspace-agent) can consume this to understand UMS state."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "meta": {"type": "object", "description": "Key-value pairs to merge into meta.json"}
            },
            "required": ["meta"]
        }
    },
]


def _check_ums_running() -> dict:
    pid = None
    pid_alive = False
    if _UMS_PID.exists():
        try:
            pid = int(_UMS_PID.read_text().strip())
            r = subprocess.run(["kill", "-0", str(pid)], capture_output=True)
            pid_alive = r.returncode == 0
        except Exception:
            pass

    http_status = None
    try:
        resp = urllib.request.urlopen("http://localhost:8080/actuator/health", timeout=3)
        body = json.loads(resp.read())
        http_status = body.get("status", "UNKNOWN")
    except Exception:
        pass

    return {
        "running": pid_alive or http_status == "UP",
        "pid": pid if pid_alive else None,
        "health_status": http_status,
    }


def _check_ui_running() -> dict:
    pid = None
    pid_alive = False
    if _UI_PID.exists():
        try:
            pid = int(_UI_PID.read_text().strip())
            r = subprocess.run(["kill", "-0", str(pid)], capture_output=True)
            pid_alive = r.returncode == 0
        except Exception:
            pass

    reachable = False
    try:
        urllib.request.urlopen("http://localhost:3000", timeout=3)
        reachable = True
    except Exception:
        pass

    return {
        "running": pid_alive or reachable,
        "pid": pid if pid_alive else None,
        "reachable": reachable,
    }


def execute_tool(name: str, inp: dict) -> dict:

    if name == "ums_status":
        return _check_ums_running()

    if name == "ui_status":
        return _check_ui_running()

    if name == "build_ums":
        if not _MVNW.exists():
            return {"success": False, "error": f"mvnw not found at {_MVNW}"}
        timeout = min(int(inp.get("timeout", 300)), 600)
        try:
            r = subprocess.run(
                ["bash", str(_MVNW), "package", "-DskipTests", "-q"],
                capture_output=True, text=True, timeout=timeout,
                cwd=str(_CONTAINER_ROOT),
            )
            output = (r.stdout + r.stderr).strip()
            return {
                "success": r.returncode == 0,
                "output":  output[-2000:] if output else "(no output)",
            }
        except subprocess.TimeoutExpired:
            return {"success": False, "error": f"build timed out after {timeout}s"}
        except Exception as e:
            return {"success": False, "error": str(e)}

    if name == "run_script":
        script_name = inp.get("script", "").strip()
        if script_name not in _KNOWN_SCRIPTS:
            return {"error": f"Unknown script '{script_name}'. Available: {list(_KNOWN_SCRIPTS.keys())}"}
        script_path = _KNOWN_SCRIPTS[script_name]
        if not script_path.exists():
            return {"error": f"Script not found: {script_path}"}
        args    = inp.get("args", "").strip()
        cmd     = ["bash", str(script_path)] + ([args] if args else [])
        timeout = 180 if script_name in ("build_ui_env", "start_ums") else 120
        try:
            r       = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
            output  = (r.stdout + r.stderr).strip()
            success = r.returncode == 0
            result  = {
                "success": success,
                "script":  script_name,
                "output":  output[-1500:] if output else "(no output)",
            }
            if success and script_name == "start_ui":
                port_info = _SCRIPT_PORTS.get(script_name)
                if port_info:
                    result["host_event"] = _notify_host("service_started", {
                        "service":   "admin-ui",
                        "port":      port_info["container_port"],
                        "host_port": port_info["host_port"],
                        "label":     port_info["label"],
                    })
            elif success and script_name == "stop_ui":
                port_info = _SCRIPT_PORTS.get("start_ui")
                if port_info:
                    result["host_event"] = _notify_host("service_stopped", {
                        "service":   "admin-ui",
                        "host_port": port_info["host_port"],
                    })
            elif success and script_name == "start_ums":
                result["host_event"] = _notify_host("status_update", {
                    "component": "ums-spring-boot",
                    "status":    "started",
                    "detail":    "UMS Spring Boot started on port 8080",
                })
            elif not success:
                result["host_event"] = _notify_host("install_error", {
                    "script":  script_name,
                    "error":   output[-500:],
                    "hint":    f"Script {script_name} failed inside {_CONTAINER_NAME}.",
                })
            return result
        except subprocess.TimeoutExpired:
            return {"success": False, "error": f"{script_name} timed out after {timeout}s"}
        except Exception as e:
            return {"success": False, "error": str(e)}

    if name == "get_logs":
        service = inp.get("service", "ums")
        lines   = inp.get("lines", 50)
        log_file = _UMS_LOG if service == "ums" else _UI_LOG
        if not log_file.exists():
            return {"error": f"Log file not found: {log_file}"}
        try:
            r = subprocess.run(["tail", f"-{lines}", str(log_file)],
                               capture_output=True, text=True, timeout=5)
            return {"log": r.stdout, "file": str(log_file)}
        except Exception as e:
            return {"error": str(e)}

    if name == "ping_service":
        host = inp["host"]
        port = int(inp["port"])
        path = inp.get("path")
        try:
            s = socket.create_connection((host, port), timeout=5)
            s.close()
        except Exception as e:
            return {"reachable": False, "host": host, "port": port, "error": str(e)}
        result = {"reachable": True, "tcp": "ok", "host": host, "port": port}
        if path:
            url = f"http://{host}:{port}{path}"
            try:
                resp = urllib.request.urlopen(url, timeout=5)
                result.update({"http_status": resp.status, "http": "ok", "url": url})
            except urllib.error.HTTPError as e:
                result.update({"http_status": e.code, "http": "error", "url": url})
            except Exception as e:
                result.update({"http": f"error: {e}", "url": url})
        return result

    if name == "run_shell":
        cmd     = inp.get("command", "").strip()
        timeout = min(int(inp.get("timeout", 30)), 300)
        if not cmd:
            return {"error": "command is required"}
        try:
            r = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True, timeout=timeout)
            output = (r.stdout + r.stderr).strip()
            return {"exit_code": r.returncode, "output": output[-3000:] if output else "(no output)"}
        except subprocess.TimeoutExpired:
            return {"exit_code": -1, "error": f"timed out after {timeout}s"}
        except Exception as e:
            return {"exit_code": -1, "error": str(e)}

    if name == "notify_host":
        event = inp.get("event", "").strip()
        data  = inp.get("data", {})
        if not event:
            return {"error": "event is required"}
        return _notify_host(event, data)

    if name == "write_memory":
        MEMORY_DIR.mkdir(exist_ok=True)
        filepath = MEMORY_DIR / inp["filename"]
        if inp.get("append") and filepath.exists():
            content = f"\n\n---\n*{datetime.now().strftime('%Y-%m-%d %H:%M')}*\n\n{inp['content']}"
            filepath.write_text(filepath.read_text() + content)
        else:
            filepath.write_text(inp["content"])
        return {"saved": str(filepath)}

    if name == "read_memory":
        filepath = MEMORY_DIR / inp["filename"]
        if not filepath.exists():
            return {"error": f"Memory file not found: {inp['filename']}"}
        return {"content": filepath.read_text()}

    if name == "list_memory":
        MEMORY_DIR.mkdir(exist_ok=True)
        files = [f.name for f in sorted(MEMORY_DIR.iterdir()) if f.is_file()]
        return {"files": files}

    if name == "update_meta":
        MEMORY_DIR.mkdir(exist_ok=True)
        meta_path = MEMORY_DIR / "meta.json"
        existing  = json.loads(meta_path.read_text()) if meta_path.exists() else {}
        existing.update(inp["meta"])
        existing["last_updated"] = datetime.now().isoformat()
        meta_path.write_text(json.dumps(existing, indent=2))
        return {"saved": str(meta_path)}

    return {"error": f"Unknown tool: {name}"}
