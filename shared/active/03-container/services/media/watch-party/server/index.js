import cors from "cors";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import http from "node:http";
import { spawn } from "node:child_process";
import express from "express";
import multer from "multer";
import { Server } from "socket.io";

const app = express();
const server = http.createServer(app);
const PORT = Number(process.env.PORT || 3001);
const UPLOAD_DIR = path.resolve("uploads");
const HLS_DIR = path.resolve("hls-cache");
const rooms = new Map();
const mediaFiles = new Map();
const transcodes = new Map();
const hlsJobs = new Map();
const hlsSessions = new Map();
const hlsSegmentJobs = new Map();
let publicTunnelUrl = null;
let tunnelProcess = null;
let hlsSegmentQueue = Promise.resolve();
const HLS_SEGMENT_SECONDS = 10;
const HLS_AHEAD_SEGMENTS = 3;

fs.mkdirSync(UPLOAD_DIR, { recursive: true });
fs.mkdirSync(HLS_DIR, { recursive: true });

app.use(cors({ origin: true }));
app.use(express.json({ limit: "30mb" }));

const upload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, UPLOAD_DIR),
    filename: (_req, file, cb) => cb(null, `${Date.now()}-${uid()}-${file.originalname.replace(/[^\w.\-() ]+/g, "_")}`)
  })
});

const io = new Server(server, {
  cors: { origin: true, methods: ["GET", "POST"] }
});

function uid(prefix = "") {
  return `${prefix}${crypto.randomBytes(8).toString("hex")}`;
}

function getRoom(roomId) {
  if (!rooms.has(roomId)) {
    rooms.set(roomId, {
      id: roomId,
      peers: new Map(),
      media: null,
      subtitles: {
        fa: null,
        en: null
      },
      subtitleSettings: {
        size: 34,
        faSize: 34,
        enSize: 24,
        gap: 6,
        faOffsetMs: 0,
        enOffsetMs: 0,
        mode: "both"
      },
      playback: {
        playing: false,
        currentTime: 0,
        duration: 0,
        rate: 1,
        updatedAt: Date.now(),
        origin: null
      },
      voice: {}
    });
  }

  return rooms.get(roomId);
}

function publicRoom(room) {
  return {
    id: room.id,
    peers: [...room.peers.entries()].map(([id, peer]) => ({
      id,
      name: peer.name,
      speaking: Boolean(room.voice[id]?.speaking),
      level: Number(room.voice[id]?.level || 0)
    })),
    media: room.media,
    subtitles: room.subtitles,
    subtitleSettings: room.subtitleSettings,
    playback: room.playback
  };
}

function getLanIps() {
  return Object.values(os.networkInterfaces())
    .flat()
    .filter(Boolean)
    .filter((entry) => entry.family === "IPv4" && !entry.internal)
    .map((entry) => entry.address);
}

function mimeFor(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  if (ext === ".mp4" || ext === ".m4v") return "video/mp4";
  if (ext === ".webm") return "video/webm";
  if (ext === ".ogv" || ext === ".ogg") return "video/ogg";
  if (ext === ".mov") return "video/quicktime";
  if (ext === ".mp3") return "audio/mpeg";
  if (ext === ".m4a") return "audio/mp4";
  return "application/octet-stream";
}

function cleanDisplayName(filePath) {
  const parsed = path.parse(filePath);
  let name = parsed.name
    .replace(/^\d{10,}-[a-f0-9]{16}-/i, "")
    .replace(/(?:\.phone)+$/i, "")
    .replace(/^\d{10,}-[a-f0-9]{16}-/i, "");

  while (/^\d{10,}-[a-f0-9]{16}-/i.test(name)) {
    name = name.replace(/^\d{10,}-[a-f0-9]{16}-/i, "");
  }

  return `${name}${parsed.ext && !/\.phone$/i.test(parsed.ext) ? parsed.ext : ""}`.replace(/\.phone(?=\.mp4$)/gi, "");
}

function safeOutputName(filePath) {
  const displayName = cleanDisplayName(filePath);
  const parsed = path.parse(displayName);
  const base = parsed.name.replace(/[^\w.\-() ]+/g, "_").slice(0, 72) || "movie";
  return `${base}.phone.mp4`;
}

function emitTranscode(roomId, payload) {
  io.to(roomId).emit("media:transcode", payload);
}

function hlsPublicUrl(mediaId) {
  return `/hls/${mediaId}/index.m3u8`;
}

function hlsMime(filePath) {
  if (filePath.endsWith(".m3u8")) return "application/vnd.apple.mpegurl";
  if (filePath.endsWith(".ts")) return "video/mp2t";
  return "application/octet-stream";
}

function parseDuration(output) {
  const duration = Number.parseFloat(String(output || "").trim());
  return Number.isFinite(duration) && duration > 0 ? duration : 0;
}

function getMediaById(mediaId) {
  for (const room of rooms.values()) {
    if (room.media?.id === mediaId) return { room, media: room.media };
  }
  return { room: null, media: null };
}

function runFfprobeDuration(filePath) {
  return new Promise((resolve) => {
    const ffprobe = spawn("ffprobe", [
      "-v", "error",
      "-show_entries", "format=duration",
      "-of", "default=noprint_wrappers=1:nokey=1",
      filePath
    ]);
    let output = "";
    ffprobe.stdout.on("data", (chunk) => { output += chunk.toString(); });
    ffprobe.on("close", () => resolve(parseDuration(output)));
    ffprobe.on("error", () => resolve(0));
  });
}

async function ensureHlsSession(mediaId, inputPath) {
  const existing = hlsSessions.get(mediaId);
  if (existing) return existing;

  const outputDir = path.join(HLS_DIR, mediaId);
  await fs.promises.mkdir(outputDir, { recursive: true });
  const duration = await runFfprobeDuration(inputPath);
  const segmentCount = Math.max(1, Math.ceil((duration || HLS_SEGMENT_SECONDS) / HLS_SEGMENT_SECONDS));
  const session = { mediaId, inputPath, outputDir, duration, segmentCount, segmentSeconds: HLS_SEGMENT_SECONDS };
  hlsSessions.set(mediaId, session);
  return session;
}

function hlsPlaylist(session) {
  const lines = [
    "#EXTM3U",
    "#EXT-X-VERSION:6",
    `#EXT-X-TARGETDURATION:${session.segmentSeconds}`,
    "#EXT-X-MEDIA-SEQUENCE:0",
    "#EXT-X-INDEPENDENT-SEGMENTS",
    "#EXT-X-PLAYLIST-TYPE:VOD"
  ];

  for (let index = 0; index < session.segmentCount; index += 1) {
    const start = index * session.segmentSeconds;
    const remaining = session.duration ? Math.max(0.1, session.duration - start) : session.segmentSeconds;
    const segmentDuration = Math.min(session.segmentSeconds, remaining);
    lines.push(`#EXTINF:${segmentDuration.toFixed(3)},`);
    lines.push(`segment_${String(index).padStart(5, "0")}.ts`);
  }
  lines.push("#EXT-X-ENDLIST");
  return `${lines.join("\n")}\n`;
}

async function ensureHlsSegment(session, index) {
  if (index < 0 || index >= session.segmentCount) throw new Error("Segment out of range.");
  const segmentName = `segment_${String(index).padStart(5, "0")}.ts`;
  const segmentPath = path.join(session.outputDir, segmentName);

  try {
    const stat = await fs.promises.stat(segmentPath);
    if (stat.size > 0) return segmentPath;
  } catch {
    // Segment needs to be generated.
  }

  const jobKey = `${session.mediaId}:${index}`;
  if (hlsSegmentJobs.has(jobKey)) {
    await hlsSegmentJobs.get(jobKey);
    return segmentPath;
  }

  const start = index * session.segmentSeconds;
  const duration = Math.min(session.segmentSeconds, Math.max(1, (session.duration || start + session.segmentSeconds) - start));
  const tempPath = `${segmentPath}.tmp`;
  const runSegmentJob = () => new Promise((resolve, reject) => {
    const ffmpeg = spawn("ffmpeg", [
      "-y",
      "-ss", String(start),
      "-i", session.inputPath,
      "-t", String(duration),
      "-map", "0:v:0",
      "-map", "0:a:0?",
      "-c:v", "libx264",
      "-preset", "ultrafast",
      "-tune", "zerolatency",
      "-crf", "26",
      "-pix_fmt", "yuv420p",
      "-threads", "2",
      "-c:a", "aac",
      "-b:a", "128k",
      "-ac", "2",
      "-f", "mpegts",
      tempPath
    ]);
    let lastLine = "";
    ffmpeg.stderr.on("data", (chunk) => {
      lastLine = chunk.toString().trim().split("\n").pop() || lastLine;
    });
    ffmpeg.on("close", async (code) => {
      if (code !== 0) {
        await fs.promises.rm(tempPath, { force: true }).catch(() => {});
        reject(new Error(lastLine || "ffmpeg segment failed"));
        return;
      }
      await fs.promises.rename(tempPath, segmentPath);
      resolve(segmentPath);
    });
    ffmpeg.on("error", reject);
  });

  const job = hlsSegmentQueue.then(runSegmentJob).finally(() => {
    hlsSegmentJobs.delete(jobKey);
  });
  hlsSegmentQueue = job.catch(() => {});

  hlsSegmentJobs.set(jobKey, job);
  await job;
  return segmentPath;
}

function warmHlsWindow(session, currentTime = 0) {
  const currentIndex = Math.max(0, Math.floor(Number(currentTime || 0) / session.segmentSeconds));
  let chain = Promise.resolve();
  for (let offset = 0; offset <= HLS_AHEAD_SEGMENTS; offset += 1) {
    const index = currentIndex + offset;
    if (index >= session.segmentCount) break;
    chain = chain.then(() => ensureHlsSegment(session, index));
  }
  chain.catch(() => {});
}

app.get("/api/health", (_req, res) => {
  res.json({ ok: true, port: PORT, lanIps: getLanIps(), hostname: os.hostname(), publicUrl: publicTunnelUrl });
});

// ICE server configuration for WebRTC voice chat.
// Reads from ICE_SERVERS env var (JSON array of RTCIceServer objects).
// Falls back to Google STUN if not configured.
app.get("/api/config", (_req, res) => {
  let iceServers = [{ urls: "stun:stun.l.google.com:19302" }];
  try {
    const parsed = JSON.parse(process.env.ICE_SERVERS || "[]");
    if (Array.isArray(parsed) && parsed.length > 0) {
      iceServers = parsed;
    }
  } catch {
    // Keep default if env var is invalid
  }
  res.json({ iceServers });
});

app.post("/api/rooms/:roomId/media", async (req, res) => {
  const requestedPath = String(req.body.path || "").trim();
  if (!requestedPath) {
    return res.status(400).json({ error: "Movie path is required." });
  }

  const absolutePath = path.resolve(requestedPath.replace(/^~/, os.homedir()));
  let stat;
  try {
    stat = await fs.promises.stat(absolutePath);
  } catch {
    return res.status(404).json({ error: "File not found on this laptop." });
  }

  if (!stat.isFile()) {
    return res.status(400).json({ error: "Selected path is not a file." });
  }

  const mediaId = uid("m_");
  const media = {
    id: mediaId,
    name: path.basename(absolutePath),
    displayName: cleanDisplayName(absolutePath),
    size: stat.size,
    mime: mimeFor(absolutePath),
    loadedAt: Date.now()
  };

  mediaFiles.set(mediaId, absolutePath);
  const room = getRoom(req.params.roomId);
  room.media = media;
  room.playback = {
    playing: false,
    currentTime: 0,
    duration: 0,
    rate: 1,
    updatedAt: Date.now(),
    origin: null
  };

  io.to(req.params.roomId).emit("room:state", publicRoom(room));
  res.json({ media });
});

app.post("/api/rooms/:roomId/media-upload", upload.single("movie"), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: "Movie file is required." });
  }

  const absolutePath = req.file.path;
  const stat = await fs.promises.stat(absolutePath);
  const mediaId = uid("m_");
  const media = {
    id: mediaId,
    name: req.file.originalname,
    displayName: cleanDisplayName(req.file.originalname),
    size: stat.size,
    mime: mimeFor(req.file.originalname),
    loadedAt: Date.now()
  };

  mediaFiles.set(mediaId, absolutePath);
  const room = getRoom(req.params.roomId);
  room.media = media;
  room.playback = {
    playing: false,
    currentTime: 0,
    duration: 0,
    rate: 1,
    updatedAt: Date.now(),
    origin: null
  };

  io.to(req.params.roomId).emit("room:state", publicRoom(room));
  res.json({ media });
});

app.post("/api/rooms/:roomId/subtitles/:slot", async (req, res) => {
  const slot = req.params.slot === "en" ? "en" : "fa";
  const requestedPath = String(req.body.path || "").trim();
  if (!requestedPath) {
    return res.status(400).json({ error: "Subtitle path is required." });
  }

  const absolutePath = path.resolve(requestedPath.replace(/^~/, os.homedir()));
  let text;
  try {
    text = await fs.promises.readFile(absolutePath, "utf8");
  } catch {
    return res.status(404).json({ error: "Subtitle file not found on this laptop." });
  }

  const room = getRoom(req.params.roomId);
  const subtitle = {
    id: uid("s_"),
    slot,
    label: req.body.label || (slot === "fa" ? "Persian" : "English"),
    lang: slot === "fa" ? "fa" : "en",
    name: path.basename(absolutePath),
    format: path.extname(absolutePath).toLowerCase().replace(".", "") || "srt",
    text
  };

  room.subtitles[slot] = subtitle;
  io.to(req.params.roomId).emit("room:state", publicRoom(room));
  res.json({ subtitle });
});

app.post("/api/rooms/:roomId/subtitles/:slot/text", (req, res) => {
  const slot = req.params.slot === "en" ? "en" : "fa";
  const text = String(req.body.text || "").trim();
  if (!text) {
    return res.status(400).json({ error: "Subtitle text is required." });
  }

  const room = getRoom(req.params.roomId);
  const subtitle = {
    id: uid("s_"),
    slot,
    label: req.body.label || (slot === "fa" ? "Persian" : "English"),
    lang: slot === "fa" ? "fa" : "en",
    name: String(req.body.name || `${slot}.srt`).slice(0, 180),
    format: String(req.body.format || "srt").slice(0, 16),
    text
  };

  room.subtitles[slot] = subtitle;
  io.to(req.params.roomId).emit("room:state", publicRoom(room));
  res.json({ subtitle });
});

app.delete("/api/rooms/:roomId/subtitles/:slot", (req, res) => {
  const slot = req.params.slot === "en" ? "en" : "fa";
  const room = getRoom(req.params.roomId);
  room.subtitles[slot] = null;
  io.to(req.params.roomId).emit("room:state", publicRoom(room));
  res.json({ ok: true });
});

app.get("/stream/:roomId/:mediaId", async (req, res) => {
  const filePath = mediaFiles.get(req.params.mediaId);
  const room = rooms.get(req.params.roomId);
  if (!filePath || !room || room.media?.id !== req.params.mediaId) {
    return res.status(404).end("Media not found.");
  }

  let stat;
  try {
    stat = await fs.promises.stat(filePath);
  } catch {
    return res.status(404).end("Media disappeared from disk.");
  }

  const range = req.headers.range;
  const contentType = mimeFor(filePath);
  if (!range) {
    res.writeHead(200, {
      "Content-Length": stat.size,
      "Content-Type": contentType,
      "Accept-Ranges": "bytes"
    });
    fs.createReadStream(filePath).pipe(res);
    return;
  }

  const [startRaw, endRaw] = range.replace(/bytes=/, "").split("-");
  const start = Number.parseInt(startRaw, 10);
  const end = endRaw ? Number.parseInt(endRaw, 10) : stat.size - 1;
  if (Number.isNaN(start) || Number.isNaN(end) || start > end || start >= stat.size) {
    res.writeHead(416, { "Content-Range": `bytes */${stat.size}` });
    return res.end();
  }

  res.writeHead(206, {
    "Content-Range": `bytes ${start}-${end}/${stat.size}`,
    "Accept-Ranges": "bytes",
    "Content-Length": end - start + 1,
    "Content-Type": contentType
  });
  fs.createReadStream(filePath, { start, end }).pipe(res);
});

app.get("/hls/:mediaId/:file", async (req, res) => {
  const mediaId = String(req.params.mediaId || "");
  const fileName = String(req.params.file || "");
  if (!/^[\w.-]+$/.test(fileName)) return res.status(400).end("Bad HLS file.");

  const inputPath = mediaFiles.get(mediaId);
  if (!inputPath) return res.status(404).end("Media not found.");

  const session = await ensureHlsSession(mediaId, inputPath);
  if (fileName === "index.m3u8") {
    res.setHeader("Content-Type", hlsMime(fileName));
    res.setHeader("Cache-Control", "no-store");
    return res.end(hlsPlaylist(session));
  }

  const match = fileName.match(/^segment_(\d+)\.ts$/);
  if (!match) return res.status(404).end("HLS file not found.");

  let filePath;
  try {
    filePath = await ensureHlsSegment(session, Number(match[1]));
  } catch (error) {
    return res.status(500).end(error.message || "Could not prepare HLS segment.");
  }

  res.setHeader("Content-Type", hlsMime(filePath));
  res.setHeader("Cache-Control", "public, max-age=31536000, immutable");
  fs.createReadStream(filePath).pipe(res);
});

app.post("/api/rooms/:roomId/media/:mediaId/hls", async (req, res) => {
  const room = rooms.get(req.params.roomId);
  const inputPath = mediaFiles.get(req.params.mediaId);
  if (!room || !inputPath || room.media?.id !== req.params.mediaId) {
    return res.status(404).json({ error: "Media not found in this room." });
  }

  const session = await ensureHlsSession(req.params.mediaId, inputPath);
  const currentTime = Number(req.body?.currentTime || room.playback.currentTime || 0);

  room.media = {
    ...room.media,
    streamMode: "hls",
    hlsUrl: hlsPublicUrl(req.params.mediaId),
    hlsStatus: "windowed",
    hlsSegmentSeconds: HLS_SEGMENT_SECONDS
  };
  emitTranscode(req.params.roomId, {
    mediaId: req.params.mediaId,
    status: "ready",
    message: "Windowed stream is active. Keeping about 30s buffered ahead."
  });
  io.to(req.params.roomId).emit("room:state", publicRoom(room));
  warmHlsWindow(session, currentTime);

  res.json({ ok: true, status: "windowed", hlsUrl: hlsPublicUrl(req.params.mediaId), segmentSeconds: HLS_SEGMENT_SECONDS });
});

app.post("/api/rooms/:roomId/media/:mediaId/hls/window", async (req, res) => {
  const room = rooms.get(req.params.roomId);
  const inputPath = mediaFiles.get(req.params.mediaId);
  if (!room || !inputPath || room.media?.id !== req.params.mediaId) {
    return res.status(404).json({ error: "Media not found in this room." });
  }

  const session = await ensureHlsSession(req.params.mediaId, inputPath);
  const currentTime = Math.max(0, Number(req.body?.currentTime || 0));
  warmHlsWindow(session, currentTime);
  res.json({ ok: true, status: "warming", currentTime, segmentSeconds: HLS_SEGMENT_SECONDS });
});

app.post("/api/rooms/:roomId/media/:mediaId/phone-mp4", async (req, res) => {
  const room = rooms.get(req.params.roomId);
  const inputPath = mediaFiles.get(req.params.mediaId);
  if (!room || !inputPath || room.media?.id !== req.params.mediaId) {
    return res.status(404).json({ error: "Media not found in this room." });
  }

  if (room.media?.hlsUrl) {
    return res.status(409).json({ error: "Adaptive streaming is active. Full MP4 conversion is disabled to keep CPU low." });
  }

  if (transcodes.has(req.params.mediaId)) {
    return res.json({ ok: true, status: "already-running" });
  }

  const outputPath = path.join(UPLOAD_DIR, `${Date.now()}-${uid()}-${safeOutputName(inputPath)}`);
  const startedAt = Date.now();
  const job = { inputPath, outputPath, startedAt };
  transcodes.set(req.params.mediaId, job);
  emitTranscode(req.params.roomId, {
    mediaId: req.params.mediaId,
    status: "running",
    message: "Converting to phone-safe MP4. Keep this laptop awake."
  });

  const ffmpeg = spawn("ffmpeg", [
    "-y",
    "-i", inputPath,
    "-map", "0:v:0",
    "-map", "0:a:0?",
    "-c:v", "libx264",
    "-preset", "veryfast",
    "-crf", "23",
    "-pix_fmt", "yuv420p",
    "-c:a", "aac",
    "-b:a", "160k",
    "-movflags", "+faststart",
    outputPath
  ]);

  let lastLine = "";
  ffmpeg.stderr.on("data", (chunk) => {
    const text = chunk.toString();
    lastLine = text.trim().split("\n").pop() || lastLine;
    const match = text.match(/time=(\d+:\d+:\d+(?:\.\d+)?)/);
    if (match) {
      emitTranscode(req.params.roomId, {
        mediaId: req.params.mediaId,
        status: "running",
        message: `Converting to phone-safe MP4: ${match[1]} processed.`
      });
    }
  });

  ffmpeg.on("close", async (code) => {
    transcodes.delete(req.params.mediaId);
    if (code !== 0) {
      await fs.promises.rm(outputPath, { force: true }).catch(() => {});
      emitTranscode(req.params.roomId, {
        mediaId: req.params.mediaId,
        status: "failed",
        message: `MP4 conversion failed. ${lastLine || "Check that ffmpeg can read this file."}`
      });
      return;
    }

    let stat;
    try {
      stat = await fs.promises.stat(outputPath);
    } catch {
      emitTranscode(req.params.roomId, {
        mediaId: req.params.mediaId,
        status: "failed",
        message: "MP4 conversion finished, but the output file was not found."
      });
      return;
    }

    const mediaId = uid("m_");
    const media = {
      id: mediaId,
      name: path.basename(outputPath),
      displayName: cleanDisplayName(outputPath),
      size: stat.size,
      mime: "video/mp4",
      compatible: true,
      sourceName: room.media?.displayName || room.media?.sourceName || cleanDisplayName(room.media?.name || inputPath),
      loadedAt: Date.now()
    };

    mediaFiles.set(mediaId, outputPath);
    room.media = media;
    room.playback = {
      playing: false,
      currentTime: 0,
      duration: 0,
      rate: 1,
      updatedAt: Date.now(),
      origin: null
    };

    emitTranscode(req.params.roomId, {
      mediaId,
      status: "done",
      message: "Phone-safe MP4 is ready. The room has switched to the compatible copy."
    });
    io.to(req.params.roomId).emit("room:state", publicRoom(room));
  });

  res.json({ ok: true, status: "started" });
});

io.on("connection", (socket) => {
  socket.on("room:join", ({ roomId, name }, ack) => {
    const cleanRoomId = String(roomId || "lobby").slice(0, 64);
    const room = getRoom(cleanRoomId);
    socket.join(cleanRoomId);
    socket.data.roomId = cleanRoomId;
    room.peers.set(socket.id, { name: String(name || "Guest").slice(0, 40), joinedAt: Date.now() });
    ack?.({ socketId: socket.id, state: publicRoom(room) });
    socket.to(cleanRoomId).emit("peer:joined", { id: socket.id, name: room.peers.get(socket.id).name });
    io.to(cleanRoomId).emit("room:state", publicRoom(room));
  });

  socket.on("playback:set", (payload) => {
    const roomId = socket.data.roomId;
    if (!roomId) return;
    const room = getRoom(roomId);
    const currentTime = Number(payload.currentTime);
    room.playback = {
      playing: Boolean(payload.playing),
      currentTime: Number.isFinite(currentTime) ? Math.max(0, currentTime) : 0,
      duration: Number.isFinite(Number(payload.duration)) ? Number(payload.duration) : room.playback.duration,
      rate: Number.isFinite(Number(payload.rate)) ? Number(payload.rate) : room.playback.rate,
      updatedAt: Date.now(),
      origin: socket.id
    };
    io.to(roomId).emit("playback:state", room.playback);
  });

  socket.on("subtitle:settings", (settings) => {
    const roomId = socket.data.roomId;
    if (!roomId) return;
    const room = getRoom(roomId);
    room.subtitleSettings = {
      ...room.subtitleSettings,
      ...settings,
      mode: ["both", "fa", "en", "off"].includes(settings.mode) ? settings.mode : room.subtitleSettings.mode,
      size: Math.min(64, Math.max(18, Number(settings.size ?? room.subtitleSettings.size))),
      faSize: Math.min(72, Math.max(18, Number(settings.faSize ?? settings.size ?? room.subtitleSettings.faSize ?? room.subtitleSettings.size))),
      enSize: Math.min(60, Math.max(14, Number(settings.enSize ?? room.subtitleSettings.enSize ?? Math.round((room.subtitleSettings.size ?? 34) * 0.72)))),
      gap: Math.min(48, Math.max(0, Number(settings.gap ?? room.subtitleSettings.gap))),
      faOffsetMs: Math.max(-60000, Math.min(60000, Number(settings.faOffsetMs ?? room.subtitleSettings.faOffsetMs))),
      enOffsetMs: Math.max(-60000, Math.min(60000, Number(settings.enOffsetMs ?? room.subtitleSettings.enOffsetMs)))
    };
    io.to(roomId).emit("subtitle:settings", room.subtitleSettings);
  });

  socket.on("voice:activity", ({ speaking, level }) => {
    const roomId = socket.data.roomId;
    if (!roomId) return;
    const room = getRoom(roomId);
    const cleanLevel = Math.max(0, Math.min(1, Number(level || 0)));
    room.voice[socket.id] = { speaking: Boolean(speaking), level: cleanLevel };
    io.to(roomId).emit("voice:activity", { id: socket.id, speaking: Boolean(speaking), level: cleanLevel });
  });

  socket.on("peer:kick", ({ id }, ack) => {
    const roomId = socket.data.roomId;
    if (!roomId || !id || id === socket.id) {
      ack?.({ ok: false, error: "Invalid user." });
      return;
    }
    const room = getRoom(roomId);
    if (!room.peers.has(id)) {
      ack?.({ ok: false, error: "User is not in this room." });
      return;
    }
    const target = io.sockets.sockets.get(id);
    target?.emit("room:kicked");
    target?.leave(roomId);
    target?.disconnect(true);
    room.peers.delete(id);
    delete room.voice[id];
    socket.to(roomId).emit("peer:left", { id });
    io.to(roomId).emit("room:state", publicRoom(room));
    ack?.({ ok: true });
  });

  socket.on("signal", ({ to, data }) => {
    if (!to || !data) return;
    socket.to(to).emit("signal", { from: socket.id, data });
  });

  socket.on("disconnect", () => {
    const roomId = socket.data.roomId;
    if (!roomId) return;
    const room = rooms.get(roomId);
    if (!room) return;
    room.peers.delete(socket.id);
    delete room.voice[socket.id];
    socket.to(roomId).emit("peer:left", { id: socket.id });
    io.to(roomId).emit("room:state", publicRoom(room));
  });
});

if (process.env.NODE_ENV === "production") {
  const distDir = path.resolve("dist");
  app.use(express.static(distDir));
  app.get("*", (_req, res) => res.sendFile(path.join(distDir, "index.html")));
}

function startCloudflareTunnel() {
  tunnelProcess = spawn("npx", ["--yes", "cloudflared", "tunnel", "--url", `http://localhost:${PORT}`], {
    stdio: ["ignore", "pipe", "pipe"]
  });

  const handleOutput = (chunk) => {
    const text = chunk.toString();
    process.stdout.write(text);
    const match = text.match(/https:\/\/(?!api\.)[-a-z0-9]+\.trycloudflare\.com/i);
    if (match?.[0]) {
      publicTunnelUrl = match[0];
      console.log(`\nPublic Cloudflare tunnel is running:\n  ${publicTunnelUrl}`);
    }
  };

  tunnelProcess.stdout.on("data", handleOutput);
  tunnelProcess.stderr.on("data", handleOutput);
  tunnelProcess.on("exit", () => {
    publicTunnelUrl = null;
    tunnelProcess = null;
    console.log("Public Cloudflare tunnel closed.");
  });
}

process.on("exit", () => {
  tunnelProcess?.kill();
});

server.listen(PORT, "0.0.0.0", () => {
  const urls = [`http://localhost:${PORT}`, ...getLanIps().map((ip) => `http://${ip}:${PORT}`)];
  console.log(`Local Watch Party server is running:\n${urls.map((url) => `  ${url}`).join("\n")}`);

  if (process.env.PUBLIC_TUNNEL === "1") {
    startCloudflareTunnel();
  }
});
