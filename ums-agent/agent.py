#!/usr/bin/env python3
import os
import sys
import json
from pathlib import Path
from datetime import datetime
import anthropic
from dotenv import load_dotenv
from tools import TOOL_DEFINITIONS, execute_tool, MEMORY_DIR

AGENT_DIR = Path(__file__).parent
load_dotenv(AGENT_DIR / "agent.conf")

SYSTEM_PROMPT = f"""You are the UMS Agent running inside the ums-app container.

Container:   ums-app
Spring Boot: localhost:8080  (UMS REST API + Swagger at /swagger-ui.html)
Admin UI:    localhost:3000  (React static app — started separately via start_ui script)
Network:     ums-network  (shared with mypostgresql_db-container and other services)
Memory:      {MEMORY_DIR}
Today:       {datetime.now().strftime('%Y-%m-%d')}

YOUR PURPOSE:
You are the expert on this UMS application stack. You manage the Spring Boot service and
Admin UI, diagnose issues, monitor health, coordinate with other agents on the network,
and communicate with the host via docker-manager-agent.

WHAT YOU KNOW:
- UMS is a User Management System — Spring Boot 3 + PostgreSQL + Redis (optional)
- Database lives in mypostgresql_db-container (managed by db-agent on port 8890)
- Admin UI is a React + Vite app at /ums/ums-ui/ — built and served by start_ui script
- Container scripts are at /ums/dockerspace/container_scripts/
- Spring Boot logs: /ums/logs/ums.log
- Admin UI logs: /ums/ums-ui/admin-ui.log
- Maven wrapper: /ums/mvnw (for builds — requires JDK)
- Spring Boot default profile: dev  (reads DB_URL, DB_USERNAME, DB_PASSWORD from env)
- Port 8080 is mapped directly to the host; port 3000 uses a socat port-forward

YOUR RESPONSIBILITIES:
1. MANAGE     — Start, stop, and monitor the UMS Spring Boot service and Admin UI
2. DIAGNOSE   — Check logs, health endpoints, and process state to investigate issues
3. BUILD      — Compile the Spring Boot JAR (build_ums) or rebuild the UI bundle (start_ui)
4. BRIDGE     — Ping mypostgresql_db-container and other services on the network
5. NOTIFY     — Always inform docker-manager-agent about service start/stop events
6. REMEMBER   — Log important findings and state changes to memory
7. EXECUTE    — Run any shell command or container script the user requests

MEMORY FILES YOU MAINTAIN:
- status.md      — current state of UMS and Admin UI services
- sessions.md    — log of agent sessions with timestamps
- concerns.md    — open issues, errors, and action items
- meta.json      — machine-readable summary for other agents

SHELL EXECUTION:
- You have run_shell to execute ANY Linux command inside this container
- Always proceed and execute — never ask for confirmation before running shell commands
- Use run_script for known operations: start_ums, stop_ums, start_ui, stop_ui, etc.

NOTIFY HOST RULES:
- After start_ui succeeds → notify_host("service_started", {{service, port: 3000, host_port: 3000, label}})
- After stop_ui succeeds  → notify_host("service_stopped", {{service, host_port: 3000}})
- After any error         → notify_host("install_error", {{error, hint}})
- After task completes    → notify_host("task_complete", {{task, summary}})
The run_script tool auto-notifies for known scripts — call notify_host manually only for custom events.

SAFETY:
- Never delete /ums/src/ or /ums/pom.xml without explicit user confirmation
- For destructive shell commands, explain the impact first
"""

BOLD   = "\033[1m"
GREEN  = "\033[32m"
RED    = "\033[31m"
CYAN   = "\033[36m"
DIM    = "\033[2m"
YELLOW = "\033[33m"
RESET  = "\033[0m"


def print_tool_call(name: str, inp: dict):
    print(f"\n  {CYAN}[{name}]{RESET}", end=" ")
    if name == "run_shell":
        print(f"{DIM}{inp['command'][:120].strip()}{RESET}")
    elif name == "run_script":
        args = inp.get("args", "")
        print(f"{inp['script']}" + (f"  {args}" if args else ""))
    elif name in ("write_memory", "read_memory"):
        print(inp.get("filename", ""))
    elif name == "ping_service":
        path = inp.get("path", "")
        print(f"{inp['host']}:{inp['port']}{path}")
    elif name == "get_logs":
        print(f"{inp.get('service', 'ums')}  lines={inp.get('lines', 50)}")
    elif name == "notify_host":
        print(f"{inp.get('event', '')}  {DIM}{str(inp.get('data', {}))[:80]}{RESET}")
    elif name == "update_meta":
        print(f"keys={list(inp.get('meta', {}).keys())}")
    else:
        print()


def print_tool_result(name: str, result: dict):
    if result.get("error"):
        print(f"  {RED}  → error: {result['error']}{RESET}")
    elif name in ("ums_status", "ui_status"):
        running = result.get("running")
        icon = f"{GREEN}✔{RESET}" if running else f"{YELLOW}—{RESET}"
        detail = ""
        if result.get("pid"):
            detail += f"  PID {result['pid']}"
        if result.get("health_status"):
            detail += f"  status={result['health_status']}"
        print(f"  {icon}{detail}")
    elif name == "run_script":
        if result.get("success"):
            print(f"  {GREEN}  → ok{RESET}")
        else:
            out = result.get("output", "")
            print(f"  {RED}  → failed{RESET}  {DIM}{out[-80:]}{RESET}")
    elif name == "run_shell":
        out = result.get("output", "")
        code = result.get("exit_code", 0)
        icon = GREEN if code == 0 else RED
        for line in out.splitlines()[-10:]:
            if line.strip():
                print(f"  {DIM}  {line}{RESET}")
    elif name == "ping_service":
        if result.get("reachable"):
            print(f"  {GREEN}  → reachable{RESET}")
        else:
            print(f"  {RED}  → unreachable: {result.get('error')}{RESET}")
    elif name == "write_memory":
        print(f"  {GREEN}  → saved: {result.get('saved')}{RESET}")
    elif name == "list_memory":
        print(f"  {DIM}  {result.get('files', [])}{RESET}")
    else:
        preview = str(result)[:150]
        print(f"  {DIM}  → {preview}{RESET}")


def log_session(note: str):
    entry = f"\n---\n**{datetime.now().strftime('%Y-%m-%d %H:%M')}** — {note}"
    sessions = MEMORY_DIR / "sessions.md"
    existing = sessions.read_text() if sessions.exists() else "# UMS Agent Sessions\n"
    sessions.write_text(existing + entry)


def run_agent(user_message: str, history: list) -> list:
    client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

    history.append({"role": "user", "content": user_message})
    print(f"\n{BOLD}You:{RESET} {user_message}\n")

    while True:
        response = client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=8096,
            system=SYSTEM_PROMPT,
            tools=TOOL_DEFINITIONS,
            messages=history,
        )

        tool_calls  = [b for b in response.content if b.type == "tool_use"]
        text_blocks = [b for b in response.content if b.type == "text"]

        for block in text_blocks:
            if block.text.strip():
                print(f"\n{BOLD}Agent:{RESET} {block.text}")

        if response.stop_reason == "end_turn" or not tool_calls:
            final = " ".join(b.text for b in text_blocks if b.type == "text").strip()
            if final:
                history.append({"role": "assistant", "content": final})
            break

        history.append({"role": "assistant", "content": response.content})

        tool_results = []
        for block in tool_calls:
            print_tool_call(block.name, block.input)
            result = execute_tool(block.name, block.input)
            print_tool_result(block.name, result)
            tool_results.append({
                "type":        "tool_result",
                "tool_use_id": block.id,
                "content":     json.dumps(result, default=str),
            })

        history.append({"role": "user", "content": tool_results})

    print()
    return history


def chat_loop():
    MEMORY_DIR.mkdir(exist_ok=True)

    print(f"\n{BOLD}╔══════════════════════════════════════════╗{RESET}")
    print(f"{BOLD}║     UMS Agent                            ║{RESET}")
    print(f"{BOLD}║     ums-app container                    ║{RESET}")
    print(f"{BOLD}╚══════════════════════════════════════════╝{RESET}")
    print(f"{DIM}Type your request or 'exit' to quit.{RESET}")
    print(f"{DIM}Suggested: 'check status' | 'start ums' | 'start ui' | 'check logs'{RESET}\n")

    log_session("session started")
    history = []

    while True:
        try:
            user_input = input(f"{BOLD}>{RESET} ").strip()
        except (EOFError, KeyboardInterrupt):
            print(f"\n{DIM}Session ended.{RESET}")
            log_session("session ended by user")
            break

        if not user_input:
            continue
        if user_input.lower() in ("exit", "quit"):
            log_session("session ended")
            print("Bye.")
            break

        history = run_agent(user_input, history)


if __name__ == "__main__":
    if not os.environ.get("ANTHROPIC_API_KEY"):
        print(f"{RED}Error:{RESET} ANTHROPIC_API_KEY not set in agent.conf")
        sys.exit(1)

    MEMORY_DIR.mkdir(exist_ok=True)

    if len(sys.argv) > 1:
        run_agent(" ".join(sys.argv[1:]), [])
    else:
        chat_loop()
