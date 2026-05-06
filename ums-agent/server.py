"""
UMS Agent HTTP Server — runs inside ums-app container on port 8891.

Endpoints:
  GET  /health             liveness + UMS + Admin UI status
  GET  /api/ums/status     Spring Boot running state
  POST /api/ums/start      start UMS via start.sh
  POST /api/ums/stop       stop UMS via stop.sh
  GET  /api/ui/status      Admin UI running state
  POST /api/ui/start       start Admin UI via start_admin_ui.sh
  POST /api/ui/stop        stop Admin UI via stop_admin_ui.sh
  POST /api/tasks          AI agent task (called by docker-manager-agent)
  WS   /ws/chat            streaming chat (proxied by orchestrator)
"""
import asyncio
import json
import os
import sys
from datetime import datetime
from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
import anthropic as _anthropic
from pydantic import BaseModel

AGENT_DIR = Path(__file__).parent
load_dotenv(AGENT_DIR / "agent.conf")

sys.path.insert(0, str(AGENT_DIR))
import agent as ai_agent
from tools import TOOL_DEFINITIONS, execute_tool, MEMORY_DIR

_CHAT_LOG = MEMORY_DIR / "chat_history.log"

app = FastAPI(title="UMS Agent", version="1.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


@app.get("/")
def root():
    return RedirectResponse(url="/docs")


@app.get("/health")
def health():
    ums = execute_tool("ums_status", {})
    ui  = execute_tool("ui_status", {})
    return {
        "status":      "ok",
        "agent":       "ums-agent",
        "ums_running": ums.get("running", False),
        "ui_running":  ui.get("running", False),
        "time":        datetime.now().isoformat(),
    }


@app.get("/api/ums/status")
def ums_status():
    return execute_tool("ums_status", {})


@app.post("/api/ums/start")
def ums_start():
    result = execute_tool("run_script", {"script": "start_ums"})
    if not result.get("success"):
        raise HTTPException(status_code=500, detail=result.get("output", "start failed"))
    return result


@app.post("/api/ums/stop")
def ums_stop():
    result = execute_tool("run_script", {"script": "stop_ums"})
    if not result.get("success"):
        raise HTTPException(status_code=500, detail=result.get("output", "stop failed"))
    return result


@app.get("/api/ui/status")
def ui_status():
    return execute_tool("ui_status", {})


@app.post("/api/ui/start")
def ui_start():
    result = execute_tool("run_script", {"script": "start_ui"})
    if not result.get("success"):
        raise HTTPException(status_code=500, detail=result.get("output", "start failed"))
    return result


@app.post("/api/ui/stop")
def ui_stop():
    result = execute_tool("run_script", {"script": "stop_ui"})
    if not result.get("success"):
        raise HTTPException(status_code=500, detail=result.get("output", "stop failed"))
    return result


class TaskRequest(BaseModel):
    task: str


@app.post("/api/tasks")
async def handle_task(body: TaskRequest):
    if not body.task.strip():
        raise HTTPException(status_code=400, detail="task field required")
    if not os.environ.get("ANTHROPIC_API_KEY"):
        raise HTTPException(status_code=503, detail="ANTHROPIC_API_KEY not set in agent.conf")

    loop = asyncio.get_event_loop()

    def _run():
        client  = _anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
        history = [{"role": "user", "content": body.task.strip()}]
        response = ""
        while True:
            resp = client.messages.create(
                model="claude-sonnet-4-6", max_tokens=4096,
                system=ai_agent.SYSTEM_PROMPT,
                tools=TOOL_DEFINITIONS,
                messages=history,
            )
            tool_calls = [b for b in resp.content if b.type == "tool_use"]
            texts      = [b for b in resp.content if b.type == "text"]

            if resp.stop_reason == "end_turn" or not tool_calls:
                response = " ".join(b.text for b in texts).strip()
                break

            history.append({"role": "assistant", "content": resp.content})
            results = []
            for b in tool_calls:
                result = execute_tool(b.name, b.input)
                results.append({
                    "type":        "tool_result",
                    "tool_use_id": b.id,
                    "content":     json.dumps(result, default=str),
                })
            history.append({"role": "user", "content": results})

        return response

    result = await loop.run_in_executor(None, _run)
    return {"result": result or "(no response)"}


def _append_chat(role: str, content: str):
    _CHAT_LOG.parent.mkdir(exist_ok=True)
    ts   = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = json.dumps({"ts": ts, "role": role, "content": content}, ensure_ascii=False)
    with open(_CHAT_LOG, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def _load_chat() -> list:
    if not _CHAT_LOG.exists():
        return []
    lines = _CHAT_LOG.read_text(encoding="utf-8").splitlines()
    lines = lines[-60:]
    result = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            result.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return result


async def _chat_turn(ws: WebSocket, history: list, client) -> list:
    loop = asyncio.get_event_loop()
    while True:
        resp = await loop.run_in_executor(None, lambda: client.messages.create(
            model="claude-sonnet-4-6", max_tokens=4096,
            system=ai_agent.SYSTEM_PROMPT,
            tools=TOOL_DEFINITIONS,
            messages=history,
        ))
        tool_calls = [b for b in resp.content if b.type == "tool_use"]
        texts      = [b for b in resp.content if b.type == "text"]

        for b in texts:
            if b.text.strip():
                await ws.send_json({"type": "text", "content": b.text})

        if resp.stop_reason == "end_turn" or not tool_calls:
            final = " ".join(b.text for b in texts).strip()
            if final:
                history.append({"role": "assistant", "content": final})
                _append_chat("assistant", final)
            break

        history.append({"role": "assistant", "content": resp.content})
        results = []
        for b in tool_calls:
            await ws.send_json({"type": "tool_call", "id": b.id, "name": b.name, "input": b.input})
            result = await loop.run_in_executor(None, lambda blk=b: execute_tool(blk.name, blk.input))
            await ws.send_json({"type": "tool_result", "id": b.id, "name": b.name, "result": result})
            results.append({
                "type":        "tool_result",
                "tool_use_id": b.id,
                "content":     json.dumps(result, default=str),
            })
        history.append({"role": "user", "content": results})

    await ws.send_json({"type": "done"})
    return history


@app.websocket("/ws/chat")
async def ws_chat(ws: WebSocket):
    await ws.accept()

    if not os.environ.get("ANTHROPIC_API_KEY"):
        await ws.send_json({"type": "error", "content": "ANTHROPIC_API_KEY not set in agent.conf"})
        await ws.close()
        return

    client  = _anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
    saved   = _load_chat()
    history = [{"role": m["role"], "content": m["content"]} for m in saved]

    for m in saved:
        await ws.send_json({
            "type":    "history_msg",
            "role":    m["role"],
            "content": m["content"],
            "ts":      m.get("ts", ""),
        })

    try:
        while True:
            data = await ws.receive_text()
            text = json.loads(data).get("content", "").strip()
            if not text:
                continue
            history.append({"role": "user", "content": text})
            _append_chat("user", text)
            history = await _chat_turn(ws, history, client)
    except WebSocketDisconnect:
        pass
