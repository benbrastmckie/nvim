#!/usr/bin/env python3
"""Bidirectional Typst <-> PDF position resolver for a single Typst project.

Typst emits no SyncTeX, but `tinymist preview` already computes the mapping in both
directions and speaks it over two websockets. This daemon owns a headless
`tinymist preview` process, holds both of its planes open, and exposes the two
resolutions over a line-oriented Unix socket so that Neovim (forward search) and the
PDF viewer's click handler (inverse search) can both ask for them.

Protocol notes, each established against a live server rather than assumed:

* Forward resolution is a control-plane request, answered on the data plane.
  `{"event":"panelScrollTo","filepath":...,"line":L,"character":C}` (both 0-based)
  makes the server emit a *binary* frame `jump,<page_no> <x> <y>[,<page_no> <x> <y>...]`
  where page_no is 1-based and x/y are PDF points from the page's top-left corner.

* Inverse resolution is a data-plane request, answered on the control plane.
  The text frame `src-point <json>` makes the server resolve the span at that document
  position and emit `{"event":"editorScrollTo","filepath":...,"start":[row,col],...}`
  on the control plane, with a 0-based row. The JSON must contain no spaces: the
  server's handler splits the message on spaces and takes the second field.

* Neither request carries an id, so requests must be serialized; a lock plus a drain
  of stale replies is what keeps one answer from being read as another's.

* The data-plane client must send `current` once, as a text frame with no trailing
  newline, before any resolution works -- the render actor needs a subscriber. A
  malformed frame makes the server drop its webview actor, so frames are built, never
  formatted loosely.

* The control plane shuts the whole server down when its client disconnects, which is
  why this is a long-lived daemon rather than a per-query connection.

Socket requests (one line in, one line out, connection closed after):

    ping                                   -> ok
    forward <line0> <col0> <abs-path>      -> ok <page_no> <x> <y>
    inverse <page_no> <x> <y>              -> ok <line0> <col0> <abs-path>
    shutdown                               -> ok

Failures answer `err <reason>`. The absolute path is last so it may contain spaces.
"""

from __future__ import annotations

import argparse
import asyncio
import contextlib
import json
import os
import re
import signal
import sys

try:
    import websockets
except ImportError:  # pragma: no cover - environment guard
    sys.stderr.write("typst-sync-daemon: the python 'websockets' package is required\n")
    raise SystemExit(3)

RESOLVE_TIMEOUT = 6.0
# Per-nudge budget. A click is answered in well under a second when it resolves at all,
# so this only bounds how long a point with no span beneath it stalls the caller.
NUDGE_TIMEOUT = 1.5
# A click lands mid-glyph so the unshifted point normally resolves. The forward
# direction, though, reports a line-box boundary, so a point fed straight back needs a
# nudge into the body of the line. Small steps first, and both signs, so a near-miss
# never silently resolves to a neighbouring line when the exact point would have worked.
# Kept short deliberately: a click must feel immediate even when it lands in a margin.
Y_NUDGES = (0.0, 2.0, -2.0, 4.0)


def log(msg: str) -> None:
    sys.stderr.write(f"typst-sync-daemon: {msg}\n")
    sys.stderr.flush()


class PreviewSession:
    """A `tinymist preview` process plus its two live websocket connections."""

    def __init__(self, main: str, root: str) -> None:
        self.main = main
        self.root = root
        self.proc: asyncio.subprocess.Process | None = None
        self.data = None
        self.ctrl = None
        self._jumps: asyncio.Queue[str] = asyncio.Queue()
        self._scrolls: asyncio.Queue[dict] = asyncio.Queue()
        self._tasks: list[asyncio.Task] = []
        self._lock = asyncio.Lock()

    # -- lifecycle ---------------------------------------------------------------

    async def start(self) -> None:
        self.proc = await asyncio.create_subprocess_exec(
            "tinymist", "preview", "--no-open",
            "--root", self.root,
            "--data-plane-host", "127.0.0.1:0",
            "--control-plane-host", "127.0.0.1:0",
            "--static-file-host", "",
            self.main,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
        )
        data_host = ctrl_host = None
        assert self.proc.stdout is not None
        while data_host is None or ctrl_host is None:
            raw = await asyncio.wait_for(self.proc.stdout.readline(), 60.0)
            if not raw:
                raise RuntimeError("tinymist preview exited before announcing its ports")
            line = raw.decode(errors="replace")
            if m := re.search(r"Data plane server listening on: (\S+)", line):
                data_host = m.group(1)
            if m := re.search(r"Control panel server listening on: (\S+)", line):
                ctrl_host = m.group(1)

        # Keep draining stdout; a full pipe would otherwise stall the server.
        self._tasks.append(asyncio.create_task(self._drain_stdout()))

        # Keepalive pings must be off. The control plane answers a websocket ping frame
        # with `ERROR unsupported ping message` and closes the connection, and because
        # the server shuts down when its control-plane client goes away, the default
        # 20-second ping interval otherwise tears the whole session down on a timer.
        # Both planes are local to this process, so there is nothing for a keepalive to
        # detect that a dead-session restart does not already handle.
        self.data = await websockets.connect(
            f"ws://{data_host}/", origin="http://localhost",
            max_size=None, ping_interval=None,
        )
        self.ctrl = await websockets.connect(
            f"ws://{ctrl_host}/", origin="http://localhost",
            max_size=None, ping_interval=None,
        )
        self._tasks.append(asyncio.create_task(self._read_data()))
        self._tasks.append(asyncio.create_task(self._read_ctrl()))

        # Subscribe the render actor, then let the first compile land.
        await self.data.send("current")
        log(f"session up (data={data_host} ctrl={ctrl_host})")

    async def _drain_stdout(self) -> None:
        """Keep the server's stdout pipe empty, surfacing only its complaints.

        The pipe must be read or the server stalls once it fills. Compile-status chatter
        is noise, but the server reports a rejected frame or a dying actor here and
        nowhere else, so those lines are the only diagnosis available when a resolution
        stops working.
        """
        assert self.proc is not None and self.proc.stdout is not None
        with contextlib.suppress(Exception):
            while raw := await self.proc.stdout.readline():
                line = raw.decode(errors="replace").rstrip()
                if ("ERROR" in line or "WARN" in line
                        or "unknown message" in line or "exiting" in line):
                    log(f"preview: {line}")

    async def close(self) -> None:
        for task in self._tasks:
            task.cancel()
        for conn in (self.data, self.ctrl):
            if conn is not None:
                with contextlib.suppress(Exception):
                    await conn.close()
        if self.proc is not None and self.proc.returncode is None:
            with contextlib.suppress(ProcessLookupError):
                self.proc.terminate()
            with contextlib.suppress(asyncio.TimeoutError):
                await asyncio.wait_for(self.proc.wait(), 5.0)

    @property
    def alive(self) -> bool:
        return (
            self.proc is not None
            and self.proc.returncode is None
            and self.data is not None
            and self.ctrl is not None
        )

    # -- readers -----------------------------------------------------------------

    async def _read_data(self) -> None:
        try:
            async for frame in self.data:  # type: ignore[union-attr]
                # Rendered SVG arrives here too and is deliberately dropped.
                if isinstance(frame, bytes) and frame[:5] == b"jump,":
                    await self._jumps.put(frame.decode(errors="replace"))
        except Exception as exc:  # pragma: no cover - connection teardown
            log(f"data plane closed: {exc}")

    async def _read_ctrl(self) -> None:
        try:
            async for frame in self.ctrl:  # type: ignore[union-attr]
                if not isinstance(frame, str):
                    continue
                try:
                    msg = json.loads(frame)
                except ValueError:
                    continue
                if msg.get("event") == "editorScrollTo":
                    await self._scrolls.put(msg)
        except Exception as exc:  # pragma: no cover - connection teardown
            log(f"control plane closed: {exc}")

    @staticmethod
    def _drain(queue: asyncio.Queue) -> None:
        while not queue.empty():
            with contextlib.suppress(asyncio.QueueEmpty):
                queue.get_nowait()

    # -- resolutions -------------------------------------------------------------

    async def forward(self, path: str, line0: int, col0: int) -> tuple[int, float, float]:
        """Resolve a source position to a 1-based page and a point in PDF points."""
        async with self._lock:
            self._drain(self._jumps)
            await self.ctrl.send(json.dumps({  # type: ignore[union-attr]
                "event": "panelScrollTo",
                "filepath": path,
                "line": line0,
                "character": col0,
            }))
            try:
                frame = await asyncio.wait_for(self._jumps.get(), RESOLVE_TIMEOUT)
            except asyncio.TimeoutError:
                # The server stays silent rather than answering when the position
                # contributes no output -- a comment, a blank line, a bare `$`
                # delimiter, an import. That is an answer, not a malfunction.
                raise LookupError("no PDF output for that source position") from None

        first = frame.split(",", 1)[1].split(",")[0].split()
        if len(first) != 3:
            raise ValueError(f"malformed jump frame: {frame[:80]!r}")
        return int(first[0]), float(first[1]), float(first[2])

    async def inverse(self, page_no: int, x: float, y: float) -> tuple[str, int, int]:
        """Resolve a document point to a path and a 0-based (line, column)."""
        last_error: Exception | None = None
        for dy in Y_NUDGES:
            async with self._lock:
                self._drain(self._scrolls)
                # Compact separators are required: the server splits this on spaces.
                payload = json.dumps(
                    {"page_no": page_no, "x": x, "y": y + dy}, separators=(",", ":")
                )
                await self.data.send(f"src-point {payload}")  # type: ignore[union-attr]
                try:
                    msg = await asyncio.wait_for(self._scrolls.get(), NUDGE_TIMEOUT)
                except asyncio.TimeoutError as exc:
                    last_error = exc
                    continue
            start = msg.get("start") or [0, 0]
            return msg.get("filepath", ""), int(start[0]), int(start[1])
        raise TimeoutError("no span at that point") from last_error


class Daemon:
    def __init__(self, main: str, root: str, socket_path: str) -> None:
        self.main = main
        self.root = root
        self.socket_path = socket_path
        self.session: PreviewSession | None = None
        self._stopping = asyncio.Event()
        self._restart_lock = asyncio.Lock()

    async def _ensure_session(self) -> PreviewSession:
        async with self._restart_lock:
            if self.session is not None and self.session.alive:
                return self.session
            if self.session is not None:
                log("session died; restarting")
                await self.session.close()
            session = PreviewSession(self.main, self.root)
            await session.start()
            # Give the first compile time to produce a document to resolve against.
            await asyncio.sleep(2.0)
            self.session = session
            return session

    async def _resolve(self, op, *args):
        """Run one resolution, retrying once across a session restart.

        The preview process is long-lived but not immortal: a recompile storm or a
        dropped plane can take it down between two requests, and the request that lands
        on the dying session sees the connection error rather than the restart. Retrying
        once turns that into a transparent recovery, which is what a keypress needs.
        """
        for attempt in (1, 2):
            session = await self._ensure_session()
            try:
                return await getattr(session, op)(*args)
            except (ConnectionError, OSError) as exc:
                if attempt == 2:
                    raise
                log(f"{op} failed on a dead session ({exc}); retrying once")
                self.session = None
            except Exception as exc:
                # websockets raises its own closed-connection types, which are not
                # ConnectionError subclasses; treat them the same but only by name so
                # genuine resolution failures still surface.
                if "ConnectionClosed" not in type(exc).__name__ or attempt == 2:
                    raise
                log(f"{op} failed on a closed plane ({exc}); retrying once")
                self.session = None
        raise RuntimeError("unreachable")

    async def handle(self, request: str) -> str:
        parts = request.split(" ")
        verb = parts[0] if parts else ""

        if verb == "ping":
            return "ok"
        if verb == "shutdown":
            self._stopping.set()
            return "ok"

        if verb == "forward":
            if len(parts) < 4:
                return "err usage: forward <line0> <col0> <path>"
            try:
                line0, col0 = int(parts[1]), int(parts[2])
            except ValueError:
                return "err non-numeric position"
            path = " ".join(parts[3:])
            page_no, x, y = await self._resolve("forward", path, line0, col0)
            return f"ok {page_no} {x:.4f} {y:.4f}"

        if verb == "inverse":
            if len(parts) < 4:
                return "err usage: inverse <page_no> <x> <y>"
            try:
                page_no, x, y = int(parts[1]), float(parts[2]), float(parts[3])
            except ValueError:
                return "err non-numeric position"
            path, line0, col0 = await self._resolve("inverse", page_no, x, y)
            return f"ok {line0} {col0} {path}"

        return f"err unknown request: {verb}"

    async def _serve_client(self, reader, writer) -> None:
        try:
            raw = await asyncio.wait_for(reader.readline(), 10.0)
            request = raw.decode(errors="replace").strip()
            if not request:
                return
            try:
                reply = await self.handle(request)
            except asyncio.TimeoutError:
                reply = "err timeout"
            except Exception as exc:
                reply = f"err {type(exc).__name__}: {exc}"
            writer.write((reply + "\n").encode())
            await writer.drain()
        except (asyncio.TimeoutError, ConnectionError):
            pass
        finally:
            with contextlib.suppress(Exception):
                writer.close()
                await writer.wait_closed()

    async def run(self) -> None:
        os.makedirs(os.path.dirname(self.socket_path), exist_ok=True)
        # A socket left behind by a crashed daemon would block bind().
        with contextlib.suppress(FileNotFoundError):
            os.unlink(self.socket_path)

        server = await asyncio.start_unix_server(self._serve_client, path=self.socket_path)
        log(f"listening on {self.socket_path}")

        loop = asyncio.get_running_loop()
        for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
            with contextlib.suppress(NotImplementedError):
                loop.add_signal_handler(sig, self._stopping.set)

        # Bring the preview up eagerly so the first forward request is not slow.
        with contextlib.suppress(Exception):
            await self._ensure_session()

        try:
            await self._stopping.wait()
        finally:
            server.close()
            with contextlib.suppress(Exception):
                await server.wait_closed()
            if self.session is not None:
                await self.session.close()
            with contextlib.suppress(FileNotFoundError):
                os.unlink(self.socket_path)
            log("stopped")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--main", required=True, help="absolute path to the main .typ file")
    ap.add_argument("--root", required=True, help="typst project root")
    ap.add_argument("--socket", required=True, help="unix socket path to listen on")
    args = ap.parse_args()

    main_file = os.path.abspath(args.main)
    if not os.path.isfile(main_file):
        log(f"no such main file: {main_file}")
        return 2

    daemon = Daemon(main_file, os.path.abspath(args.root), args.socket)
    try:
        asyncio.run(daemon.run())
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
