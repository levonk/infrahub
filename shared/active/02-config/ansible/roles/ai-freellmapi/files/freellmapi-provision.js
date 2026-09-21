// freellmapi-provision.js — declarative first-run provisioning for FreeLLMAPI.
//
// Executed INSIDE the container via community.docker.docker_container_exec:
//   argv: ["node", "-e", "<this file>"]
//   env:  FL_PORT, FL_EMAIL, FL_PASSWORD, FL_LICENSE   (Docker exec API Env —
//         never on a command line, never in host `ps`)
//
// Loopback requests intentionally skip the one-time setup code:
// server/src/routes/auth.ts isLoopbackRemote() checks req.socket.remoteAddress
// (the real TCP peer, NOT X-Forwarded-For), and exec'd requests originate from
// 127.0.0.1 inside the container's network namespace. This mirrors the
// "browser on the same machine" first-run path upstream designed to be
// frictionless — it is not a spoof.
//
// Prints exactly ONE JSON line on stdout, e.g.:
//   {"setup":"done","login":"skipped","license":"done"}
// Ansible parses this for changed_when. Diagnostics go to stderr only.

const HTTP_OK = 200;
const HTTP_CREATED = 201;
const HTTP_CONFLICT = 409;
const REQ_TIMEOUT_MS = 15000;
const MASK_UNMASKED_MAX = 10; // server returns keys of this length or shorter unmasked
const MASK_HEAD = 7;
const MASK_TAIL = 4;

const BASE = `http://127.0.0.1:${process.env.FL_PORT}`;
const EMAIL = process.env.FL_EMAIL || '';
const PASSWORD = process.env.FL_PASSWORD || '';
const LICENSE = process.env.FL_LICENSE || '';

const result = { setup: 'skipped', login: 'skipped', license: 'none' };

// Mirror of server/src/routes/premium.ts maskKey(): lets us detect a rotated
// vault key against the masked key the API reports.
function maskKey(k) {
  return k.length <= MASK_UNMASKED_MAX ? k : `${k.slice(0, MASK_HEAD)}…${k.slice(-MASK_TAIL)}`;
}

async function req(path, { method = 'GET', body, token } = {}) {
  const r = await fetch(BASE + path, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(REQ_TIMEOUT_MS),
  });
  return { status: r.status, body: await r.json().catch(() => ({})) };
}

async function main() {
  const status = await req('/api/auth/status');
  let token = null;

  if (status.body.needsSetup) {
    const r = await req('/api/auth/setup', {
      method: 'POST',
      body: { email: EMAIL, password: PASSWORD },
    });
    if (r.status === HTTP_CREATED) {
      token = r.body.token;
      result.setup = 'done';
    } else if (r.status === HTTP_CONFLICT) {
      // Raced with another claimer — a user now exists; fall through to login.
    } else {
      throw new Error(`setup failed: HTTP ${r.status} ${JSON.stringify(r.body)}`);
    }
  }

  if (!token) {
    const r = await req('/api/auth/login', {
      method: 'POST',
      body: { email: EMAIL, password: PASSWORD },
    });
    if (r.status !== HTTP_OK) {
      throw new Error(`login failed: HTTP ${r.status} — vault credentials may be stale`);
    }
    token = r.body.token;
    result.login = 'done';
  }

  if (LICENSE) {
    const p = await req('/api/premium', { token });
    if (p.status !== HTTP_OK) {
      throw new Error(`premium status failed: HTTP ${p.status}`);
    }
    // Re-activate when absent OR when the vault key no longer matches the
    // stored one (rotation); identical mask = already active, skip.
    if (!p.body.hasKey || p.body.maskedKey !== maskKey(LICENSE)) {
      const r = await req('/api/premium/key', {
        method: 'POST',
        body: { key: LICENSE },
        token,
      });
      if (r.status !== HTTP_OK) {
        throw new Error(`license activation failed: HTTP ${r.status} ${JSON.stringify(r.body)}`);
      }
      result.license = 'done';
    } else {
      result.license = 'skipped';
    }
  }

  console.log(JSON.stringify(result));
}

main().then(
  () => process.exit(0),
  (e) => {
    console.error(String((e && e.message) || e));
    process.exit(1);
  },
);
