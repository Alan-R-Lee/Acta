const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = Number(process.env.PORT || 3100);
const DATA_FILE = path.resolve(process.env.AUTH_DATA_FILE || './data/auth-store.json');
const TOKEN_TTL_HOURS = Number(process.env.TOKEN_TTL_HOURS || 168);
const CORS_ORIGIN = process.env.CORS_ORIGIN || '*';

app.use(cors({ origin: CORS_ORIGIN }));
app.use(express.json({ limit: '128kb' }));

function createEmptyStore() {
  return {
    nextUserId: 1,
    nextRouteId: 1,
    nextNoteId: 1,
    nextMemoryId: 1,
    users: [],
    sessions: [],
    routes: [],
    notes: [],
    memories: []
  };
}

function ensureStoreFile() {
  fs.mkdirSync(path.dirname(DATA_FILE), { recursive: true });
  if (!fs.existsSync(DATA_FILE)) {
    fs.writeFileSync(DATA_FILE, JSON.stringify(createEmptyStore(), null, 2));
  }
}

function readStore() {
  ensureStoreFile();
  try {
    const store = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
    return {
      nextUserId: store.nextUserId || 1,
      nextRouteId: store.nextRouteId || 1,
      nextNoteId: store.nextNoteId || 1,
      nextMemoryId: store.nextMemoryId || 1,
      users: Array.isArray(store.users) ? store.users : [],
      sessions: Array.isArray(store.sessions) ? store.sessions : [],
      routes: Array.isArray(store.routes) ? store.routes : [],
      notes: Array.isArray(store.notes) ? store.notes : [],
      memories: Array.isArray(store.memories) ? store.memories : []
    };
  } catch (error) {
    return createEmptyStore();
  }
}

function writeStore(store) {
  fs.writeFileSync(DATA_FILE, JSON.stringify(store, null, 2));
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

function sanitizeUser(user) {
  return {
    id: user.id,
    username: user.username,
    email: user.email || '',
    displayName: user.displayName || '',
    createdAt: user.createdAt
  };
}

function createSession(store, userId) {
  const token = crypto.randomBytes(32).toString('hex');
  const now = Date.now();
  const expiresAt = now + TOKEN_TTL_HOURS * 60 * 60 * 1000;
  store.sessions = store.sessions.filter((session) => session.expiresAt > now);
  store.sessions.push({ token, userId, createdAt: now, expiresAt });
  return token;
}

function findUserByToken(store, token) {
  const now = Date.now();
  const session = store.sessions.find((item) => item.token === token && item.expiresAt > now);
  if (!session) {
    return null;
  }

  return store.users.find((item) => item.id === session.userId) || null;
}

function normalizeText(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function sanitizeRoute(route) {
  return {
    id: route.id,
    userId: route.userId,
    title: route.title,
    summary: route.summary || '',
    points: Array.isArray(route.points) ? route.points : [],
    tags: Array.isArray(route.tags) ? route.tags : [],
    createdAt: route.createdAt,
    cover: route.cover || ''
  };
}

function sanitizeNote(note) {
  return {
    id: note.id,
    userId: note.userId,
    routeId: note.routeId,
    title: note.title,
    content: note.content || '',
    images: Array.isArray(note.images) ? note.images : [],
    createdAt: note.createdAt
  };
}

function sanitizeMemory(memory) {
  return {
    id: memory.id,
    userId: memory.userId,
    routeId: memory.routeId,
    pointTime: memory.pointTime,
    lat: memory.lat,
    lng: memory.lng,
    altitude: memory.altitude,
    title: memory.title,
    content: memory.content || '',
    images: Array.isArray(memory.images) ? memory.images : [],
    createdAt: memory.createdAt
  };
}

function requireUser(req, res) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token) {
    res.status(401).json({ error: 'Missing bearer token.' });
    return null;
  }

  const store = readStore();
  const user = findUserByToken(store, token);
  if (!user) {
    res.status(401).json({ error: 'Token is invalid or expired.' });
    return null;
  }

  return { store, user };
}

function findRouteById(store, routeId, userId) {
  return store.routes.find((item) => item.id === routeId && item.userId === userId) || null;
}

app.get('/health', (req, res) => {
  res.json({ ok: true, service: 'acta-auth-api' });
});

app.post('/api/auth/register', (req, res) => {
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

  const store = readStore();
  const usernameKey = username.toLowerCase();
  const emailKey = email.toLowerCase();
  const exists = store.users.some((user) => {
    return user.username.toLowerCase() === usernameKey || (emailKey && (user.email || '').toLowerCase() === emailKey);
  });
  if (exists) {
    return res.status(409).json({ error: 'Username already exists.' });
  }

  const passwordResult = hashPassword(password);
  const user = {
    id: store.nextUserId,
    username,
    email,
    displayName,
    passwordSalt: passwordResult.salt,
    passwordHash: passwordResult.hash,
    createdAt: Date.now()
  };
  store.nextUserId += 1;
  store.users.push(user);
  const token = createSession(store, user.id);
  writeStore(store);

  return res.status(201).json({
    message: 'Registered.',
    token,
    user: sanitizeUser(user)
  });
});

app.post('/api/auth/login', (req, res) => {
  const username = normalizeText(req.body && req.body.username);
  const password = req.body && req.body.password;

  if (!username || !password) {
    return res.status(400).json({ error: 'Username and password are required.' });
  }

  const store = readStore();
  const usernameKey = username.toLowerCase();
  const user = store.users.find((item) => item.username.toLowerCase() === usernameKey);
  if (!user) {
    return res.status(401).json({ error: 'Username or password is incorrect.' });
  }

  const passwordResult = hashPassword(password, user.passwordSalt);
  if (passwordResult.hash !== user.passwordHash) {
    return res.status(401).json({ error: 'Username or password is incorrect.' });
  }

  const token = createSession(store, user.id);
  writeStore(store);

  return res.json({
    message: 'Logged in.',
    token,
    user: sanitizeUser(user)
  });
});

app.get('/api/users/me', (req, res) => {
  const auth = requireUser(req, res);
  if (!auth) {
    return;
  }

  return res.json({ user: sanitizeUser(auth.user) });
});

app.get('/api/travel/snapshot', (req, res) => {
  const auth = requireUser(req, res);
  if (!auth) {
    return;
  }

  const { store, user } = auth;
  const routes = store.routes
    .filter((item) => item.userId === user.id)
    .map(sanitizeRoute);
  const notes = store.notes
    .filter((item) => item.userId === user.id)
    .map(sanitizeNote);
  const memories = store.memories
    .filter((item) => item.userId === user.id)
    .map(sanitizeMemory);

  return res.json({ routes, notes, memories });
});

app.post('/api/routes', (req, res) => {
  const auth = requireUser(req, res);
  if (!auth) {
    return;
  }

  const { store, user } = auth;
  const clientId = normalizeText(req.body && req.body.id);
  const title = normalizeText(req.body && req.body.title) || `Route ${store.nextRouteId}`;
  const existing = clientId
    ? store.routes.find((item) => item.id === clientId && item.userId === user.id)
    : null;
  if (existing) {
    return res.json({ route: sanitizeRoute(existing) });
  }

  const route = {
    id: clientId || `${store.nextRouteId}`,
    userId: user.id,
    title,
    summary: normalizeText(req.body && req.body.summary),
    points: Array.isArray(req.body && req.body.points) ? req.body.points : [],
    tags: Array.isArray(req.body && req.body.tags) ? req.body.tags : [],
    createdAt: Number(req.body && req.body.createdAt) || Date.now(),
    cover: normalizeText(req.body && req.body.cover)
  };
  store.nextRouteId += 1;
  store.routes.unshift(route);
  writeStore(store);
  return res.status(201).json({ route: sanitizeRoute(route) });
});

app.put('/api/routes/:routeId', (req, res) => {
  const auth = requireUser(req, res);
  if (!auth) {
    return;
  }

  const { store, user } = auth;
  const route = findRouteById(store, req.params.routeId, user.id);
  if (!route) {
    return res.status(404).json({ error: 'Route not found.' });
  }

  if (typeof req.body?.title === 'string') {
    route.title = normalizeText(req.body.title) || route.title;
  }
  if (typeof req.body?.summary === 'string') {
    route.summary = normalizeText(req.body.summary);
  }
  if (Array.isArray(req.body?.tags)) {
    route.tags = req.body.tags;
  }
  if (typeof req.body?.cover === 'string') {
    route.cover = normalizeText(req.body.cover);
  }
  writeStore(store);
  return res.json({ route: sanitizeRoute(route) });
});

app.post('/api/routes/:routeId/points', (req, res) => {
  const auth = requireUser(req, res);
  if (!auth) {
    return;
  }

  const { store, user } = auth;
  const route = findRouteById(store, req.params.routeId, user.id);
  if (!route) {
    return res.status(404).json({ error: 'Route not found.' });
  }

  const point = req.body || {};
  if (!Number.isFinite(point.lat) || !Number.isFinite(point.lng)) {
    return res.status(400).json({ error: 'Point lat/lng are required.' });
  }

  route.points.push({
    lat: Number(point.lat),
    lng: Number(point.lng),
    altitude: Number(point.altitude) || 0,
    altitudeAccuracy: Number.isFinite(point.altitudeAccuracy) ? Number(point.altitudeAccuracy) : undefined,
    time: Number(point.time) || Date.now(),
    note: normalizeText(point.note)
  });
  writeStore(store);
  return res.status(201).json({ route: sanitizeRoute(route) });
});

app.get('/api/routes/:routeId/notes', (req, res) => {
  const auth = requireUser(req, res);
  if (!auth) {
    return;
  }

  const { store, user } = auth;
  const route = findRouteById(store, req.params.routeId, user.id);
  if (!route) {
    return res.status(404).json({ error: 'Route not found.' });
  }

  const notes = store.notes
    .filter((item) => item.userId === user.id && item.routeId === route.id)
    .map(sanitizeNote);
  return res.json({ notes });
});

app.post('/api/routes/:routeId/notes', (req, res) => {
  const auth = requireUser(req, res);
  if (!auth) {
    return;
  }

  const { store, user } = auth;
  const route = findRouteById(store, req.params.routeId, user.id);
  if (!route) {
    return res.status(404).json({ error: 'Route not found.' });
  }

  const clientId = normalizeText(req.body && req.body.id);
  const existing = clientId
    ? store.notes.find((item) => item.id === clientId && item.userId === user.id)
    : null;
  if (existing) {
    return res.json({ note: sanitizeNote(existing) });
  }

  const note = {
    id: clientId || `${store.nextNoteId}`,
    userId: user.id,
    routeId: route.id,
    title: normalizeText(req.body && req.body.title) || 'Untitled Note',
    content: normalizeText(req.body && req.body.content),
    images: Array.isArray(req.body && req.body.images) ? req.body.images : [],
    createdAt: Number(req.body && req.body.createdAt) || Date.now()
  };
  store.nextNoteId += 1;
  store.notes.unshift(note);
  writeStore(store);
  return res.status(201).json({ note: sanitizeNote(note) });
});

app.get('/api/routes/:routeId/memories', (req, res) => {
  const auth = requireUser(req, res);
  if (!auth) {
    return;
  }

  const { store, user } = auth;
  const route = findRouteById(store, req.params.routeId, user.id);
  if (!route) {
    return res.status(404).json({ error: 'Route not found.' });
  }

  const memories = store.memories
    .filter((item) => item.userId === user.id && item.routeId === route.id)
    .map(sanitizeMemory);
  return res.json({ memories });
});

app.post('/api/routes/:routeId/memories', (req, res) => {
  const auth = requireUser(req, res);
  if (!auth) {
    return;
  }

  const { store, user } = auth;
  const route = findRouteById(store, req.params.routeId, user.id);
  if (!route) {
    return res.status(404).json({ error: 'Route not found.' });
  }

  const clientId = normalizeText(req.body && req.body.id);
  const existing = clientId
    ? store.memories.find((item) => item.id === clientId && item.userId === user.id)
    : null;
  if (existing) {
    return res.json({ memory: sanitizeMemory(existing) });
  }

  const memory = {
    id: clientId || `${store.nextMemoryId}`,
    userId: user.id,
    routeId: route.id,
    pointTime: Number(req.body && req.body.pointTime) || Date.now(),
    lat: Number(req.body && req.body.lat) || 0,
    lng: Number(req.body && req.body.lng) || 0,
    altitude: Number(req.body && req.body.altitude) || 0,
    title: normalizeText(req.body && req.body.title) || 'Untitled Memory',
    content: normalizeText(req.body && req.body.content),
    images: Array.isArray(req.body && req.body.images) ? req.body.images : [],
    createdAt: Number(req.body && req.body.createdAt) || Date.now()
  };
  store.nextMemoryId += 1;
  store.memories.unshift(memory);
  writeStore(store);
  return res.status(201).json({ memory: sanitizeMemory(memory) });
});

app.listen(PORT, () => {
  console.log(`Acta auth API listening on http://127.0.0.1:${PORT}`);
  console.log(`Auth data file: ${DATA_FILE}`);
});
