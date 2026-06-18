const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
const PORT = Number(process.env.PORT || 3100);
const TOKEN_TTL_HOURS = Number(process.env.TOKEN_TTL_HOURS || 168);
const CORS_ORIGIN = process.env.CORS_ORIGIN || '*';
const DATABASE_URL = process.env.DATABASE_URL;

if (!DATABASE_URL) {
  console.error('DATABASE_URL is required. PostgreSQL storage is now the production data store.');
  process.exit(1);
}

const pool = new Pool({
  connectionString: DATABASE_URL,
  ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : undefined
});

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

async function initDb() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id BIGSERIAL PRIMARY KEY,
      username TEXT NOT NULL UNIQUE,
      email TEXT UNIQUE,
      display_name TEXT NOT NULL DEFAULT '',
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
