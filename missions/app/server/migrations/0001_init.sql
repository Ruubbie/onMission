-- Mission App API: accounts, devices, synced records and file metadata.
CREATE TABLE users (
  id            TEXT PRIMARY KEY,
  email         TEXT NOT NULL UNIQUE,
  name          TEXT NOT NULL,
  password_hash TEXT NOT NULL,           -- pbkdf2$iterations$salt$hash (base64url)
  created_at    TEXT NOT NULL
);

-- A space holds all records and files. One per user today; shareable later via memberships.
CREATE TABLE spaces (
  id                 TEXT PRIMARY KEY,
  name               TEXT NOT NULL,
  seq                INTEGER NOT NULL DEFAULT 0,  -- last change number handed out
  pruned_through_seq INTEGER NOT NULL DEFAULT 0,  -- tombstones with seq <= this may be gone
  created_at         TEXT NOT NULL
);

CREATE TABLE memberships (
  space_id TEXT NOT NULL REFERENCES spaces(id),
  user_id  TEXT NOT NULL REFERENCES users(id),
  role     TEXT NOT NULL CHECK (role IN ('owner', 'editor', 'viewer')),
  PRIMARY KEY (space_id, user_id)
);

CREATE TABLE devices (
  id           TEXT PRIMARY KEY,
  user_id      TEXT NOT NULL REFERENCES users(id),
  token_hash   TEXT NOT NULL UNIQUE,      -- sha256 hex of the bearer token; the token itself is never stored
  name         TEXT NOT NULL,
  platform     TEXT NOT NULL,
  app_version  TEXT,
  created_at   TEXT NOT NULL,
  last_seen_at TEXT,
  revoked_at   TEXT
);

CREATE TABLE login_failures (
  email TEXT NOT NULL,
  at    TEXT NOT NULL
);
CREATE INDEX login_failures_email ON login_failures (email, at);

CREATE TABLE records (
  space_id   TEXT NOT NULL,
  id         TEXT NOT NULL,
  collection TEXT NOT NULL,
  data       TEXT NOT NULL,               -- JSON object
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,               -- client clock, decides last-writer-wins
  deleted_at TEXT,
  seq        INTEGER NOT NULL,            -- server change number, drives pulls
  updated_by TEXT,                        -- device id
  PRIMARY KEY (space_id, id)
);
CREATE INDEX records_seq ON records (space_id, seq);
CREATE INDEX records_collection ON records (space_id, collection);

CREATE TABLE files (
  space_id    TEXT NOT NULL,
  id          TEXT NOT NULL,
  file_name   TEXT,
  mime_type   TEXT NOT NULL,
  size_bytes  INTEGER NOT NULL,
  sha256      TEXT NOT NULL,
  uploaded_at TEXT NOT NULL,
  PRIMARY KEY (space_id, id)
);
