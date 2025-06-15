# tracking.sh
TRACKING_DB="${ROOT_DIR}/tracking.db"

function init_db() {
  DebugEcho "Initializing SQLite DB at ${TRACKING_DB}"
  sqlite3 "${TRACKING_DB}" <<SQL
CREATE TABLE IF NOT EXISTS books (
  id TEXT PRIMARY KEY,
  path TEXT,
  state TEXT,
  updated_at TEXT
);
SQL
}
