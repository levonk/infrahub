import React, { useState, useEffect, useRef, useCallback } from "react";
import { createRoot } from "react-dom/client";
import { io } from "socket.io-client";
import Hls from "hls.js";
import {
  Captions,
  Copy,
  Expand,
  Gauge,
  Link2,
  Mic,
  MicOff,
  MonitorPlay,
  Pause,
  Play,
  RotateCcw,
  RotateCw,
  Settings2,
  Users,
  X,
  Volume2,
  VolumeX,
  Wifi,
  Minus,
  Maximize,
  ChevronUp,
  ChevronDown,
  FolderOpen,
  Plus
} from "lucide-react";
import "./styles.css";

const SERVER_URL = window.location.hostname.includes("trycloudflare.com")
  ? window.location.origin
  : `http://${window.location.hostname}:3001`;

const SPEAKER_HOLD_MS = 2500;
const SEEK_FORWARD_SECONDS = 15;
const SEEK_BACK_SECONDS = 5;

function formatTime(seconds) {
  if (!Number.isFinite(seconds) || seconds < 0) return "0:00";
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  if (h > 0) return `${h}:${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
  return `${m}:${s.toString().padStart(2, "0")}`;
}

function formatBytes(bytes) {
  if (!bytes) return "0 B";
  const k = 1024;
  const sizes = ["B", "KB", "MB", "GB", "TB"];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(1))} ${sizes[i]}`;
}

function parseSrt(text) {
  const cues = [];
  const blocks = text.replace(/\r\n/g, "\n").split(/\n\s*\n/);
  for (const block of blocks) {
    const lines = block.split("\n");
    if (lines.length >= 3) {
      const timeLine = lines[1];
      const match = timeLine.match(/(\d{2}):(\d{2}):(\d{2}),(\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2}),(\d{3})/);
      if (match) {
        const start =
          parseInt(match[1], 10) * 3600 +
          parseInt(match[2], 10) * 60 +
          parseInt(match[3], 10) +
          parseInt(match[4], 10) / 1000;
        const end =
          parseInt(match[5], 10) * 3600 +
          parseInt(match[6], 10) * 60 +
          parseInt(match[7], 10) +
          parseInt(match[8], 10) / 1000;
        const textContent = lines.slice(2).join("\n").replace(/<[^>]+>/g, "").trim();
        cues.push({ start, end, text: textContent });
      }
    }
  }
  return cues;
}

function parseVtt(text) {
  const cues = [];
  const lines = text.replace(/\r\n/g, "\n").split("\n");
  let i = 0;
  if (lines[0].startsWith("WEBVTT")) i++;
  while (i < lines.length) {
    if (!lines[i].trim()) {
      i++;
      continue;
    }
    let timeLine = lines[i];
    if (!timeLine.includes("-->")) {
      i++;
      timeLine = lines[i];
    }
    if (!timeLine || !timeLine.includes("-->")) {
      i++;
      continue;
    }
    const match = timeLine.match(/(?:(\d{2}):)?(\d{2}):(\d{2})\.(\d{3})\s*-->\s*(?:(\d{2}):)?(\d{2}):(\d{2})\.(\d{3})/);
    if (match) {
      const h1 = match[1] ? parseInt(match[1], 10) : 0;
      const m1 = parseInt(match[2], 10);
      const s1 = parseInt(match[3], 10);
      const ms1 = parseInt(match[4], 10);
      const start = h1 * 3600 + m1 * 60 + s1 + ms1 / 1000;

      const h2 = match[5] ? parseInt(match[5], 10) : 0;
      const m2 = parseInt(match[6], 10);
      const s2 = parseInt(match[7], 10);
      const ms2 = parseInt(match[8], 10);
      const end = h2 * 3600 + m2 * 60 + s2 + ms2 / 1000;

      i++;
      const textLines = [];
      while (i < lines.length && lines[i].trim()) {
        textLines.push(lines[i].replace(/<[^>]+>/g, "").trim());
        i++;
      }
      cues.push({ start, end, text: textLines.join("\n") });
    } else {
      i++;
    }
  }
  return cues;
}

async function readSubtitleFile(file) {
  const text = await file.text();
  return text;
}

function parseSubtitleData(text, format) {
  if (format === "vtt" || text.startsWith("WEBVTT")) return parseVtt(text);
  return parseSrt(text);
}

function findActiveCue(cues, currentTime, offsetMs = 0) {
  if (!cues || !cues.length) return null;
  const t = currentTime - offsetMs / 1000;
  let left = 0;
  let right = cues.length - 1;
  while (left <= right) {
    const mid = Math.floor((left + right) / 2);
    const cue = cues[mid];
    if (t >= cue.start && t <= cue.end) return cue;
    if (t < cue.start) right = mid - 1;
    else left = mid + 1;
  }
  return null;
}

function initials(name) {
  return (name || "?").slice(0, 2).toUpperCase();
}

function makeRoomId() {
  const words = ["emerald", "crimson", "azure", "nova", "pulse", "echo", "neon", "flux", "zenith", "vertex"];
  const word = words[Math.floor(Math.random() * words.length)];
  return `${word}-room`;
}

function isTypingTarget(target) {
  if (!target) return false;
  const tag = target.tagName.toLowerCase();
  return tag === "input" || tag === "textarea" || tag === "select" || target.isContentEditable;
}

function RemoteAudio({ stream, muted, volume, unlockKey, onBlocked }) {
  const audioRef = useRef(null);
  
  useEffect(() => {
    if (audioRef.current && stream) {
      audioRef.current.srcObject = stream;
      audioRef.current.play().catch(() => onBlocked());
    }
  }, [stream, unlockKey, onBlocked]);

  useEffect(() => {
    if (audioRef.current) {
      audioRef.current.volume = volume;
      audioRef.current.muted = muted;
    }
  }, [volume, muted]);

  return <audio ref={audioRef} autoPlay playsInline style={{ display: "none" }} />;
}

function levelPercent(level) {
  return `${Math.min(100, Math.max(0, level * 100))}%`;
}

function App() {
  const [profileReady, setProfileReady] = useState(Boolean(localStorage.getItem("watch-name")));
  const [name, setName] = useState(localStorage.getItem("watch-name") || "");
  const [roomId, setRoomId] = useState(() => {
    const params = new URLSearchParams(window.location.search);
    return params.get("room") || localStorage.getItem("watch-room") || makeRoomId();
  });

  const [connected, setConnected] = useState(false);
  const [health, setHealth] = useState(null);
  const [socketId, setSocketId] = useState(null);
  const [room, setRoom] = useState(null);

  const [moviePath, setMoviePath] = useState("");
  const [subtitlePathFa, setSubtitlePathFa] = useState("");
  const [subtitlePathEn, setSubtitlePathEn] = useState("");

  const [transcodeStatus, setTranscodeStatus] = useState(null);
  const [status, setStatus] = useState("");

  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [mediaError, setMediaError] = useState("");
  const [playbackUnlocked, setPlaybackUnlocked] = useState(true);
  const [pendingAutoplay, setPendingAutoplay] = useState(false);

  const [userVolume, setUserVolume] = useState(1);
  const [videoMuted, setVideoMuted] = useState(false);
  const [theaterMode, setTheaterMode] = useState(false);
  const [showChrome, setShowChrome] = useState(true);
  const [seekFlash, setSeekFlash] = useState(null);

  const [subtitleSettings, setSubtitleSettings] = useState({
    mode: "both",
    size: 42,
    faSize: 42,
    enSize: 30,
    gap: 8,
    faOffsetMs: +120,
    enOffsetMs: -80
  });
  const [lastSubtitleMode, setLastSubtitleMode] = useState("both");

  const [micEnabled, setMicEnabled] = useState(false);
  const [micDevices, setMicDevices] = useState([]);
  const [micStatus, setMicStatus] = useState("");
  const [localMicLevel, setLocalMicLevel] = useState(0);
  const [localSpeaking, setLocalSpeaking] = useState(false);

  const [voiceState, setVoiceState] = useState({});
  const [remoteStreams, setRemoteStreams] = useState(new Map());
  const [adaptiveDucking, setAdaptiveDucking] = useState(true);
  const [voiceOutputEnabled, setVoiceOutputEnabled] = useState(true);
  const [defaultRemoteVoiceVolume, setDefaultRemoteVoiceVolume] = useState(1);
  const [remoteVoiceVolumes, setRemoteVoiceVolumes] = useState({});
  const [voiceBlocked, setVoiceBlocked] = useState(false);
  const [voiceUnlockKey, setVoiceUnlockKey] = useState(0);
  const [speakerToast, setSpeakerToast] = useState({ entries: [], exiting: false });
  const [pingMs, setPingMs] = useState(0);
  const [iceServers, setIceServers] = useState([{ urls: "stun:stun.l.google.com:19302" }]);

  const socketRef = useRef(null);
  const videoRef = useRef(null);
  const screenRef = useRef(null);
  const peerConnectionsRef = useRef(new Map());
  const localStreamRef = useRef(null);
  const analyserRef = useRef(null);
  const vadFrameRef = useRef(null);
  const lastVoiceEmitRef = useRef(0);
  const noiseFloorRef = useRef(0.01);
  const lastSpeakingRef = useRef(false);
  const localMicLevelRef = useRef(0);

  const applyingRemoteRef = useRef(false);
  const chromeTimerRef = useRef(null);
  const seekTimerRef = useRef(null);
  const tapTimerRef = useRef(null);
  const speakerHideTimerRef = useRef(null);
  const speakerExitTimerRef = useRef(null);
  const hlsRequestedRef = useRef(new Set());
  const hlsWindowRef = useRef("");

  const media = room?.media;
  const streamUrl = media ? `${SERVER_URL}/stream/${roomId}/${media.id}` : "";
  const playbackUrl = media?.hlsUrl ? `${SERVER_URL}${media.hlsUrl}` : streamUrl;
  const displayMediaName = media ? (media.displayName || media.sourceName || media.name) : "";
  const shareUrl = `${health?.publicUrl || window.location.origin}/?room=${encodeURIComponent(roomId)}`;
  const shouldOfferPhoneMp4 = Boolean(media && media.mime !== "video/mp4" && !media.hlsUrl);
  const shouldOfferAdaptiveStream = Boolean(media && media.mime !== "video/mp4" && !media.hlsUrl);

  const faData = room?.subtitles?.fa;
  const enData = room?.subtitles?.en;
  const faCues = React.useMemo(() => faData ? parseSubtitleData(faData.text, faData.format) : [], [faData]);
  const enCues = React.useMemo(() => enData ? parseSubtitleData(enData.text, enData.format) : [], [enData]);

  const faCue = React.useMemo(() => findActiveCue(faCues, currentTime, subtitleSettings.faOffsetMs), [faCues, currentTime, subtitleSettings.faOffsetMs]);
  const enCue = React.useMemo(() => findActiveCue(enCues, currentTime, subtitleSettings.enOffsetMs), [enCues, currentTime, subtitleSettings.enOffsetMs]);
  const faSubtitleSize = subtitleSettings.faSize ?? subtitleSettings.size ?? 42;
  const enSubtitleSize = subtitleSettings.enSize ?? Math.max(18, Math.round((subtitleSettings.size ?? 42) * 0.72));
  const subtitleGap = subtitleSettings.gap ?? 8;

  const peers = room?.peers || [];
  const otherPeers = peers.filter((peer) => peer.id !== socketId);
  const localParticipant = { id: socketId || "local", name: name || "You", self: true, speaking: localSpeaking, level: localMicLevelRef.current };
  const remoteParticipants = otherPeers.map((peer) => ({
    ...peer,
    self: false,
    speaking: Boolean(voiceState[peer.id]?.speaking),
    level: voiceState[peer.id]?.level || 0
  }));
  const participants = [localParticipant, ...remoteParticipants];
  const participantCount = participants.length;
  const activeSpeakers = participants
    .filter(p => p.speaking)
    .sort((a, b) => b.level - a.level)
    .slice(0, 3);
  const anyoneSpeaking = activeSpeakers.length > 0;
  const effectiveVolume = anyoneSpeaking && adaptiveDucking ? userVolume * 0.15 : userVolume;

  const showPlayerChrome = useCallback((force = false) => {
    setShowChrome(true);
    window.clearTimeout(chromeTimerRef.current);
    if (!force && isPlaying) {
      chromeTimerRef.current = window.setTimeout(() => setShowChrome(false), 3000);
    }
  }, [isPlaying]);

  const flashSeek = useCallback((direction, seconds) => {
    setSeekFlash({ direction, seconds, id: Date.now() });
    window.clearTimeout(seekTimerRef.current);
    seekTimerRef.current = window.setTimeout(() => setSeekFlash(null), 600);
  }, []);

  const handleRemoteVoiceBlocked = useCallback(() => {
    setVoiceBlocked(true);
  }, []);

  const unlockRemoteVoice = useCallback(() => {
    setVoiceBlocked(false);
    setVoiceUnlockKey(Date.now());
  }, []);

  // Fetch ICE server configuration from the backend for WebRTC voice chat.
  // Falls back to Google STUN if the endpoint is unavailable.
  useEffect(() => {
    fetch(`${SERVER_URL}/api/config`)
      .then((r) => r.json())
      .then((c) => {
        if (c.iceServers && Array.isArray(c.iceServers) && c.iceServers.length > 0) {
          setIceServers(c.iceServers);
        }
      })
      .catch(() => {});
  }, []);

  useEffect(() => {
    if (profileReady && name.trim()) localStorage.setItem("watch-name", name.trim());
  }, [name, profileReady]);

  useEffect(() => {
    localStorage.setItem("watch-room", roomId);
  }, [roomId]);

  useEffect(() => {
    let cancelled = false;
    const refreshHealth = () => {
      const start = Date.now();
      fetch(`${SERVER_URL}/api/health`)
        .then((response) => response.json())
        .then((payload) => {
          if (!cancelled) {
            setHealth(payload);
            setPingMs(Date.now() - start);
          }
        })
        .catch(() => {
          if (!cancelled) setHealth(null);
        });
    };
    refreshHealth();
    const timer = window.setInterval(refreshHealth, 2500);
    return () => {
      cancelled = true;
      window.clearInterval(timer);
    };
  }, []);

  const emitPlayback = useCallback((patch = {}) => {
    const video = videoRef.current;
    if (!video || !socketRef.current) return;
    socketRef.current.emit("playback:set", {
      playing: patch.playing ?? !video.paused,
      currentTime: patch.currentTime ?? video.currentTime,
      duration: Number.isFinite(video.duration) ? video.duration : duration,
      rate: patch.rate ?? video.playbackRate
    });
  }, [duration]);

  const applyPlaybackState = useCallback((state, force = false) => {
    const video = videoRef.current;
    if (!video || !state) return;
    const targetTime = state.playing ? state.currentTime + (Date.now() - state.updatedAt) / 1000 : state.currentTime;
    const drift = Math.abs(video.currentTime - targetTime);
    applyingRemoteRef.current = true;
    video.playbackRate = state.rate || 1;
    if (force || drift > 0.35) {
      video.currentTime = Math.max(0, targetTime);
    }
    if (state.playing && video.paused) {
      video
        .play()
        .then(() => {
          setPlaybackUnlocked(true);
          setPendingAutoplay(false);
          setIsPlaying(true);
        })
        .catch(() => {
          setPendingAutoplay(true);
          setIsPlaying(false);
          setStatus("Click Enable playback.");
        });
    }
    if (!state.playing && !video.paused) {
      video.pause();
      setIsPlaying(false);
      setPendingAutoplay(false);
    }
    window.setTimeout(() => {
      applyingRemoteRef.current = false;
    }, 180);
  }, []);

  const ensurePeerConnection = useCallback((peerId) => {
    if (peerConnectionsRef.current.has(peerId)) return peerConnectionsRef.current.get(peerId);

    const pc = new RTCPeerConnection({
      iceServers: iceServers
    });

    pc.onicecandidate = (event) => {
      if (event.candidate) {
        socketRef.current?.emit("signal", { to: peerId, data: { candidate: event.candidate } });
      }
    };

    pc.ontrack = (event) => {
      const [stream] = event.streams;
      if (!stream) return;
      setRemoteStreams((previous) => {
        const next = new Map(previous);
        next.set(peerId, stream);
        return next;
      });
    };

    localStreamRef.current?.getTracks().forEach((track) => {
      if (!pc.getSenders().some((sender) => sender.track?.id === track.id)) {
        pc.addTrack(track, localStreamRef.current);
      }
    });

    peerConnectionsRef.current.set(peerId, pc);
    return pc;
  }, []);

  const makeOffer = useCallback(async (peerId) => {
    const pc = ensurePeerConnection(peerId);
    const offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    socketRef.current?.emit("signal", { to: peerId, data: { description: pc.localDescription } });
  }, [ensurePeerConnection]);

  const renegotiateAll = useCallback(() => {
    [...peerConnectionsRef.current.keys()].forEach((peerId) => {
      makeOffer(peerId).catch(() => setStatus("Voice negotiation failed."));
    });
  }, [makeOffer]);

  useEffect(() => {
    if (!profileReady) return undefined;
    const socket = io(SERVER_URL, { transports: ["websocket", "polling"] });
    socketRef.current = socket;

    socket.on("connect", () => {
      setConnected(true);
      socket.emit("room:join", { roomId, name }, ({ socketId: id, state }) => {
        setSocketId(id);
        setRoom(state);
        setSubtitleSettings(state.subtitleSettings);
        setVoiceState(() => {
          const next = {};
          state.peers.forEach((peer) => {
            next[peer.id] = { speaking: Boolean(peer.speaking), level: Number(peer.level || 0) };
          });
          return next;
        });
        if (state.subtitleSettings?.mode && state.subtitleSettings.mode !== "off") {
          setLastSubtitleMode(state.subtitleSettings.mode);
        }
        state.peers
          .filter((peer) => peer.id !== id)
          .forEach((peer) => ensurePeerConnection(peer.id));
      });
    });

    socket.on("disconnect", () => setConnected(false));
    socket.on("room:state", (state) => {
      setRoom(state);
      setSubtitleSettings(state.subtitleSettings);
      setVoiceState((previous) => {
        const next = { ...previous };
        state.peers.forEach((peer) => {
          next[peer.id] = { speaking: Boolean(peer.speaking), level: Number(peer.level || 0) };
        });
        return next;
      });
      if (state.subtitleSettings?.mode && state.subtitleSettings.mode !== "off") {
        setLastSubtitleMode(state.subtitleSettings.mode);
      }
    });
    socket.on("media:transcode", (payload) => {
      setTranscodeStatus(payload);
      setStatus(payload.message);
      if (payload.status === "done") {
        setMediaError("");
        setPlaybackUnlocked(false);
        setPendingAutoplay(false);
      }
    });
    socket.on("playback:state", (state) => {
      setRoom((previous) => (previous ? { ...previous, playback: state } : previous));
      if (state.origin !== socket.id) applyPlaybackState(state);
    });
    socket.on("subtitle:settings", (settings) => {
      setSubtitleSettings(settings);
      if (settings?.mode && settings.mode !== "off") setLastSubtitleMode(settings.mode);
    });
    socket.on("voice:activity", ({ id, speaking, level }) => {
      if (id === socket.id) return;
      setVoiceState((previous) => ({
        ...previous,
        [id]: { speaking: Boolean(speaking), level: Number(level || 0) }
      }));
    });
    socket.on("peer:joined", ({ id }) => {
      ensurePeerConnection(id);
      makeOffer(id).catch(() => setStatus("Could not connect voice."));
    });
    socket.on("peer:left", ({ id }) => {
      peerConnectionsRef.current.get(id)?.close();
      peerConnectionsRef.current.delete(id);
      setRemoteStreams((previous) => {
        const next = new Map(previous);
        next.delete(id);
        return next;
      });
      setVoiceState((previous) => {
        const next = { ...previous };
        delete next[id];
        return next;
      });
    });
    socket.on("room:kicked", () => {
      setStatus("You were removed from the room.");
      setProfileReady(false);
      socket.disconnect();
    });
    socket.on("signal", async ({ from, data }) => {
      const pc = ensurePeerConnection(from);
      try {
        if (data.description) {
          await pc.setRemoteDescription(data.description);
          if (data.description.type === "offer") {
            const answer = await pc.createAnswer();
            await pc.setLocalDescription(answer);
            socket.emit("signal", { to: from, data: { description: pc.localDescription } });
          }
        }
        if (data.candidate) await pc.addIceCandidate(data.candidate);
      } catch {
        setStatus("WebRTC error.");
      }
    });

    return () => {
      socket.disconnect();
      socketRef.current = null;
      peerConnectionsRef.current.forEach((pc) => pc.close());
      peerConnectionsRef.current.clear();
    };
  }, [applyPlaybackState, ensurePeerConnection, makeOffer, name, profileReady, roomId]);

  useEffect(() => {
    const onKeyDown = (event) => {
      if (isTypingTarget(event.target)) return;
      const key = event.key.toLowerCase();
      if (event.key === "Escape") {
        setTheaterMode(false);
        return;
      }
      if (!media) return;
      if (event.code === "Space") {
        event.preventDefault();
        togglePlay();
        showPlayerChrome();
      }
      if (event.key === "ArrowLeft") {
        event.preventDefault();
        seekBy(-SEEK_BACK_SECONDS);
      }
      if (event.key === "ArrowRight") {
        event.preventDefault();
        seekBy(SEEK_FORWARD_SECONDS);
      }
      if (key === "c") {
        event.preventDefault();
        toggleSubtitles();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });

  useEffect(() => {
    document.body.classList.toggle("no-scroll", theaterMode);
    return () => document.body.classList.remove("no-scroll");
  }, [theaterMode]);

  useEffect(() => {
    const onFullscreenChange = () => {
      if (!document.fullscreenElement) setTheaterMode(false);
    };
    document.addEventListener("fullscreenchange", onFullscreenChange);
    return () => document.removeEventListener("fullscreenchange", onFullscreenChange);
  }, []);

  useEffect(() => {
    showPlayerChrome(!isPlaying);
    return () => window.clearTimeout(chromeTimerRef.current);
  }, [isPlaying, showPlayerChrome]);

  useEffect(() => () => window.clearTimeout(tapTimerRef.current), []);

  useEffect(() => {
    window.clearTimeout(speakerHideTimerRef.current);
    window.clearTimeout(speakerExitTimerRef.current);

    if (activeSpeakers.length) {
      setSpeakerToast({ entries: activeSpeakers, exiting: false });
      return undefined;
    }

    speakerHideTimerRef.current = window.setTimeout(() => {
      setSpeakerToast((current) => current.entries.length ? { ...current, exiting: true } : current);
      speakerExitTimerRef.current = window.setTimeout(() => {
        setSpeakerToast({ entries: [], exiting: false });
      }, 260);
    }, SPEAKER_HOLD_MS);

    return () => {
      window.clearTimeout(speakerHideTimerRef.current);
      window.clearTimeout(speakerExitTimerRef.current);
    };
  }, [activeSpeakers]);

  useEffect(() => {
    const video = videoRef.current;
    if (!video) return undefined;
    video.volume = effectiveVolume;
    video.muted = videoMuted;
    return undefined;
  }, [effectiveVolume, videoMuted]);

  useEffect(() => {
    const video = videoRef.current;
    if (!video || !media) return undefined;

    let hls;
    setMediaError("");

    if (media.hlsUrl) {
      if (video.canPlayType("application/vnd.apple.mpegurl")) {
        video.src = playbackUrl;
      } else if (Hls.isSupported()) {
        hls = new Hls({
          lowLatencyMode: false,
          maxBufferLength: 35,
          maxMaxBufferLength: 70,
          backBufferLength: 30,
          manifestLoadingMaxRetry: 6,
          manifestLoadingRetryDelay: 700,
          fragLoadingMaxRetry: 8,
          fragLoadingRetryDelay: 800,
          fragLoadingMaxRetryTimeout: 8000
        });
        hls.loadSource(playbackUrl);
        hls.attachMedia(video);
        hls.on(Hls.Events.ERROR, (_event, data) => {
          if (!data?.fatal) return;
          if (data.type === Hls.ErrorTypes.NETWORK_ERROR) {
            setMediaError("Buffering next video chunk...");
            hls.startLoad(video.currentTime || currentTime || 0);
            return;
          }
          if (data.type === Hls.ErrorTypes.MEDIA_ERROR) {
            setMediaError("Recovering video playback...");
            hls.recoverMediaError();
            return;
          }
          setMediaError("Adaptive stream playback error.");
        });
      } else {
        setMediaError("This browser cannot play HLS adaptive streams.");
      }
    } else {
      video.src = streamUrl;
    }

    video.load();
    return () => {
      hls?.destroy();
    };
  }, [media?.id, media?.hlsUrl, playbackUrl, streamUrl]);

  useEffect(() => {
    const video = videoRef.current;
    let frame;
    const tick = () => {
      if (video) {
        setCurrentTime(video.currentTime || 0);
        setDuration(Number.isFinite(video.duration) ? video.duration : 0);
      }
      frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, []);

  useEffect(() => {
    const timer = window.setInterval(() => {
      if (room?.playback?.playing) applyPlaybackState(room.playback);
    }, 2200);
    return () => window.clearInterval(timer);
  }, [applyPlaybackState, room?.playback]);

  useEffect(() => {
    if (!shouldOfferAdaptiveStream || !media?.id || hlsRequestedRef.current.has(media.id)) return;
    hlsRequestedRef.current.add(media.id);
    startAdaptiveStream(true);
  }, [media?.id, shouldOfferAdaptiveStream]);

  useEffect(() => {
    if (!media?.hlsUrl || !media?.id) return undefined;
    const warmWindow = () => {
      const segmentSeconds = media.hlsSegmentSeconds || 30;
      const segmentIndex = Math.floor((videoRef.current?.currentTime || currentTime || 0) / segmentSeconds);
      const key = `${media.id}:${segmentIndex}`;
      if (hlsWindowRef.current === key) return;
      hlsWindowRef.current = key;
      fetch(`${SERVER_URL}/api/rooms/${roomId}/media/${media.id}/hls/window`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ currentTime: videoRef.current?.currentTime || currentTime || 0 })
      }).catch(() => {});
    };

    warmWindow();
    const timer = window.setInterval(warmWindow, 8000);
    return () => window.clearInterval(timer);
  }, [media?.id, media?.hlsUrl, media?.hlsSegmentSeconds, roomId, currentTime]);

  function setRoomAndUrl(nextRoomId) {
    const clean = nextRoomId.trim() || makeRoomId();
    setRoomId(clean);
    window.history.replaceState(null, "", `?room=${encodeURIComponent(clean)}`);
  }

  async function postJson(url, body) {
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body)
    });
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.error || "Request failed.");
    return payload;
  }

  async function loadMovie() {
    try {
      setStatus("Preparing the movie...");
      await postJson(`${SERVER_URL}/api/rooms/${roomId}/media`, { path: moviePath });
      setStatus("Movie is ready.");
    } catch (error) {
      setStatus(error.message);
    }
  }

  async function uploadMovieFile(file) {
    if (!file) return;
    try {
      setStatus(`Copying movie: ${file.name}`);
      setMoviePath(file.name);
      const form = new FormData();
      form.append("movie", file);
      const response = await fetch(`${SERVER_URL}/api/rooms/${roomId}/media-upload`, {
        method: "POST",
        body: form
      });
      const payload = await response.json();
      if (!response.ok) throw new Error(payload.error || "Movie upload failed.");
      setPlaybackUnlocked(false);
      setPendingAutoplay(false);
      setMediaError("");
      setTranscodeStatus(null);
      setStatus("Movie is ready.");
    } catch (error) {
      setStatus(error.message);
    }
  }

  async function makePhoneSafeMp4() {
    if (!media) return;
    if (media.hlsUrl) {
      setStatus("Adaptive stream is active. Full MP4 conversion is disabled to keep CPU low.");
      return;
    }
    try {
      setTranscodeStatus({ status: "starting", message: "Starting phone-safe MP4 conversion..." });
      setStatus("Starting conversion...");
      const response = await fetch(`${SERVER_URL}/api/rooms/${roomId}/media/${media.id}/phone-mp4`, {
        method: "POST"
      });
      const payload = await response.json();
      if (!response.ok) throw new Error(payload.error || "MP4 conversion failed.");
      setStatus("Converting MP4.");
    } catch (error) {
      setTranscodeStatus({ status: "failed", message: error.message });
      setStatus(error.message);
    }
  }

  async function startAdaptiveStream(silent = false) {
    if (!media) return;
    try {
      if (!silent) setStatus("Starting adaptive stream...");
      await postJson(`${SERVER_URL}/api/rooms/${roomId}/media/${media.id}/hls`, {
        currentTime: videoRef.current?.currentTime || currentTime || 0
      });
      if (!silent) setStatus("Adaptive stream is buffering.");
    } catch (error) {
      hlsRequestedRef.current.delete(media.id);
      setStatus(error.message);
    }
  }

  async function loadSubtitle(slot) {
    const subtitlePath = slot === "fa" ? subtitlePathFa : subtitlePathEn;
    if (!subtitlePath.trim()) {
      setStatus(slot === "fa" ? "Choose a Persian subtitle first." : "Choose an English subtitle first.");
      return;
    }
    try {
      await postJson(`${SERVER_URL}/api/rooms/${roomId}/subtitles/${slot}`, { path: subtitlePath });
      setStatus(slot === "fa" ? "Persian subtitle loaded." : "English subtitle loaded.");
    } catch (error) {
      setStatus(error.message);
    }
  }

  async function uploadSubtitleFile(slot, file) {
    if (!file) return;
    try {
      const text = await readSubtitleFile(file);
      const ext = file.name.split(".").pop() || "srt";
      await postJson(`${SERVER_URL}/api/rooms/${roomId}/subtitles/${slot}/text`, {
        text,
        name: file.name,
        format: ext,
        label: slot === "fa" ? "Persian" : "English"
      });
      if (slot === "fa") setSubtitlePathFa(file.name);
      if (slot === "en") setSubtitlePathEn(file.name);
      setStatus(slot === "fa" ? "Persian subtitle synced." : "English subtitle synced.");
    } catch (error) {
      setStatus(error.message);
    }
  }

  function updateSubtitleSettings(patch) {
    const next = { ...subtitleSettings, ...patch };
    if (next.mode && next.mode !== "off") setLastSubtitleMode(next.mode);
    setSubtitleSettings(next);
    socketRef.current?.emit("subtitle:settings", next);
  }

  function toggleSubtitles() {
    const nextMode = subtitleSettings.mode === "off" ? lastSubtitleMode : "off";
    updateSubtitleSettings({ mode: nextMode });
    setStatus(nextMode === "off" ? "Subtitles hidden." : "Subtitles shown.");
    showPlayerChrome();
  }

  function seekTo(nextTime) {
    const video = videoRef.current;
    if (!video) return;
    video.currentTime = Math.max(0, Math.min(nextTime, duration || nextTime));
    emitPlayback({ currentTime: video.currentTime });
    showPlayerChrome();
  }

  function seekBy(deltaSeconds) {
    const video = videoRef.current;
    if (!video || !media) return;
    const nextTime = video.currentTime + deltaSeconds;
    seekTo(nextTime);
    flashSeek(deltaSeconds > 0 ? "forward" : "back", Math.abs(deltaSeconds));
  }

  async function togglePlay() {
    const video = videoRef.current;
    if (!video || !media) return;
    setPlaybackUnlocked(true);
    if (video.paused) {
      try {
        await video.play();
      } catch {
        setPendingAutoplay(true);
        setStatus("The browser blocked playback.");
        return;
      }
      setPendingAutoplay(false);
      emitPlayback({ playing: true });
      showPlayerChrome();
    } else {
      video.pause();
      emitPlayback({ playing: false });
      showPlayerChrome(true);
    }
  }

  function setRate(rate) {
    const video = videoRef.current;
    if (!video) return;
    video.playbackRate = rate;
    emitPlayback({ rate });
  }

  function startVad(stream) {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    const audioContext = new AudioContext();
    const analyser = audioContext.createAnalyser();
    analyser.fftSize = 1024;
    const source = audioContext.createMediaStreamSource(stream);
    source.connect(analyser);
    analyserRef.current = { audioContext, analyser };
    const samples = new Uint8Array(analyser.frequencyBinCount);

    const loop = () => {
      if (!analyserRef.current) return;
      analyser.getByteTimeDomainData(samples);
      let sum = 0;
      for (const sample of samples) {
        const centered = (sample - 128) / 128;
        sum += centered * centered;
      }
      const rms = Math.sqrt(sum / samples.length);
      const threshold = Math.max(0.045, noiseFloorRef.current * 4.4);
      if (rms < threshold) noiseFloorRef.current = noiseFloorRef.current * 0.96 + rms * 0.04;
      const speaking = rms > threshold;
      const level = Math.max(0, Math.min(1, (rms - noiseFloorRef.current) * 9));
      localMicLevelRef.current = level;
      setLocalMicLevel(level);
      const now = Date.now();
      if (now - lastVoiceEmitRef.current > 120) {
        lastVoiceEmitRef.current = now;
        socketRef.current?.emit("voice:activity", { speaking, level });
      }
      if (speaking !== lastSpeakingRef.current) {
        lastSpeakingRef.current = speaking;
        setLocalSpeaking(speaking);
      }
      vadFrameRef.current = requestAnimationFrame(loop);
    };
    vadFrameRef.current = requestAnimationFrame(loop);
  }

  function stopVad() {
    if (vadFrameRef.current) cancelAnimationFrame(vadFrameRef.current);
    if (analyserRef.current) {
      analyserRef.current.audioContext.close();
      analyserRef.current = null;
    }
    setLocalSpeaking(false);
    setLocalMicLevel(0);
    socketRef.current?.emit("voice:activity", { speaking: false, level: 0 });
  }

  async function toggleMic() {
    if (micEnabled) {
      localStreamRef.current?.getTracks().forEach(track => track.stop());
      localStreamRef.current = null;
      setMicEnabled(false);
      setMicStatus("Mic off");
      stopVad();
      socketRef.current?.emit("voice:activity", { speaking: false, level: 0 });
      return;
    }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      localStreamRef.current = stream;
      setMicEnabled(true);
      setMicStatus("Mic connected");
      startVad(stream);
      peerConnectionsRef.current.forEach(pc => {
        stream.getTracks().forEach(track => {
          if (!pc.getSenders().some(s => s.track?.id === track.id)) {
            pc.addTrack(track, stream);
          }
        });
      });
      renegotiateAll();
    } catch (e) {
      setMicStatus("Mic access denied");
    }
  }

  async function refreshMicDevices() {
    try {
      const devices = await navigator.mediaDevices.enumerateDevices();
      setMicDevices(devices.filter(d => d.kind === 'audioinput'));
    } catch (e) {}
  }

  function copyShareLink() {
    navigator.clipboard.writeText(shareUrl);
    setStatus("Link copied!");
  }

  function unlockPlayback() {
    const video = videoRef.current;
    if (!video) return;
    video.muted = true;
    video.play().then(() => {
      video.muted = videoMuted;
      setPlaybackUnlocked(true);
      setPendingAutoplay(false);
      setIsPlaying(true);
    }).catch(() => {});
  }

  function onVideoLoaded() {
    const video = videoRef.current;
    if (!video) return;
    setDuration(video.duration);
    if (room?.playback) {
      applyPlaybackState(room.playback, true);
    }
  }

  function handleScreenPointerUp(e) {
    if (e.target.closest('.lan-transport') || e.target.closest('.unlock-overlay')) return;
    if (!media) return;
    const rect = e.currentTarget.getBoundingClientRect();
    const ratio = (e.clientX - rect.left) / rect.width;
    const zone = ratio < 0.36 ? "left" : ratio > 0.64 ? "right" : "center";
    const now = Date.now();
    const lastTap = lastTapRef.current;
    const isDoubleTap = now - lastTap.time < 280 && lastTap.zone === zone;

    window.clearTimeout(tapTimerRef.current);
    showPlayerChrome();

    if (isDoubleTap) {
      lastTapRef.current = { time: 0, zone: "center" };
      if (zone === "left") seekBy(-SEEK_BACK_SECONDS);
      if (zone === "right") seekBy(SEEK_FORWARD_SECONDS);
      if (zone === "center") togglePlay();
      return;
    }

    lastTapRef.current = { time: now, zone };
    tapTimerRef.current = window.setTimeout(() => {
      if (zone === "center") togglePlay();
    }, 310);
  }

  function setRemoteVolume(id, vol) {
    setRemoteVoiceVolumes(prev => ({...prev, [id]: vol}));
  }

  function removeParticipant(id) {
    if (!id || id === socketId) return;
    socketRef.current?.emit("peer:kick", { id }, (result) => {
      setStatus(result?.ok ? "User removed from room." : (result?.error || "Could not remove user."));
    });
  }

  function saveProfile(e) {
    e.preventDefault();
    if (name.trim()) setProfileReady(true);
  }

  async function toggleTheaterMode() {
    const entering = !theaterMode;
    setTheaterMode(entering);

    if (entering) {
      showPlayerChrome(true);
      const target = screenRef.current || document.documentElement;
      try {
        await target.requestFullscreen?.();
      } catch {
        // Mobile browsers can reject fullscreen; theaterMode still gives us the custom player.
      }
      try {
        await screen.orientation?.lock?.("landscape");
      } catch {
        // Orientation lock is optional and unavailable in many mobile browsers.
      }
      return;
    }

    if (document.fullscreenElement) {
      document.exitFullscreen().catch(() => {});
    }
    screen.orientation?.unlock?.();
  }

  return (
    <div className={`lan-app ${theaterMode ? "theater-mode" : ""}`}>
      {!profileReady && (
        <div className="welcome-layer">
          <form className="welcome-card" onSubmit={saveProfile}>
            <span className="brand-mark"><MonitorPlay size={22} /></span>
            <h1>Join LAN CINEMA</h1>
            <p>Enter your display name to continue.</p>
            <label className="field">
              <input
                autoFocus
                value={name}
                onChange={(event) => setName(event.target.value)}
                placeholder="Your name"
              />
            </label>
            <button className="button primary wide" type="submit">Enter Room</button>
          </form>
        </div>
      )}
      
      {/* Top Bar */}
      <header className="lan-topbar">
        <div className="topbar-left">
          <MonitorPlay className="lan-logo-icon" size={24} />
          <div className="lan-brand">
            <h1>LAN CINEMA</h1>
            <p>Watch Together. Locally.</p>
          </div>
        </div>
        
        <div className="topbar-center">
          <div className="room-badge">
            <span className="room-label">Room:</span>
            <span className="room-id">{roomId}</span>
            <button onClick={copyShareLink} className="copy-btn"><Copy size={14}/></button>
          </div>
          <button className="share-btn" onClick={copyShareLink}>
            <Link2 size={14} /> Share Link
          </button>
          {status && <span className="status-toast" style={{marginLeft: '12px', fontSize: '13px', color: 'var(--accent)'}}>{status}</span>}
        </div>
        
        <div className="topbar-right">
          <div className="users-count">
            <Users size={16} />
            <span>{participantCount} online</span>
            <span className="dot ok" />
          </div>
          <div className="window-controls">
            <button onClick={toggleTheaterMode} title="Fullscreen"><Maximize size={16}/></button>
          </div>
        </div>
      </header>

      <div className="lan-workspace">
        <div className="lan-main-col">
          <div 
            className={`lan-video-container ${showChrome ? "chrome-visible" : "chrome-hidden"}`}
            ref={screenRef}
            onPointerMove={() => showPlayerChrome()}
            onPointerUp={handleScreenPointerUp}
          >
            <video
              ref={videoRef}
              playsInline
              preload="metadata"
              onLoadedMetadata={onVideoLoaded}
              onPlay={() => setIsPlaying(true)}
              onPause={() => setIsPlaying(false)}
              onCanPlay={() => setMediaError("")}
              onError={() => {
                if (!media) return;
                if (media.hlsUrl) {
                  setMediaError("Buffering adaptive stream...");
                  return;
                }
                setIsPlaying(false);
                setMediaError("Playback error.");
              }}
              onEnded={() => emitPlayback({ playing: false, currentTime: duration })}
            />
            {!media && (
              <div className="empty-state">
                <MonitorPlay size={44} />
                <h2>No movie selected</h2>
                <p style={{color: 'var(--text-muted)'}}>Use the Host Controls panel to load a file.</p>
              </div>
            )}
            
            {media && (
              <div
                className={`subtitle-layer ${subtitleSettings.bg ? "with-bg" : ""}`}
                style={{
                  "--subtitle-gap": `${subtitleGap}px`,
                  "--subtitle-bg": `rgba(0,0,0,${(subtitleSettings.bgOpacity ?? 70) / 100})`
                }}
              >
                {(subtitleSettings.mode === "both" || subtitleSettings.mode === "fa") && faCue && (
                  <div className="subtitle-line subtitle-fa" dir="rtl" style={{ "--line-size": `${faSubtitleSize}px` }}>{faCue.text}</div>
                )}
                {(subtitleSettings.mode === "both" || subtitleSettings.mode === "en") && enCue && (
                  <div className="subtitle-line subtitle-en" style={{ "--line-size": `${enSubtitleSize}px` }}>{enCue.text}</div>
                )}
              </div>
            )}

            {seekFlash && (
              <div className={`seek-flash ${seekFlash.direction}`}>
                {seekFlash.direction === "forward" ? "+" : "-"}{seekFlash.seconds}s
              </div>
            )}

            {theaterMode && speakerToast.entries.length > 0 && (
              <div className={`speaker-toast ${speakerToast.exiting ? "exiting" : ""}`}>
                {speakerToast.entries.map((speaker) => (
                  <div className="speaker-toast-row" key={speaker.id} style={{ "--level": levelPercent(speaker.level || 0) }}>
                    <span className="toast-avatar">{initials(speaker.name)}</span>
                    <span>{speaker.self ? "You" : speaker.name}</span>
                    <span className="wave-bars" aria-hidden="true"><i/><i/><i/><i/></span>
                  </div>
                ))}
              </div>
            )}
            
            <div className={`lan-transport ${showChrome ? 'visible' : ''}`}>
               <div className="scrub-row">
                 <span>{formatTime(currentTime)}</span>
                 <input
                   type="range"
                   className="scrub-slider"
                   min="0"
                   max={duration || 0}
                   value={Math.min(currentTime, duration || currentTime)}
                   step="0.05"
                   onChange={(event) => seekTo(Number(event.target.value))}
                   disabled={!media}
                 />
                 <span>-{formatTime(Math.max(0, duration - currentTime))}</span>
               </div>
               
               <div className="control-row">
                 <div className="control-left">
                   <button onClick={() => setVideoMuted(!videoMuted)} className="icon-btn">
                     {videoMuted ? <VolumeX size={18}/> : <Volume2 size={18}/>}
                   </button>
                   <input type="range" className="vol-slider" min="0" max="1" step="0.01" value={userVolume} onChange={(e) => setUserVolume(Number(e.target.value))} />
                   <span className="vol-text">{Math.round(userVolume*100)}%</span>
                 </div>
                 
                 <div className="control-center compact">
                   <button className={`icon-btn center-control-btn ${micEnabled ? "active" : ""}`} onClick={toggleMic} title={micEnabled ? "Turn mic off" : "Turn mic on"}>
                     {micEnabled ? <Mic size={19}/> : <MicOff size={19}/>}
                   </button>
                   <button className="icon-btn seek-btn" onClick={() => seekBy(-SEEK_BACK_SECONDS)} title={`${SEEK_BACK_SECONDS}s back`}>
                     <RotateCcw size={20}/>
                     <span>{SEEK_BACK_SECONDS}</span>
                   </button>
                   <button className="play-btn" onClick={togglePlay}>
                     {isPlaying ? <Pause fill="currentColor" size={24}/> : <Play fill="currentColor" size={24}/>}
                   </button>
                   <button className="icon-btn seek-btn" onClick={() => seekBy(SEEK_FORWARD_SECONDS)} title={`${SEEK_FORWARD_SECONDS}s forward`}>
                     <RotateCw size={20}/>
                     <span>{SEEK_FORWARD_SECONDS}</span>
                   </button>
                   <button className={`icon-btn center-control-btn ${subtitleSettings.mode !== "off" ? "active" : ""}`} onClick={toggleSubtitles} title={subtitleSettings.mode === "off" ? "Show captions" : "Hide captions"}>
                     <Captions size={20}/>
                   </button>
                 </div>
                 
                 <div className="control-right">
                   <button className="icon-btn" onClick={toggleTheaterMode}><Maximize size={18}/></button>
                 </div>
               </div>
            </div>
            
            {media && (!playbackUnlocked || pendingAutoplay) && (
              <button className="unlock-overlay" onClick={unlockPlayback}>
                <Play size={22} /> Enable playback
              </button>
            )}
            {mediaError && (
              <div className="unlock-overlay" style={{background: 'rgba(200,30,30,0.8)'}}>
                {mediaError}
              </div>
            )}
            {voiceBlocked && (
              <button className="unlock-overlay" onClick={unlockRemoteVoice} style={{background: 'rgba(5, 213, 154, 0.9)', color: '#000', top: '20px', bottom: 'auto', height: 'auto', padding: '10px 20px', borderRadius: '8px'}}>
                <Mic size={22} /> Click to hear voice chat
              </button>
            )}
          </div>
          
          <div className="lan-voice-panel">
            <div className="ducking-section">
              <div className="ducking-header">
                <span>Adaptive Ducking</span>
              </div>
                            <div className="ducking-controls">
                <div className={`fake-waveform ${anyoneSpeaking && adaptiveDucking ? 'animating' : ''}`}>
                  <div className="bar" style={{height: '40%'}}></div>
                  <div className="bar" style={{height: '70%'}}></div>
                  <div className="bar" style={{height: '100%'}}></div>
                  <div className="bar" style={{height: '60%'}}></div>
                  <div className="bar" style={{height: '30%'}}></div>
                  <div className="bar" style={{height: '80%'}}></div>
                  <div className="bar" style={{height: '50%'}}></div>
                  <div className="bar" style={{height: '90%'}}></div>
                </div>
                <label className="switch">
                  <input type="checkbox" checked={adaptiveDucking} onChange={(e) => setAdaptiveDucking(e.target.checked)} />
                  <span className="slider round"></span>
                </label>
              </div>
            </div>
            
            <div className="voice-activity-section">
               <span className="section-label">Voice Activity</span>
               <div className="voice-meters">
                 {participants.map((participant) => {
                    const level = participant.self ? localMicLevel : participant.level;
                    return (
                      <div className="meter-row" key={participant.id}>
                        <span className="meter-name">{participant.self ? "You" : participant.name}</span>
                        <div className="meter-bars">
                          {Array.from({length: 15}).map((_, i) => <div key={i} className={`meter-segment ${level > i/15 ? 'active' : ''}`} />)}
                        </div>
                        {!participant.self && (
                          <button className="remove-user-btn" onClick={() => removeParticipant(participant.id)} title={`Remove ${participant.name}`}>
                            <X size={13} />
                          </button>
                        )}
                      </div>
                    )
                 })}
                 
               </div>
            </div>
            
            <div className="audio-mode-section">
               <span className="section-label">Audio Mode</span>
               <select className="lan-select" value={voiceOutputEnabled ? "ducking" : "muted"} onChange={(e) => setVoiceOutputEnabled(e.target.value === "ducking")}>
                 <option value="ducking">Ducking (Auto)</option>
                 <option value="muted">Muted</option>
               </select>
               <span className="audio-mode-desc">Lowering movie volume when someone talks.</span>
            </div>
          </div>
          
                    <footer className="lan-status-bar">
             <div className="status-item">
               Server: <span className="highlight-id">{roomId}</span> 
               <span className="status-badge">Online</span>
             </div>
             <div className="status-item">
               Local IP: <span className="highlight-white">{health?.lanIps?.[0] || '127.0.0.1'}</span>
             </div>
             <div className="status-item">
               <Wifi size={14} className="accent-icon"/> Quality: <span className="highlight-white">LAN (Excellent)</span>
             </div>
             <div className="status-item">
               <Gauge size={14} className="accent-icon"/> Latency: <span className="highlight-white">{pingMs} ms</span>
             </div>
          </footer>
        </div>

        <aside className="lan-sidebar">
          <div className="sidebar-section">
             <div className="section-header">
                <h3>HOST CONTROLS</h3>
                <ChevronUp size={16} className="chevron"/>
             </div>
             <div className="section-content">
               <div className="input-group">
                 <label>Movie File</label>
                 <div className="file-input-wrapper">
                    <input type="text" value={moviePath || displayMediaName} readOnly placeholder="D:\Movies\Dune.Part.Two.mkv" />
                    <button className="folder-btn" onClick={() => document.getElementById('movie-upload').click()}><FolderOpen size={16}/></button>
                    <input id="movie-upload" type="file" style={{display:'none'}} accept="video/*,.mkv,.mp4,.m4v,.mov,.webm,.ogg,.ogv" onChange={(e) => uploadMovieFile(e.target.files?.[0])} />
                 </div>
                                  <div className="file-meta">
                   <span className={media ? "success-text" : "muted-text"}>{media ? "File loaded" : "No file"}</span>
                   <span className="muted-text">{media ? formatBytes(media.size) : '0 GB'}</span>
                 </div>
                 {shouldOfferPhoneMp4 && (
                   <button className="button primary mt-2" onClick={makePhoneSafeMp4} style={{fontSize: '12px', padding: '4px 8px', borderRadius: '4px'}}>
                     Convert to phone safe MP4
                   </button>
                 )}
                 {shouldOfferAdaptiveStream && (
                   <button className="button secondary mt-2" onClick={() => startAdaptiveStream()} style={{fontSize: '12px', padding: '4px 8px', borderRadius: '4px'}}>
                     Start adaptive stream now
                   </button>
                 )}
                 {media?.hlsUrl && (
                   <div className="file-meta">
                     <span className="success-text">Adaptive stream active</span>
                     <span className="muted-text">{media.hlsStatus || "buffering"}</span>
                   </div>
                 )}
                 {transcodeStatus && (
                   <div className="transcode-status mt-2" style={{fontSize: '12px', color: 'var(--accent)'}}>
                     {transcodeStatus.message}
                   </div>
                 )}
               </div>
               
               <div className="input-group">
                 <label>Subtitles</label>
                 <div className="subtitle-import-row mb-2">
                  <div className="file-input-wrapper">
                    <select className="lang-select">
                      <option>فارسی (Persian)</option>
                    </select>
                    <input type="text" value={subtitlePathFa} placeholder={faData?.name || "/path/Movie.fa.srt"} onChange={(e) => setSubtitlePathFa(e.target.value)} />
                    <button className="clear-btn" onClick={() => setSubtitlePathFa('')}><X size={14}/></button>
                    <button className="folder-btn" onClick={() => document.getElementById('fa-upload').click()}><FolderOpen size={16}/></button>
                    <input id="fa-upload" type="file" style={{display:'none'}} onChange={(e) => uploadSubtitleFile("fa", e.target.files?.[0])} />
                  </div>
                  <button className="load-subtitle-btn" onClick={() => loadSubtitle("fa")}>Load</button>
                 </div>
                 <div className="subtitle-import-row">
                  <div className="file-input-wrapper">
                    <select className="lang-select">
                      <option>English</option>
                    </select>
                    <input type="text" value={subtitlePathEn} placeholder={enData?.name || "/path/Movie.en.srt"} onChange={(e) => setSubtitlePathEn(e.target.value)} />
                    <button className="clear-btn" onClick={() => setSubtitlePathEn('')}><X size={14}/></button>
                    <button className="folder-btn" onClick={() => document.getElementById('en-upload').click()}><FolderOpen size={16}/></button>
                    <input id="en-upload" type="file" style={{display:'none'}} onChange={(e) => uploadSubtitleFile("en", e.target.files?.[0])} />
                  </div>
                  <button className="load-subtitle-btn" onClick={() => loadSubtitle("en")}>Load</button>
                 </div>
               </div>
             </div>
          </div>
          
          <div className="sidebar-section">
             <div className="section-header">
                <h3>ROOM & CONNECTION</h3>
                <ChevronDown size={16} className="chevron"/>
             </div>
             <div className="section-content">
               <div className="input-group">
                 <label>Room Link</label>
                 <div className="file-input-wrapper">
                   <input type="text" value={shareUrl} readOnly />
                   <button className="folder-btn" onClick={copyShareLink}><Copy size={16}/></button>
                 </div>
               </div>
               <div className="input-group">
                 <label>Or share this code with your friend:</label>
                 <div className="file-input-wrapper">
                   <input type="text" value={roomId.toUpperCase()} className="code-input" readOnly />
                   <button className="folder-btn" onClick={copyShareLink}><Copy size={16}/></button>
                 </div>
               </div>
               <div className="connection-status">
                 <div className="conn-left">
                   <Wifi size={18} className="muted-icon"/>
                   <div className="conn-texts">
                     <div className="muted-text">Connection</div>
                     <div className="white-text">Peers: {otherPeers.length}</div>
                   </div>
                 </div>
                 <div className="conn-right">
                   <span className="success-text">{health ? 'Excellent' : 'Connecting'}</span>
                   <span className="dot ok"></span>
                 </div>
               </div>
             </div>
          </div>
          
          <div className="sidebar-section">
             <div className="section-header">
                <h3>SUBTITLES</h3>
                <ChevronUp size={16} className="chevron"/>
             </div>
             <div className="section-content">
                <div className="slider-group">
                  <label>Persian</label>
                  <span className="slider-label-a">A</span>
                  <input type="range" min="18" max="72" value={faSubtitleSize} onChange={(e) => updateSubtitleSettings({faSize: Number(e.target.value), size: Number(e.target.value)})} className="lan-slider" />
                  <div className="number-box">{faSubtitleSize} <span className="unit">px</span></div>
                </div>

                <div className="slider-group">
                  <label>English</label>
                  <span className="slider-label-a">A</span>
                  <input type="range" min="14" max="60" value={enSubtitleSize} onChange={(e) => updateSubtitleSettings({enSize: Number(e.target.value)})} className="lan-slider" />
                  <div className="number-box">{enSubtitleSize} <span className="unit">px</span></div>
                </div>

                <div className="slider-group">
                  <label>Gap</label>
                  <span className="slider-label-a">G</span>
                  <input type="range" min="0" max="40" value={subtitleGap} onChange={(e) => updateSubtitleSettings({gap: Number(e.target.value)})} className="lan-slider" />
                  <div className="number-box">{subtitleGap} <span className="unit">px</span></div>
                </div>
                
                <div className="offset-group">
                  <label>Persian Offset</label>
                  <div className="stepper">
                    <button onClick={() => updateSubtitleSettings({faOffsetMs: subtitleSettings.faOffsetMs - 50})}><Minus size={14}/></button>
                    <div className="step-val">{subtitleSettings.faOffsetMs > 0 ? `+${subtitleSettings.faOffsetMs}` : subtitleSettings.faOffsetMs} ms</div>
                    <button onClick={() => updateSubtitleSettings({faOffsetMs: subtitleSettings.faOffsetMs + 50})}><Plus size={14}/></button>
                  </div>
                </div>
                
                <div className="offset-group">
                  <label>English Offset</label>
                  <div className="stepper">
                    <button onClick={() => updateSubtitleSettings({enOffsetMs: subtitleSettings.enOffsetMs - 50})}><Minus size={14}/></button>
                    <div className="step-val">{subtitleSettings.enOffsetMs > 0 ? `+${subtitleSettings.enOffsetMs}` : subtitleSettings.enOffsetMs} ms</div>
                    <button onClick={() => updateSubtitleSettings({enOffsetMs: subtitleSettings.enOffsetMs + 50})}><Plus size={14}/></button>
                  </div>
                </div>
                
                                <div className="preview-box" style={{ 
                    "--preview-gap": `${subtitleGap}px`,
                    background: subtitleSettings.bg ? `rgba(0,0,0,${(subtitleSettings.bgOpacity ?? 70) / 100})` : 'transparent'
                }}>
                  {subtitleSettings.mode !== 'en' && <div className="preview-fa" dir="rtl" style={{ fontSize: `${Math.max(14, faSubtitleSize * 0.4)}px` }}>گاهی برای پیدا کردن پاسخ، باید مسیرت را گم کنی.</div>}
                  {subtitleSettings.mode !== 'fa' && <div className="preview-en" style={{ fontSize: `${Math.max(12, enSubtitleSize * 0.4)}px` }}>Sometimes you have to get lost to find the answer.</div>}
                </div>
                
                <div className="input-group mt-3">
                  <label>Display Mode</label>
                  <select className="lan-select w-full" value={subtitleSettings.mode} onChange={(e) => updateSubtitleSettings({mode: e.target.value})}>
                    <option value="both">Both Languages (Stacked)</option>
                    <option value="fa">Persian Only</option>
                    <option value="en">English Only</option>
                    <option value="off">Off</option>
                  </select>
                </div>
                
                <div className="bg-check-group mt-3">
                  <label className="checkbox-label" style={{flex: 1}}>
                    <input type="checkbox" checked={subtitleSettings.bg || false} onChange={(e) => updateSubtitleSettings({bg: e.target.checked})} />
                    <span className="check-box" style={{ background: subtitleSettings.bg ? 'var(--accent)' : 'transparent', borderColor: subtitleSettings.bg ? 'var(--accent)' : 'var(--border)' }}></span>
                    Background
                  </label>
                  <input type="range" min="0" max="100" value={subtitleSettings.bgOpacity ?? 70} onChange={(e) => updateSubtitleSettings({bgOpacity: Number(e.target.value)})} style={{width: '80px'}} className="lan-slider" />
                  <span className="opacity-val" style={{width: '32px', textAlign: 'right'}}>{subtitleSettings.bgOpacity ?? 70}%</span>
                </div>
             </div>
          </div>
        </aside>
      </div>
      
      {[...remoteStreams.entries()].map(([id, stream]) => (
        <RemoteAudio
          key={id}
          stream={stream}
          muted={!voiceOutputEnabled}
          volume={remoteVoiceVolumes[id] ?? defaultRemoteVoiceVolume}
          unlockKey={voiceUnlockKey}
          onBlocked={handleRemoteVoiceBlocked}
        />
      ))}
    </div>
  );
}

createRoot(document.getElementById("root")).render(<App />);
