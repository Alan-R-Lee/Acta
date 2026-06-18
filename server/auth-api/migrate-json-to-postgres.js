const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');
require('dotenv').config();

const DATABASE_URL = process.env.DATABASE_URL;
const DATA_FILE = path.resolve(process.env.AUTH_DATA_FILE || './data/auth-store.json');

if (!DATABASE_URL) {
  console.error('DATABASE_URL is required.');
  process.exit(1);
}

if (!fs.existsSync(DATA_FILE)) {
  console.error(`JSON data file not found: ${DATA_FILE}`);
  process.exit(1);
}

const pool = new Pool({
  connectionString: DATABASE_URL,
  ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : undefined
});

function parseStore() {
  const store = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
  return {
    users: Array.isArray(store.users) ? store.users : [],
    sessions: Array.isArray(store.sessions) ? store.sessions : [],
    routes: Array.isArray(store.routes) ? store.routes : [],
    notes: Array.isArray(store.notes) ? store.notes : [],
    memories: Array.isArray(store.memories) ? store.memories : []
  };
}

function toDate(value) {
  return new Date(Number(value) || Date.now());
}

async function initDb(client) {
  await client.query(`
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

async function run() {
  const store = parseStore();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await initDb(client);

    for (const user of store.users) {
      await client.query(`
        INSERT INTO users (id, username, email, display_name, password_salt, password_hash, created_at)
        VALUES ($1, $2, NULLIF($3, ''), $4, $5, $6, $7)
        ON CONFLICT (id) DO UPDATE SET
          username = EXCLUDED.username,
          email = EXCLUDED.email,
          display_name = EXCLUDED.display_name,
          password_salt = EXCLUDED.password_salt,
          password_hash = EXCLUDED.password_hash
      `, [
        user.id,
        user.username,
        user.email || '',
        user.displayName || '',
        user.passwordSalt,
        user.passwordHash,
        toDate(user.createdAt)
      ]);
    }

    for (const session of store.sessions) {
      await client.query(`
        INSERT INTO sessions (token, user_id, created_at, expires_at)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (token) DO NOTHING
      `, [
        session.token,
        session.userId,
        toDate(session.createdAt),
        toDate(session.expiresAt)
      ]);
    }

    for (const route of store.routes) {
      await client.query(`
        INSERT INTO routes (id, user_id, title, summary, points, tags, cover, created_at)
        VALUES ($1, $2, $3, $4, $5::jsonb, $6::jsonb, $7, $8)
        ON CONFLICT (id) DO UPDATE SET
          title = EXCLUDED.title,
          summary = EXCLUDED.summary,
          points = EXCLUDED.points,
          tags = EXCLUDED.tags,
          cover = EXCLUDED.cover
      `, [
        route.id,
        route.userId,
        route.title,
        route.summary || '',
        JSON.stringify(Array.isArray(route.points) ? route.points : []),
        JSON.stringify(Array.isArray(route.tags) ? route.tags : []),
        route.cover || '',
        toDate(route.createdAt)
      ]);
    }

    for (const note of store.notes) {
      await client.query(`
        INSERT INTO notes (id, user_id, route_id, title, content, images, created_at)
        VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7)
        ON CONFLICT (id) DO UPDATE SET
          title = EXCLUDED.title,
          content = EXCLUDED.content,
          images = EXCLUDED.images
      `, [
        note.id,
        note.userId,
        note.routeId,
        note.title,
        note.content || '',
        JSON.stringify(Array.isArray(note.images) ? note.images : []),
        toDate(note.createdAt)
      ]);
    }

    for (const memory of store.memories) {
      await client.query(`
        INSERT INTO memories (id, user_id, route_id, point_time, lat, lng, altitude, title, content, images, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::jsonb, $11)
        ON CONFLICT (id) DO UPDATE SET
          point_time = EXCLUDED.point_time,
          lat = EXCLUDED.lat,
          lng = EXCLUDED.lng,
          altitude = EXCLUDED.altitude,
          title = EXCLUDED.title,
          content = EXCLUDED.content,
          images = EXCLUDED.images
      `, [
        memory.id,
        memory.userId,
        memory.routeId,
        toDate(memory.pointTime),
        Number(memory.lat) || 0,
        Number(memory.lng) || 0,
        Number(memory.altitude) || 0,
        memory.title,
        memory.content || '',
        JSON.stringify(Array.isArray(memory.images) ? memory.images : []),
        toDate(memory.createdAt)
      ]);
    }

    await client.query("SELECT setval(pg_get_serial_sequence('users', 'id'), COALESCE((SELECT MAX(id) FROM users), 1), true)");
    await client.query('COMMIT');
    console.log(`Imported ${store.users.length} users, ${store.routes.length} routes, ${store.notes.length} notes, ${store.memories.length} memories.`);
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
