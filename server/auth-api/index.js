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
    users: [],
    sessions: []
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
      users: Array.isArray(store.users) ? store.users : [],
      sessions: Array.isArray(store.sessions) ? store.sessions : []
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
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token) {
    return res.status(401).json({ error: 'Missing bearer token.' });
  }

  const store = readStore();
  const user = findUserByToken(store, token);
  if (!user) {
    return res.status(401).json({ error: 'Token is invalid or expired.' });
  }

  return res.json({ user: sanitizeUser(user) });
});

app.listen(PORT, () => {
  console.log(`Acta auth API listening on http://127.0.0.1:${PORT}`);
  console.log(`Auth data file: ${DATA_FILE}`);
});
