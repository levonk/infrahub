from __future__ import annotations

import asyncio
import logging
import os
import uuid
from datetime import datetime, timezone
from typing import Dict, Optional

from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel, Field

LOGGER = logging.getLogger("opencode-runner")
logging.basicConfig(level=logging.INFO)

app = FastAPI(title="Opencode Runner", version="0.1.0")


class SessionStartPayload(BaseModel):
    repo_path: str = Field(..., description="Path inside /p mount for the repo worktree")
    # Additional fields can be added if Opencode requires them (e.g. specific provider args)


class SessionStopPayload(BaseModel):
    session_id: str


class RunnerSession(BaseModel):
    session_id: str
    repo_path: str
    state: str
    created_at: datetime
    updated_at: datetime
    detail: Optional[str]
    log_path: str
    docker_host: Optional[str]


_SESSIONS: Dict[str, RunnerSession] = {}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _ensure_repo_path(repo_path: str) -> None:
    if not repo_path.startswith("/p/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="repo_path must be under /p/",
        )
    if not os.path.exists(repo_path):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"repo_path does not exist: {repo_path}",
        )


async def _async_run(cmd: list[str], env: dict[str, str], log_path: str, cwd: str) -> None:
    LOGGER.info("launching process: %s in %s", " ".join(cmd), cwd)
    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            env=env,
            cwd=cwd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
        )
        assert proc.stdout
        with open(log_path, "a", encoding="utf-8") as log_file:
            async for line in proc.stdout:
                text = line.decode("utf-8", errors="replace")
                log_file.write(text)
        await proc.wait()
        LOGGER.info("process exited code=%s", proc.returncode)
    except FileNotFoundError as exc:
        LOGGER.error("failed to launch process: %s", exc)
        raise


async def _launch_opencode(session_id: str, session: RunnerSession) -> None:
    env = dict(os.environ)
    env["OPENCODE_SESSION_ID"] = session_id
    # Ensure Docker access is passed through
    env.setdefault("DOCKER_HOST", os.getenv("DOCKER_HOST", "unix:///var/run/docker.sock"))

    # Opencode command - strictly non-interactive mode if available, or just standard start
    # Using bunx to align with oh-my-opencode tooling
    cmd = [
        "bunx",
        "opencode-ai",
    ]

    try:
        # Run in the repo path so it picks up context?
        # Or does it take args? Docs are sparse, assuming CWD matters.
        await _async_run(cmd, env, session.log_path, cwd=session.repo_path)
        session.state = "completed"
    except Exception as exc:  # pylint: disable=broad-except
        LOGGER.exception("session %s failed", session_id)
        session.state = "error"
        session.detail = str(exc)
    finally:
        session.updated_at = _now()


@app.get("/healthz", status_code=status.HTTP_200_OK)
async def healthz() -> dict[str, str]:
    docker_host = os.getenv("DOCKER_HOST", "unset")
    return {"status": "ok", "docker_host": docker_host}


@app.post("/sessions/start", response_model=RunnerSession, status_code=status.HTTP_201_CREATED)
async def start_session(payload: SessionStartPayload) -> RunnerSession:
    _ensure_repo_path(payload.repo_path)

    session_id = str(uuid.uuid4())
    log_path = f"/var/log/opencode/{session_id}.log"
    os.makedirs(os.path.dirname(log_path), exist_ok=True)

    session = RunnerSession(
        session_id=session_id,
        repo_path=payload.repo_path,
        state="starting",
        created_at=_now(),
        updated_at=_now(),
        detail=None,
        log_path=log_path,
        docker_host=os.getenv("DOCKER_HOST"),
    )
    _SESSIONS[session_id] = session

    asyncio.create_task(_launch_opencode(session_id, session))

    return session


@app.post("/sessions/stop", response_model=RunnerSession)
async def stop_session(payload: SessionStopPayload) -> RunnerSession:
    session = _SESSIONS.get(payload.session_id)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="session not found",
        )
    # Placeholder for stop logic
    session.state = "stopped"
    session.updated_at = _now()
    return session


@app.get("/sessions", response_model=list[RunnerSession])
async def list_sessions() -> list[RunnerSession]:
    return list(_SESSIONS.values())
