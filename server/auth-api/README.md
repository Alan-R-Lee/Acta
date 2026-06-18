# Acta Auth API

Node/Express backend for Acta authentication and travel data sync. Runtime storage is PostgreSQL.

## Environment

Copy `.env.example` to `.env` and set:

```env
PORT=3100
DATABASE_URL=postgresql://acta_user:change_me@127.0.0.1:5432/acta
DATABASE_SSL=false
AUTH_DATA_FILE=./data/auth-store.json
TOKEN_TTL_HOURS=168
CORS_ORIGIN=*
```

`AUTH_DATA_FILE` is only used by the one-time JSON migration script.

## Start

```bash
cd server/auth-api
npm install
npm start
```

Health check:

```bash
curl http://127.0.0.1:3100/health
```

Expected response:

```json
{"ok":true,"service":"acta-auth-api","storage":"postgres"}
```

## Migrate Existing JSON Data

If the previous server has `data/auth-store.json`, configure `DATABASE_URL` first, then run:

```bash
npm run migrate:json
```

The script imports users, sessions, routes, notes, and memories into PostgreSQL. It creates the required tables if they do not exist.

## API

Auth:

```http
POST /api/auth/register
POST /api/auth/login
GET /api/users/me
```

Travel data:

```http
GET /api/travel/snapshot
POST /api/routes
PUT /api/routes/:routeId
POST /api/routes/:routeId/points
GET /api/routes/:routeId/notes
POST /api/routes/:routeId/notes
GET /api/routes/:routeId/memories
POST /api/routes/:routeId/memories
```

All travel endpoints require:

```http
Authorization: Bearer <token>
```

## Azure VM Notes

Install PostgreSQL on the VM, create the database/user, update `.env`, run the migration once, then restart PM2:

```bash
sudo apt install -y postgresql postgresql-contrib
sudo -u postgres psql
```

Inside `psql`:

```sql
CREATE DATABASE acta;
CREATE USER acta_user WITH ENCRYPTED PASSWORD 'change_this_password';
GRANT ALL PRIVILEGES ON DATABASE acta TO acta_user;
\c acta
GRANT ALL ON SCHEMA public TO acta_user;
```

Then:

```bash
cd /home/azureuser/auth-api
npm install
npm run migrate:json
pm2 restart acta-auth-api --update-env
```
