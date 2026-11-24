export const HISTORY_TABLE_NAME: string = 'library_reading_history';
export const STATE_TABLE_NAME: string = 'library_reading_state';

export const CREATE_HISTORY_TABLE: string =
  'CREATE TABLE IF NOT EXISTS library_reading_history (' +
  'content_key TEXT PRIMARY KEY, content_id TEXT NOT NULL, title TEXT NOT NULL, ' +
  'content_kind TEXT NOT NULL, opened_at INTEGER NOT NULL, ' +
  'last_read_at INTEGER NOT NULL, scroll_offset INTEGER NOT NULL, ' +
  'completed INTEGER NOT NULL DEFAULT 0)';

export const ADD_HISTORY_COMPLETED_COLUMN: string =
  'ALTER TABLE library_reading_history ADD COLUMN completed INTEGER NOT NULL DEFAULT 0';

export const CREATE_HISTORY_TIME_INDEX: string =
  'CREATE INDEX IF NOT EXISTS idx_library_reading_history_time ' +
  'ON library_reading_history(last_read_at DESC, content_key ASC)';

export const CREATE_STATE_TABLE: string =
  'CREATE TABLE IF NOT EXISTS library_reading_state (' +
  'content_key TEXT PRIMARY KEY, content_id TEXT NOT NULL, title TEXT NOT NULL, ' +
  'content_kind TEXT NOT NULL, scroll_offset INTEGER NOT NULL DEFAULT 0, ' +
  'completed INTEGER NOT NULL DEFAULT 0, completed_at INTEGER NOT NULL DEFAULT 0, ' +
  'updated_at INTEGER NOT NULL DEFAULT 0)';

export const CREATE_STATE_UPDATED_INDEX: string =
  'CREATE INDEX IF NOT EXISTS idx_library_reading_state_updated ' +
  'ON library_reading_state(updated_at DESC, content_key ASC)';

/** Idempotently backfill permanent states from existing history rows on upgrade. */
export const BACKFILL_STATE_FROM_HISTORY: string =
  'INSERT OR IGNORE INTO library_reading_state (' +
  'content_key, content_id, title, content_kind, scroll_offset, completed, completed_at, updated_at' +
  ') SELECT ' +
  'content_key, content_id, title, content_kind, ' +
  'CASE WHEN scroll_offset > 0 THEN scroll_offset ELSE 0 END, ' +
  'CASE WHEN completed > 0 THEN 1 ELSE 0 END, ' +
  'CASE WHEN completed > 0 THEN last_read_at ELSE 0 END, ' +
  'last_read_at ' +
  'FROM library_reading_history ' +
  'WHERE (scroll_offset > 0 OR completed > 0) ' +
  "AND content_kind IN ('scp', 'tale', 'wiki', 'knowledge') " +
  'AND length(trim(content_id)) > 0';

export function buildPruneHistorySql(limit: number): string {
  const safeLimit = Number.isFinite(limit) && limit >= 1 ? Math.floor(limit) : 1;
  return 'DELETE FROM library_reading_history WHERE content_key NOT IN (' +
    'SELECT content_key FROM library_reading_history ' +
    `ORDER BY last_read_at DESC, content_key ASC LIMIT ${safeLimit})`;
}
