// Relayer signaling server with health, metrics, JWT and optional mTLS
const fs = require('fs');
const http = require('http');
const https = require('https');
const express = require('express');
const WebSocket = require('ws');
const promClient = require('prom-client');
const jwt = require('jsonwebtoken');
const ocsp = require('ocsp');

const DEFAULT_PORT = 8080;
const PORT = process.env.PORT ? parseInt(process.env.PORT) : DEFAULT_PORT;

// Auth-related env vars
const RELAYER_API_KEY = process.env.RELAYER_API_KEY || '';
const RELAYER_JWT_SECRET = process.env.RELAYER_JWT_SECRET || '';
const RELAYER_MTLS_REQUIRED = (process.env.RELAYER_MTLS_REQUIRED || 'false') === 'true';
const TLS_KEY_PATH = process.env.RELAYER_TLS_KEY_PATH || '';
const TLS_CERT_PATH = process.env.RELAYER_TLS_CERT_PATH || '';
const TLS_CA_PATH = process.env.RELAYER_TLS_CA_PATH || '';
const RELAYER_OCSP_REQUIRED = (process.env.RELAYER_OCSP_REQUIRED || 'false') === 'true';
const RELAYER_OCSP_ISSUER_CERT_PATH = process.env.RELAYER_OCSP_ISSUER_CERT_PATH || '';

// Prometheus metrics
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });
const wsConnections = new promClient.Gauge({ name: 'unit_relayer_ws_connections', help: 'Active WS connections' });
const wsMessages = new promClient.Counter({ name: 'unit_relayer_ws_messages_total', help: 'Total WS messages received' });
const wsUnauthorized = new promClient.Counter({ name: 'unit_relayer_ws_unauthorized_total', help: 'Unauthorized connection attempts' });
register.registerMetric(wsConnections);
register.registerMetric(wsMessages);
register.registerMetric(wsUnauthorized);
const signalLatency = new promClient.Histogram({ name: 'unit_relayer_signal_latency_seconds', help: 'Signal broadcast latency (s)', buckets: [0.001, 0.01, 0.05, 0.1, 0.5, 1, 5] });
const roomsCount = new promClient.Gauge({ name: 'unit_relayer_rooms_count', help: 'Number of active rooms' });
register.registerMetric(signalLatency);
register.registerMetric(roomsCount);

const app = express();
app.get('/health', (req, res) => res.json({ status: 'ok', uptime: process.uptime() }));
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Create HTTP or HTTPS server depending on TLS envs
let server;
if (RELAYER_MTLS_REQUIRED || (TLS_KEY_PATH && TLS_CERT_PATH)) {
  try {
    const options = {
      key: fs.readFileSync(TLS_KEY_PATH),
      cert: fs.readFileSync(TLS_CERT_PATH),
      requestCert: RELAYER_MTLS_REQUIRED,
      rejectUnauthorized: false
    };
    if (TLS_CA_PATH) options.ca = fs.readFileSync(TLS_CA_PATH);
    server = https.createServer(options, app);
    console.log('Starting HTTPS relayer server');
  } catch (err) {
    console.error('Failed to read TLS files, falling back to HTTP:', err.message);
    server = http.createServer(app);
  }
} else {
  server = http.createServer(app);
}

// WebSocket server bound to the HTTP(S) server
const wss = new WebSocket.Server({ server });

// Minimal in-memory rooms
const rooms = new Map();

async function validateAuth(req) {
  // mTLS check
  if (RELAYER_MTLS_REQUIRED) {
    const cert = req.socket.getPeerCertificate(true);
    if (!cert || Object.keys(cert).length === 0) {
      return { ok: false, reason: 'missing-client-cert' };
    }
    // Note: additional certificate validation (CN/O, fingerprint) should be implemented as needed
  }

  // JWT takes precedence
  if (RELAYER_JWT_SECRET) {
    const authHeader = (req.headers['authorization'] || '').toString();
    if (!authHeader.startsWith('Bearer ')) return { ok: false, reason: 'missing-jwt' };
    const token = authHeader.slice(7);
    try {
      const payload = jwt.verify(token, RELAYER_JWT_SECRET);
      return { ok: true, payload };
    } catch (err) {
      return { ok: false, reason: 'invalid-jwt' };
    }
  }

  // Fallback to API key if configured
  if (RELAYER_API_KEY) {
    try {
      const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
      const keyParam = url.searchParams.get('key');
      const authHeader = (req.headers['authorization'] || '').toString();
      const provided = keyParam || (authHeader.startsWith('Bearer ') ? authHeader.slice(7) : authHeader);
      if (!provided || provided !== RELAYER_API_KEY) return { ok: false, reason: 'invalid-api-key' };
    } catch (e) {
      return { ok: false, reason: 'invalid-request' };
    }
  }

  // Optional strict client cert subject/fingerprint whitelist
  const allowedSubjects = (process.env.RELAYER_ALLOWED_CLIENT_CERT_SUBJECTS || '').split(',').map(s => s.trim()).filter(Boolean);
  const allowedFPS = (process.env.RELAYER_ALLOWED_CLIENT_CERT_FPS || '').split(',').map(s => s.trim().toLowerCase()).filter(Boolean);
  if (RELAYER_MTLS_REQUIRED && (allowedSubjects.length > 0 || allowedFPS.length > 0)) {
    const cert = req.socket.getPeerCertificate(true);
    if (cert && cert.fingerprint) {
      const fp = cert.fingerprint.replace(/:/g,'').toLowerCase();
      if (allowedFPS.includes(fp)) return { ok: true };
    }
    if (cert && cert.subject) {
      const subj = JSON.stringify(cert.subject);
      for (const allowed of allowedSubjects) {
        if (subj.includes(allowed)) return { ok: true };
      }
    }
    return { ok: false, reason: 'client-cert-not-whitelisted' };
  }

  // Optional OCSP check when configured
  if (RELAYER_MTLS_REQUIRED && RELAYER_OCSP_REQUIRED) {
    try {
      const cert = req.socket.getPeerCertificate(true);
      if (!cert || !cert.raw) return { ok: false, reason: 'missing-cert-for-ocsp' };
      if (!RELAYER_OCSP_ISSUER_CERT_PATH) return { ok: false, reason: 'missing-issuer-for-ocsp' };
      const issuerPem = fs.readFileSync(RELAYER_OCSP_ISSUER_CERT_PATH);
      const ocspResult = await new Promise((resolve, reject) => {
        ocsp.check({ cert: cert.raw, issuer: issuerPem }, (err, res) => {
          if (err) return reject(err);
          resolve(res);
        });
      });
      // ocspResult.status === 'good' in successful case
      if (ocspResult && (ocspResult.type === 'good' || ocspResult.status === 'good')) {
        // OK
      } else {
        return { ok: false, reason: 'ocsp-not-good' };
      }
    } catch (err) {
      console.error('OCSP check failed:', err && err.message ? err.message : err);
      return { ok: false, reason: 'ocsp-error' };
    }
  }

  return { ok: true };
}

wss.on('connection', function connection(ws, req) {
  (async () => {
    const auth = await validateAuth(req);
    if (!auth.ok) {
      try { ws.send(JSON.stringify({ type: 'error', message: 'unauthorized', reason: auth.reason })); } catch (e) {}
      wsUnauthorized.inc();
      ws.close(1008, 'unauthorized');
      return;
    }

    // Increase connection gauge
    wsConnections.inc();

    ws.on('message', function incoming(message) {
      wsMessages.inc();
      try {
        const msg = JSON.parse(message);
        if (msg.type === 'join' && msg.room) {
          const clients = rooms.get(msg.room) || [];
          clients.push(ws);
          rooms.set(msg.room, clients);
          ws.room = msg.room;
          ws.send(JSON.stringify({ type: 'joined', room: msg.room }));
          roomsCount.set(rooms.size);
        } else if (msg.type === 'signal' && ws.room) {
          const start = process.hrtime();
          const clients = rooms.get(ws.room) || [];
          // Broadcast signal to other clients in the room
          clients.forEach(client => {
            if (client !== ws && client.readyState === WebSocket.OPEN) {
              client.send(JSON.stringify({ type: 'signal', from: msg.from, data: msg.data }));
            }
          });
          const diff = process.hrtime(start);
          const seconds = diff[0] + diff[1] / 1e9;
          signalLatency.observe(seconds);
        }
      } catch (err) {
        console.error('Invalid message', err);
      }
    });

    ws.on('close', () => {
      wsConnections.dec();
      if (ws.room) {
        const clients = rooms.get(ws.room) || [];
        rooms.set(ws.room, clients.filter(c => c !== ws));
      }
    });
  })();
});

server.listen(PORT, () => {
  console.log(`UNIT relayer running on ${server instanceof https.Server ? 'https' : 'http'}://0.0.0.0:${PORT}`);
  if (RELAYER_MTLS_REQUIRED) console.log('mTLS required: true');
  if (RELAYER_JWT_SECRET) console.log('JWT auth enabled');
  if (RELAYER_API_KEY) console.log('API key auth enabled');
});
