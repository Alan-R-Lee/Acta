const crypto = require('crypto');
const fs = require('fs');
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
const PORT = Number(process.env.PORT || 3100);
const TOKEN_TTL_HOURS = Number(process.env.TOKEN_TTL_HOURS || 168);
const CORS_ORIGIN = process.env.CORS_ORIGIN || '*';
const DATABASE_URL = process.env.DATABASE_URL;
const HUAWEI_AI_ENDPOINT = process.env.HUAWEI_AI_ENDPOINT || '';
const HUAWEI_AI_CREDENTIALS_PATH = process.env.HUAWEI_AI_CREDENTIALS_PATH || '';
const HUAWEI_AI_TOKEN_URI = process.env.HUAWEI_AI_TOKEN_URI || '';
const HUAWEI_AI_SCOPE = process.env.HUAWEI_AI_SCOPE || '';
const HUAWEI_AI_MODEL = process.env.HUAWEI_AI_MODEL || '';

if (!DATABASE_URL) {
  console.error('DATABASE_URL is required. PostgreSQL storage is now the production data store.');
  process.exit(1);
}

const pool = new Pool({
  connectionString: DATABASE_URL,
  ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : undefined
});

let huaweiCredentialCache = null;
let huaweiAccessTokenCache = {
  accessToken: '',
  expiresAt: 0
};

app.use(cors({ origin: CORS_ORIGIN }));
app.use(express.json({ limit: '512kb' }));

function asyncHandler(handler) {
  return (req, res, next) => {
    Promise.resolve(handler(req, res, next)).catch(next);
  };
}

function hashPassword(password, salt = crypto.randomBytes(16).toString('hex')) {
  const hash = crypto.pbkdf2Sync(password, salt, 120000, 32, 'sha256').toString('hex');
  return { salt, hash };
}

function isPasswordValid(password) {
  return typeof password === 'string'
    && password.length >= 8
    && /[A-Za-z]/.test(password)
    && /\d/.test(password);
}

function normalizeText(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function toMillis(value) {
  if (!value) {
    return Date.now();
  }
  if (typeof value === 'number') {
    return value;
  }
  return new Date(value).getTime();
}

function millisToDate(value) {
  return new Date(Number(value) || Date.now());
}

function sanitizeUser(row) {
  return {
    id: row.id,
    username: row.username,
    email: row.email || '',
    displayName: row.display_name || '',
    avatar: row.avatar || '',
    createdAt: toMillis(row.created_at)
  };
}

function sanitizeRoute(row) {
  return {
    id: row.id,
    userId: row.user_id,
    title: row.title,
    summary: row.summary || '',
    points: Array.isArray(row.points) ? row.points : [],
    tags: Array.isArray(row.tags) ? row.tags : [],
    createdAt: toMillis(row.created_at),
    cover: row.cover || ''
  };
}

function sanitizeNote(row) {
  return {
    id: row.id,
    userId: row.user_id,
    routeId: row.route_id,
    title: row.title,
    content: row.content || '',
    images: Array.isArray(row.images) ? row.images : [],
    createdAt: toMillis(row.created_at)
  };
}

function sanitizeMemory(row) {
  return {
    id: row.id,
    userId: row.user_id,
    routeId: row.route_id,
    pointTime: toMillis(row.point_time),
    lat: Number(row.lat) || 0,
    lng: Number(row.lng) || 0,
    altitude: Number(row.altitude) || 0,
    title: row.title,
    content: row.content || '',
    images: Array.isArray(row.images) ? row.images : [],
    createdAt: toMillis(row.created_at)
  };
}

function base64UrlEncode(value) {
  const buffer = Buffer.isBuffer(value) ? value : Buffer.from(value);
  return buffer.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function loadHuaweiCredentials() {
  if (huaweiCredentialCache) {
    return huaweiCredentialCache;
  }

  if (!HUAWEI_AI_CREDENTIALS_PATH) {
    throw new Error('HUAWEI_AI_CREDENTIALS_PATH is not configured.');
  }

  const raw = fs.readFileSync(HUAWEI_AI_CREDENTIALS_PATH, 'utf8');
  const json = JSON.parse(raw);
  huaweiCredentialCache = json;
  return huaweiCredentialCache;
}

function buildServiceAccountJwt(credentials, tokenUri) {
  const issuedAt = Math.floor(Date.now() / 1000);
  const expiresAt = issuedAt + 3600;
  const header = {
    alg: 'RS256',
    typ: 'JWT',
    kid: credentials.private_key_id || undefined
  };

  const payload = {
    iss: credentials.client_email,
    sub: credentials.client_email,
    aud: tokenUri,
    iat: issuedAt,
    exp: expiresAt
  };

  if (HUAWEI_AI_SCOPE) {
    payload.scope = HUAWEI_AI_SCOPE;
  }

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;
  const signature = crypto.sign('RSA-SHA256', Buffer.from(unsignedToken), credentials.private_key);
  return `${unsignedToken}.${base64UrlEncode(signature)}`;
}

async function fetchHuaweiAccessToken() {
  if (huaweiAccessTokenCache.accessToken && Date.now() < huaweiAccessTokenCache.expiresAt - 60_000) {
    return huaweiAccessTokenCache.accessToken;
  }

  const credentials = loadHuaweiCredentials();
  const tokenUri = HUAWEI_AI_TOKEN_URI || credentials.token_uri;
  if (!tokenUri) {
    throw new Error('Huawei token URI is missing. Set HUAWEI_AI_TOKEN_URI or provide token_uri in credentials JSON.');
  }

  const assertion = buildServiceAccountJwt(credentials, tokenUri);
  const body = new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion
  });

  const response = await fetch(tokenUri, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: body.toString()
  });
  const text = await response.text();
  let data = {};
  try {
    data = text ? JSON.parse(text) : {};
  } catch (error) {
    data = { raw: text };
  }

  if (!response.ok || !data.access_token) {
    throw new Error(`Huawei token request failed: ${response.status} ${JSON.stringify(data)}`);
  }

  const expiresIn = Number(data.expires_in) || 3600;
  huaweiAccessTokenCache = {
    accessToken: data.access_token,
    expiresAt: Date.now() + expiresIn * 1000
  };
  return huaweiAccessTokenCache.accessToken;
}

async function initDb() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id BIGSERIAL PRIMARY KEY,
      username TEXT NOT NULL UNIQUE,
      email TEXT UNIQUE,
      display_name TEXT NOT NULL DEFAULT '',
      avatar TEXT NOT NULL DEFAULT '',
      password_salt TEXT NOT NULL,
      password_hash TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS sessions (
      token TEXT PRIMARY KEY,
      user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      expires_at TIMESTAMPTZ NOT NULL
    );

    CREATE TABLE IF NOT EXISTS routes (
      id TEXT PRIMARY KEY,
      user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      summary TEXT NOT NULL DEFAULT '',
      points JSONB NOT NULL DEFAULT '[]'::jsonb,
      tags JSONB NOT NULL DEFAULT '[]'::jsonb,
      cover TEXT NOT NULL DEFAULT '',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS notes (
      id TEXT PRIMARY KEY,
      user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      route_id TEXT NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      content TEXT NOT NULL DEFAULT '',
      images JSONB NOT NULL DEFAULT '[]'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS memories (
      id TEXT PRIMARY KEY,
      user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      route_id TEXT NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
      point_time TIMESTAMPTZ NOT NULL,
      lat DOUBLE PRECISION NOT NULL DEFAULT 0,
      lng DOUBLE PRECISION NOT NULL DEFAULT 0,
      altitude DOUBLE PRECISION NOT NULL DEFAULT 0,
      title TEXT NOT NULL,
      content TEXT NOT NULL DEFAULT '',
      images JSONB NOT NULL DEFAULT '[]'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS idx_routes_user_created ON routes(user_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_notes_route_created ON notes(route_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_memories_route_created ON memories(route_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_sessions_expires ON sessions(expires_at);
  `);

  await pool.query(`
    ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar TEXT NOT NULL DEFAULT '';
  `);
}

async function createSession(client, userId) {
  const token = crypto.randomBytes(32).toString('hex');
  const expiresAt = new Date(Date.now() + TOKEN_TTL_HOURS * 60 * 60 * 1000);
  await client.query('DELETE FROM sessions WHERE expires_at <= NOW()');
  await client.query(
    'INSERT INTO sessions (token, user_id, expires_at) VALUES ($1, $2, $3)',
    [token, userId, expiresAt]
  );
  return token;
}

async function requireUser(req, res) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token) {
    res.status(401).json({ error: 'Missing bearer token.' });
    return null;
  }

  const result = await pool.query(`
    SELECT users.*
    FROM sessions
    JOIN users ON users.id = sessions.user_id
    WHERE sessions.token = $1 AND sessions.expires_at > NOW()
  `, [token]);

  if (result.rowCount === 0) {
    res.status(401).json({ error: 'Token is invalid or expired.' });
    return null;
  }

  return result.rows[0];
}

async function findRoute(routeId, userId) {
  const result = await pool.query(
    'SELECT * FROM routes WHERE id = $1 AND user_id = $2',
    [routeId, userId]
  );
  return result.rows[0] || null;
}

app.get('/health', (req, res) => {
  res.json({ ok: true, service: 'acta-auth-api', storage: 'postgres' });
});

app.post('/api/auth/register', asyncHandler(async (req, res) => {
  const username = normalizeText(req.body && req.body.username);
  const password = req.body && req.body.password;
  const email = normalizeText(req.body && req.body.email);
  const displayName = normalizeText(req.body && req.body.displayName);

  if (username.length < 3) {
    return res.status(400).json({ error: 'Username must be at least 3 characters.' });
  }
  if (!isPasswordValid(password)) {
    return res.status(400).json({ error: 'Password must be at least 8 characters and include letters and numbers.' });
  }
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return res.status(400).json({ error: 'Email is invalid.' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const passwordResult = hashPassword(password);
    const insertResult = await client.query(`
      INSERT INTO users (username, email, display_name, password_salt, password_hash)
      VALUES ($1, NULLIF($2, ''), $3, $4, $5)
      RETURNING *
    `, [username, email, displayName, passwordResult.salt, passwordResult.hash]);
    const user = insertResult.rows[0];
    const token = await createSession(client, user.id);
    await client.query('COMMIT');
    return res.status(201).json({ message: 'Registered.', token, user: sanitizeUser(user) });
  } catch (error) {
    await client.query('ROLLBACK');
    if (error.code === '23505') {
      return res.status(409).json({ error: 'Username already exists.' });
    }
    throw error;
  } finally {
    client.release();
  }
}));

app.post('/api/auth/login', asyncHandler(async (req, res) => {
  const username = normalizeText(req.body && req.body.username);
  const password = req.body && req.body.password;

  if (!username || !password) {
    return res.status(400).json({ error: 'Username and password are required.' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await client.query(
      'SELECT * FROM users WHERE LOWER(username) = LOWER($1)',
      [username]
    );
    const user = result.rows[0];
    if (!user) {
      await client.query('ROLLBACK');
      return res.status(401).json({ error: 'Username or password is incorrect.' });
    }

    const passwordResult = hashPassword(password, user.password_salt);
    if (passwordResult.hash !== user.password_hash) {
      await client.query('ROLLBACK');
      return res.status(401).json({ error: 'Username or password is incorrect.' });
    }

    const token = await createSession(client, user.id);
    await client.query('COMMIT');
    return res.json({ message: 'Logged in.', token, user: sanitizeUser(user) });
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}));

app.get('/api/users/me', asyncHandler(async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) {
    return;
  }

  return res.json({ user: sanitizeUser(user) });
}));

app.put('/api/users/me', asyncHandler(async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) {
    return;
  }

  const displayName = typeof req.body?.displayName === 'string'
    ? normalizeText(req.body.displayName)
    : user.display_name;
  const avatar = typeof req.body?.avatar === 'string'
    ? req.body.avatar.trim()
    : user.avatar;

  const result = await pool.query(`
    UPDATE users
    SET display_name = $2,
        avatar = $3
    WHERE id = $1
    RETURNING *
  `, [user.id, displayName, avatar]);

  return res.json({ message: 'Profile updated.', user: sanitizeUser(result.rows[0]) });
}));

app.post('/api/ai/ask', asyncHandler(async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) {
    return;
  }

  const prompt = normalizeText(req.body && req.body.prompt);
  if (!prompt) {
    return res.status(400).json({ error: 'Prompt is required.' });
  }

  if (!HUAWEI_AI_ENDPOINT || !HUAWEI_AI_CREDENTIALS_PATH) {
    return res.status(500).json({ error: 'Huawei AI credentials are not configured.' });
  }

  const payload = HUAWEI_AI_MODEL
    ? {
        model: HUAWEI_AI_MODEL,
        messages: [
          { role: 'system', content: 'You are a helpful travel assistant for the Acta app.' },
          { role: 'user', content: prompt }
        ]
      }
    : { prompt };

  const accessToken = await fetchHuaweiAccessToken();

  const upstream = await fetch(HUAWEI_AI_ENDPOINT, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${accessToken}`
    },
    body: JSON.stringify(payload)
  });

  const text = await upstream.text();
  let data = {};
  try {
    data = text ? JSON.parse(text) : {};
  } catch (error) {
    data = { raw: text };
  }

  if (!upstream.ok) {
    return res.status(502).json({
      error: 'Huawei AI upstream request failed.',
      detail: data
    });
  }

  const result =
    data?.choices?.[0]?.message?.content
    || data?.result
    || data?.output
    || data?.answer
    || data?.content
    || text;

  return res.json({ result });
}));

app.get('/api/travel/snapshot', asyncHandler(async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) {
    return;
  }

  const [routesResult, notesResult, memoriesResult] = await Promise.all([
    pool.query('SELECT * FROM routes WHERE user_id = $1 ORDER BY created_at DESC', [user.id]),
    pool.query('SELECT * FROM notes WHERE user_id = $1 ORDER BY created_at DESC', [user.id]),
    pool.query('SELECT * FROM memories WHERE user_id = $1 ORDER BY created_at DESC', [user.id])
  ]);

  return res.json({
    routes: routesResult.rows.map(sanitizeRoute),
    notes: notesResult.rows.map(sanitizeNote),
    memories: memoriesResult.rows.map(sanitizeMemory)
  });
}));

app.post('/api/routes', asyncHandler(async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) {
    return;
  }

  const clientId = normalizeText(req.body && req.body.id) || `${Date.now()}`;
  const title = normalizeText(req.body && req.body.title) || 'Untitled Route';
  const result = await pool.query(`
    INSERT INTO routes (id, user_id, title, summary, points, tags, cover, created_at)
    VALUES ($1, $2, $3, $4, $5::jsonb, $6::jsonb, $7, $8)
    ON CONFLICT (id) DO NOTHING
    RETURNING *
  `, [
    clientId,
    user.id,
    title,
    normalizeText(req.body && req.body.summary),
    JSON.stringify(Array.isArray(req.body?.points) ? req.body.points : []),
    JSON.stringify(Array.isArray(req.body?.tags) ? req.body.tags : []),
    normalizeText(req.body && req.body.cover),
    millisToDate(req.body && req.body.createdAt)
  ]);

  if (result.rowCount > 0) {
    return res.status(201).json({ route: sanitizeRoute(result.rows[0]) });
  }

  const existing = await findRoute(clientId, user.id);
  if (existing) {
    return res.json({ route: sanitizeRoute(existing) });
  }

  return res.status(409).json({ error: 'Route id already exists.' });
}));

app.put('/api/routes/:routeId', asyncHandler(async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) {
    return;
  }

  const route = await findRoute(req.params.routeId, user.id);
  if (!route) {
    return res.status(404).json({ error: 'Route not found.' });
  }

  const result = await pool.query(`
    UPDATE routes
    SET title = COALESCE(NULLIF($3, ''), title),
        summary = $4,
        tags = COALESCE($5::jsonb, tags),
        cover = $6
    WHERE id = $1 AND user_id = $2
    RETURNING *
  `, [
    req.params.routeId,
    user.id,
    typeof req.body?.title === 'string' ? normalizeText(req.body.title) : '',
    typeof req.body?.summary === 'string' ? normalizeText(req.body.summary) : route.summary,
    Array.isArray(req.body?.tags) ? JSON.stringify(req.body.tags) : null,
    typeof req.body?.cover === 'string' ? normalizeText(req.body.cover) : route.cover
  ]);

  return res.json({ route: sanitizeRoute(result.rows[0]) });
}));

app.delete('/api/routes/:routeId', asyncHandler(async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) {
    return;
  }

  const result = await pool.query(
    'DELETE FROM routes WHERE id = $1 AND user_id = $2 RETURNING id',
    [req.params.routeId, user.id]
  );
  if (result.rowCount === 0) {
    return res.status(404).json({ error: 'Route not found.' });
  }

  return res.json({ message: 'Route deleted.' });
}));

app.post('/api/routes/:routeId/points', asyncHandler(async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) {
    return;
  }

  const route = await findRoute(req.params.routeId, user.id);
  if (!route) {
    return res.status(404).json({ error: 'Route not found.' });
  }

  const point = req.body || {};
  if (!Number.isFinite(point.lat) || !Number.isFinite(point.lng)) {
    return res.status(400).json({ error: 'Point lat/lng are required.' });
  }

  const nextPoint = {
    lat: Number(point.lat),
    lng: Number(point.lng),
    altitude: Number(point.altitude) || 0,
    altitudeAccuracy: Number.isFinite(point.altitudeAccuracy) ? Number(point.altitudeAccuracy) : undefined,
    time: Number(point.time) || Date.now(),
    note: normalizeText(point.note)
  };
  const points = Array.isArray(route.points) ? [...route.points, nextPoint] : [nextPoint];
  const result = await pool.query(
    'UPDATE routes SET points = $3::jsonb WHERE id = $1 AND user_id = $2 RETURNING *',
    [req.params.routeId, user.id, JSON.stringify(points)]
  );
  return res.status(201).json({ route: sanitizeRoute(result.rows[0]) });
}));

app.get('/api/routes/:routeId/notes', asyncHandler(async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) {
    return;
  }

  const route = await findRoute(req.params.routeId, user.id);
  if (!route) {
    return res.status(404).json({ error: 'Route not found.' });
  }

  const result = await pool.query(
    'SELECT * FROM notes WHERE user_id = $1 AND route_id = $2 ORDER BY created_at DESC',
    [user.id, req.params.routeId]
  );
  return res.json({ notes: result.rows.map(sanitizeNote) });
}));

app.post('/api/routes/:routeId/notes', asyncHandler(async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) {
    return;
  }

  const route = await findRoute(req.params.routeId, user.id);
  if (!route) {
    return res.status(404).json({ error: 'Route not found.' });
  }

  const id = normalizeText(req.body && req.body.id) || `${Date.now()}`;
  const result = await pool.query(`
    INSERT INTO notes (id, user_id, route_id, title, content, images, created_at)
    VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7)
    ON CONFLICT (id) DO NOTHING
    RETURNING *
  `, [
    id,
    user.id,
    route.id,
    normalizeText(req.body && req.body.title) || 'Untitled Note',
    normalizeText(req.body && req.body.content),
    JSON.stringify(Array.isArray(req.body?.images) ? req.body.images : []),
    millisToDate(req.body && req.body.createdAt)
  ]);

  if (result.rowCount > 0) {
    return res.status(201).json({ note: sanitizeNote(result.rows[0]) });
  }

  const existing = await pool.query(
    'SELECT * FROM notes WHERE id = $1 AND user_id = $2',
    [id, user.id]
  );
  if (existing.rowCount > 0) {
    return res.json({ note: sanitizeNote(existing.rows[0]) });
  }

  return res.status(409).json({ error: 'Note id already exists.' });
}));

app.put('/api/routes/:routeId/notes/:noteId', asyncHandler(async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) {
    return;
  }

  const route = await findRoute(req.params.routeId, user.id);
  if (!route) {
    return res.status(404).json({ error: 'Route not found.' });
  }

  const existing = await pool.query(
    'SELECT * FROM notes WHERE id = $1 AND user_id = $2 AND route_id = $3',
    [req.params.noteId, user.id, route.id]
  );
  if (existing.rowCount === 0) {
    return res.status(404).json({ error: 'Note not found.' });
  }

  const current = existing.rows[0];
  const result = await pool.query(`
    UPDATE notes
    SET title = COALESCE(NULLIF($4, ''), title),
        content = $5,
        images = $6::jsonb
    WHERE id = $1 AND user_id = $2 AND route_id = $3
    RETURNING *
  `, [
    req.params.noteId,
    user.id,
    route.id,
    typeof req.body?.title === 'string' ? normalizeText(req.body.title) : current.title,
    typeof req.body?.content === 'string' ? normalizeText(req.body.content) : current.content,
    JSON.stringify(Array.isArray(req.body?.images) ? req.body.images : (Array.isArray(current.images) ? current.images : []))
  ]);

  return res.json({ note: sanitizeNote(result.rows[0]) });
}));

app.get('/api/routes/:routeId/memories', asyncHandler(async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) {
    return;
  }

  const route = await findRoute(req.params.routeId, user.id);
  if (!route) {
    return res.status(404).json({ error: 'Route not found.' });
  }

  const result = await pool.query(
    'SELECT * FROM memories WHERE user_id = $1 AND route_id = $2 ORDER BY created_at DESC',
    [user.id, req.params.routeId]
  );
  return res.json({ memories: result.rows.map(sanitizeMemory) });
}));

app.post('/api/routes/:routeId/memories', asyncHandler(async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) {
    return;
  }

  const route = await findRoute(req.params.routeId, user.id);
  if (!route) {
    return res.status(404).json({ error: 'Route not found.' });
  }

  const id = normalizeText(req.body && req.body.id) || `${Date.now()}`;
  const result = await pool.query(`
    INSERT INTO memories (id, user_id, route_id, point_time, lat, lng, altitude, title, content, images, created_at)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::jsonb, $11)
    ON CONFLICT (id) DO NOTHING
    RETURNING *
  `, [
    id,
    user.id,
    route.id,
    millisToDate(req.body && req.body.pointTime),
    Number(req.body && req.body.lat) || 0,
    Number(req.body && req.body.lng) || 0,
    Number(req.body && req.body.altitude) || 0,
    normalizeText(req.body && req.body.title) || 'Untitled Memory',
    normalizeText(req.body && req.body.content),
    JSON.stringify(Array.isArray(req.body?.images) ? req.body.images : []),
    millisToDate(req.body && req.body.createdAt)
  ]);

  if (result.rowCount > 0) {
    return res.status(201).json({ memory: sanitizeMemory(result.rows[0]) });
  }

  const existing = await pool.query(
    'SELECT * FROM memories WHERE id = $1 AND user_id = $2',
    [id, user.id]
  );
  if (existing.rowCount > 0) {
    return res.json({ memory: sanitizeMemory(existing.rows[0]) });
  }

  return res.status(409).json({ error: 'Memory id already exists.' });
}));

app.use((error, req, res, next) => {
  console.error(error);
  res.status(500).json({ error: 'Internal server error.' });
});

initDb().then(() => {
  app.listen(PORT, () => {
    console.log(`Acta auth API listening on http://127.0.0.1:${PORT}`);
    console.log('Storage: PostgreSQL');
  });
}).catch((error) => {
  console.error('Failed to initialize database.');
  console.error(error);
  process.exit(1);
});
