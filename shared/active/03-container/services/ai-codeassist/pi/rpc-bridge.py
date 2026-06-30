#!/usr/bin/env python3
"""Pi RPC HTTP bridge.

Omnigent's runner normally spawns `pi --mode rpc` as a local subprocess and
talks to it over stdin/stdout (JSONL). When pi is containerized (for cloud
sandbox hosts), the runner reaches it over the network instead. This bridge
exposes the RPC protocol over HTTP so a remote runner can dispatch work to pi.

Endpoints:
  GET  /health       — liveness probe
  POST /rpc          — send a single JSONL command, return streamed JSONL events
  POST /session/start — start a new pi RPC subprocess, return session id
  POST /session/:id/prompt — send a prompt to a specific session
  POST /session/:id/abort  — abort the current operation in a session
  DELETE /session/:id      — stop a session subprocess

The bridge spawns one `pi --mode rpc` subprocess per session and holds the
stdin/stdout pipes for the lifetime of that session. This is the minimal
mapping of the RPC protocol to HTTP; Omnigent's runner SDK handles the
higher-level session orchestration.

ponytail: single-process, in-memory session map. Ceiling: one bridge instance
can't be horizontally scaled (sessions are local subprocess state). Upgrade
path: move session state to a shared store (Redis) and run multiple bridge
replicas behind a load balancer with sticky sessions.
"""
import json
import os
import signal
import subprocess
import threading
import uuid
from http.server import HTTPServer, BaseHTTPRequestHandler

PI_RPC_PORT = int(os.environ.get("PI_RPC_PORT", "8090"))
PI_PROVIDER = os.environ.get("PI_PROVIDER", "openai")
PI_MODEL = os.environ.get("PI_MODEL", "claude-sonnet-4-20250514")
PI_WORKSPACE = os.environ.get("PI_WORKSPACE_DIR", "/workspace")
PI_SESSION_DIR = os.environ.get("PI_SESSION_DIR", "/data/sessions")
PI_NO_SESSION = os.environ.get("PI_NO_SESSION", "0")

# In-memory session map: session_id → {proc, stdin, stdout, lock}
sessions: dict = {}
sessions_lock = threading.Lock()


def start_pi_subprocess():
    cmd = [
        "pi", "--mode", "rpc",
        "--provider", PI_PROVIDER,
        "--model", PI_MODEL,
        "--session-dir", PI_SESSION_DIR,
    ]
    if PI_NO_SESSION == "1":
        cmd.append("--no-session")
    return subprocess.Popen(
        cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        cwd=PI_WORKSPACE,
    )


class RPCHandler(BaseHTTPRequestHandler):
    def _send_json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_body(self):
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return {}
        return json.loads(self.rfile.read(length))

    def do_GET(self):
        if self.path == "/health":
            self._send_json(200, {"status": "ok", "sessions": len(sessions)})
        else:
            self._send_json(404, {"error": "not found"})

    def do_POST(self):
        parts = self.path.strip("/").split("/")
        if parts[0] == "rpc":
            self._handle_rpc()
        elif parts[0] == "session" and len(parts) >= 2 and parts[1] == "start":
            self._handle_session_start()
        elif parts[0] == "session" and len(parts) >= 3 and parts[2] == "prompt":
            self._handle_session_prompt(parts[1])
        elif parts[0] == "session" and len(parts) >= 3 and parts[2] == "abort":
            self._handle_session_abort(parts[1])
        else:
            self._send_json(404, {"error": "not found"})

    def do_DELETE(self):
        parts = self.path.strip("/").split("/")
        if parts[0] == "session" and len(parts) >= 2:
            self._handle_session_stop(parts[1])
        else:
            self._send_json(404, {"error": "not found"})

    def _handle_rpc(self):
        """Single-shot RPC: send one command, stream events until response."""
        body = self._read_body()
        sid = body.get("session_id")
        with sessions_lock:
            s = sessions.get(sid)
        if not s:
            self._send_json(404, {"error": "session not found"})
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/x-ndjson")
        self.end_headers()
        with s["lock"]:
            s["stdin"].write(json.dumps(body) + "\n")
            s["stdin"].flush()
            # Stream events until we see the response for this command
            req_id = body.get("id")
            for line in s["stdout"]:
                self.wfile.write(line.encode())
                self.wfile.flush()
                try:
                    evt = json.loads(line)
                    if evt.get("type") == "response" and (req_id is None or evt.get("id") == req_id):
                        break
                except json.JSONDecodeError:
                    continue

    def _handle_session_start(self):
        with sessions_lock:
            sid = str(uuid.uuid4())
            proc = start_pi_subprocess()
            sessions[sid] = {
                "proc": proc,
                "stdin": proc.stdin,
                "stdout": proc.stdout,
                "lock": threading.Lock(),
            }
        self._send_json(200, {"session_id": sid})

    def _handle_session_prompt(self, sid):
        body = self._read_body()
        with sessions_lock:
            s = sessions.get(sid)
        if not s:
            self._send_json(404, {"error": "session not found"})
            return
        cmd = {"type": "prompt", "message": body.get("message", "")}
        if "id" in body:
            cmd["id"] = body["id"]
        self.send_response(200)
        self.send_header("Content-Type", "application/x-ndjson")
        self.end_headers()
        with s["lock"]:
            s["stdin"].write(json.dumps(cmd) + "\n")
            s["stdin"].flush()
            for line in s["stdout"]:
                self.wfile.write(line.encode())
                self.wfile.flush()
                try:
                    evt = json.loads(line)
                    if evt.get("type") == "response":
                        break
                except json.JSONDecodeError:
                    continue

    def _handle_session_abort(self, sid):
        with sessions_lock:
            s = sessions.get(sid)
        if not s:
            self._send_json(404, {"error": "session not found"})
            return
        with s["lock"]:
            s["stdin"].write(json.dumps({"type": "abort"}) + "\n")
            s["stdin"].flush()
        self._send_json(200, {"status": "aborted"})

    def _handle_session_stop(self, sid):
        with sessions_lock:
            s = sessions.pop(sid, None)
        if not s:
            self._send_json(404, {"error": "session not found"})
            return
        try:
            s["proc"].terminate()
            s["proc"].wait(timeout=5)
        except subprocess.TimeoutExpired:
            s["proc"].kill()
        self._send_json(200, {"status": "stopped"})

    def log_message(self, fmt, *args):
        pass  # suppress default logging


def main():
    server = HTTPServer(("0.0.0.0", PI_RPC_PORT), RPCHandler)
    print(f"pi RPC bridge listening on :{PI_RPC_PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
